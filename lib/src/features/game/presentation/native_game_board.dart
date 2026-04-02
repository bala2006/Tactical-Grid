import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

import '../../shell/presentation/game_theme.dart';
import '../infrastructure/native_game_bridge.dart';

class NativeGameBoard extends StatelessWidget {
  const NativeGameBoard({super.key});

  @override
  Widget build(BuildContext context) {
    if (!supportsNativeGameBoard) {
      return const _UnsupportedNativeBoard();
    }
    return PlatformViewLink(
      viewType: nativeBoardViewType,
      surfaceFactory:
          (BuildContext context, PlatformViewController controller) {
            return AndroidViewSurface(
              controller: controller as AndroidViewController,
              gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
              hitTestBehavior: PlatformViewHitTestBehavior.opaque,
            );
          },
      onCreatePlatformView: (PlatformViewCreationParams params) {
        return PlatformViewsService.initSurfaceAndroidView(
          id: params.id,
          viewType: nativeBoardViewType,
          layoutDirection: TextDirection.ltr,
          creationParams: const <String, dynamic>{},
          creationParamsCodec: const StandardMessageCodec(),
          onFocus: () => params.onFocusChanged(true),
        )
          ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
          ..create();
      },
    );
  }
}

class _UnsupportedNativeBoard extends StatelessWidget {
  const _UnsupportedNativeBoard();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: GameColors.background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF2A5474)),
      ),
      child: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Native Android board rendering is only available on Android.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
