import '../../game/domain/models.dart';

/// A tower that can be permanently unlocked with crystals.
class TowerUnlock {
  const TowerUnlock({
    required this.kind,
    required this.crystalCost,
    required this.blurb,
  });

  final TowerKind kind;
  final int crystalCost;
  final String blurb;
}

/// The meta shop catalog. Tower unlocks are the P2 spend; commanders and stat
/// perks (which need engine support) come later.
class Shop {
  const Shop._();

  /// Towers available from the very first run, before spending any crystals.
  /// Kept deliberately small so unlocking the rest feels like real progression.
  static const Set<TowerKind> defaultUnlockedTowers = <TowerKind>{
    TowerKind.gun,
    TowerKind.slow,
  };

  /// Purchasable tower unlocks, in suggested unlock order (rising cost).
  static const List<TowerUnlock> towerUnlocks = <TowerUnlock>[
    TowerUnlock(
      kind: TowerKind.laser,
      crystalCost: 40,
      blurb: 'Directed-energy beam for steady close defense.',
    ),
    TowerUnlock(
      kind: TowerKind.sniper,
      crystalCost: 60,
      blurb: 'Long-range, high-damage single shots.',
    ),
    TowerUnlock(
      kind: TowerKind.rocket,
      crystalCost: 90,
      blurb: 'Guided missiles with splash damage.',
    ),
    TowerUnlock(
      kind: TowerKind.gatling,
      crystalCost: 110,
      blurb: 'Rotary autocannon — shreds swarms at close range.',
    ),
    TowerUnlock(
      kind: TowerKind.bomb,
      crystalCost: 120,
      blurb: 'Lobbed explosives for tight enemy clusters.',
    ),
    TowerUnlock(
      kind: TowerKind.mortar,
      crystalCost: 150,
      blurb: 'Artillery lobbing arcing shells with wide splash.',
    ),
    TowerUnlock(
      kind: TowerKind.tesla,
      crystalCost: 160,
      blurb: 'Chaining electric arcs across nearby foes.',
    ),
    TowerUnlock(
      kind: TowerKind.interceptor,
      crystalCost: 200,
      blurb: 'Fast SAM interceptors that lead and chase targets.',
    ),
  ];

  /// All tower kinds that the storefront can ever surface (starter + unlockable).
  /// This is the canonical store set the dock filters against.
  static const Set<TowerKind> storefrontTowers = <TowerKind>{
    TowerKind.gun,
    TowerKind.laser,
    TowerKind.slow,
    TowerKind.sniper,
    TowerKind.rocket,
    TowerKind.gatling,
    TowerKind.bomb,
    TowerKind.mortar,
    TowerKind.tesla,
    TowerKind.interceptor,
  };
}
