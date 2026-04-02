package com.sekhar.towerdefense

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    companion object {
        init {
            System.loadLibrary("towerdefense")
        }
    }

    private val soundPlayer by lazy { NativeSoundPlayer(applicationContext) }
    private val stateStream by lazy { NativeStateStream(soundPlayer) }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine
            .platformViewsController
            .registry
            .registerViewFactory(
                "towerdefense/native_board",
                GameBoardPlatformViewFactory(
                    flutterEngine.dartExecutor.binaryMessenger,
                    stateStream,
                ),
            )
        io.flutter.plugin.common.MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "towerdefense/native_control",
        ).setMethodCallHandler(NativeControlChannelHandler(stateStream))
        io.flutter.plugin.common.EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "towerdefense/native_state",
        ).setStreamHandler(stateStream)
    }

    override fun onResume() {
        super.onResume()
        NativeBridge.nativeOnResume()
        stateStream.emitNow()
    }

    override fun onPause() {
        NativeBridge.nativeOnPause()
        super.onPause()
    }

    override fun onDestroy() {
        soundPlayer.release()
        super.onDestroy()
    }
}
