import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

/// Low-latency sound-effect voice backed by Android SoundPool
/// (`PlayerMode.lowLatency`).
///
/// Why this exists:
/// The previous implementation used `MediaPlayer`-backed pools, which created
/// a heavyweight `MediaPlayer` (plus DRM session) per voice. With several
/// sounds each holding multiple voices the device ran out of codec resources
/// (`MEDIA_ERROR_UNKNOWN extra:-19`). When a player then errored, the plugin's
/// `onCompletion` path called `prepareAsync` in an invalid state and threw an
/// uncaught `IllegalStateException` that crashed the whole app.
///
/// SoundPool decodes each clip into memory once, replays it with near-zero
/// latency, never instantiates a `MediaPlayer` per shot, and does not use the
/// crashing completion path. It is also far lighter on the GC.
///
/// Each [SfxVoice] owns a small ring of preloaded players so the same effect
/// can overlap (e.g. rapid "pop" kills) without cutting itself off.
class SfxVoice {
  SfxVoice._(this._players);

  final List<AudioPlayer> _players;
  int _cursor = 0;
  double _lastVolume = -1;
  bool _disposed = false;

  static bool _globalContextConfigured = false;

  /// Configure audio output ONCE so it never grabs Android audio focus. Game
  /// SFX should mix and never duck other audio. Requesting/losing focus on every
  /// shot was flooding the main thread with `onAudioFocusChange` callbacks,
  /// cutting the sounds and causing severe frame drops.
  static Future<void> _ensureGlobalAudioContext() async {
    if (_globalContextConfigured) {
      return;
    }
    _globalContextConfigured = true;
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            isSpeakerphoneOn: false,
            stayAwake: false,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.game,
            audioFocus: AndroidAudioFocus.none,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.ambient,
            options: const <AVAudioSessionOptions>{
              AVAudioSessionOptions.mixWithOthers,
            },
          ),
        ),
      );
    } catch (_) {
      // Non-fatal: if context can't be set we still play, just less ideal.
    }
  }

  /// Creates and preloads a voice. [voices] is how many overlapping copies of
  /// the sound can play at once. Failures are swallowed so audio is never fatal.
  static Future<SfxVoice> create(
    String assetPath, {
    int voices = 3,
    double volume = 1.0,
  }) async {
    await _ensureGlobalAudioContext();

    // The asset paths passed in are already fully-qualified ('assets/audio/..'),
    // so the default audio cache prefix ('assets/') must be cleared once to
    // avoid resolving to 'assets/assets/...'.
    AudioCache.instance.prefix = '';

    final List<AudioPlayer> players = <AudioPlayer>[];
    for (int i = 0; i < voices; i++) {
      final AudioPlayer player = AudioPlayer();
      try {
        await player.setReleaseMode(ReleaseMode.stop);
        await player.setPlayerMode(PlayerMode.lowLatency);
        // Preload (decode) the clip once.
        await player.setSource(AssetSource(assetPath));
        await player.setVolume(volume.clamp(0.0, 1.0));
      } catch (_) {
        // Ignore: a failed voice simply stays silent instead of crashing.
      }
      players.add(player);
    }
    return SfxVoice._(players);
  }

  /// Plays the next available copy of the sound. Never throws.
  Future<void> play({double volume = 1.0}) async {
    if (_disposed || _players.isEmpty) {
      return;
    }
    final AudioPlayer player = _players[_cursor];
    _cursor = (_cursor + 1) % _players.length;
    final double v = volume.clamp(0.0, 1.0);
    try {
      // Only push volume across the channel when it actually changed; avoid the
      // unsupported `seek` (it throws on SoundPool). `resume()` replays a
      // low-latency clip from the start.
      if ((v - _lastVolume).abs() > 0.02) {
        _lastVolume = v;
        await player.setVolume(v);
      }
      await player.resume();
    } catch (_) {
      // Swallow transient player-state errors; SFX must never be fatal.
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    for (final AudioPlayer player in _players) {
      try {
        await player.release();
        await player.dispose();
      } catch (_) {}
    }
    _players.clear();
  }
}
