import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/models.dart';

const String _nativeControlChannelName = 'towerdefense/native_control';
const String _nativeStateChannelName = 'towerdefense/native_state';
const String nativeBoardViewType = 'towerdefense/native_board';

bool get supportsNativeGameBoard =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

class NativeGameBridge {
  NativeGameBridge()
    : _controlChannel = const MethodChannel(_nativeControlChannelName),
      _stateChannel = const EventChannel(_nativeStateChannelName);

  final MethodChannel _controlChannel;
  final EventChannel _stateChannel;

  Stream<NativeGameSnapshot> snapshots() {
    return _stateChannel.receiveBroadcastStream().map((dynamic event) {
      final String raw = event is String ? event : jsonEncode(event);
      return NativeGameSnapshot.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    });
  }

  Future<void> initialize() => _invoke('initialize');

  Future<void> setScreen(String screenId) =>
      _invoke('setScreen', <String, dynamic>{'screen': screenId});

  Future<void> restart() => _invoke('restart');

  Future<void> togglePause() => _invoke('togglePause');

  Future<void> sellTower() => _invoke('sellTower');

  Future<void> upgradeTower() => _invoke('upgradeTower');

  Future<void> confirmPlacement() => _invoke('confirmPlacement');

  Future<void> cancelPlacement() => _invoke('cancelPlacement');

  Future<void> selectTower(String towerId) =>
      _invoke('selectTower', <String, dynamic>{'towerId': towerId});

  Future<void> setMap(String mapId) =>
      _invoke('setMap', <String, dynamic>{'mapId': mapId});

  Future<void> setDifficulty(Difficulty difficulty) => _invoke(
    'setDifficulty',
    <String, dynamic>{'difficulty': difficulty.index},
  );

  Future<void> setWaveMode(WaveMode waveMode) =>
      _invoke('setWaveMode', <String, dynamic>{'waveMode': waveMode.index});

  Future<void> setQuality(PerformanceQuality quality) => _invoke(
    'setQuality',
    <String, dynamic>{'quality': quality.index},
  );

  Future<void> setToggle(String action, bool value) =>
      _invoke(action, <String, dynamic>{'value': value});

  Future<bool> importMapString(String value) async {
    final bool? result = await _controlChannel.invokeMethod<bool>(
      'importMap',
      <String, dynamic>{'value': value},
    );
    return result ?? false;
  }

  Future<String?> exportMapString() =>
      _controlChannel.invokeMethod<String>('exportMap');

  Future<void> _invoke(String method, [Map<String, dynamic>? arguments]) async {
    await _controlChannel.invokeMethod<void>(method, arguments);
  }
}

class NativeGameSnapshot {
  const NativeGameSnapshot({
    required this.runId,
    required this.tick,
    required this.simTimeMs,
    required this.activeScreen,
    required this.hud,
    required this.selection,
    required this.pendingPlacement,
    required this.performance,
    required this.runStats,
    required this.defeatVisible,
    required this.defeatSummary,
    required this.config,
    required this.exportMap,
  });

  factory NativeGameSnapshot.fromJson(Map<String, dynamic> json) {
    return NativeGameSnapshot(
      runId: (json['runId'] as num?)?.toInt() ?? 0,
      tick: (json['tick'] as num?)?.toInt() ?? 0,
      simTimeMs: (json['simTimeMs'] as num?)?.toDouble() ?? 0,
      activeScreen: _screenIdToName((json['activeScreen'] as num?)?.toInt() ?? 0),
      hud: NativeHudState.fromJson(
        (json['hud'] as Map<String, dynamic>? ?? <String, dynamic>{}),
      ),
      selection: json['selection'] == null
          ? null
          : NativeSelectionInfo.fromJson(
              (json['selection'] as Map<String, dynamic>),
            ),
      pendingPlacement: json['pendingPlacement'] == null
          ? null
          : NativePendingPlacementInfo.fromJson(
              json['pendingPlacement'] as Map<String, dynamic>,
            ),
      performance: NativePerfStats.fromJson(
        (json['perf'] as Map<String, dynamic>? ?? <String, dynamic>{}),
      ),
      runStats: NativeRunStats.fromJson(
        (json['runStats'] as Map<String, dynamic>? ?? <String, dynamic>{}),
      ),
      defeatVisible:
          ((json['defeat'] as Map<String, dynamic>? ?? <String, dynamic>{})['visible']
              as bool?) ??
          false,
      defeatSummary:
          ((json['defeat'] as Map<String, dynamic>? ?? <String, dynamic>{})['summary']
              as String?) ??
          '',
      config: NativeConfigState.fromJson(
        (json['config'] as Map<String, dynamic>? ?? <String, dynamic>{}),
      ),
      exportMap: json['exportMap'] as String?,
    );
  }

  final int runId;
  final int tick;
  final double simTimeMs;
  final String activeScreen;
  final NativeHudState hud;
  final NativeSelectionInfo? selection;
  final NativePendingPlacementInfo? pendingPlacement;
  final NativePerfStats performance;
  final NativeRunStats runStats;
  final bool defeatVisible;
  final String defeatSummary;
  final NativeConfigState config;
  final String? exportMap;
}

class NativeHudState {
  const NativeHudState({
    required this.health,
    required this.maxHealth,
    required this.cash,
    required this.wave,
    required this.kills,
    required this.waveState,
    required this.paused,
  });

  factory NativeHudState.fromJson(Map<String, dynamic> json) {
    return NativeHudState(
      health: (json['health'] as num?)?.toInt() ?? 0,
      maxHealth: (json['maxHealth'] as num?)?.toInt() ?? 0,
      cash: (json['cash'] as num?)?.toInt() ?? 0,
      wave: (json['wave'] as num?)?.toInt() ?? 0,
      kills: (json['kills'] as num?)?.toInt() ?? 0,
      waveState: json['waveState'] as String? ?? 'Idle',
      paused: json['paused'] as bool? ?? true,
    );
  }

  final int health;
  final int maxHealth;
  final int cash;
  final int wave;
  final int kills;
  final String waveState;
  final bool paused;
}

class NativeSelectionInfo {
  const NativeSelectionInfo({
    required this.status,
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

  factory NativeSelectionInfo.fromJson(Map<String, dynamic> json) {
    final int titleColor = (json['titleColor'] as num?)?.toInt() ?? 0xFFFFFFFF;
    return NativeSelectionInfo(
      status: json['status'] as String? ?? 'Selected: None',
      title: json['title'] as String? ?? '',
      titleColor: Color(titleColor),
      cost: (json['cost'] as num?)?.toDouble() ?? 0,
      sellPrice: (json['sellPrice'] as num?)?.toDouble() ?? 0,
      upgradePrice: json['upgradePrice'] == null
          ? null
          : (json['upgradePrice'] as num).toDouble(),
      upgradeDelta: json['upgradeDelta'] as String? ?? 'No more upgrades',
      damage: json['damage'] as String? ?? '',
      dps: (json['dps'] as num?)?.toDouble() ?? 0,
      damageTypeLabel: json['damageTypeLabel'] as String? ?? '',
      range: (json['range'] as num?)?.toDouble() ?? 0,
      cooldownSeconds: (json['cooldownSeconds'] as num?)?.toDouble() ?? 0,
      targeting: json['targeting'] as String? ?? '',
      effect: json['effect'] as String? ?? '',
      placementReason: json['placementReason'] as String? ?? '',
      canSell: json['canSell'] as bool? ?? false,
      canUpgrade: json['canUpgrade'] as bool? ?? false,
    );
  }

  final String status;
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

class NativePendingPlacementInfo {
  const NativePendingPlacementInfo({
    required this.id,
    required this.title,
    required this.cost,
    required this.anchorX,
    required this.anchorY,
  });

  factory NativePendingPlacementInfo.fromJson(Map<String, dynamic> json) {
    return NativePendingPlacementInfo(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      cost: (json['cost'] as num?)?.toDouble() ?? 0,
      anchorX: (json['anchorX'] as num?)?.toDouble() ?? 0,
      anchorY: (json['anchorY'] as num?)?.toDouble() ?? 0,
    );
  }

  final String id;
  final String title;
  final double cost;
  final double anchorX;
  final double anchorY;
}

class NativePerfStats {
  const NativePerfStats({
    required this.show,
    required this.fps,
    required this.frameTimeMs,
    required this.quality,
  });

  factory NativePerfStats.fromJson(Map<String, dynamic> json) {
    return NativePerfStats(
      show: json['show'] as bool? ?? false,
      fps: (json['fps'] as num?)?.toDouble() ?? 0,
      frameTimeMs: (json['frameTimeMs'] as num?)?.toDouble() ?? 0,
      quality: json['quality'] as String? ?? PerformanceQuality.high.name,
    );
  }

  final bool show;
  final double fps;
  final double frameTimeMs;
  final String quality;
}

class NativeRunStats {
  const NativeRunStats({
    required this.built,
    required this.kills,
    required this.leaks,
    required this.totalDamage,
  });

  factory NativeRunStats.fromJson(Map<String, dynamic> json) {
    return NativeRunStats(
      built: (json['built'] as num?)?.toInt() ?? 0,
      kills: (json['kills'] as num?)?.toInt() ?? 0,
      leaks: (json['leaks'] as num?)?.toInt() ?? 0,
      totalDamage: (json['totalDamage'] as num?)?.toDouble() ?? 0,
    );
  }

  final int built;
  final int kills;
  final int leaks;
  final double totalDamage;
}

class NativeConfigState {
  const NativeConfigState({
    required this.mapId,
    required this.difficulty,
    required this.waveMode,
    required this.quality,
    required this.effects,
    required this.healthBars,
    required this.muted,
    required this.autoSend,
    required this.adaptiveQuality,
    required this.showFps,
    required this.godMode,
    required this.firingDisabled,
    required this.zoom,
  });

  factory NativeConfigState.fromJson(Map<String, dynamic> json) {
    return NativeConfigState(
      mapId: json['mapId'] as String? ?? 'sparse2',
      difficulty: (json['difficulty'] as num?)?.toInt() ?? 1,
      waveMode: (json['waveMode'] as num?)?.toInt() ?? 0,
      quality: (json['quality'] as num?)?.toInt() ?? 0,
      effects: json['effects'] as bool? ?? true,
      healthBars: json['healthBars'] as bool? ?? true,
      muted: json['muted'] as bool? ?? false,
      autoSend: json['autoSend'] as bool? ?? false,
      adaptiveQuality: json['adaptiveQuality'] as bool? ?? true,
      showFps: json['showFps'] as bool? ?? false,
      godMode: json['godMode'] as bool? ?? false,
      firingDisabled: json['firingDisabled'] as bool? ?? false,
      zoom: (json['zoom'] as num?)?.toInt() ?? 18,
    );
  }

  final String mapId;
  final int difficulty;
  final int waveMode;
  final int quality;
  final bool effects;
  final bool healthBars;
  final bool muted;
  final bool autoSend;
  final bool adaptiveQuality;
  final bool showFps;
  final bool godMode;
  final bool firingDisabled;
  final int zoom;
}

String _screenIdToName(int screenId) {
  switch (screenId) {
    case 1:
      return 'map';
    case 2:
      return 'settings';
    case 3:
      return 'game';
    case 4:
      return 'leaderboard';
    default:
      return 'home';
  }
}
