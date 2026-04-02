#include <jni.h>

#include "NativeEngine.h"

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

extern "C" const towerdefense::NativeGameSnapshot *nativeGetGameSnapshot() {
    return &NativeEngine::instance().snapshot();
}

extern "C" int nativeConsumeAudioEvents(towerdefense::NativeAudioEvent *buffer, int maxEvents) {
    return NativeEngine::instance().consumeAudioEvents(buffer, maxEvents);
}

extern "C" void nativeSetActiveScreenFfi(int screenId) {
    NativeEngine::instance().setActiveScreen(screenId);
}

extern "C" bool nativeInvokeActionFfi(const char *actionId, const char *payload) {
    return NativeEngine::instance().invokeAction(
        actionId == nullptr ? std::string() : std::string(actionId),
        payload == nullptr ? std::string() : std::string(payload)
    );
}
