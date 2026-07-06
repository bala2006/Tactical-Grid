import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../domain/profile.dart';
import 'profile_store.dart';

/// Factory used by the conditional import in `profile_store.dart`.
ProfileStore createProfileStore() => _IoProfileStore();

/// File-backed profile store. Writes a single JSON document to the app's
/// documents directory. All failures degrade gracefully to a default profile
/// so progression issues can never block play.
class _IoProfileStore implements ProfileStore {
  static const String _fileName = 'player_profile.json';

  File? _cachedFile;

  Future<File> _file() async {
    final File? cached = _cachedFile;
    if (cached != null) {
      return cached;
    }
    final Directory dir = await getApplicationDocumentsDirectory();
    final File file = File('${dir.path}${Platform.pathSeparator}$_fileName');
    _cachedFile = file;
    return file;
  }

  @override
  Future<PlayerProfile> load() async {
    try {
      final File file = await _file();
      if (!await file.exists()) {
        return const PlayerProfile();
      }
      final String raw = await file.readAsString();
      if (raw.trim().isEmpty) {
        return const PlayerProfile();
      }
      final Object? decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return PlayerProfile.fromJson(decoded);
      }
      return const PlayerProfile();
    } catch (_) {
      return const PlayerProfile();
    }
  }

  @override
  Future<void> save(PlayerProfile profile) async {
    try {
      final File file = await _file();
      await file.writeAsString(jsonEncode(profile.toJson()), flush: true);
    } catch (_) {
      // Intentionally ignored: a failed save must not interrupt gameplay.
    }
  }
}
