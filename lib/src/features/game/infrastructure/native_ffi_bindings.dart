import 'dart:ffi' as ffi;

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

const int _mapIdCapacity = 32;
const int _waveStateCapacity = 32;
const int _defeatSummaryCapacity = 160;
const int _selectionStatusCapacity = 64;
const int _selectionTitleCapacity = 48;
const int _upgradeDeltaCapacity = 96;
const int _damageTextCapacity = 24;
const int _damageTypeCapacity = 24;
const int _targetingCapacity = 32;
const int _effectCapacity = 48;
const int _placementReasonCapacity = 96;
const int _pendingPlacementIdCapacity = 48;
const int _pendingPlacementTitleCapacity = 48;
const int _pendingPlacementStatusCapacity = 96;

enum NativeSoundId {
  none(0),
  boom(1),
  missile(2),
  pop(3),
  railgun(4),
  sniper(5),
  spark(6),
  taunt(7);

  const NativeSoundId(this.value);
  final int value;

  static NativeSoundId fromValue(int value) {
    return NativeSoundId.values.firstWhere(
      (NativeSoundId id) => id.value == value,
      orElse: () => NativeSoundId.none,
    );
  }
}

final class NativeAudioEvent {
  const NativeAudioEvent({required this.soundId, required this.volume});

  final NativeSoundId soundId;
  final double volume;
}

final class NativeFfiBindings {
  NativeFfiBindings._()
    : _snapshotPointer = _library
          .lookupFunction<
            ffi.Pointer<NativeGameSnapshotStruct> Function(),
            ffi.Pointer<NativeGameSnapshotStruct> Function()
          >('nativeGetGameSnapshot'),
      _consumeAudioEvents = _library
          .lookupFunction<
            ffi.Int32 Function(ffi.Pointer<NativeAudioEventStruct>, ffi.Int32),
            int Function(ffi.Pointer<NativeAudioEventStruct>, int)
          >('nativeConsumeAudioEvents'),
      _setActiveScreen = _library
          .lookupFunction<ffi.Void Function(ffi.Int32), void Function(int)>(
            'nativeSetActiveScreenFfi',
          ),
      _invokeAction = _library
          .lookupFunction<
            ffi.Bool Function(ffi.Pointer<Utf8>, ffi.Pointer<Utf8>),
            bool Function(ffi.Pointer<Utf8>, ffi.Pointer<Utf8>)
          >('nativeInvokeActionFfi');

  static final NativeFfiBindings instance = NativeFfiBindings._();

  static final ffi.DynamicLibrary _library = _openLibrary();
  final ffi.Pointer<NativeGameSnapshotStruct> Function() _snapshotPointer;
  final int Function(ffi.Pointer<NativeAudioEventStruct>, int)
  _consumeAudioEvents;
  final void Function(int) _setActiveScreen;
  final bool Function(ffi.Pointer<Utf8>, ffi.Pointer<Utf8>) _invokeAction;

  static ffi.DynamicLibrary _openLibrary() {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw UnsupportedError('Native bindings are only available on Android.');
    }
    return ffi.DynamicLibrary.open('libtowerdefense.so');
  }

  NativeGameSnapshotStruct readSnapshot() => _snapshotPointer().ref;

  // Reused scratch buffer for draining audio events. Allocated once and kept for
  // the process lifetime so the 60 Hz drain loop does not calloc/free every poll
  // (that per-poll native allocation was a primary driver of GC churn).
  ffi.Pointer<NativeAudioEventStruct>? _audioBuffer;
  int _audioBufferCapacity = 0;

  List<NativeAudioEvent> drainAudioEvents([int maxEvents = 16]) {
    if (_audioBuffer == null || _audioBufferCapacity < maxEvents) {
      if (_audioBuffer != null) {
        calloc.free(_audioBuffer!);
      }
      _audioBuffer = calloc<NativeAudioEventStruct>(maxEvents);
      _audioBufferCapacity = maxEvents;
    }
    final ffi.Pointer<NativeAudioEventStruct> buffer = _audioBuffer!;
    final int count = _consumeAudioEvents(buffer, maxEvents);
    if (count <= 0) {
      return const <NativeAudioEvent>[];
    }
    return List<NativeAudioEvent>.generate(count, (int index) {
      final NativeAudioEventStruct event = buffer[index];
      return NativeAudioEvent(
        soundId: NativeSoundId.fromValue(event.soundId),
        volume: event.volume,
      );
    }, growable: false);
  }

  void setActiveScreen(int screenId) {
    _setActiveScreen(screenId);
  }

  bool invokeAction(String actionId, [String payload = '']) {
    final ffi.Pointer<Utf8> actionPtr = actionId.toNativeUtf8();
    final ffi.Pointer<Utf8> payloadPtr = payload.toNativeUtf8();
    try {
      return _invokeAction(actionPtr, payloadPtr);
    } finally {
      calloc.free(actionPtr);
      calloc.free(payloadPtr);
    }
  }
}

@ffi.Packed(1)
final class NativeAudioEventStruct extends ffi.Struct {
  @ffi.Uint8()
  external int soundId;

  @ffi.Float()
  external double volume;
}

@ffi.Packed(1)
final class NativeHudSnapshotStruct extends ffi.Struct {
  @ffi.Int32()
  external int health;

  @ffi.Int32()
  external int maxHealth;

  @ffi.Int32()
  external int cash;

  @ffi.Int32()
  external int wave;

  @ffi.Int32()
  external int kills;

  @ffi.Array.multi([_waveStateCapacity])
  external ffi.Array<ffi.Uint8> waveState;

  @ffi.Uint8()
  external int paused;
}

@ffi.Packed(1)
final class NativePerfSnapshotStruct extends ffi.Struct {
  @ffi.Uint8()
  external int show;

  @ffi.Float()
  external double fps;

  @ffi.Float()
  external double frameTimeMs;

  @ffi.Int32()
  external int quality;
}

@ffi.Packed(1)
final class NativeRunStatsSnapshotStruct extends ffi.Struct {
  @ffi.Int32()
  external int built;

  @ffi.Int32()
  external int kills;

  @ffi.Int32()
  external int leaks;

  @ffi.Float()
  external double totalDamage;
}

@ffi.Packed(1)
final class NativeConfigSnapshotStruct extends ffi.Struct {
  @ffi.Int32()
  external int difficulty;

  @ffi.Int32()
  external int waveMode;

  @ffi.Int32()
  external int quality;

  @ffi.Uint8()
  external int effects;

  @ffi.Uint8()
  external int healthBars;

  @ffi.Uint8()
  external int muted;

  @ffi.Uint8()
  external int autoSend;

  @ffi.Uint8()
  external int adaptiveQuality;

  @ffi.Uint8()
  external int showFps;

  @ffi.Uint8()
  external int godMode;

  @ffi.Uint8()
  external int firingDisabled;

  @ffi.Int32()
  external int zoom;

  @ffi.Array.multi([_mapIdCapacity])
  external ffi.Array<ffi.Uint8> mapId;
}

@ffi.Packed(1)
final class NativeSelectionSnapshotStruct extends ffi.Struct {
  @ffi.Uint8()
  external int present;

  @ffi.Array.multi([_selectionStatusCapacity])
  external ffi.Array<ffi.Uint8> status;

  @ffi.Array.multi([_selectionTitleCapacity])
  external ffi.Array<ffi.Uint8> title;

  @ffi.Uint32()
  external int titleColor;

  @ffi.Float()
  external double cost;

  @ffi.Float()
  external double sellPrice;

  @ffi.Uint8()
  external int hasUpgradePrice;

  @ffi.Float()
  external double upgradePrice;

  @ffi.Array.multi([_upgradeDeltaCapacity])
  external ffi.Array<ffi.Uint8> upgradeDelta;

  @ffi.Array.multi([_damageTextCapacity])
  external ffi.Array<ffi.Uint8> damage;

  @ffi.Float()
  external double dps;

  @ffi.Array.multi([_damageTypeCapacity])
  external ffi.Array<ffi.Uint8> damageTypeLabel;

  @ffi.Float()
  external double range;

  @ffi.Float()
  external double cooldownSeconds;

  @ffi.Array.multi([_targetingCapacity])
  external ffi.Array<ffi.Uint8> targeting;

  @ffi.Array.multi([_effectCapacity])
  external ffi.Array<ffi.Uint8> effect;

  @ffi.Array.multi([_placementReasonCapacity])
  external ffi.Array<ffi.Uint8> placementReason;

  @ffi.Uint8()
  external int canSell;

  @ffi.Uint8()
  external int canUpgrade;
}

@ffi.Packed(1)
final class NativePendingPlacementSnapshotStruct extends ffi.Struct {
  @ffi.Uint8()
  external int present;

  @ffi.Array.multi([_pendingPlacementIdCapacity])
  external ffi.Array<ffi.Uint8> id;

  @ffi.Array.multi([_pendingPlacementTitleCapacity])
  external ffi.Array<ffi.Uint8> title;

  @ffi.Float()
  external double cost;

  @ffi.Float()
  external double anchorX;

  @ffi.Float()
  external double anchorY;

  @ffi.Uint8()
  external int placementAllowed;

  @ffi.Uint8()
  external int placementAffordable;

  @ffi.Uint8()
  external int showPlaceAction;

  @ffi.Int32()
  external int remainingTicks;

  @ffi.Array.multi([_pendingPlacementStatusCapacity])
  external ffi.Array<ffi.Uint8> statusText;
}

@ffi.Packed(1)
final class NativeGameSnapshotStruct extends ffi.Struct {
  @ffi.Int32()
  external int runId;

  @ffi.Int32()
  external int tick;

  @ffi.Int64()
  external int simTimeMs;

  @ffi.Int32()
  external int activeScreen;

  external NativeHudSnapshotStruct hud;
  external NativePerfSnapshotStruct perf;

  @ffi.Uint8()
  external int defeatVisible;

  @ffi.Array.multi([_defeatSummaryCapacity])
  external ffi.Array<ffi.Uint8> defeatSummary;

  external NativeConfigSnapshotStruct config;
  external NativeRunStatsSnapshotStruct runStats;
  external NativeSelectionSnapshotStruct selection;
  external NativePendingPlacementSnapshotStruct pendingPlacement;

  @ffi.Array.multi([_mapIdCapacity])
  external ffi.Array<ffi.Uint8> exportMap;

  // Remaster (appended to match NativeInterop.h; preserves existing offsets):
  @ffi.Uint8()
  external int victoryVisible;

  @ffi.Int32()
  external int stars;

  @ffi.Int32()
  external int totalWaves;
}

String readNativeString(ffi.Array<ffi.Uint8> buffer, int capacity) {
  final StringBuffer out = StringBuffer();
  for (int index = 0; index < capacity; index++) {
    final int codeUnit = buffer[index];
    if (codeUnit == 0) {
      break;
    }
    out.writeCharCode(codeUnit);
  }
  return out.toString();
}
