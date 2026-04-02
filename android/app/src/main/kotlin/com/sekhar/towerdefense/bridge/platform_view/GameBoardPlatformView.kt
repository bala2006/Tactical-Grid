package com.sekhar.towerdefense

import android.content.Context
import android.opengl.GLSurfaceView
import android.view.MotionEvent
import android.view.View
import io.flutter.plugin.platform.PlatformView

class GameBoardPlatformView(
    context: Context,
) : PlatformView {
    private val root = NativeGameSurfaceView(context)

    init {
        root.requestFocus()
    }

    override fun getView(): View = root

    override fun dispose() {
        root.onPause()
    }

    private class NativeGameSurfaceView(
        context: Context,
    ) : GLSurfaceView(context) {
        private val renderer = NativeRenderer()

        init {
            setEGLContextClientVersion(3)
            preserveEGLContextOnPause = true
            setRenderer(renderer)
            renderMode = RENDERMODE_CONTINUOUSLY
            addOnLayoutChangeListener { _, _, _, _, _, _, _, _, _ -> updateBoardViewport() }
            isFocusable = true
            isFocusableInTouchMode = true
        }

        override fun onAttachedToWindow() {
            super.onAttachedToWindow()
            updateBoardViewport()
        }

        override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
            super.onSizeChanged(w, h, oldw, oldh)
            updateBoardViewport()
        }

        override fun onTouchEvent(event: MotionEvent): Boolean {
            val touchX = event.x
            val touchY = event.y
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    NativeBridge.nativeHandleBoardDrag(touchX, touchY, 0)
                    NativeBridge.nativeHandleBoardTap(touchX, touchY)
                    return true
                }
                MotionEvent.ACTION_MOVE -> {
                    NativeBridge.nativeHandleBoardDrag(touchX, touchY, 1)
                    return true
                }
                MotionEvent.ACTION_UP -> {
                    return true
                }
                MotionEvent.ACTION_CANCEL -> {
                    NativeBridge.nativeHandleBoardDrag(touchX, touchY, 3)
                    return true
                }
            }
            return false
        }

        private fun updateBoardViewport() {
            if (!isAttachedToWindow || width == 0 || height == 0) {
                NativeBridge.nativeSetBoardViewport(0, 0, 0, 0, resources.displayMetrics.density)
                return
            }
            NativeBridge.nativeSetBoardViewport(
                0,
                0,
                width,
                height,
                resources.displayMetrics.density,
            )
        }

        private class NativeRenderer : GLSurfaceView.Renderer {
            override fun onSurfaceCreated(gl: javax.microedition.khronos.opengles.GL10?, config: javax.microedition.khronos.egl.EGLConfig?) {
                NativeBridge.nativeOnSurfaceCreated()
            }

            override fun onSurfaceChanged(gl: javax.microedition.khronos.opengles.GL10?, width: Int, height: Int) {
                NativeBridge.nativeOnSurfaceChanged(width, height)
            }

            override fun onDrawFrame(gl: javax.microedition.khronos.opengles.GL10?) {
                NativeBridge.nativeOnDrawFrame()
            }
        }
    }
}
