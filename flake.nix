{
  description = "A volumetric screen simulation";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/23.11";
    k4a.url = "github:RobbieBuxton/k4a-nix";
  };

  outputs = { self, nixpkgs, k4a }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ dlibOverlay ];
        config.cudaSupport = true;
        config.allowUnfree = true;
      };

      #This fixes the dlib package (I think i'll put a pr into nixpkgs)
      dlibOverlay = self: super: {
        blas = super.blas.override { blasProvider = self.mkl; };

        lapack = super.lapack.override { lapackProvider = self.mkl; };
        dlib =
          let
            cudaDeps =
              if super.config.cudaSupport then [
                super.cudaPackages.cudatoolkit
                super.cudaPackages.cudnn
                self.fftw
                self.blas
              ] else
                [ ];
          in
          super.dlib.overrideAttrs (oldAttrs: {
            buildInputs = oldAttrs.buildInputs ++ cudaDeps;

            # Use CUDA stdenv if CUDA is enabled
            stdenv =
              if super.config.cudaSupport then
                super.cudaPackages.backendStdenv
              else
                oldAttrs.stdenv;
          });
      };

      opencv = (pkgs.opencv.override { enableGtk2 = true; });

      dlib = (pkgs.dlib.override {
        guiSupport = true;
        cudaSupport = true;
        avxSupport = true;
        sse4Support = true;
      });

      tinyobjloaderSrc = builtins.fetchurl {
        url =
          "https://raw.githubusercontent.com/tinyobjloader/tinyobjloader/release/tiny_obj_loader.h";
        sha256 = "sha256:1yhdm96zmpak0gma019xh9d0v1m99vm0akk5qy7v4gyaj0a50690";
      };
      concatStringsWithSpace = pkgs.lib.strings.concatStringsSep " ";
    in
    {
      # Development shell used by running "nix develop".
      # It will configure vscode settings for finding the correct c++ libs for Intellisense
      devShells.${system}.default = pkgs.mkShell rec {
        name = "volumetricSim";

        enableParallelBuilding = true;

        packages = [
          k4a.packages.${system}.libk4a-dev
          k4a.packages.${system}.k4a-tools
          pkgs.nixpkgs-fmt

          #Setup and window
          pkgs.gcc
          pkgs.python310Packages.glad2
          pkgs.glxinfo
          pkgs.killall
          pkgs.jq

          # Libs
          dlib
          opencv
          pkgs.cudatoolkit
          pkgs.cudaPackages.cudnn
          pkgs.linuxPackages.nvidia_x11
          pkgs.glfw
          pkgs.glm
          pkgs.stb
          pkgs.xorg.libX11
          pkgs.xorg.libXrandr
          pkgs.xorg.libXi

          # Debug 
          pkgs.dpkg
        ];

        shellHook =
          let
            vscodeDir = ".vscode";
            vscodeCppConfig = {
              configurations = [{
                name = "Linux";
                includePath = [
                  "include"
                  ".vscode/include"
                  ".vscode/glad/include"
                  "${pkgs.glfw}/include"
                  "${pkgs.glm}/include"
                  "${pkgs.stb}/include"
                  "${opencv}/include/opencv4"
                  "${dlib}/include"
                  "${k4a.packages.${system}.libk4a-dev}/include"
                ];
                defines = [ ];
                compilerPath = "${pkgs.gcc}/bin/gcc";
                cStandard = "c17";
                cppStandard = "gnu++17";
                intelliSenseMode = "linux-gcc-x64";
              }];
              version = 4;
            };
            openGLVersion =
              "glxinfo | grep -oP '(?<=OpenGL version string: )[0-9]+.?[0-9]'";
            gladBuildDir = "${vscodeDir}/glad";
          in
          ''
            export PS1="\e[0;31m[\u@\h \W]\$ \e[m "
            glad --api gl:core=`${openGLVersion}` --out-path ${gladBuildDir} --reproducible --quiet
            jq --indent 4 -n '${
              builtins.toJSON vscodeCppConfig
            }' >> ${vscodeDir}/c_cpp_properties.json
            mkdir -p ${vscodeDir}/include && cp ${tinyobjloaderSrc} ./${vscodeDir}/include/tiny_obj_loader.h
            trap "rm ${vscodeDir} -rf;" exit 
          '';
      };

      packages.${system} = {
        default = pkgs.cudaPackages.backendStdenv.mkDerivation {
          pname = "volumetricSim";
          version = "0.0.1";

          enableParallelBuilding = true;

          src = ./.;

          buildInputs = [
            pkgs.python310Packages.glad2
            pkgs.bzip2
            pkgs.glxinfo

            # Libs
            pkgs.assimp
            dlib
            pkgs.libpng
            pkgs.libjpeg
            opencv
            pkgs.cudatoolkit
            pkgs.cudaPackages.cudnn
            pkgs.linuxPackages.nvidia_x11
            k4a.packages.${system}.libk4a-dev
            k4a.packages.${system}.k4a-tools
            pkgs.glfw
            pkgs.glm
            pkgs.stb
            pkgs.xorg.libX11
            pkgs.xorg.libXrandr
            pkgs.xorg.libXi
            pkgs.udev
            pkgs.mkl
          ];

          configurePhase =
            let
              faceLandmarksSrc = builtins.fetchurl {
                url =
                  "http://dlib.net/files/shape_predictor_5_face_landmarks.dat.bz2";
                sha256 =
                  "sha256:0wm4bbwnja7ik7r28pv00qrl3i1h6811zkgnjfvzv7jwpyz7ny3f";
              };
              mmodHumanFaceDetectorSrc = builtins.fetchurl {
                url = "http://dlib.net/files/mmod_human_face_detector.dat.bz2";
                sha256 =
                  "sha256:15g6nm3zpay80a2qch9y81h55z972bk465m7dh1j45mcjx4cm3hw";
              };
            in
            ''
              cp ${tinyobjloaderSrc} ./include/tiny_obj_loader.h
              cd data
              cp ${faceLandmarksSrc} ./shape_predictor_5_face_landmarks.dat.bz2
              bzip2 -d ./shape_predictor_5_face_landmarks.dat.bz2
              cp ${mmodHumanFaceDetectorSrc} ./mmod_human_face_detector.dat.bz2
              bzip2 -d ./mmod_human_face_detector.dat.bz2       
              cd ..
            '';

          buildPhase =
            let
              gladBuildDir = "build/glad";
              flags = [
                "-Ofast"
                "-Wall"
                "-march=skylake" # This is platform specific need to find a way to optimise this
              ];
              sources = [
                "src/main.cpp"
                "src/display.cpp"
                "src/tracker.cpp"
                "src/model.cpp"
                "src/mesh.cpp"
                "${gladBuildDir}/src/gl.c"
              ];
              libs = [
                "-L ${k4a.packages.${system}.libk4a-dev}/lib/x86_64-linux-gnu"
                "-lglfw"
                "-lGL"
                "-lX11"
                "-lpthread"
                "-lXrandr"
                "-lXi"
                "-ldl"
                "-lm"
                "-ludev"
                "-lk4a"
                "-lopencv_core"
                "-lopencv_imgproc"
                "-lopencv_highgui"
                "-lopencv_imgcodecs"
                "-lopencv_cudafeatures2d"
                "-lopencv_cudafilters"
                "-lopencv_cudawarping"
                "-lopencv_features2d"
                "-lopencv_flann"
                "-ldlib"
                "-lcudart"
                "-lcuda"
                "-lcudnn"
                "-lcublas"
                "-lcurand"
                "-lcusolver"
                "-lmkl_intel_lp64"
              ];
              headers = [
                "-I ${dlib}/include"
                "-I ${opencv}/include/opencv4"
                "-I ${gladBuildDir}/include"
                "-I ${k4a.packages.${system}.libk4a-dev}/include"
                "-I include"
              ];
              macros = [ ''-DPACKAGE_PATH=\"$out\"'' ];
              openGLVersion =
                "glxinfo | grep -oP '(?<=OpenGL version string: )[0-9]+.?[0-9]'";
            in
            ''
              glad --api gl:core=`${openGLVersion}` --out-path ${gladBuildDir} --reproducible 
              g++ ${
                concatStringsWithSpace
                (macros ++ flags ++ sources ++ libs ++ headers)
              } -o volumetricSim
            '';

          installPhase = ''
            mkdir -p $out/bin
            cp volumetricSim $out/bin
            cp -a data $out/data
          '';
        };
      };
    };
}
