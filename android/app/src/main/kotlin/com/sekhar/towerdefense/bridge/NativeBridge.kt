package com.sekhar.towerdefense

object NativeBridge {
    external fun nativeOnSurfaceCreated()
    external fun nativeOnSurfaceChanged(width: Int, height: Int)
    external fun nativeOnDrawFrame()
    external fun nativeHandlePointer(xPx: Float, yPx: Float, phase: Int)
    external fun nativeSetActiveScreen(screenId: Int)
    external fun nativeInvokeAction(actionId: String, payload: String = ""): Boolean
    external fun nativeOnPause()
    external fun nativeOnResume()
    external fun nativeSetBoardViewport(leftPx: Int, topPx: Int, widthPx: Int, heightPx: Int, density: Float)
    external fun nativeHandleBoardTap(xPx: Float, yPx: Float)
    external fun nativeHandleBoardDrag(xPx: Float, yPx: Float, phase: Int)
    external fun nativeConsumeUiSnapshot(): String
}
