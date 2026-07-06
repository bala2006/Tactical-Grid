/// A per-level bonus challenge that pays extra crystals the first time it is
/// achieved. Evaluated at victory from the run's stats. Each objective can be
/// claimed once per level (tracked in the profile), so it rewards mastery and
/// replays without allowing infinite farming.
class BonusObjective {
  const BonusObjective({
    required this.id,
    required this.label,
    required this.description,
    required this.crystalReward,
  });

  final String id;
  final String label;
  final String description;
  final int crystalReward;
}

/// The set of bonus objectives applied to every campaign level.
class Objectives {
  const Objectives._();

  /// Win having built no more than this many towers.
  static const int efficientTowerLimit = 8;

  static const BonusObjective efficient = BonusObjective(
    id: 'efficient',
    label: 'Efficient Defense',
    description: 'Win with $efficientTowerLimit towers or fewer.',
    crystalReward: 15,
  );

  static const BonusObjective noSales = BonusObjective(
    id: 'noSales',
    label: 'No Sales',
    description: 'Win without selling a tower.',
    crystalReward: 10,
  );

  static const List<BonusObjective> all = <BonusObjective>[efficient, noSales];

  static BonusObjective? byId(String id) {
    for (final BonusObjective objective in all) {
      if (objective.id == id) {
        return objective;
      }
    }
    return null;
  }

  /// Storage key used in the profile's claimed set: `levelId:objectiveId`.
  static String claimKey(String levelId, String objectiveId) =>
      '$levelId:$objectiveId';

  /// Evaluates which objectives a run satisfied.
  static List<BonusObjective> evaluate({
    required int towersBuilt,
    required bool soldAny,
  }) {
    return <BonusObjective>[
      if (towersBuilt <= efficientTowerLimit) efficient,
      if (!soldAny) noSales,
    ];
  }
}
