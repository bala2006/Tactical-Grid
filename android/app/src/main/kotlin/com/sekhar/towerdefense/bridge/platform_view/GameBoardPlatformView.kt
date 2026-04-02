package com.sekhar.towerdefense

import android.content.Context
import android.graphics.Color
import android.graphics.Typeface
import android.opengl.GLSurfaceView
import android.os.Handler
import android.os.Looper
import android.util.TypedValue
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.View.MeasureSpec
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import io.flutter.plugin.platform.PlatformView
import kotlin.math.max
import kotlin.math.min

class GameBoardPlatformView(
    private val context: Context,
    private val stateStream: NativeStateStream,
) : PlatformView {
    private val handler = Handler(Looper.getMainLooper())
    private val root = FrameLayout(context)
    private val popupMinWidthPx = dp(108)
    private val gameSurfaceView = NativeGameSurfaceView(context) {
        stateStream.emitNow()
        refreshPlacementPopup()
    }
    private val popupRow = LinearLayout(context).apply {
        orientation = LinearLayout.HORIZONTAL
        gravity = Gravity.CENTER_VERTICAL
    }
    private val countdownLabel = TextView(context).apply {
        setTextColor(Color.parseColor("#FFC16B"))
        setTextSize(TypedValue.COMPLEX_UNIT_SP, 10f)
        setTypeface(typeface, Typeface.BOLD)
        gravity = Gravity.CENTER
    }
    private val countdownSpacer = TextView(context).apply {
        width = dp(6)
    }
    private val cancelButton = TextView(context).apply {
        text = "Cancel"
        setTextColor(Color.parseColor("#9CCEFF"))
        setTextSize(TypedValue.COMPLEX_UNIT_SP, 10f)
        gravity = Gravity.CENTER
        setPadding(dp(4), dp(2), dp(4), dp(2))
        setOnClickListener {
            val cancelled = NativeBridge.nativeInvokeAction("cancelPlacement")
            stateStream.emitNow()
            if (cancelled) {
                hidePlacementPopup()
                return@setOnClickListener
            }
            refreshPlacementPopup()
        }
    }
    private val actionSpacer = TextView(context).apply {
        width = dp(6)
    }
    private val placeButton = TextView(context).apply {
        text = "Place"
        setTextColor(Color.parseColor("#072033"))
        setTextSize(TypedValue.COMPLEX_UNIT_SP, 10f)
        setTypeface(typeface, Typeface.BOLD)
        gravity = Gravity.CENTER
        setPadding(dp(7), dp(2), dp(7), dp(2))
        background = android.graphics.drawable.GradientDrawable().apply {
            shape = android.graphics.drawable.GradientDrawable.RECTANGLE
            cornerRadius = dp(9).toFloat()
            setColor(Color.parseColor("#79B9FF"))
        }
        setOnClickListener {
            val placed = NativeBridge.nativeInvokeAction("confirmPlacement")
            stateStream.emitNow()
            if (placed) {
                hidePlacementPopup()
                return@setOnClickListener
            }
            refreshPlacementPopup()
        }
    }
    private val statusLabel = TextView(context).apply {
        setTextColor(Color.parseColor("#9CCEFF"))
        setTextSize(TypedValue.COMPLEX_UNIT_SP, 8f)
        gravity = Gravity.CENTER
        isSingleLine = true
        ellipsize = android.text.TextUtils.TruncateAt.END
    }
    private val popupView = LinearLayout(context).apply {
        orientation = LinearLayout.VERTICAL
        gravity = Gravity.CENTER_HORIZONTAL
        minimumWidth = popupMinWidthPx
        setPadding(dp(6), dp(4), dp(6), dp(4))
        background = android.graphics.drawable.GradientDrawable().apply {
            shape = android.graphics.drawable.GradientDrawable.RECTANGLE
            cornerRadius = dp(12).toFloat()
            setColor(Color.parseColor("#F0122A45").toInt())
            setStroke(dp(1), Color.parseColor("#2A5474"))
        }
        alpha = 0.98f
        visibility = View.GONE
        popupRow.addView(
            countdownLabel,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ),
        )
        popupRow.addView(countdownSpacer)
        popupRow.addView(
            cancelButton,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ),
        )
        popupRow.addView(actionSpacer)
        popupRow.addView(
            placeButton,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ),
        )
        addView(
            popupRow,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ),
        )
        addView(TextView(context).apply { height = dp(2) })
        addView(
            statusLabel,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ),
        )
    }
    private var activePlacementId: String? = null
    private val popupPoller = object : Runnable {
        override fun run() {
            stateStream.emitNow()
            refreshPlacementPopup()
            if (activePlacementId != null) {
                handler.postDelayed(this, 100L)
            }
        }
    }

    init {
        root.addView(
            gameSurfaceView,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
            ),
        )
        root.addView(
            popupView,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.WRAP_CONTENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
            ),
        )
    }

    override fun getView(): View = root

    override fun dispose() {
        handler.removeCallbacksAndMessages(null)
        gameSurfaceView.onPause()
    }

    private fun refreshPlacementPopup() {
        val pending = stateStream.currentPendingPlacement()
        if (pending == null || pending.id.isBlank()) {
            hidePlacementPopup()
            return
        }
        if (pending.id != activePlacementId) {
            activePlacementId = pending.id
        }
        val hasCountdown = pending.remainingTicks > 0
        val countdownText = if (hasCountdown) "${(pending.remainingTicks + 59) / 60}s" else ""
        if (countdownLabel.text != countdownText) {
            countdownLabel.text = countdownText
        }
        countdownLabel.visibility = if (hasCountdown) View.VISIBLE else View.GONE
        countdownSpacer.visibility = if (hasCountdown) View.VISIBLE else View.GONE
        if (statusLabel.text != pending.statusText) {
            statusLabel.text = pending.statusText
        }
        placeButton.visibility = if (pending.showPlaceAction) View.VISIBLE else View.GONE
        placeButton.isEnabled = pending.showPlaceAction
        actionSpacer.visibility = if (pending.showPlaceAction) View.VISIBLE else View.GONE
        popupView.measure(
            MeasureSpec.makeMeasureSpec(root.width, MeasureSpec.AT_MOST),
            MeasureSpec.makeMeasureSpec(root.height, MeasureSpec.AT_MOST),
        )
        val popupWidthPx = max(popupMinWidthPx, popupView.measuredWidth)
        val popupHeightPx = popupView.measuredHeight
        val maxLeft = max(dp(8), root.width - popupWidthPx - dp(8))
        val left = min(
            max(dp(8), (pending.anchorX - popupWidthPx / 2f).toInt()),
            maxLeft,
        )
        val top = max(dp(8), (pending.anchorY - popupHeightPx - dp(12)).toInt())
        val layoutParams = popupView.layoutParams as FrameLayout.LayoutParams
        if (layoutParams.leftMargin != left || layoutParams.topMargin != top) {
            layoutParams.leftMargin = left
            layoutParams.topMargin = top
            popupView.layoutParams = layoutParams
        }
        if (popupView.visibility != View.VISIBLE) {
            popupView.visibility = View.VISIBLE
        }
        handler.removeCallbacks(popupPoller)
        handler.postDelayed(popupPoller, 100L)
    }

    private fun hidePlacementPopup() {
        handler.removeCallbacks(popupPoller)
        if (popupView.visibility != View.GONE) {
            popupView.visibility = View.GONE
        }
        activePlacementId = null
        statusLabel.text = ""
    }

    private fun dp(value: Int): Int =
        TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            value.toFloat(),
            context.resources.displayMetrics,
        ).toInt()

    private class NativeGameSurfaceView(
        context: Context,
        private val onBoardTapHandled: () -> Unit,
    ) : GLSurfaceView(context) {
        private val renderer = NativeRenderer()

        init {
            setEGLContextClientVersion(3)
            preserveEGLContextOnPause = true
            setRenderer(renderer)
            renderMode = RENDERMODE_CONTINUOUSLY
            addOnLayoutChangeListener { _, _, _, _, _, _, _, _, _ -> updateBoardViewport() }
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
                    onBoardTapHandled()
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

        private class NativeRenderer : Renderer {
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
