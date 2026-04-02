#ifndef TOWERDEFENSE_GL_RENDERER_2D_H
#define TOWERDEFENSE_GL_RENDERER_2D_H

#include <GLES3/gl3.h>

#include <vector>

class GlRenderer2D {
public:
    GlRenderer2D() = default;
    ~GlRenderer2D();

    GlRenderer2D(const GlRenderer2D &) = delete;
    GlRenderer2D &operator=(const GlRenderer2D &) = delete;

    bool initialize();
    void shutdown();
    void beginFrame(int surfaceWidth, int surfaceHeight);
    void drawRect(float x, float y, float width, float height, unsigned int color);
    void drawTriangle(
        float ax, float ay,
        float bx, float by,
        float cx, float cy,
        unsigned int color
    );
    void drawQuad(
        float ax, float ay,
        float bx, float by,
        float cx, float cy,
        float dx, float dy,
        unsigned int color
    );
    void drawLine(float x1, float y1, float x2, float y2, float thickness, unsigned int color);
    void drawCircle(float cx, float cy, float radius, unsigned int color, int segments = 24);
    void drawEllipse(float cx, float cy, float radiusX, float radiusY, unsigned int color, int segments = 24);
    void flush();

private:
    struct Vertex {
        float x;
        float y;
        float r;
        float g;
        float b;
        float a;
    };

    void appendTriangle(
        float ax, float ay,
        float bx, float by,
        float cx, float cy,
        unsigned int color
    );

    GLuint program_ = 0;
    GLuint vertexBuffer_ = 0;
    GLint projectionLocation_ = -1;
    int surfaceWidth_ = 0;
    int surfaceHeight_ = 0;
    GLsizeiptr vertexBufferCapacityBytes_ = 0;
    std::vector<Vertex> vertices_;
};

#endif
