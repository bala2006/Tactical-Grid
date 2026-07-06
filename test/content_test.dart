// Content-invariant tests for the authored Dart catalog that feeds the store/dock
// and (on non-Android) the fallback simulation. These mirror the native
// `validateContentOnce()` checks so balance/content can't silently regress —
// this is the drift class that previously shipped a 0-damage Machine Gun.
import 'package:flutter_test/flutter_test.dart';
import 'package:towerdefense/src/features/game/domain/content.dart';
import 'package:towerdefense/src/features/game/domain/models.dart';

void main() {
  group('Tower catalog invariants', () {
    test('every TowerKind has a blueprint', () {
      for (final TowerKind kind in TowerKind.values) {
        expect(
          towerBlueprints.containsKey(kind),
          isTrue,
          reason: 'Missing blueprint for tower $kind',
        );
      }
    });

    test('each blueprint key matches its declared kind', () {
      towerBlueprints.forEach((TowerKind key, TowerBlueprint bp) {
        expect(bp.kind, key, reason: 'Blueprint under $key declares kind ${bp.kind}');
      });
    });

    test('costs and ranges are positive', () {
      towerBlueprints.forEach((TowerKind kind, TowerBlueprint bp) {
        expect(bp.cost, greaterThan(0), reason: '$kind cost must be > 0');
        expect(bp.range, greaterThan(0), reason: '$kind range must be > 0');
      });
    });

    test('damage range is well-formed (min <= max, non-negative)', () {
      towerBlueprints.forEach((TowerKind kind, TowerBlueprint bp) {
        expect(bp.damageMin, greaterThanOrEqualTo(0), reason: '$kind damageMin');
        expect(
          bp.damageMax,
          greaterThanOrEqualTo(bp.damageMin),
          reason: '$kind damageMax must be >= damageMin',
        );
      });
    });

    test('damage-dealing towers never round to a 0-damage hit', () {
      // Status-only towers (no direct damage) are exempt — they apply slow/poison.
      const Set<TowerKind> statusOnly = <TowerKind>{TowerKind.slow, TowerKind.poison};
      towerBlueprints.forEach((TowerKind kind, TowerBlueprint bp) {
        if (statusOnly.contains(kind)) {
          return;
        }
        expect(
          bp.damageMax,
          greaterThanOrEqualTo(1),
          reason: '$kind is not status-only but can deal < 1 damage',
        );
      });
    });

    test('upgrade chains reference real towers and never regress DPS', () {
      const Set<TowerKind> statusOnly = <TowerKind>{TowerKind.slow, TowerKind.poison};
      // Upgrades may trade per-shot damage for fire rate (e.g. Gun -> Machine Gun),
      // so the meaningful invariant is damage-per-second, not per-shot damage.
      double dps(TowerBlueprint bp) {
        final double avgDamage = (bp.damageMin + bp.damageMax) / 2;
        final double avgCooldownTicks = (bp.cooldownMin + bp.cooldownMax) / 2;
        final double cooldownSeconds = avgCooldownTicks / 60.0;
        return cooldownSeconds <= 0 ? avgDamage * 60 : avgDamage / cooldownSeconds;
      }

      towerBlueprints.forEach((TowerKind kind, TowerBlueprint bp) {
        for (final TowerKind next in bp.upgrades) {
          final TowerBlueprint? upgrade = towerBlueprints[next];
          expect(upgrade, isNotNull, reason: '$kind upgrades to undefined $next');
          if (upgrade == null || statusOnly.contains(kind)) {
            continue;
          }
          expect(
            dps(upgrade),
            greaterThanOrEqualTo(dps(bp)),
            reason: 'Upgrade $kind -> $next reduces DPS '
                '(${dps(bp).toStringAsFixed(1)} -> ${dps(upgrade).toStringAsFixed(1)})',
          );
        }
      });
    });
  });

  group('Enemy catalog invariants', () {
    test('every EnemyKind has a blueprint', () {
      for (final EnemyKind kind in EnemyKind.values) {
        expect(
          enemyBlueprints.containsKey(kind),
          isTrue,
          reason: 'Missing blueprint for enemy $kind',
        );
      }
    });

    test('each blueprint key matches its declared kind', () {
      enemyBlueprints.forEach((EnemyKind key, EnemyBlueprint bp) {
        expect(bp.kind, key, reason: 'Blueprint under $key declares kind ${bp.kind}');
      });
    });

    test('enemies have positive health, speed and a non-empty name', () {
      enemyBlueprints.forEach((EnemyKind kind, EnemyBlueprint bp) {
        expect(bp.health, greaterThan(0), reason: '$kind health must be > 0');
        expect(bp.speed, greaterThan(0), reason: '$kind speed must be > 0');
        expect(bp.cash, greaterThanOrEqualTo(0), reason: '$kind cash must be >= 0');
        expect(bp.name, isNotEmpty, reason: '$kind must have a name');
      });
    });
  });
}
