import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../game/domain/models.dart';
import '../domain/campaign.dart';
import '../domain/objectives.dart';
import '../domain/profile.dart';
import '../domain/shop.dart';
import '../infrastructure/profile_store.dart';

/// Result of recording a level outcome, surfaced to the victory screen.
class LevelResult {
  const LevelResult({
    required this.levelId,
    required this.stars,
    required this.previousStars,
    required this.crystalsAwarded,
    required this.isNewBest,
    required this.unlockedNext,
    required this.newObjectives,
  });

  final String levelId;
  final int stars;
  final int previousStars;

  /// Total crystals awarded this clear (star improvement + newly claimed bonus
  /// objectives).
  final int crystalsAwarded;
  final bool isNewBest;
  final CampaignLevel? unlockedNext;

  /// Bonus objectives claimed for the first time on this clear.
  final List<BonusObjective> newObjectives;
}

/// Owns the persistent [PlayerProfile]: loading, mutation, and saving.
///
/// Deliberately separate from the gameplay `GameController` so progression has a
/// single clear home (the old build had none) and can be tested in isolation.
class ProgressionController {
  ProgressionController({ProfileStore? store})
    : _store = store ?? ProfileStore();

  final ProfileStore _store;

  final ValueNotifier<PlayerProfile> profileListenable =
      ValueNotifier<PlayerProfile>(const PlayerProfile());

  PlayerProfile get profile => profileListenable.value;

  bool _loaded = false;

  /// Loads the saved profile once. Safe to call multiple times.
  Future<void> load() async {
    if (_loaded) {
      return;
    }
    profileListenable.value = await _store.load();
    _loaded = true;
  }

  /// Records a campaign level victory, awarding stars and crystals and
  /// unlocking the next level. Returns a [LevelResult] synchronously; the disk
  /// write happens in the background so the UI is never blocked.
  LevelResult recordVictory({
    required String levelId,
    required int health,
    required int maxHealth,
    required int kills,
    required int waveReached,
    required int towersBuilt,
    required bool soldAny,
    int? clearSeconds,
  }) {
    final PlayerProfile current = profile;
    final int previousStars = current.starsFor(levelId);
    final int stars = computeStars(health: health, maxHealth: maxHealth);
    final int bestStars = stars > previousStars ? stars : previousStars;
    final int starCrystals = crystalRewardForImprovement(
      previousStars: previousStars,
      newStars: stars,
    );

    // Bonus objectives: award each at most once per level.
    final List<BonusObjective> achieved = Objectives.evaluate(
      towersBuilt: towersBuilt,
      soldAny: soldAny,
    );
    final List<BonusObjective> newObjectives = <BonusObjective>[];
    final Set<String> claimed = Set<String>.from(current.claimedObjectives);
    int objectiveCrystals = 0;
    for (final BonusObjective objective in achieved) {
      final String key = Objectives.claimKey(levelId, objective.id);
      if (claimed.add(key)) {
        newObjectives.add(objective);
        objectiveCrystals += objective.crystalReward;
      }
    }

    final int crystalsAwarded = starCrystals + objectiveCrystals;

    final Map<String, int> nextStars = Map<String, int>.from(current.levelStars)
      ..[levelId] = bestStars;

    final int? nextFastest = clearSeconds == null
        ? current.fastestClearSeconds
        : (current.fastestClearSeconds == null ||
                  clearSeconds < current.fastestClearSeconds!
              ? clearSeconds
              : current.fastestClearSeconds);

    final PlayerProfile updated = current.copyWith(
      levelStars: nextStars,
      crystals: current.crystals + crystalsAwarded,
      totalKills: current.totalKills + kills,
      bestWaveReached: waveReached > current.bestWaveReached
          ? waveReached
          : current.bestWaveReached,
      fastestClearSeconds: nextFastest,
      claimedObjectives: claimed,
    );

    _commit(updated);

    return LevelResult(
      levelId: levelId,
      stars: bestStars,
      previousStars: previousStars,
      crystalsAwarded: crystalsAwarded,
      isNewBest: stars > previousStars,
      unlockedNext: stars > 0 && previousStars == 0
          ? Campaign.nextLevel(levelId)
          : null,
      newObjectives: newObjectives,
    );
  }

  /// True if [kind] can be built — either a starter tower or one purchased in
  /// the shop.
  bool isTowerUnlocked(TowerKind kind) {
    return Shop.defaultUnlockedTowers.contains(kind) ||
        profile.unlockedTowers.contains(kind.name);
  }

  /// Attempts to buy a tower unlock. Returns true on success; false if it is
  /// already unlocked or the player cannot afford it.
  bool unlockTower(TowerUnlock unlock) {
    final PlayerProfile current = profile;
    if (isTowerUnlocked(unlock.kind)) {
      return false;
    }
    if (current.crystals < unlock.crystalCost) {
      return false;
    }
    _commit(
      current.copyWith(
        crystals: current.crystals - unlock.crystalCost,
        unlockedTowers: <String>{...current.unlockedTowers, unlock.kind.name},
      ),
    );
    return true;
  }

  /// Records a non-campaign run (e.g. a defeat or an endless session) so the
  /// leaderboard's lifetime stats stay current.
  void recordRunStats({required int waveReached, required int kills}) {
    final PlayerProfile current = profile;
    if (waveReached <= current.bestWaveReached && kills <= 0) {
      return;
    }
    final PlayerProfile updated = current.copyWith(
      totalKills: current.totalKills + kills,
      bestWaveReached: waveReached > current.bestWaveReached
          ? waveReached
          : current.bestWaveReached,
    );
    _commit(updated);
  }

  /// Updates the in-memory profile immediately and persists it in the
  /// background; a failed write never blocks or crashes gameplay.
  void _commit(PlayerProfile updated) {
    profileListenable.value = updated;
    unawaited(_store.save(updated));
  }

  void dispose() {
    profileListenable.dispose();
  }
}
