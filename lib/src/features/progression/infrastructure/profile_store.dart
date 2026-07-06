import '../domain/profile.dart';

// Conditional import: the IO implementation (path_provider + dart:io) is used on
// every platform that has dart:io (Android/iOS/desktop); web falls back to an
// in-memory stub so the app still compiles and runs there.
import 'profile_store_stub.dart' if (dart.library.io) 'profile_store_io.dart';

/// Persists the [PlayerProfile] between sessions.
abstract class ProfileStore {
  /// Creates the platform-appropriate store.
  factory ProfileStore() => createProfileStore();

  /// Loads the saved profile, or a fresh default profile if none exists or the
  /// stored data is unreadable.
  Future<PlayerProfile> load();

  /// Persists [profile]. Failures are swallowed so a write error never crashes
  /// gameplay.
  Future<void> save(PlayerProfile profile);
}
