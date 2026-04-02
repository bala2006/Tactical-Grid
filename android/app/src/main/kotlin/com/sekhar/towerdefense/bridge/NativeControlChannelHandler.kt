package com.sekhar.towerdefense

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class NativeControlChannelHandler(
    private val stateStream: NativeStateStream,
) : MethodChannel.MethodCallHandler {
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val arguments = call.arguments as? Map<*, *>
        when (call.method) {
            "initialize" -> {
                stateStream.emitNow()
                result.success(null)
            }
            "setScreen" -> {
                val screen = arguments?.get("screen") as? String ?: "home"
                stateStream.updateScreen(screen)
                NativeBridge.nativeSetActiveScreen(screenIdFor(screen))
                stateStream.emitNow()
                result.success(null)
            }
            "restart" -> {
                NativeBridge.nativeInvokeAction("restart")
                stateStream.emitNow()
                result.success(null)
            }
            "togglePause" -> {
                NativeBridge.nativeInvokeAction("togglePause")
                stateStream.emitNow()
                result.success(null)
            }
            "selectTower" -> {
                val towerId = arguments?.get("towerId") as? String ?: "gun"
                NativeBridge.nativeInvokeAction("selectTower", towerId)
                stateStream.emitNow()
                result.success(null)
            }
            "setMap" -> {
                val mapId = arguments?.get("mapId") as? String ?: "sparse2"
                NativeBridge.nativeInvokeAction("setMap", mapId)
                stateStream.emitNow()
                result.success(null)
            }
            "setDifficulty" -> {
                NativeBridge.nativeInvokeAction(
                    "setDifficulty",
                    (arguments?.get("difficulty") as? Number)?.toInt()?.toString() ?: "1",
                )
                stateStream.emitNow()
                result.success(null)
            }
            "setWaveMode" -> {
                NativeBridge.nativeInvokeAction(
                    "setWaveMode",
                    (arguments?.get("waveMode") as? Number)?.toInt()?.toString() ?: "0",
                )
                stateStream.emitNow()
                result.success(null)
            }
            "setQuality" -> {
                NativeBridge.nativeInvokeAction(
                    "setQuality",
                    (arguments?.get("quality") as? Number)?.toInt()?.toString() ?: "0",
                )
                stateStream.emitNow()
                result.success(null)
            }
            "toggleMute" -> invokeBooleanAction("toggleMute", result)
            "toggleEffects" -> invokeBooleanAction("toggleEffects", result)
            "toggleHealthBars" -> invokeBooleanAction("toggleHealthBars", result)
            "toggleAutoSend" -> invokeBooleanAction("toggleAutoSend", result)
            "toggleAdaptiveQuality" -> invokeBooleanAction("toggleAdaptiveQuality", result)
            "setShowFps" -> invokeValueAction("setShowFps", arguments, "value", result)
            "setGodMode" -> invokeValueAction("setGodMode", arguments, "value", result)
            "setFiringDisabled" -> invokeValueAction("setFiringDisabled", arguments, "value", result)
            "upgradeTower" -> invokeBooleanAction("upgradeTower", result)
            "sellTower" -> invokeBooleanAction("sellTower", result)
            "confirmPlacement" -> invokeBooleanAction("confirmPlacement", result)
            "cancelPlacement" -> invokeBooleanAction("cancelPlacement", result)
            "importMap" -> {
                val value = arguments?.get("value") as? String ?: ""
                NativeBridge.nativeInvokeAction("importMap", value)
                stateStream.emitNow()
                result.success(value.isNotBlank())
            }
            "exportMap" -> {
                val payload = NativeBridge.nativeConsumeUiSnapshot()
                result.success(payload)
            }
            else -> result.notImplemented()
        }
    }

    private fun invokeBooleanAction(actionId: String, result: MethodChannel.Result) {
        val actionResult = NativeBridge.nativeInvokeAction(actionId)
        stateStream.emitNow()
        result.success(actionResult)
    }

    private fun invokeValueAction(
        actionId: String,
        arguments: Map<*, *>?,
        key: String,
        result: MethodChannel.Result,
    ) {
        NativeBridge.nativeInvokeAction(actionId, (arguments?.get(key) ?: false).toString())
        stateStream.emitNow()
        result.success(null)
    }

    private fun screenIdFor(value: String): Int {
        return when (value) {
            "map" -> 1
            "settings" -> 2
            "game" -> 3
            "leaderboard" -> 4
            else -> 0
        }
    }
}
