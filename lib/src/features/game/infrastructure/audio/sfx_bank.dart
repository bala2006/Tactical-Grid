import 'package:flutter/services.dart';

/// Low-latency sound-effect bank backed by a native, **codec-free** AudioTrack
/// engine (see `android/.../SfxChannel.kt`), reached over a method channel.
///
/// Why native + codec-free:
/// * `MediaPlayer`-per-voice (original build) exhausted codecs and crashed.
/// * The `soundpool` plugin no longer compiles (legacy v1 embedding).
/// * `audioplayers` AND `SoundPool` both decode clips through `MediaCodec`
///   (`c2.android.raw.decoder`), spamming the codec pipeline.
///
/// The native side parses each WAV to raw 16-bit PCM once and plays it straight
/// through `AudioTrack` (MODE_STATIC) — no decoder at all, near-zero latency,
/// no audio-focus management (so it can't duck other audio or stall the UI),
/// and overlap handled by a small ring of tracks per clip. Every call is
/// guarded so audio is never fatal.
class SfxBank {
  SfxBank({this.voicesPerSound = 3});

  /// Retained for API compatibility; the native pool handles overlap via its
  /// stream limit, so this is no longer used per-sound.
  final int voicesPerSound;

  static const MethodChannel _channel = MethodChannel('towerdefense/sfx');
  bool _disposed = false;

  /// Creates the underlying native pool.
  Future<void> init() async {
    if (_disposed) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('init');
    } catch (_) {
      // Non-fatal: audio simply stays silent.
    }
  }

  /// Decodes a clip once and registers it under [key], with a ring of [voices]
  /// tracks for overlap (defaults to [voicesPerSound]).
  Future<void> load(String key, String assetPath, {int? voices}) async {
    if (_disposed) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('load', <String, Object?>{
        'key': key,
        'asset': assetPath,
        'voices': voices ?? voicesPerSound,
      });
    } catch (_) {
      // A clip that fails to load simply stays silent.
    }
  }

  /// Plays [key]. Fire-and-forget for lowest latency; never throws.
  void play(String key, {double volume = 1.0}) {
    if (_disposed) {
      return;
    }
    // Intentionally not awaited: the platform call is queued without blocking
    // the 16 ms audio drain on the UI isolate.
    _channel
        .invokeMethod<void>('play', <String, Object?>{
          'key': key,
          'volume': volume.clamp(0.0, 1.0),
        })
        .catchError((_) {});
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    try {
      await _channel.invokeMethod<void>('dispose');
    } catch (_) {}
  }
}
