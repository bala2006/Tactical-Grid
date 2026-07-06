import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

enum Difficulty { relaxed, normal, hard }

enum WaveMode { endless, preset, custom }

enum DamageType { physical, energy, explosion, poison, slow, piercing, regen }

enum TowerKind {
  gun,
  machineGun,
  laser,
  beamEmitter,
  slow,
  poison,
  sniper,
  railgun,
  rocket,
  missileSilo,
  bomb,
  clusterBomb,
  tesla,
  plasma,
  gatling,
  vulcanCiws,
  mortar,
  siegeHowitzer,
  interceptor,
  aegisBattery,
}

enum EnemyKind {
  weak,
  strong,
  fast,
  strongFast,
  medic,
  stronger,
  faster,
  tank,
  taunt,
  spawner,
}

enum EffectKind { slow, poison, regen }

enum TargetingMode { first, strongest, nearest, area, chain }

enum TowerBehavior {
  direct,
  beam,
  areaStatus,
  splashOnHit,
  missile,
  missileSilo,
  clusterBomb,
  chain,
}

enum EnemyBehavior { basic, arrowhead, medic, tank, taunt, spawner }

enum ParticleKind { fire, bomb, shrapnel, smoke, spark }

enum PerformanceQuality { high, balanced, battery }

class DevFlags {
  const DevFlags({
    this.showFps = false,
    this.godMode = false,
    this.firingDisabled = false,
    this.zoom = 18,
  });

  final bool showFps;
  final bool godMode;
  final bool firingDisabled;
  final int zoom;

  DevFlags copyWith({
    bool? showFps,
    bool? godMode,
    bool? firingDisabled,
    int? zoom,
  }) {
    return DevFlags(
      showFps: showFps ?? this.showFps,
      godMode: godMode ?? this.godMode,
      firingDisabled: firingDisabled ?? this.firingDisabled,
      zoom: zoom ?? this.zoom,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'showFps': showFps,
      'godMode': godMode,
      'firingDisabled': firingDisabled,
      'zoom': zoom,
    };
  }

  factory DevFlags.fromJson(Map<String, dynamic> json) {
    return DevFlags(
      showFps: json['showFps'] as bool? ?? false,
      godMode: json['godMode'] as bool? ?? false,
      firingDisabled: json['firingDisabled'] as bool? ?? false,
      zoom: (json['zoom'] as num?)?.toInt() ?? 18,
    );
  }
}

class GameConfig {
  const GameConfig({
    this.mapSelection = 'sparse2',
    this.difficulty = Difficulty.normal,
    this.waveMode = WaveMode.endless,
    this.muted = false,
    this.effectsEnabled = true,
    this.healthBars = true,
    this.autoSend = false,
    this.adaptiveQuality = true,
    this.quality = PerformanceQuality.high,
    this.devFlags = const DevFlags(),
  });

  final String mapSelection;
  final Difficulty difficulty;
  final WaveMode waveMode;
  final bool muted;
  final bool effectsEnabled;
  final bool healthBars;
  final bool autoSend;
  final bool adaptiveQuality;
  final PerformanceQuality quality;
  final DevFlags devFlags;

  GameConfig copyWith({
    String? mapSelection,
    Difficulty? difficulty,
    WaveMode? waveMode,
    bool? muted,
    bool? effectsEnabled,
    bool? healthBars,
    bool? autoSend,
    bool? adaptiveQuality,
    PerformanceQuality? quality,
    DevFlags? devFlags,
  }) {
    return GameConfig(
      mapSelection: mapSelection ?? this.mapSelection,
      difficulty: difficulty ?? this.difficulty,
      waveMode: waveMode ?? this.waveMode,
      muted: muted ?? this.muted,
      effectsEnabled: effectsEnabled ?? this.effectsEnabled,
      healthBars: healthBars ?? this.healthBars,
      autoSend: autoSend ?? this.autoSend,
      adaptiveQuality: adaptiveQuality ?? this.adaptiveQuality,
      quality: quality ?? this.quality,
      devFlags: devFlags ?? this.devFlags,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'mapSelection': mapSelection,
      'difficulty': difficulty.index,
      'waveMode': waveMode.index,
      'muted': muted,
      'effectsEnabled': effectsEnabled,
      'healthBars': healthBars,
      'autoSend': autoSend,
      'adaptiveQuality': adaptiveQuality,
      'quality': quality.index,
      'devFlags': devFlags.toJson(),
    };
  }

  factory GameConfig.fromJson(Map<String, dynamic> json) {
    final int difficultyIndex = (json['difficulty'] as num?)?.toInt() ?? 1;
    final int waveModeIndex = (json['waveMode'] as num?)?.toInt() ?? 0;
    final int qualityIndex = (json['quality'] as num?)?.toInt() ?? 0;
    return GameConfig(
      mapSelection: json['mapSelection'] as String? ?? 'sparse2',
      difficulty: Difficulty.values[
          difficultyIndex.clamp(0, Difficulty.values.length - 1)],
      waveMode:
          WaveMode.values[waveModeIndex.clamp(0, WaveMode.values.length - 1)],
      muted: json['muted'] as bool? ?? false,
      effectsEnabled: json['effectsEnabled'] as bool? ?? true,
      healthBars: json['healthBars'] as bool? ?? true,
      autoSend: json['autoSend'] as bool? ?? false,
      adaptiveQuality: json['adaptiveQuality'] as bool? ?? true,
      quality: PerformanceQuality.values[
          qualityIndex.clamp(0, PerformanceQuality.values.length - 1)],
      devFlags: json['devFlags'] == null
          ? const DevFlags()
          : DevFlags.fromJson(json['devFlags'] as Map<String, dynamic>),
    );
  }
}

class ShellState {
  const ShellState({
    required this.activeScreen,
    required this.isInitializing,
    required this.loadError,
  });

  final String activeScreen;
  final bool isInitializing;
  final String? loadError;
}

class PerformanceStats {
  const PerformanceStats({
    required this.fps,
    required this.frameTimeMs,
    required this.quality,
    required this.activeEnemies,
    required this.activeTowers,
    required this.activeMissiles,
    required this.activeParticles,
    required this.activeBeams,
    required this.activePulses,
    required this.pendingPathJobs,
    required this.uiRebuilds,
  });

  const PerformanceStats.empty()
    : fps = 0,
      frameTimeMs = 0,
      quality = PerformanceQuality.high,
      activeEnemies = 0,
      activeTowers = 0,
      activeMissiles = 0,
      activeParticles = 0,
      activeBeams = 0,
      activePulses = 0,
      pendingPathJobs = 0,
      uiRebuilds = 0;

  final double fps;
  final double frameTimeMs;
  final PerformanceQuality quality;
  final int activeEnemies;
  final int activeTowers;
  final int activeMissiles;
  final int activeParticles;
  final int activeBeams;
  final int activePulses;
  final int pendingPathJobs;
  final int uiRebuilds;
}

@immutable
class GridPoint {
  const GridPoint(this.x, this.y);

  final int x;
  final int y;

  GridPoint operator +(GridPoint other) => GridPoint(x + other.x, y + other.y);

  GridPoint operator -(GridPoint other) => GridPoint(x - other.x, y - other.y);

  Vector2 center(double tileSize) =>
      Vector2(x * tileSize + tileSize / 2, y * tileSize + tileSize / 2);

  double distanceTo(GridPoint other) {
    final dx = (x - other.x).toDouble();
    final dy = (y - other.y).toDouble();
    return math.sqrt(dx * dx + dy * dy);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GridPoint &&
          runtimeType == other.runtimeType &&
          x == other.x &&
          y == other.y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => '$x,$y';

  static GridPoint fromString(String value) {
    final parts = value.split(',');
    return GridPoint(int.parse(parts[0]), int.parse(parts[1]));
  }

  List<int> toJson() => <int>[x, y];

  factory GridPoint.fromJson(List<dynamic> json) {
    return GridPoint((json[0] as num).toInt(), (json[1] as num).toInt());
  }
}

class WaveGroup {
  const WaveGroup({required this.sequence, required this.count});

  final List<EnemyKind> sequence;
  final int count;

  List<dynamic> toJson() => [...sequence.map((enemy) => enemy.name), count];
}

class WaveTemplate {
  const WaveTemplate({required this.spawnCooldown, required this.groups});

  final int spawnCooldown;
  final List<WaveGroup> groups;

  List<dynamic> toJson() => [
    spawnCooldown,
    ...groups.map((group) => group.toJson()),
  ];
}

class TowerBlueprint {
  const TowerBlueprint({
    required this.kind,
    required this.title,
    required this.effectText,
    required this.targetingText,
    required this.damageType,
    required this.behavior,
    required this.targetingMode,
    required this.cost,
    required this.range,
    required this.damageMin,
    required this.damageMax,
    required this.cooldownMin,
    required this.cooldownMax,
    required this.color,
    required this.secondaryColor,
    required this.flashColor,
    required this.radius,
    required this.length,
    required this.width,
    required this.weight,
    required this.baseOnTop,
    required this.hasBase,
    required this.hasBarrel,
    required this.drawLine,
    required this.follow,
    required this.recoilAmount,
    required this.sound,
    required this.upgrades,
  });

  final TowerKind kind;
  final String title;
  final String effectText;
  final String targetingText;
  final DamageType damageType;
  final TowerBehavior behavior;
  final TargetingMode targetingMode;
  final int cost;
  final double range;
  final double damageMin;
  final double damageMax;
  final int cooldownMin;
  final int cooldownMax;
  final Color color;
  final Color secondaryColor;
  final Color flashColor;
  final double radius;
  final double length;
  final double width;
  final double weight;
  final bool baseOnTop;
  final bool hasBase;
  final bool hasBarrel;
  final bool drawLine;
  final bool follow;
  final double recoilAmount;
  final String? sound;
  final List<TowerKind> upgrades;
}

class EnemyBlueprint {
  const EnemyBlueprint({
    required this.kind,
    required this.name,
    required this.behavior,
    required this.color,
    required this.secondaryColor,
    required this.radius,
    required this.cash,
    required this.health,
    required this.damage,
    required this.speed,
    required this.taunt,
    required this.sound,
    required this.immunities,
    required this.resistances,
    required this.weaknesses,
  });

  final EnemyKind kind;
  final String name;
  final EnemyBehavior behavior;
  final Color color;
  final Color secondaryColor;
  final double radius;
  final int cash;
  final double health;
  final int damage;
  final double speed;
  final bool taunt;
  final String sound;
  final Set<DamageType> immunities;
  final Set<DamageType> resistances;
  final Set<DamageType> weaknesses;
}

class EffectBlueprint {
  const EffectBlueprint({required this.kind, required this.color});

  final EffectKind kind;
  final Color color;
}

class TowerAnalytics {
  int damage = 0;
  int kills = 0;
  int shots = 0;
}

class StatusEffectInstance {
  StatusEffectInstance({required this.kind, required this.duration});

  final EffectKind kind;
  int duration;
  double? storedSpeed;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'kind': kind.name,
      'duration': duration,
      'storedSpeed': storedSpeed,
    };
  }

  factory StatusEffectInstance.fromJson(Map<String, dynamic> json) {
    final EffectKind kind = EffectKind.values.firstWhere(
      (EffectKind value) => value.name == (json['kind'] as String? ?? 'slow'),
      orElse: () => EffectKind.slow,
    );
    final StatusEffectInstance effect = StatusEffectInstance(
      kind: kind,
      duration: (json['duration'] as num?)?.toInt() ?? 0,
    );
    effect.storedSpeed = (json['storedSpeed'] as num?)?.toDouble();
    return effect;
  }
}

class EnemyEntity {
  EnemyEntity({required this.blueprint, required this.position})
    : velocity = Vector2.zero(),
      health = blueprint.health,
      maxHealth = blueprint.health,
      damage = blueprint.damage;

  final EnemyBlueprint blueprint;
  final Vector2 position;
  final Vector2 velocity;
  final List<StatusEffectInstance> effects = [];

  double health;
  final double maxHealth;
  final int damage;
  bool alive = true;
  double hitFlash = 0;
  TowerEntity? lastHitBy;

  double speed = 0;

  void initialize() {
    speed = blueprint.speed;
  }
}

class TowerEntity {
  TowerEntity({
    required this.blueprint,
    required this.gridPosition,
    required this.position,
  }) : totalCost = blueprint.cost.toDouble(),
       analytics = TowerAnalytics();

  TowerBlueprint blueprint;
  final GridPoint gridPosition;
  final Vector2 position;
  double angle = 0;
  bool alive = true;
  int cooldown = 0;
  double flash = 0;
  double recoil = 0;
  double totalCost;
  EnemyEntity? lastTarget;
  int beamDuration = 0;
  final TowerAnalytics analytics;
}

class MissileEntity {
  MissileEntity({
    required this.position,
    required this.target,
    required this.source,
    required this.color,
    required this.secondaryColor,
    required this.damageMin,
    required this.damageMax,
    required this.blastRadius,
    required this.topSpeed,
    required this.acceleration,
    required this.range,
  }) : velocity = Vector2.zero(),
       accelerationVector = Vector2.zero();

  final Vector2 position;
  final Vector2 velocity;
  final Vector2 accelerationVector;
  EnemyEntity target;
  final TowerEntity source;
  final Color color;
  final Color secondaryColor;
  final double damageMin;
  final double damageMax;
  final double blastRadius;
  final double topSpeed;
  final double acceleration;
  final double range;
  bool alive = true;
  int lifetime = 60;
  int trailCooldown = 0;
}

class ParticleEntity {
  ParticleEntity({
    required this.kind,
    required this.position,
    required this.velocity,
    required this.acceleration,
    required this.color,
    required this.radius,
    required this.drag,
    required this.decay,
    required this.gravity,
    this.angle = 0,
    this.angularVelocity = 0,
    this.lifespan = 255,
  });

  final ParticleKind kind;
  final Vector2 position;
  final Vector2 velocity;
  final Vector2 acceleration;
  final Color color;
  final double radius;
  final double drag;
  final double decay;
  final double gravity;
  double angle;
  double angularVelocity;
  double lifespan;
}

class TempSpawn {
  TempSpawn({required this.point, required this.ticks});

  final GridPoint point;
  int ticks;
}

class RunStats {
  const RunStats({
    this.built = 0,
    this.kills = 0,
    this.leaks = 0,
    this.totalDamage = 0,
  });

  final int built;
  final int kills;
  final int leaks;
  final double totalDamage;

  RunStats copyWith({int? built, int? kills, int? leaks, double? totalDamage}) {
    return RunStats(
      built: built ?? this.built,
      kills: kills ?? this.kills,
      leaks: leaks ?? this.leaks,
      totalDamage: totalDamage ?? this.totalDamage,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'built': built,
      'kills': kills,
      'leaks': leaks,
      'totalDamage': totalDamage,
    };
  }

  factory RunStats.fromJson(Map<String, dynamic> json) {
    return RunStats(
      built: (json['built'] as num?)?.toInt() ?? 0,
      kills: (json['kills'] as num?)?.toInt() ?? 0,
      leaks: (json['leaks'] as num?)?.toInt() ?? 0,
      totalDamage: (json['totalDamage'] as num?)?.toDouble() ?? 0,
    );
  }
}

class SelectionInfo {
  const SelectionInfo({
    required this.title,
    required this.titleColor,
    required this.cost,
    required this.sellPrice,
    required this.upgradePrice,
    required this.upgradeDelta,
    required this.damage,
    required this.dps,
    required this.damageTypeLabel,
    required this.range,
    required this.cooldownSeconds,
    required this.targeting,
    required this.effect,
    required this.placementReason,
    required this.canSell,
    required this.canUpgrade,
  });

  final String title;
  final Color titleColor;
  final double cost;
  final double sellPrice;
  final double? upgradePrice;
  final String upgradeDelta;
  final String damage;
  final double dps;
  final String damageTypeLabel;
  final double range;
  final double cooldownSeconds;
  final String targeting;
  final String effect;
  final String placementReason;
  final bool canSell;
  final bool canUpgrade;
}

class PendingPlacementInfo {
  const PendingPlacementInfo({
    required this.id,
    required this.title,
    required this.cost,
    required this.anchorX,
    required this.anchorY,
    this.placementAllowed = false,
    this.placementAffordable = false,
    this.showPlaceAction = false,
    this.remainingTicks = 0,
    this.statusText = '',
  });

  final String id;
  final String title;
  final double cost;
  final double anchorX;
  final double anchorY;
  final bool placementAllowed;
  final bool placementAffordable;
  final bool showPlaceAction;
  final int remainingTicks;
  final String statusText;
}

class AppUiState {
  const AppUiState({
    required this.wave,
    required this.waveState,
    required this.health,
    required this.maxHealth,
    required this.cash,
    required this.selectionStatus,
    required this.threatLabel,
    required this.pills,
    required this.selectionInfo,
    required this.pendingPlacement,
    required this.runStats,
    required this.isPaused,
    required this.canAdvanceWave,
    required this.isMuted,
    required this.effectsEnabled,
    required this.healthBarsEnabled,
    required this.defeat,
    required this.performance,
    this.victory = false,
    this.stars = 0,
    this.totalWaves = 0,
  });

  final int wave;
  final String waveState;
  final int health;
  final int maxHealth;
  final int cash;
  final String selectionStatus;
  final String threatLabel;
  final List<String> pills;
  final SelectionInfo? selectionInfo;
  final PendingPlacementInfo? pendingPlacement;
  final RunStats runStats;
  final bool isPaused;
  final bool canAdvanceWave;
  final bool isMuted;
  final bool effectsEnabled;
  final bool healthBarsEnabled;
  final bool defeat;
  final PerformanceStats performance;

  /// Remaster: finite campaign-level outcome.
  final bool victory;
  final int stars;
  final int totalWaves;
}

class MapDefinition {
  MapDefinition({
    required this.name,
    required this.display,
    required this.displayDirection,
    required this.grid,
    required this.metadata,
    required this.paths,
    required this.exit,
    required this.spawnpoints,
    required this.background,
    required this.border,
    required this.borderAlpha,
    required this.cols,
    required this.rows,
    this.customWaves,
  });

  final String name;
  final List<List<String>> display;
  final List<List<int>> displayDirection;
  final List<List<int>> grid;
  final List<List<dynamic>> metadata;
  final List<List<int>> paths;
  final GridPoint exit;
  final List<GridPoint> spawnpoints;
  final List<int> background;
  final int border;
  final int borderAlpha;
  final int cols;
  final int rows;
  final List<WaveTemplate>? customWaves;

  Map<String, dynamic> toJsonCompatible() {
    return <String, dynamic>{
      'display': display,
      'displayDir': displayDirection,
      'grid': grid,
      'metadata': metadata,
      'paths': paths,
      'exit': [exit.x, exit.y],
      'spawnpoints': spawnpoints.map((spawn) => [spawn.x, spawn.y]).toList(),
      'bg': background,
      'border': border,
      'borderAlpha': borderAlpha,
      'cols': cols,
      'rows': rows,
      'waves': customWaves?.map((wave) => wave.toJson()).toList(),
    };
  }
}

Color colorFromList(List<int> rgb, {int alpha = 255}) =>
    Color.fromARGB(alpha, rgb[0], rgb[1], rgb[2]);
