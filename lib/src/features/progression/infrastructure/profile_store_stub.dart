import '../domain/profile.dart';
import 'profile_store.dart';

/// Factory used by the conditional import in `profile_store.dart` on platforms
/// without `dart:io` (web). Progression is kept in memory only for the session.
ProfileStore createProfileStore() => _MemoryProfileStore();

class _MemoryProfileStore implements ProfileStore {
  PlayerProfile _profile = const PlayerProfile();

  @override
  Future<PlayerProfile> load() async => _profile;

  @override
  Future<void> save(PlayerProfile profile) async {
    _profile = profile;
  }
}
