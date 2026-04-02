#include "GlRenderer2D.h"

#include <android/log.h>

#include <algorithm>
#include <cmath>
#include <cstddef>
#include <string>

namespace {
constexpr char kLogTag[] = "towerdefense";

constexpr char kVertexShader[] = R"(#version 300 es
layout(location = 0) in vec2 aPosition;
layout(location = 1) in uint aColor;
uniform mat4 uProjection;
out vec4 vColor;
void main() {
    gl_Position = uProjection * vec4(aPosition, 0.0, 1.0);
    vColor = vec4(
        float(aColor & 255u) / 255.0,
        float((aColor >> 8) & 255u) / 255.0,
        float((aColor >> 16) & 255u) / 255.0,
        float((aColor >> 24) & 255u) / 255.0
    );
}
)";

constexpr char kFragmentShader[] = R"(#version 300 es
precision mediump float;
in vec4 vColor;
out vec4 outColor;
void main() {
    outColor = vColor;
}
)";

GLuint compileShader(GLenum type, const char *source) {
    const GLuint shader = glCreateShader(type);
    glShaderSource(shader, 1, &source, nullptr);
    glCompileShader(shader);

    GLint compiled = 0;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &compiled);
    if (compiled == GL_TRUE) {
        return shader;
    }

    GLint logLength = 0;
    glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &logLength);
    std::string log(static_cast<size_t>(std::max(logLength, 1)), '\0');
    glGetShaderInfoLog(shader, logLength, nullptr, log.data());
    __android_log_print(ANDROID_LOG_ERROR, kLogTag, "Shader compile failed: %s", log.c_str());
    glDeleteShader(shader);
    return 0;
}

}

const GlRenderer2D::CircleMesh &GlRenderer2D::circleMeshForSegments(int segments) {
    if (segments < 3) {
        static const CircleMesh kEmptyMesh;
        return kEmptyMesh;
    }

    if (circleMeshes_.size() <= static_cast<size_t>(segments)) {
        circleMeshes_.resize(static_cast<size_t>(segments + 1));
    }

    CircleMesh &mesh = circleMeshes_[static_cast<size_t>(segments)];
    if (mesh.unitXs.size() != static_cast<size_t>(segments)) {
        constexpr float kTau = 6.28318530718f;
        mesh.unitXs.resize(static_cast<size_t>(segments));
        mesh.unitYs.resize(static_cast<size_t>(segments));
        for (int index = 0; index < segments; ++index) {
            const float angle = (static_cast<float>(index) / static_cast<float>(segments)) * kTau;
            mesh.unitXs[static_cast<size_t>(index)] = std::cos(angle);
            mesh.unitYs[static_cast<size_t>(index)] = std::sin(angle);
        }
    }

    return mesh;
}

GlRenderer2D::~GlRenderer2D() {
    shutdown();
}

bool GlRenderer2D::initialize() {
    shutdown();

    const GLuint vertexShader = compileShader(GL_VERTEX_SHADER, kVertexShader);
    const GLuint fragmentShader = compileShader(GL_FRAGMENT_SHADER, kFragmentShader);
    if (vertexShader == 0 || fragmentShader == 0) {
        glDeleteShader(vertexShader);
        glDeleteShader(fragmentShader);
        return false;
    }

    program_ = glCreateProgram();
    glAttachShader(program_, vertexShader);
    glAttachShader(program_, fragmentShader);
    glLinkProgram(program_);

    GLint linked = 0;
    glGetProgramiv(program_, GL_LINK_STATUS, &linked);
    glDeleteShader(vertexShader);
    glDeleteShader(fragmentShader);
    if (linked != GL_TRUE) {
        GLint logLength = 0;
        glGetProgramiv(program_, GL_INFO_LOG_LENGTH, &logLength);
        std::string log(static_cast<size_t>(std::max(logLength, 1)), '\0');
        glGetProgramInfoLog(program_, logLength, nullptr, log.data());
        __android_log_print(ANDROID_LOG_ERROR, kLogTag, "Program link failed: %s", log.c_str());
        shutdown();
        return false;
    }

    glGenBuffers(1, &vertexBuffer_);
    projectionLocation_ = glGetUniformLocation(program_, "uProjection");
    vertices_.reserve(65536);
    return true;
}

void GlRenderer2D::shutdown() {
    if (vertexBuffer_ != 0 && glIsBuffer(vertexBuffer_) == GL_TRUE) {
        glDeleteBuffers(1, &vertexBuffer_);
    }
    vertexBuffer_ = 0;
    if (program_ != 0 && glIsProgram(program_) == GL_TRUE) {
        glDeleteProgram(program_);
    }
    program_ = 0;
    projectionLocation_ = -1;
    vertexBufferCapacityBytes_ = 0;
    vertices_.clear();
    circleMeshes_.clear();
}

void GlRenderer2D::beginFrame(int surfaceWidth, int surfaceHeight) {
    surfaceWidth_ = surfaceWidth;
    surfaceHeight_ = surfaceHeight;
    vertices_.clear();
}

void GlRenderer2D::drawRect(float x, float y, float width, float height, unsigned int color) {
    const float x2 = x + width;
    const float y2 = y + height;
    appendTriangle(x, y, x2, y, x2, y2, color);
    appendTriangle(x, y, x2, y2, x, y2, color);
}

void GlRenderer2D::drawTriangle(
    float ax, float ay,
    float bx, float by,
    float cx, float cy,
    unsigned int color
) {
    appendTriangle(ax, ay, bx, by, cx, cy, color);
}

void GlRenderer2D::drawQuad(
    float ax, float ay,
    float bx, float by,
    float cx, float cy,
    float dx, float dy,
    unsigned int color
) {
    appendTriangle(ax, ay, bx, by, cx, cy, color);
    appendTriangle(ax, ay, cx, cy, dx, dy, color);
}

void GlRenderer2D::drawLine(float x1, float y1, float x2, float y2, float thickness, unsigned int color) {
    const float deltaX = x2 - x1;
    const float deltaY = y2 - y1;
    const float length = std::sqrt(deltaX * deltaX + deltaY * deltaY);
    if (length <= 0.0001f) {
        return;
    }

    const float normalX = -deltaY / length;
    const float normalY = deltaX / length;
    const float half = thickness * 0.5f;

    const float ax = x1 + normalX * half;
    const float ay = y1 + normalY * half;
    const float bx = x2 + normalX * half;
    const float by = y2 + normalY * half;
    const float cx = x2 - normalX * half;
    const float cy = y2 - normalY * half;
    const float dx = x1 - normalX * half;
    const float dy = y1 - normalY * half;

    appendTriangle(ax, ay, bx, by, cx, cy, color);
    appendTriangle(ax, ay, cx, cy, dx, dy, color);
}

void GlRenderer2D::drawCircle(float cx, float cy, float radius, unsigned int color, int segments) {
    if (radius <= 0.0f || segments < 3) {
        return;
    }

    const CircleMesh &mesh = circleMeshForSegments(segments);
    for (int index = 0; index < segments; ++index) {
        const size_t nextIndex = static_cast<size_t>((index + 1) % segments);
        appendTriangle(
            cx,
            cy,
            cx + mesh.unitXs[static_cast<size_t>(index)] * radius,
            cy + mesh.unitYs[static_cast<size_t>(index)] * radius,
            cx + mesh.unitXs[nextIndex] * radius,
            cy + mesh.unitYs[nextIndex] * radius,
            color
        );
    }
}

void GlRenderer2D::drawEllipse(float cx, float cy, float radiusX, float radiusY, unsigned int color, int segments) {
    if (radiusX <= 0.0f || radiusY <= 0.0f || segments < 3) {
        return;
    }

    const CircleMesh &mesh = circleMeshForSegments(segments);
    for (int index = 0; index < segments; ++index) {
        const size_t nextIndex = static_cast<size_t>((index + 1) % segments);
        appendTriangle(
            cx,
            cy,
            cx + mesh.unitXs[static_cast<size_t>(index)] * radiusX,
            cy + mesh.unitYs[static_cast<size_t>(index)] * radiusY,
            cx + mesh.unitXs[nextIndex] * radiusX,
            cy + mesh.unitYs[nextIndex] * radiusY,
            color
        );
    }
}

void GlRenderer2D::flush() {
    if (program_ == 0 || vertexBuffer_ == 0 || vertices_.empty() || surfaceWidth_ <= 0 || surfaceHeight_ <= 0) {
        return;
    }

    const float projection[16] = {
        2.0f / static_cast<float>(surfaceWidth_), 0.0f, 0.0f, 0.0f,
        0.0f, -2.0f / static_cast<float>(surfaceHeight_), 0.0f, 0.0f,
        0.0f, 0.0f, 1.0f, 0.0f,
        -1.0f, 1.0f, 0.0f, 1.0f,
    };

    glUseProgram(program_);
    glUniformMatrix4fv(projectionLocation_, 1, GL_FALSE, projection);

    glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer_);
    const GLsizeiptr vertexBytes = static_cast<GLsizeiptr>(vertices_.size() * sizeof(Vertex));
    if (vertexBytes > vertexBufferCapacityBytes_) {
        glBufferData(GL_ARRAY_BUFFER, vertexBytes, nullptr, GL_DYNAMIC_DRAW);
        vertexBufferCapacityBytes_ = vertexBytes;
    }
    glBufferSubData(GL_ARRAY_BUFFER, 0, vertexBytes, vertices_.data());

    glEnableVertexAttribArray(0);
    glEnableVertexAttribArray(1);
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, sizeof(Vertex), reinterpret_cast<const void *>(offsetof(Vertex, x)));
    glVertexAttribIPointer(1, 1, GL_UNSIGNED_INT, sizeof(Vertex), reinterpret_cast<const void *>(offsetof(Vertex, color)));
    glDrawArrays(GL_TRIANGLES, 0, static_cast<GLsizei>(vertices_.size()));

    glDisableVertexAttribArray(0);
    glDisableVertexAttribArray(1);
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glUseProgram(0);
}

void GlRenderer2D::appendTriangle(
    float ax, float ay,
    float bx, float by,
    float cx, float cy,
    unsigned int color
) {
    vertices_.push_back(Vertex{ax, ay, color});
    vertices_.push_back(Vertex{bx, by, color});
    vertices_.push_back(Vertex{cx, cy, color});
}
