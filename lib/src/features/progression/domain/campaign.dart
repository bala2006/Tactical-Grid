import '../../game/domain/models.dart';

/// Campaign model — a single continuous **Deployment ladder**.
///
/// The old build grouped levels into themed "worlds" of four. This is a flat,
/// linear chain of distinct missions instead: one escalating climb where every
/// mission has its own fixed map and the difficulty ramps continuously. A few
/// missions are flagged as **Elite Ops** — milestone beats that punctuate the
/// run without breaking it into regions.
///
/// Pure data + value types so it can be unit-tested and shared by both the
/// native (Android/C++) path and the Dart fallback engine.

/// A single playable mission on the deployment ladder.
class CampaignLevel {
  const CampaignLevel({
    required this.id,
    required this.name,
    required this.codename,
    required this.mapId,
    required this.difficulty,
    required this.totalWaves,
    required this.order,
    this.isElite = false,
  });

  /// Stable unique id, e.g. `m03`. Persistence key + native `setLevel` payload.
  final String id;

  /// Player-facing mission name.
  final String name;

  /// Short operational codename shown as an eyebrow (e.g. "OP. IRONFALL").
  final String codename;

  /// The fixed map this mission is always played on.
  final String mapId;

  /// Difficulty this mission is locked to.
  final Difficulty difficulty;

  /// Number of waves to survive; clearing the last wave wins the mission.
  final int totalWaves;

  /// 0-based position in the linear chain, used for the unlock order.
  final int order;

  /// Milestone "boss beat" missions, surfaced distinctly on the timeline.
  final bool isElite;
}

/// The full campaign, defined once as one ordered ladder of missions.
class Campaign {
  const Campaign._();

  /// The deployment ladder: 12 distinct missions on 12 fixed maps, with a
  /// smooth wave + difficulty ramp and three Elite Op milestones.
  static const List<CampaignLevel> missions = <CampaignLevel>[
    CampaignLevel(
      id: 'm01',
      name: 'Shakedown',
      codename: 'OP. FIRST LIGHT',
      mapId: 'empty2',
      difficulty: Difficulty.relaxed,
      totalWaves: 5,
      order: 0,
    ),
    CampaignLevel(
      id: 'm02',
      name: 'Open Ground',
      codename: 'OP. CLEAR FIELD',
      mapId: 'sparse2',
      difficulty: Difficulty.relaxed,
      totalWaves: 6,
      order: 1,
    ),
    CampaignLevel(
      id: 'm03',
      name: 'The Loops',
      codename: 'OP. SWITCHBACK',
      mapId: 'loops',
      difficulty: Difficulty.normal,
      totalWaves: 7,
      order: 2,
    ),
    CampaignLevel(
      id: 'm04',
      name: 'Spiral Descent',
      codename: 'ELITE — VORTEX',
      mapId: 'spiral',
      difficulty: Difficulty.normal,
      totalWaves: 8,
      order: 3,
      isElite: true,
    ),
    CampaignLevel(
      id: 'm05',
      name: 'Assembly Line',
      codename: 'OP. FORGEWORKS',
      mapId: 'dense2',
      difficulty: Difficulty.normal,
      totalWaves: 9,
      order: 4,
    ),
    CampaignLevel(
      id: 'm06',
      name: 'Branch Works',
      codename: 'OP. CROSSCUT',
      mapId: 'branch',
      difficulty: Difficulty.normal,
      totalWaves: 10,
      order: 5,
    ),
    CampaignLevel(
      id: 'm07',
      name: 'City Grid',
      codename: 'OP. GRIDLOCK',
      mapId: 'city',
      difficulty: Difficulty.hard,
      totalWaves: 11,
      order: 6,
    ),
    CampaignLevel(
      id: 'm08',
      name: 'The Walls',
      codename: 'ELITE — BULWARK',
      mapId: 'walls',
      difficulty: Difficulty.hard,
      totalWaves: 12,
      order: 7,
      isElite: true,
    ),
    CampaignLevel(
      id: 'm09',
      name: 'The Freeway',
      codename: 'OP. FAST LANE',
      mapId: 'freeway',
      difficulty: Difficulty.hard,
      totalWaves: 12,
      order: 8,
    ),
    CampaignLevel(
      id: 'm10',
      name: 'Forking Paths',
      codename: 'OP. SPLIT DECISION',
      mapId: 'fork',
      difficulty: Difficulty.hard,
      totalWaves: 13,
      order: 9,
    ),
    CampaignLevel(
      id: 'm11',
      name: 'Deep Approach',
      codename: 'OP. THRESHOLD',
      mapId: 'dense3',
      difficulty: Difficulty.hard,
      totalWaves: 14,
      order: 10,
    ),
    CampaignLevel(
      id: 'm12',
      name: 'The Overmind',
      codename: 'ELITE — FINAL STAND',
      mapId: 'solid3',
      difficulty: Difficulty.hard,
      totalWaves: 16,
      order: 11,
      isElite: true,
    ),
  ];

  /// Backwards-compatible alias: the order-sorted chain of every mission.
  static List<CampaignLevel> get orderedLevels => missions;

  /// Total number of missions in the campaign.
  static int get levelCount => missions.length;

  /// Look up a mission by its id, or null if unknown.
  static CampaignLevel? levelById(String id) {
    for (final CampaignLevel level in missions) {
      if (level.id == id) {
        return level;
      }
    }
    return null;
  }

  /// The mission immediately after [id] in the chain, or null if [id] is the
  /// final mission (campaign complete).
  static CampaignLevel? nextLevel(String id) {
    final CampaignLevel? current = levelById(id);
    if (current == null) {
      return null;
    }
    final int nextOrder = current.order + 1;
    for (final CampaignLevel level in missions) {
      if (level.order == nextOrder) {
        return level;
      }
    }
    return null;
  }
}
