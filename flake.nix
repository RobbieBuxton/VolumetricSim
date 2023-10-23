{
  description = "A volumetric screen simulation";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/23.05";
  };

  outputs = { self, nixpkgs }: 
  let 
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
  in
  {
  # Development shell used by running "nix develop".
  # It will configure vscode settings for finding the correct c++ libs for Intellisense
  devShells.${system}.default = pkgs.mkShell rec {
    name = "volumetricSim";

    packages = with pkgs; [ 
      #Setup and windown
      gcc
      python310Packages.glad2
      glxinfo
      killall
      jq
      
      # Libs
      glfw
      glm
      stb
      xorg.libX11
      xorg.libXrandr
      xorg.libXi
    ];

    shellHook = let
      vscodeDir = ".vscode";
      vscodeCppConfig = { 
        configurations = [
          {
            name = "Linux"; 
            includePath = [
              "include" 
              ".vscode/glad/include"
              "${pkgs.glfw}/include"
              "${pkgs.glm}/include"
              "${pkgs.stb}/include"
            ]; 
            defines = []; 
            compilerPath = "${pkgs.gcc}/bin/gcc";
            cStandard = "c17"; 
            cppStandard = "gnu++17"; 
            intelliSenseMode = "linux-gcc-x64";
          }
        ]; 
        version = 4;
      };
      openGLVersion = "glxinfo | grep -oP '(?<=OpenGL version string: )[0-9]+.?[0-9]'";
      gladBuildDir = "${vscodeDir}/glad";
    in ''
      export PS1="\e[0;31m[\u@\h \W]\$ \e[m "
      glad --api gl:core=`${openGLVersion}` --out-path ${gladBuildDir} --reproducible --quiet
      jq --indent 4 -n '${builtins.toJSON vscodeCppConfig}' >> ${vscodeDir}/c_cpp_properties.json
      trap "rm ${vscodeDir} -rf;" exit 
    '';
  };

    packages.${system}.default = pkgs.stdenv.mkDerivation {
      pname = "volumetricSim";
      version = "0.0.1";

      src = ./.; 

      buildInputs = with pkgs; [
        python310Packages.glad2
        glxinfo

        # Libs
        glfw
        glm
        stb
        xorg.libX11
        xorg.libXrandr
        xorg.libXi
      ];

     currentPath = toString ./.;

      buildPhase = let
        gccBuildLibs = "-lglfw -lGL -lX11 -lpthread -lXrandr -lXi -ldl -lm";
        openGLVersion = "glxinfo | grep -oP '(?<=OpenGL version string: )[0-9]+.?[0-9]'";
        gladBuildDir = "build/glad";
        sourceFiles = "src/main.cpp ${gladBuildDir}/src/gl.c";
        includePaths = "-I ${gladBuildDir}/include -I include";
      in ''
        glad --api gl:core=`${openGLVersion}` --out-path ${gladBuildDir} --reproducible 
        echo ${includePaths}
        g++ ${gccBuildLibs} ${sourceFiles} ${includePaths} -o volumetricSim 
      '';

      installPhase = ''
        mkdir -p $out/bin
        cp volumetricSim $out/bin
      '';
    };

    
  };
}
