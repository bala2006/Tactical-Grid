import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../domain/models.dart';
import 'native_ffi_bindings.dart';

export 'native_ffi_bindings.dart' show NativeAudioEvent, NativeSoundId;

const String nativeBoardViewType = 'towerdefense/native_board';
const int _bridgeMapIdCapacity = 32;
const int _bridgeWaveStateCapacity = 32;
const int _bridgeDefeatSummaryCapacity = 160;
const int _bridgeSelectionStatusCapacity = 64;
const int _bridgeSelectionTitleCapacity = 48;
const int _bridgeUpgradeDeltaCapacity = 96;
const int _bridgeDamageTextCapacity = 24;
const int _bridgeDamageTypeCapacity = 24;
const int _bridgeTargetingCapacity = 32;
const int _bridgeEffectCapacity = 48;
const int _bridgePlacementReasonCapacity = 96;
const int _bridgePendingPlacementIdCapacity = 48;
const int _bridgePendingPlacementTitleCapacity = 48;
const int _bridgePendingPlacementStatusCapacity = 96;

bool get supportsNativeGameBoard =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

class NativeGameBridge {
  NativeGameBridge() : _bindings = NativeFfiBindings.instance;

  static const Duration _pollInterval = Duration(milliseconds: 16);

  final NativeFfiBindings _bindings;
  StreamController<NativeGameSnapshot>? _snapshotController;
  Timer? _snapshotTimer;
  NativeGameSnapshot? _latestSnapshot;

  // Change-detection for the HUD emit. The native board renders independently at
  // 60 fps; the Dart snapshot only feeds HUD/overlays, so we skip rebuilding the
  // DTO tree (and waking the UI) when nothing user-visible changed. A periodic
  // safety re-emit keeps the FPS/perf overlay and any non-signature field fresh.
  int _lastSignature = 0;
  int _lastEmitMs = 0;
  static const int _maxQuietMs = 200;

  Stream<NativeGameSnapshot> snapshots() {
    _snapshotController ??= StreamController<NativeGameSnapshot>.broadcast(
      onListen: _startPolling,
      onCancel: _stopPollingIfIdle,
    );
    return _snapshotController!.stream;
  }

  Future<void> initialize() async {
    _emitSnapshot(force: true);
    _startPolling();
  }

  Future<void> dispose() async {
    _snapshotTimer?.cancel();
    _snapshotTimer = null;
    await _snapshotController?.close();
  }

  List<NativeAudioEvent> consumeAudioEvents() => _bindings.drainAudioEvents();

  Future<void> setScreen(String screenId) async {
    _bindings.setActiveScreen(_screenNameToId(screenId));
    _emitSnapshot(force: true);
  }

  Future<void> restart() async => _invoke('restart');

  Future<void> togglePause() async => _invoke('togglePause');

  Future<void> sellTower() async => _invoke('sellTower');

  Future<void> upgradeTower() async => _invoke('upgradeTower');

  Future<void> confirmPlacement() async => _invoke('confirmPlacement');

  Future<void> cancelPlacement() async => _invoke('cancelPlacement');

  Future<void> selectTower(String towerId) async =>
      _invoke('selectTower', towerId);

  Future<void> setMap(String mapId) async => _invoke('setMap', mapId);

  /// Loads a finite campaign level. Payload: `mapId|difficulty|totalWaves|waveMode`.
  Future<void> setLevel({
    required String mapId,
    required Difficulty difficulty,
    required int totalWaves,
    WaveMode waveMode = WaveMode.preset,
  }) async => _invoke(
    'setLevel',
    '$mapId|${difficulty.index}|$totalWaves|${waveMode.index}',
  );

  Future<void> setDifficulty(Difficulty difficulty) async =>
      _invoke('setDifficulty', difficulty.index.toString());

  Future<void> setWaveMode(WaveMode waveMode) async =>
      _invoke('setWaveMode', waveMode.index.toString());

  Future<void> setQuality(PerformanceQuality quality) async =>
      _invoke('setQuality', quality.index.toString());

  Future<void> setToggle(String action, bool value) async =>
      _invoke(action, value.toString());

  Future<bool> importMapString(String value) async =>
      _invoke('importMap', value.trim());

  Future<String?> exportMapString() async => _latestSnapshot?.exportMap;

  void _startPolling() {
    _snapshotTimer ??= Timer.periodic(_pollInterval, (_) => _emitSnapshot());
  }

  void _stopPollingIfIdle() {
    if (_snapshotController?.hasListener ?? false) {
      return;
    }
    _snapshotTimer?.cancel();
    _snapshotTimer = null;
  }

  bool _invoke(String actionId, [String payload = '']) {
    final bool result = _bindings.invokeAction(actionId, payload);
    // User actions always force a fresh emit so taps/selection feel instant.
    _emitSnapshot(force: true);
    return result;
  }

  void _emitSnapshot({bool force = false}) {
    final NativeGameSnapshotStruct ref = _bindings.readSnapshot();
    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    final int signature = _hudSignature(ref);
    if (!force &&
        signature == _lastSignature &&
        (nowMs - _lastEmitMs) < _maxQuietMs) {
      return;
    }
    _lastSignature = signature;
    _lastEmitMs = nowMs;
    final NativeGameSnapshot next = NativeGameSnapshot.fromStruct(ref);
    _latestSnapshot = next;
    _snapshotController?.add(next);
  }

  // Cheap scalar-only signature of the fields that affect the HUD/overlays.
  // Deliberately excludes tick, simTime and per-frame perf (fps/frameTime) so a
  // steady board does not force 60 Hz rebuilds; string fields are covered by the
  // scalars they travel with plus the _maxQuietMs safety re-emit.
  int _hudSignature(NativeGameSnapshotStruct s) {
    final NativeHudSnapshotStruct hud = s.hud;
    final NativeSelectionSnapshotStruct sel = s.selection;
    final NativePendingPlacementSnapshotStruct pend = s.pendingPlacement;
    final NativeConfigSnapshotStruct cfg = s.config;
    final NativeRunStatsSnapshotStruct rs = s.runStats;
    int h = 17;
    h = h * 31 + s.runId;
    h = h * 31 + s.activeScreen;
    h = h * 31 + s.defeatVisible;
    h = h * 31 + s.victoryVisible;
    h = h * 31 + s.stars;
    h = h * 31 + s.totalWaves;
    h = h * 31 + hud.health;
    h = h * 31 + hud.maxHealth;
    h = h * 31 + hud.cash;
    h = h * 31 + hud.wave;
    h = h * 31 + hud.kills;
    h = h * 31 + hud.paused;
    h = h * 31 + sel.present;
    h = h * 31 + sel.titleColor;
    h = h * 31 + sel.cost.hashCode;
    h = h * 31 + sel.sellPrice.hashCode;
    h = h * 31 + sel.hasUpgradePrice;
    h = h * 31 + sel.upgradePrice.hashCode;
    h = h * 31 + sel.canSell;
    h = h * 31 + sel.canUpgrade;
    h = h * 31 + pend.present;
    h = h * 31 + pend.placementAllowed;
    h = h * 31 + pend.placementAffordable;
    h = h * 31 + pend.showPlaceAction;
    h = h * 31 + pend.remainingTicks;
    h = h * 31 + cfg.difficulty;
    h = h * 31 + cfg.waveMode;
    h = h * 31 + cfg.quality;
    h = h * 31 + cfg.effects;
    h = h * 31 + cfg.healthBars;
    h = h * 31 + cfg.muted;
    h = h * 31 + cfg.autoSend;
    h = h * 31 + cfg.adaptiveQuality;
    h = h * 31 + cfg.showFps;
    h = h * 31 + cfg.godMode;
    h = h * 31 + cfg.firingDisabled;
    h = h * 31 + rs.built;
    h = h * 31 + rs.kills;
    h = h * 31 + rs.leaks;
    return h & 0x3FFFFFFFFFFFFFFF;
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
    required this.victoryVisible,
    required this.stars,
    required this.totalWaves,
  });

  factory NativeGameSnapshot.fromStruct(NativeGameSnapshotStruct value) {
    final NativeSelectionSnapshotStruct selection = value.selection;
    final NativePendingPlacementSnapshotStruct pending = value.pendingPlacement;
    return NativeGameSnapshot(
      runId: value.runId,
      tick: value.tick,
      simTimeMs: value.simTimeMs.toDouble(),
      activeScreen: _screenIdToName(value.activeScreen),
      hud: NativeHudState.fromStruct(value.hud),
      selection: selection.present == 0
          ? null
          : NativeSelectionInfo.fromStruct(selection),
      pendingPlacement: pending.present == 0
          ? null
          : NativePendingPlacementInfo.fromStruct(pending),
      performance: NativePerfStats.fromStruct(value.perf),
      runStats: NativeRunStats.fromStruct(value.runStats),
      defeatVisible: value.defeatVisible != 0,
      defeatSummary: readNativeString(
        value.defeatSummary,
        _bridgeDefeatSummaryCapacity,
      ),
      config: NativeConfigState.fromStruct(value.config),
      exportMap: readNativeString(value.exportMap, _bridgeMapIdCapacity),
      victoryVisible: value.victoryVisible != 0,
      stars: value.stars,
      totalWaves: value.totalWaves,
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
  final bool victoryVisible;
  final int stars;
  final int totalWaves;
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

  factory NativeHudState.fromStruct(NativeHudSnapshotStruct value) {
    return NativeHudState(
      health: value.health,
      maxHealth: value.maxHealth,
      cash: value.cash,
      wave: value.wave,
      kills: value.kills,
      waveState: readNativeString(value.waveState, _bridgeWaveStateCapacity),
      paused: value.paused != 0,
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

  factory NativeSelectionInfo.fromStruct(NativeSelectionSnapshotStruct value) {
    return NativeSelectionInfo(
      status: readNativeString(value.status, _bridgeSelectionStatusCapacity),
      title: readNativeString(value.title, _bridgeSelectionTitleCapacity),
      titleColor: Color(value.titleColor),
      cost: value.cost,
      sellPrice: value.sellPrice,
      upgradePrice: value.hasUpgradePrice == 0 ? null : value.upgradePrice,
      upgradeDelta: readNativeString(
        value.upgradeDelta,
        _bridgeUpgradeDeltaCapacity,
      ),
      damage: readNativeString(value.damage, _bridgeDamageTextCapacity),
      dps: value.dps,
      damageTypeLabel: readNativeString(
        value.damageTypeLabel,
        _bridgeDamageTypeCapacity,
      ),
      range: value.range,
      cooldownSeconds: value.cooldownSeconds,
      targeting: readNativeString(value.targeting, _bridgeTargetingCapacity),
      effect: readNativeString(value.effect, _bridgeEffectCapacity),
      placementReason: readNativeString(
        value.placementReason,
        _bridgePlacementReasonCapacity,
      ),
      canSell: value.canSell != 0,
      canUpgrade: value.canUpgrade != 0,
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
    required this.placementAllowed,
    required this.placementAffordable,
    required this.showPlaceAction,
    required this.remainingTicks,
    required this.statusText,
  });

  factory NativePendingPlacementInfo.fromStruct(
    NativePendingPlacementSnapshotStruct value,
  ) {
    return NativePendingPlacementInfo(
      id: readNativeString(value.id, _bridgePendingPlacementIdCapacity),
      title: readNativeString(
        value.title,
        _bridgePendingPlacementTitleCapacity,
      ),
      cost: value.cost,
      anchorX: value.anchorX,
      anchorY: value.anchorY,
      placementAllowed: value.placementAllowed != 0,
      placementAffordable: value.placementAffordable != 0,
      showPlaceAction: value.showPlaceAction != 0,
      remainingTicks: value.remainingTicks,
      statusText: readNativeString(
        value.statusText,
        _bridgePendingPlacementStatusCapacity,
      ),
    );
  }

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

class NativePerfStats {
  const NativePerfStats({
    required this.show,
    required this.fps,
    required this.frameTimeMs,
    required this.quality,
  });

  factory NativePerfStats.fromStruct(NativePerfSnapshotStruct value) {
    return NativePerfStats(
      show: value.show != 0,
      fps: value.fps,
      frameTimeMs: value.frameTimeMs,
      quality: _qualityIdToName(value.quality),
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

  factory NativeRunStats.fromStruct(NativeRunStatsSnapshotStruct value) {
    return NativeRunStats(
      built: value.built,
      kills: value.kills,
      leaks: value.leaks,
      totalDamage: value.totalDamage,
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

  factory NativeConfigState.fromStruct(NativeConfigSnapshotStruct value) {
    return NativeConfigState(
      mapId: readNativeString(value.mapId, _bridgeMapIdCapacity),
      difficulty: value.difficulty,
      waveMode: value.waveMode,
      quality: value.quality,
      effects: value.effects != 0,
      healthBars: value.healthBars != 0,
      muted: value.muted != 0,
      autoSend: value.autoSend != 0,
      adaptiveQuality: value.adaptiveQuality != 0,
      showFps: value.showFps != 0,
      godMode: value.godMode != 0,
      firingDisabled: value.firingDisabled != 0,
      zoom: value.zoom,
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
    case 5:
      return 'world';
    case 6:
      return 'shop';
    default:
      return 'home';
  }
}

int _screenNameToId(String value) {
  switch (value) {
    case 'map':
      return 1;
    case 'settings':
      return 2;
    case 'game':
      return 3;
    case 'leaderboard':
      return 4;
    case 'world':
      return 5;
    case 'shop':
      return 6;
    default:
      return 0;
  }
}

String _qualityIdToName(int qualityId) {
  switch (qualityId) {
    case 1:
      return PerformanceQuality.balanced.name;
    case 2:
      return PerformanceQuality.battery.name;
    default:
      return PerformanceQuality.high.name;
  }
}
