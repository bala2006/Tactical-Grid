// Regression tests for the remaster's progression systems: star rating, crystal
// rewards, the campaign unlock chain, profile persistence (JSON round-trip),
// bonus objectives, and the ProgressionController's victory/unlock flows.
// These are pure Dart and need no native engine, locking in the meta layer.
import 'package:flutter_test/flutter_test.dart';
import 'package:towerdefense/src/features/game/domain/models.dart';
import 'package:towerdefense/src/features/progression/application/progression_controller.dart';
import 'package:towerdefense/src/features/progression/domain/campaign.dart';
import 'package:towerdefense/src/features/progression/domain/objectives.dart';
import 'package:towerdefense/src/features/progression/domain/profile.dart';
import 'package:towerdefense/src/features/progression/domain/shop.dart';
import 'package:towerdefense/src/features/progression/infrastructure/profile_store.dart';

/// In-memory store so the controller can be exercised without disk/path_provider.
class _FakeStore implements ProfileStore {
  PlayerProfile toLoad = const PlayerProfile();
  PlayerProfile? saved;

  @override
  Future<PlayerProfile> load() async => toLoad;

  @override
  Future<void> save(PlayerProfile profile) async {
    saved = profile;
  }
}

void main() {
  group('computeStars', () {
    test('full health is three stars', () {
      expect(computeStars(health: 40, maxHealth: 40), 3);
    });
    test('half or more health is two stars', () {
      expect(computeStars(health: 20, maxHealth: 40), 2);
      expect(computeStars(health: 21, maxHealth: 40), 2);
    });
    test('below half is one star', () {
      expect(computeStars(health: 19, maxHealth: 40), 1);
      expect(computeStars(health: 1, maxHealth: 40), 1);
    });
    test('degenerate maxHealth never crashes', () {
      expect(computeStars(health: 0, maxHealth: 0), 1);
    });
  });

  group('crystalRewardForImprovement', () {
    test('first clear to three stars pays all tiers', () {
      expect(
        crystalRewardForImprovement(previousStars: 0, newStars: 3),
        kCrystalsPerStarTier[1]! +
            kCrystalsPerStarTier[2]! +
            kCrystalsPerStarTier[3]!,
      );
    });
    test('only the improved tiers pay', () {
      expect(crystalRewardForImprovement(previousStars: 1, newStars: 2), 20);
    });
    test('no improvement pays nothing', () {
      expect(crystalRewardForImprovement(previousStars: 2, newStars: 2), 0);
      expect(crystalRewardForImprovement(previousStars: 3, newStars: 1), 0);
    });
  });

  group('Campaign', () {
    test('has 12 missions with unique sequential orders', () {
      expect(Campaign.levelCount, 12);
      final List<int> orders =
          Campaign.orderedLevels.map((CampaignLevel l) => l.order).toList();
      expect(orders, List<int>.generate(12, (int i) => i));
    });
    test('nextLevel walks the chain and stops at the end', () {
      expect(Campaign.nextLevel('m01')?.id, 'm02');
      expect(Campaign.nextLevel('m11')?.id, 'm12');
      expect(Campaign.nextLevel('m12'), isNull);
    });
    test('every mission has a unique fixed map id and positive waves', () {
      final Set<String> seenMaps = <String>{};
      for (final CampaignLevel level in Campaign.orderedLevels) {
        expect(level.totalWaves, greaterThan(0));
        expect(level.mapId.isNotEmpty, isTrue);
        expect(
          seenMaps.add(level.mapId),
          isTrue,
          reason: 'map "${level.mapId}" is reused by more than one mission',
        );
      }
    });
  });

  group('PlayerProfile', () {
    test('only the first mission is unlocked on a fresh profile', () {
      const PlayerProfile profile = PlayerProfile();
      expect(profile.isLevelUnlocked('m01'), isTrue);
      expect(profile.isLevelUnlocked('m02'), isFalse);
    });
    test('clearing a mission unlocks the next', () {
      const PlayerProfile profile = PlayerProfile(
        levelStars: <String, int>{'m01': 2},
      );
      expect(profile.isLevelUnlocked('m02'), isTrue);
      expect(profile.isLevelUnlocked('m03'), isFalse);
    });
    test('totals aggregate stars and cleared levels', () {
      const PlayerProfile profile = PlayerProfile(
        levelStars: <String, int>{'w1_l1': 3, 'w1_l2': 1},
      );
      expect(profile.totalStars, 4);
      expect(profile.levelsCleared, 2);
      expect(profile.isCampaignComplete, isFalse);
    });
    test('JSON round-trip preserves all fields', () {
      const PlayerProfile profile = PlayerProfile(
        levelStars: <String, int>{'w1_l1': 3},
        crystals: 42,
        bestWaveReached: 17,
        totalKills: 999,
        fastestClearSeconds: 88,
        unlockedTowers: <String>{'laser', 'sniper'},
        claimedObjectives: <String>{'w1_l1:efficient'},
      );
      final PlayerProfile restored =
          PlayerProfile.fromJson(profile.toJson());
      expect(restored.levelStars, profile.levelStars);
      expect(restored.crystals, 42);
      expect(restored.bestWaveReached, 17);
      expect(restored.totalKills, 999);
      expect(restored.fastestClearSeconds, 88);
      expect(restored.unlockedTowers, profile.unlockedTowers);
      expect(restored.claimedObjectives, profile.claimedObjectives);
    });
    test('fromJson tolerates missing/garbage fields', () {
      final PlayerProfile restored =
          PlayerProfile.fromJson(<String, dynamic>{'crystals': 'oops'});
      expect(restored.crystals, 0);
      expect(restored.unlockedTowers, isEmpty);
    });
  });

  group('Objectives', () {
    test('efficient + no-sales evaluate from run stats', () {
      final List<BonusObjective> both =
          Objectives.evaluate(towersBuilt: 8, soldAny: false);
      expect(both.map((BonusObjective o) => o.id),
          containsAll(<String>['efficient', 'noSales']));
    });
    test('over the tower limit or after a sale awards neither', () {
      expect(Objectives.evaluate(towersBuilt: 9, soldAny: true), isEmpty);
    });
  });

  group('ProgressionController.recordVictory', () {
    test('first clear awards stars, crystals, objectives and unlocks next', () {
      final ProgressionController controller =
          ProgressionController(store: _FakeStore());
      final LevelResult result = controller.recordVictory(
        levelId: 'm01',
        health: 40,
        maxHealth: 40,
        kills: 30,
        waveReached: 8,
        towersBuilt: 5,
        soldAny: false,
      );
      expect(result.stars, 3);
      expect(result.unlockedNext?.id, 'm02');
      expect(result.newObjectives.length, 2);
      // 65 (stars) + 15 (efficient) + 10 (no sales)
      expect(result.crystalsAwarded, 90);
      expect(controller.profile.crystals, 90);
      expect(controller.profile.starsFor('m01'), 3);
      controller.dispose();
    });

    test('replaying without improvement awards nothing again', () {
      final ProgressionController controller =
          ProgressionController(store: _FakeStore());
      controller.recordVictory(
        levelId: 'm01',
        health: 40,
        maxHealth: 40,
        kills: 30,
        waveReached: 8,
        towersBuilt: 5,
        soldAny: false,
      );
      final int crystalsAfterFirst = controller.profile.crystals;
      final LevelResult replay = controller.recordVictory(
        levelId: 'm01',
        health: 10,
        maxHealth: 40,
        kills: 30,
        waveReached: 8,
        towersBuilt: 12,
        soldAny: true,
      );
      expect(replay.crystalsAwarded, 0);
      expect(replay.newObjectives, isEmpty);
      expect(controller.profile.crystals, crystalsAfterFirst);
      expect(controller.profile.starsFor('m01'), 3);
      controller.dispose();
    });

    test('kills accumulate toward lifetime totals', () {
      final ProgressionController controller =
          ProgressionController(store: _FakeStore());
      controller.recordVictory(
        levelId: 'm01',
        health: 40,
        maxHealth: 40,
        kills: 12,
        waveReached: 8,
        towersBuilt: 5,
        soldAny: false,
      );
      expect(controller.profile.totalKills, 12);
      expect(controller.profile.bestWaveReached, 8);
      controller.dispose();
    });
  });

  group('ProgressionController tower unlocks', () {
    test('starter towers are unlocked, others are not', () {
      final ProgressionController controller =
          ProgressionController(store: _FakeStore());
      expect(controller.isTowerUnlocked(TowerKind.gun), isTrue);
      expect(controller.isTowerUnlocked(TowerKind.slow), isTrue);
      expect(controller.isTowerUnlocked(TowerKind.laser), isFalse);
      controller.dispose();
    });

    test('cannot unlock without enough crystals', () {
      final _FakeStore store = _FakeStore()
        ..toLoad = const PlayerProfile(crystals: 5);
      final ProgressionController controller =
          ProgressionController(store: store);
      // Seed the in-memory profile directly via load.
      return controller.load().then((_) {
        final TowerUnlock laser = Shop.towerUnlocks
            .firstWhere((TowerUnlock u) => u.kind == TowerKind.laser);
        expect(controller.unlockTower(laser), isFalse);
        expect(controller.isTowerUnlocked(TowerKind.laser), isFalse);
        controller.dispose();
      });
    });

    test('unlocking deducts crystals and persists', () {
      final _FakeStore store = _FakeStore()
        ..toLoad = const PlayerProfile(crystals: 500);
      final ProgressionController controller =
          ProgressionController(store: store);
      return controller.load().then((_) {
        final TowerUnlock laser = Shop.towerUnlocks
            .firstWhere((TowerUnlock u) => u.kind == TowerKind.laser);
        expect(controller.unlockTower(laser), isTrue);
        expect(controller.isTowerUnlocked(TowerKind.laser), isTrue);
        expect(controller.profile.crystals, 500 - laser.crystalCost);
        // Already owned -> second purchase is a no-op.
        expect(controller.unlockTower(laser), isFalse);
        controller.dispose();
      });
    });
  });
}
