import 'campaign.dart';

/// Persistent, account-wide player progression.
///
/// This is the home for everything that must survive between runs — the old
/// build had no persistence at all. Stored as JSON on disk via
/// [ProfileStore]. Kept as a plain immutable value type with explicit
/// `copyWith` so it is easy to test and reason about.
class PlayerProfile {
  const PlayerProfile({
    this.levelStars = const <String, int>{},
    this.crystals = 0,
    this.bestWaveReached = 0,
    this.totalKills = 0,
    this.fastestClearSeconds,
    this.unlockedTowers = const <String>{},
    this.claimedObjectives = const <String>{},
  });

  /// Best star rating (0–3) earned per campaign level id.
  final Map<String, int> levelStars;

  /// Meta-currency earned from stars/bosses, spent in the shop (P2).
  final int crystals;

  /// Highest wave number reached in any run (feeds the leaderboard).
  final int bestWaveReached;

  /// Lifetime enemy kills (feeds the leaderboard).
  final int totalKills;

  /// Fastest campaign level clear in seconds, or null if none cleared yet.
  final int? fastestClearSeconds;

  /// Tower kind names purchased in the shop (does not include starter towers).
  final Set<String> unlockedTowers;

  /// Bonus objectives already claimed, keyed `levelId:objectiveId`.
  final Set<String> claimedObjectives;

  /// Stars earned for a specific level (0 if never cleared).
  int starsFor(String levelId) => levelStars[levelId] ?? 0;

  /// Sum of all stars earned across the campaign.
  int get totalStars =>
      levelStars.values.fold<int>(0, (int sum, int s) => sum + s);

  /// Number of distinct levels cleared with at least one star.
  int get levelsCleared => levelStars.values.where((int s) => s > 0).length;

  /// A level is unlocked if it is the first level or the previous level (in
  /// campaign order) has been cleared with at least one star.
  bool isLevelUnlocked(String levelId) {
    final CampaignLevel? level = Campaign.levelById(levelId);
    if (level == null) {
      return false;
    }
    if (level.order == 0) {
      return true;
    }
    for (final CampaignLevel candidate in Campaign.orderedLevels) {
      if (candidate.order == level.order - 1) {
        return starsFor(candidate.id) > 0;
      }
    }
    return false;
  }

  /// True when every campaign level has at least one star.
  bool get isCampaignComplete => levelsCleared >= Campaign.levelCount;

  PlayerProfile copyWith({
    Map<String, int>? levelStars,
    int? crystals,
    int? bestWaveReached,
    int? totalKills,
    int? fastestClearSeconds,
    bool clearFastestClear = false,
    Set<String>? unlockedTowers,
    Set<String>? claimedObjectives,
  }) {
    return PlayerProfile(
      levelStars: levelStars ?? this.levelStars,
      crystals: crystals ?? this.crystals,
      bestWaveReached: bestWaveReached ?? this.bestWaveReached,
      totalKills: totalKills ?? this.totalKills,
      fastestClearSeconds: clearFastestClear
          ? null
          : (fastestClearSeconds ?? this.fastestClearSeconds),
      unlockedTowers: unlockedTowers ?? this.unlockedTowers,
      claimedObjectives: claimedObjectives ?? this.claimedObjectives,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'levelStars': levelStars,
      'crystals': crystals,
      'bestWaveReached': bestWaveReached,
      'totalKills': totalKills,
      'fastestClearSeconds': fastestClearSeconds,
      'unlockedTowers': unlockedTowers.toList(),
      'claimedObjectives': claimedObjectives.toList(),
    };
  }

  factory PlayerProfile.fromJson(Map<String, dynamic> json) {
    final Map<String, int> stars = <String, int>{};
    final Object? rawStars = json['levelStars'];
    if (rawStars is Map) {
      rawStars.forEach((Object? key, Object? value) {
        if (key is String && value is num) {
          stars[key] = value.toInt().clamp(0, 3);
        }
      });
    }
    final Set<String> unlocked = <String>{};
    final Object? rawUnlocked = json['unlockedTowers'];
    if (rawUnlocked is List) {
      for (final Object? entry in rawUnlocked) {
        if (entry is String) {
          unlocked.add(entry);
        }
      }
    }
    final Set<String> claimed = <String>{};
    final Object? rawClaimed = json['claimedObjectives'];
    if (rawClaimed is List) {
      for (final Object? entry in rawClaimed) {
        if (entry is String) {
          claimed.add(entry);
        }
      }
    }
    return PlayerProfile(
      levelStars: stars,
      crystals: _asInt(json['crystals']),
      bestWaveReached: _asInt(json['bestWaveReached']),
      totalKills: _asInt(json['totalKills']),
      fastestClearSeconds:
          json['fastestClearSeconds'] is num
          ? (json['fastestClearSeconds'] as num).toInt()
          : null,
      unlockedTowers: unlocked,
      claimedObjectives: claimed,
    );
  }
}

/// Safely reads an int from untrusted JSON; non-numeric values fall back to 0.
int _asInt(Object? value) => value is num ? value.toInt() : 0;

/// Crystals awarded per star tier, per the remaster design table.
const Map<int, int> kCrystalsPerStarTier = <int, int>{1: 10, 2: 20, 3: 35};

/// Computes star rating (1–3) for a cleared level from the health that
/// remained at victory. Mirrors the design table:
///   ★   cleared (any health)
///   ★★  cleared with >= 50% health
///   ★★★ cleared with 100% health (no leaks)
int computeStars({required int health, required int maxHealth}) {
  if (maxHealth <= 0) {
    return 1;
  }
  if (health >= maxHealth) {
    return 3;
  }
  if (health * 2 >= maxHealth) {
    return 2;
  }
  return 1;
}

/// Crystals earned for going from [previousStars] to [newStars] on a level.
/// Only the *incremental* tier value is awarded so replaying for a better score
/// pays the difference, and a worse/equal result pays nothing.
int crystalRewardForImprovement({
  required int previousStars,
  required int newStars,
}) {
  if (newStars <= previousStars) {
    return 0;
  }
  int total = 0;
  for (int tier = previousStars + 1; tier <= newStars; tier++) {
    total += kCrystalsPerStarTier[tier] ?? 0;
  }
  return total;
}
