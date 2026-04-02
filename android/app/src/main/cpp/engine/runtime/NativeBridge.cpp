#include <jni.h>

#include "NativeEngine.h"

namespace {
std::string toString(JNIEnv *env, jstring value) {
    if (value == nullptr) {
        return {};
    }
    const char *chars = env->GetStringUTFChars(value, nullptr);
    std::string result = chars == nullptr ? std::string() : std::string(chars);
    if (chars != nullptr) {
        env->ReleaseStringUTFChars(value, chars);
    }
    return result;
}
}

extern "C" JNIEXPORT void JNICALL
Java_com_sekhar_towerdefense_NativeBridge_nativeOnSurfaceCreated(JNIEnv *, jobject) {
    NativeEngine::instance().onSurfaceCreated();
}

extern "C" JNIEXPORT void JNICALL
Java_com_sekhar_towerdefense_NativeBridge_nativeOnSurfaceChanged(JNIEnv *, jobject, jint width, jint height) {
    NativeEngine::instance().onSurfaceChanged(width, height);
}

extern "C" JNIEXPORT void JNICALL
Java_com_sekhar_towerdefense_NativeBridge_nativeOnDrawFrame(JNIEnv *, jobject) {
    NativeEngine::instance().onDrawFrame();
}

extern "C" JNIEXPORT void JNICALL
Java_com_sekhar_towerdefense_NativeBridge_nativeHandlePointer(JNIEnv *, jobject, jfloat xPx, jfloat yPx, jint phase) {
    NativeEngine::instance().onPointer(xPx, yPx, phase);
}

extern "C" JNIEXPORT void JNICALL
Java_com_sekhar_towerdefense_NativeBridge_nativeSetActiveScreen(JNIEnv *, jobject, jint screenId) {
    NativeEngine::instance().setActiveScreen(screenId);
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_sekhar_towerdefense_NativeBridge_nativeInvokeAction(JNIEnv *env, jobject, jstring actionId, jstring payload) {
    return NativeEngine::instance().invokeAction(toString(env, actionId), toString(env, payload)) ? JNI_TRUE : JNI_FALSE;
}

extern "C" JNIEXPORT void JNICALL
Java_com_sekhar_towerdefense_NativeBridge_nativeOnPause(JNIEnv *, jobject) {
    NativeEngine::instance().onPause();
}

extern "C" JNIEXPORT void JNICALL
Java_com_sekhar_towerdefense_NativeBridge_nativeOnResume(JNIEnv *, jobject) {
    NativeEngine::instance().onResume();
}

extern "C" JNIEXPORT void JNICALL
Java_com_sekhar_towerdefense_NativeBridge_nativeSetBoardViewport(JNIEnv *, jobject, jint leftPx, jint topPx, jint widthPx, jint heightPx, jfloat density) {
    NativeEngine::instance().setBoardViewport(leftPx, topPx, widthPx, heightPx, density);
}

extern "C" JNIEXPORT void JNICALL
Java_com_sekhar_towerdefense_NativeBridge_nativeHandleBoardTap(JNIEnv *, jobject, jfloat xPx, jfloat yPx) {
    NativeEngine::instance().handleBoardTap(xPx, yPx);
}

extern "C" JNIEXPORT void JNICALL
Java_com_sekhar_towerdefense_NativeBridge_nativeHandleBoardDrag(JNIEnv *, jobject, jfloat xPx, jfloat yPx, jint phase) {
    NativeEngine::instance().handleBoardDrag(xPx, yPx, phase);
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_sekhar_towerdefense_NativeBridge_nativeConsumeUiSnapshot(JNIEnv *env, jobject) {
    const std::string snapshot = NativeEngine::instance().consumeUiSnapshot();
    return env->NewStringUTF(snapshot.c_str());
}
