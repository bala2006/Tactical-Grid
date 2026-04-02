package com.sekhar.towerdefense

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    companion object {
        init {
            System.loadLibrary("towerdefense")
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine
            .platformViewsController
            .registry
            .registerViewFactory(
                "towerdefense/native_board",
                GameBoardPlatformViewFactory(),
            )
    }

    override fun onResume() {
        super.onResume()
        NativeBridge.nativeOnResume()
    }

    override fun onPause() {
        NativeBridge.nativeOnPause()
        super.onPause()
    }
}
