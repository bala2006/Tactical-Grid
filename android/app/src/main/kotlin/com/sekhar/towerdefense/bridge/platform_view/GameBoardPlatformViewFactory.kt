package com.sekhar.towerdefense

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class GameBoardPlatformViewFactory(
    messenger: BinaryMessenger,
    private val stateStream: NativeStateStream,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    @Suppress("UNUSED_PARAMETER")
    private val binaryMessenger = messenger

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return GameBoardPlatformView(context, stateStream)
    }
}
