#ifndef MAIN_H
#define MAIN_H

#include <glad/gl.h>
#include <GLFW/glfw3.h>
#include <glm/glm.hpp>
#include "tracker.hpp"
#include "image.hpp"
#include "hand.hpp"
#include <opencv2/core.hpp>
#include "json.hpp"

enum Mode
{
    TRACKER = 0,
    TRACKER_OFFSET = 1,
    STATIC = 2,
	STATIC_OFFSET = 3,
};

extern "C" const char* runSimulation(Mode trackerMode, int challengeNum, float  camera_x, float  camera_y, float  camera_z, float  camera_rot);
void debugInitPrint();
void framebufferSizeCallback(GLFWwindow *window, int width, int height);
GLFWwindow *initOpenGL(GLuint pixelWidth, GLuint pixelHeight);
void processInput(GLFWwindow *window);
void pollTracker(Tracker *tracker, GLFWwindow *window);
void pollCapture(Tracker *tracker, GLFWwindow *window);
void saveDebugInfo(Tracker &trackerPtr, Image &colourCamera,  Image &colourCameraSkeleton,  Image &colourCameraSkeletonFace, Image &colourCameraSkeletonHand, Image &colourCameraImportant, Image &depthCamera, Image &depthCameraImportant, Hand &hand);
cv::Mat generateDebugPrintBox(int fps);
// This should be refactored/removed/done properly
void saveVec3ToCSV(const glm::vec3 &vec, const std::string &filename);
#endif