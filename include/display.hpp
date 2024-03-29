#ifndef DISPLAY_H
#define DISPLAY_H

#include <glad/gl.h>
#include <glm/glm.hpp>

class Display
{
public:
    Display(glm::vec3 origin, GLfloat width, GLfloat height, GLfloat depth, GLfloat n, GLfloat f);
    glm::mat4 projectionToEye(glm::vec3 eye);

    const GLfloat width;
    const GLfloat height;
    const GLfloat depth;

private:
    glm::vec3 origin;
    // Three corners of the screen
    glm::vec3 pa;
    glm::vec3 pb;
    glm::vec3 pc;
    // Orthonomal basis for the screen
    glm::vec3 sr;
    glm::vec3 su;
    glm::vec3 sn;

    // Distance to near and far clipping planes
    const GLfloat n;
    const GLfloat f;
};
#endif
