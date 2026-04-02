package com.sekhar.towerdefense

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import org.json.JSONObject

class NativeStateStream(
    private val soundPlayer: NativeSoundPlayer,
) : EventChannel.StreamHandler {
    data class PendingPlacementSnapshot(
        val id: String,
        val anchorX: Float,
        val anchorY: Float,
        val statusText: String,
        val remainingTicks: Int,
        val placementAllowed: Boolean,
        val placementAffordable: Boolean,
        val showPlaceAction: Boolean,
    )

    private val handler = Handler(Looper.getMainLooper())
    private var eventSink: EventChannel.EventSink? = null
    private var activeScreen: String = "home"
    @Volatile private var latestPayload: String = ""
    @Volatile private var latestPendingPlacement: PendingPlacementSnapshot? = null
    @Volatile private var lastSoundNonce: Int = -1

    private val poller = object : Runnable {
        override fun run() {
            emitNow()
            handler.postDelayed(this, if (activeScreen == "game") 33L else 100L)
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        handler.removeCallbacks(poller)
        handler.post(poller)
    }

    override fun onCancel(arguments: Any?) {
        handler.removeCallbacks(poller)
        eventSink = null
    }

    fun updateScreen(screen: String) {
        activeScreen = screen
    }

    fun currentPendingPlacement(): PendingPlacementSnapshot? = latestPendingPlacement

    fun emitNow() {
        val payload = NativeBridge.nativeConsumeUiSnapshot()
        if (payload.isBlank()) {
            latestPayload = ""
            latestPendingPlacement = null
            return
        }
        latestPayload = payload
        latestPendingPlacement = parsePendingPlacement(payload)
        consumeSound(payload)
        val sink = eventSink
        if (sink != null) {
            sink.success(payload)
        }
    }

    private fun parsePendingPlacement(payload: String): PendingPlacementSnapshot? {
        return try {
            val pending = JSONObject(payload).optJSONObject("pendingPlacement")
                ?: return null
            val id = pending.optString("id", "")
            if (id.isBlank()) {
                null
            } else {
                PendingPlacementSnapshot(
                    id = id,
                    anchorX = pending.optDouble("anchorX", 0.0).toFloat(),
                    anchorY = pending.optDouble("anchorY", 0.0).toFloat(),
                    statusText = pending.optString("statusText", ""),
                    remainingTicks = pending.optInt("remainingTicks", 0),
                    placementAllowed = pending.optBoolean("placementAllowed", false),
                    placementAffordable = pending.optBoolean("placementAffordable", false),
                    showPlaceAction = pending.optBoolean("showPlaceAction", false),
                )
            }
        } catch (_: Throwable) {
            null
        }
    }

    private fun consumeSound(payload: String) {
        try {
            val root = JSONObject(payload)
            val nonce = root.optInt("soundNonce", -1)
            if (nonce < 0 || nonce == lastSoundNonce) {
                return
            }
            lastSoundNonce = nonce
            val soundName = root.optString("lastSound", "")
            val muted = root.optJSONObject("config")?.optBoolean("muted", false) ?: false
            soundPlayer.play(soundName, muted)
        } catch (_: Throwable) {
        }
    }
}
