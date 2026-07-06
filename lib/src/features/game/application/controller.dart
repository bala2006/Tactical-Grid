import 'dart:async';
import 'dart:async' as async show Timer;
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../domain/content.dart';
import '../infrastructure/audio/sfx_bank.dart';
import '../infrastructure/maps.dart';
import '../domain/models.dart';
import '../infrastructure/native_game_bridge.dart';
import '../infrastructure/simulation_worker.dart';
import '../../progression/application/progression_controller.dart';
import '../../progression/domain/campaign.dart';
import '../../progression/domain/shop.dart';

part 'controller_render.dart';
part 'controller_simulation.dart';
part 'controller_ui.dart';

class GameController extends ChangeNotifier {
  GameController()
    : shellStateListenable = ValueNotifier<ShellState>(
        const ShellState(
          activeScreen: 'home',
          isInitializing: false,
          loadError: null,
        ),
      ),
      uiStateListenable = ValueNotifier<AppUiState>(
        const AppUiState(
          wave: 0,
          waveState: 'Loading',
          health: 0,
          maxHealth: 0,
          cash: 0,
          selectionStatus: 'Selected: None',
          threatLabel: 'Threat: Clear',
          pills: <String>[],
          selectionInfo: null,
          pendingPlacement: null,
          runStats: RunStats(),
          isPaused: true,
          canAdvanceWave: false,
          isMuted: false,
          effectsEnabled: true,
          healthBarsEnabled: true,
          defeat: false,
          performance: PerformanceStats.empty(),
        ),
      ),
      configListenable = ValueNotifier<GameConfig>(const GameConfig());

  static const double _fixedStep = 1 / 60;
  // Native SFX use a single Android SoundPool (the `soundpool` plugin) via
  // [SfxBank]: clips are decoded once, playback is one fire-and-forget call with
  // near-zero latency, and — unlike the old audioplayers path — it performs no
  // per-play audio-focus management, so it never thrashes onAudioFocusChange or
  // freezes the UI.
  static const bool _nativeAudioEnabled = true;
  static const int _tempSpawnCount = 40;
  static const double _resistance = 0.5;
  static const double _weakness = 0.5;
  static const double _sellConst = 0.75;
  static const int _particleAmount = 32;
  static const int _maxBeamTracesHigh = 96;
  static const int _maxBeamTracesBalanced = 56;
  static const int _maxBeamTracesBattery = 28;
  static const int _maxPulsesHigh = 32;
  static const int _maxPulsesBalanced = 18;
  static const int _maxPulsesBattery = 8;

  final ValueNotifier<ShellState> shellStateListenable;
  final ValueNotifier<AppUiState> uiStateListenable;
  final ValueNotifier<GameConfig> configListenable;

  final math.Random _random = math.Random();
  final SimulationWorker _worker = SimulationWorker();
  final ProgressionController progression = ProgressionController();
  final List<EnemyEntity> _enemies = <EnemyEntity>[];
  final List<TowerEntity> _towers = <TowerEntity>[];
  final List<TowerEntity> _pendingTowers = <TowerEntity>[];
  final List<MissileEntity> _missiles = <MissileEntity>[];
  final List<ParticleEntity> _particles = <ParticleEntity>[];
  final List<_BeamTrace> _beamTraces = <_BeamTrace>[];
  final List<_PulseEffect> _pulseEffects = <_PulseEffect>[];
  final List<TempSpawn> _tempSpawns = <TempSpawn>[];
  final List<EnemyKind> _queuedEnemies = <EnemyKind>[];
  final Map<int, List<EnemyEntity>> _enemyBuckets = <int, List<EnemyEntity>>{};
  final List<EnemyEntity> _enemyQueryBuffer = <EnemyEntity>[];
  final List<EnemyEntity> _enemyTauntBuffer = <EnemyEntity>[];
  final List<EnemyEntity> _enemyChainCandidates = <EnemyEntity>[];
  final Map<String, int> _soundCooldowns = <String, int>{};
  final Paint _fillPaint = Paint();
  final Paint _strokePaint = Paint()..style = PaintingStyle.stroke;
  final Paint _effectPaint = Paint();
  final Paint _gradientPaint = Paint();
  final SfxBank _sfx = SfxBank();
  StreamSubscription<NativeGameSnapshot>? _nativeSnapshotSubscription;
  async.Timer? _nativeAudioTimer;
  NativeGameBridge? _nativeBridge;
  int _lastNativeRunId = -1;
  int _lastNativeTick = -1;
  String? _lastExportedMap;

  GameConfig _config = const GameConfig();
  AppUiState _uiState = const AppUiState(
    wave: 0,
    waveState: 'Loading',
    health: 0,
    maxHealth: 0,
    cash: 0,
    selectionStatus: 'Selected: None',
    threatLabel: 'Threat: Clear',
    pills: <String>[],
    selectionInfo: null,
    pendingPlacement: null,
    runStats: RunStats(),
    isPaused: true,
    canAdvanceWave: false,
    isMuted: false,
    effectsEnabled: true,
    healthBarsEnabled: true,
    defeat: false,
    performance: PerformanceStats.empty(),
  );

  MapCatalog? _mapCatalog;
  MapDefinition? _activeMap;
  MapDefinition? _customMap;
  RunStats _runStats = const RunStats();
  String _activeScreen = 'home';
  String? _loadError;
  String? _uiSignature;
  String? _shellSignature;
  bool _initialized = false;
  bool _initializing = false;
  bool _paused = true;
  bool _defeat = false;
  bool _victory = false;
  int _stars = 0;
  int _totalWaves = 0;
  String? _activeLevelId;
  int? _runStartMs;
  bool _resultRecorded = false;
  bool _soldThisRun = false;
  LevelResult? _lastLevelResult;
  bool _waitingForWave = false;
  bool _pendingPathfind = false;
  int _cash = 0;
  int _health = 0;
  int _maxHealth = 0;
  int _wave = 0;
  int _spawnCooldown = 0;
  int _spawnCooldownMax = 0;
  int _waveCooldown = 0;
  int _waveCooldownMax = 120;
  double _accumulator = 0;
  Size _viewport = Size.zero;
  double _tileSize = 24;
  Offset _boardOffset = Offset.zero;
  ui.Picture? _staticBoardPicture;
  ui.Picture? _enemySquarePicture;
  ui.Picture? _enemyArrowPicture;
  ui.Picture? _enemyTankPicture;
  ui.Picture? _enemyTauntPicture;
  final Map<TowerKind, ui.Picture> _towerBodyPictures =
      <TowerKind, ui.Picture>{};
  GridPoint? _previewTile;
  String _placementMessage = '';
  TowerKind? _placingTowerKind;
  TowerEntity? _selectedTower;
  GridPoint? _pendingPlacementTile;
  List<List<int?>> _distanceMap = <List<int?>>[];
  List<List<int>> _pathMap = <List<int>>[];
  PerformanceStats _performance = const PerformanceStats.empty();
  PerformanceQuality _resolvedQuality = PerformanceQuality.high;
  double _smoothedFrameTimeMs = 16.6;
  int _uiRebuilds = 0;
  int _pendingPathJobs = 0;
  bool _uiPublishScheduled = false;
  bool _disposed = false;
  AppUiState? _pendingUiState;

  GameConfig get config => _config;
  AppUiState get uiState => _uiState;
  PerformanceStats get performance => _performance;
  bool get isReady => _initialized && _activeMap != null;
  bool get isInitializing => _initializing;
  String? get loadError => _loadError;
  String get activeScreen => _activeScreen;
  bool get showBoard => _activeScreen == 'game';
  List<String> get availableMaps => selectableMapNames;
  List<TowerBlueprint> get storeBlueprints => TowerKind.values
      .map((TowerKind kind) => towerBlueprints[kind]!)
      .where((TowerBlueprint blueprint) {
        return Shop.storefrontTowers.contains(blueprint.kind) &&
            progression.isTowerUnlocked(blueprint.kind);
      })
      .toList(growable: false);
  bool get isNativeBoardEnabled => supportsNativeGameBoard;

  Future<void> initialize() async {
    if (_initialized || _initializing) {
      return;
    }
    _initializing = true;
    _publishShellState(force: true);
    try {
      await progression.load();
      if (isNativeBoardEnabled) {
        _nativeBridge = NativeGameBridge();
        await _initializeNativeAudio();
        _nativeSnapshotSubscription = _nativeBridge!.snapshots().listen((
          NativeGameSnapshot snapshot,
        ) {
          _handleNativeSnapshot(snapshot);
        });
        // Audio is drained on its own steady 16 ms timer, independent of the
        // (change-gated) snapshot stream. When audio is disabled the drain is a
        // cheap no-op (see _nativeAudioEnabled).
        _nativeAudioTimer = async.Timer.periodic(
          const Duration(milliseconds: 16),
          (_) => _drainNativeAudioEvents(),
        );
        await _nativeBridge!.initialize();
        _initialized = true;
        _loadError = null;
        return;
      }
      FlameAudio.audioCache.prefix = '';
      unawaited(_preloadAudio());
      await _worker.start();
      _mapCatalog = await MapCatalog.load();
      await _resetGame();
      _initialized = true;
      _loadError = null;
    } catch (error, stackTrace) {
      _loadError = '$error';
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'tower_defense_app',
          context: ErrorDescription('initializing game controller'),
        ),
      );
    } finally {
      _initializing = false;
      _publishShellState(force: true);
      if (isNativeBoardEnabled) {
        uiStateListenable.value = _uiState;
      } else {
        _commitUiState(force: true);
      }
    }
  }

  void step(double dt) {
    if (isNativeBoardEnabled) {
      return;
    }
    if (!isReady) {
      return;
    }
    _updatePerformance(dt);
    _accumulator += dt.clamp(0, 0.25);
    while (_accumulator >= _fixedStep) {
      _tick();
      _accumulator -= _fixedStep;
    }
  }

  void setViewport(Size size) {
    if (isNativeBoardEnabled) {
      return;
    }
    if (size == _viewport || !size.isFinite || size.isEmpty) {
      return;
    }
    final bool hadEmptyViewport = _viewport.isEmpty;
    _viewport = size;
    if (hadEmptyViewport) {
      unawaited(_refreshProceduralMapForViewport());
    }
    _recalculateBoardMetrics();
  }

  void setActiveScreen(String value) {
    if (_activeScreen == value) {
      return;
    }
    _activeScreen = value;
    _publishShellState(force: true);
    if (isNativeBoardEnabled) {
      unawaited(_nativeBridge?.setScreen(value) ?? Future<void>.value());
    }
  }

  Future<void> restartGame() {
    _resultRecorded = false;
    _soldThisRun = false;
    _runStartMs = DateTime.now().millisecondsSinceEpoch;
    if (isNativeBoardEnabled) {
      return _nativeBridge?.restart() ?? Future<void>.value();
    }
    return _resetGame();
  }

  /// Starts a finite campaign level: configures map, difficulty, preset waves
  /// and the win condition, then begins the run.
  Future<void> startCampaignLevel(CampaignLevel level) async {
    _activeLevelId = level.id;
    _totalWaves = level.totalWaves;
    _resultRecorded = false;
    _soldThisRun = false;
    _runStartMs = DateTime.now().millisecondsSinceEpoch;
    _config = _config.copyWith(
      mapSelection: level.mapId,
      difficulty: level.difficulty,
      waveMode: WaveMode.preset,
    );
    _publishConfig();
    if (isNativeBoardEnabled) {
      await (_nativeBridge?.setLevel(
            mapId: level.mapId,
            difficulty: level.difficulty,
            totalWaves: level.totalWaves,
            waveMode: WaveMode.preset,
          ) ??
          Future<void>.value());
      return;
    }
    await _resetGame();
  }

  String? get activeLevelId => _activeLevelId;

  /// Starts an Endless (sandbox) run on the currently selected map with no win
  /// condition. `setMap` resets the native engine's `totalWaves` to 0, so this
  /// can never inherit a stale campaign finish line.
  Future<void> startEndlessRun() async {
    _activeLevelId = null;
    _totalWaves = 0;
    _resultRecorded = false;
    _soldThisRun = false;
    _runStartMs = DateTime.now().millisecondsSinceEpoch;
    if (isNativeBoardEnabled) {
      await (_nativeBridge?.setMap(_config.mapSelection) ??
          Future<void>.value());
      return;
    }
    await _resetGame();
  }

  /// The most recent campaign victory result, for the victory overlay.
  LevelResult? get lastLevelResult => _lastLevelResult;

  /// Records a campaign victory exactly once per run.
  void _recordVictoryOnce({
    required int health,
    required int maxHealth,
    required int kills,
    required int wave,
    required int towersBuilt,
  }) {
    if (_resultRecorded || _activeLevelId == null) {
      return;
    }
    _resultRecorded = true;
    final int? clearSeconds = _runStartMs == null
        ? null
        : ((DateTime.now().millisecondsSinceEpoch - _runStartMs!) / 1000)
              .round();
    _lastLevelResult = progression.recordVictory(
      levelId: _activeLevelId!,
      health: health,
      maxHealth: maxHealth,
      kills: kills,
      waveReached: wave,
      towersBuilt: towersBuilt,
      soldAny: _soldThisRun,
      clearSeconds: clearSeconds,
    );
  }

  /// Records a defeat/endless run's lifetime stats exactly once per run.
  void _recordDefeatOnce({required int kills, required int wave}) {
    if (_resultRecorded) {
      return;
    }
    _resultRecorded = true;
    progression.recordRunStats(waveReached: wave, kills: kills);
  }

  void togglePause() {
    if (isNativeBoardEnabled) {
      unawaited(_nativeBridge?.togglePause() ?? Future<void>.value());
      return;
    }
    if (_defeat) {
      return;
    }
    _paused = !_paused;
    _commitUiState(force: true);
  }

  void startNextWaveNow() {
    if (isNativeBoardEnabled) {
      return;
    }
    if (_defeat || _queuedEnemies.isNotEmpty || !_waitingForWave) {
      return;
    }
    _waitingForWave = false;
    _waveCooldown = 0;
    _nextWave();
    _commitUiState(force: true);
  }

  Future<void> selectBuildTower(TowerKind kind) async {
    if (isNativeBoardEnabled) {
      _pendingPlacementTile = null;
      _placingTowerKind = kind;
      _selectedTower = null;
      _placementMessage = 'Choose a tile for ${towerBlueprints[kind]!.title}.';
      _commitUiState(force: true);
      await (_nativeBridge?.selectTower(kind.name) ?? Future<void>.value());
      return;
    }
    _placingTowerKind = kind;
    _pendingPlacementTile = null;
    _selectedTower = null;
    _placementMessage = 'Choose a tile for ${towerBlueprints[kind]!.title}.';
    _commitUiState(force: true);
  }

  void cancelPlacement() {
    if (isNativeBoardEnabled) {
      _pendingPlacementTile = null;
      _placingTowerKind = null;
      _placementMessage = '';
      unawaited(_nativeBridge?.cancelPlacement() ?? Future<void>.value());
      _commitUiState(force: true);
      return;
    }
    if (_placingTowerKind == null && _pendingPlacementTile == null) {
      return;
    }
    _pendingPlacementTile = null;
    _placingTowerKind = null;
    _placementMessage = '';
    _commitUiState(force: true);
  }

  void confirmPendingPlacement() {
    if (isNativeBoardEnabled) {
      unawaited(_nativeBridge?.confirmPlacement() ?? Future<void>.value());
      return;
    }
    final GridPoint? tile = _pendingPlacementTile;
    if (tile == null || !_canPlace(tile)) {
      return;
    }
    _buyTower(tile);
    _pendingPlacementTile = null;
    _commitUiState(force: true);
  }

  void updateBoardPointer(Offset localPosition) {
    if (isNativeBoardEnabled) {
      return;
    }
    if (!isReady) {
      return;
    }
    if (_placingTowerKind == null) {
      return;
    }
    final GridPoint? nextTile = _gridFromOffset(localPosition);
    if (nextTile == _previewTile) {
      return;
    }
    _previewTile = nextTile;
    _commitUiState();
  }

  void handleBoardTap(Offset localPosition) {
    if (isNativeBoardEnabled) {
      return;
    }
    if (!isReady) {
      return;
    }
    final GridPoint? tile = _gridFromOffset(localPosition);
    if (tile == null) {
      return;
    }
    _previewTile = tile;
    final TowerEntity? existing = _towerAt(tile);
    if (existing != null) {
      _pendingPlacementTile = null;
      _selectedTower = existing;
      _placingTowerKind = null;
      _placementMessage = '';
      _commitUiState(force: true);
      return;
    }
    if (_canPlace(tile)) {
      _pendingPlacementTile = tile;
      _commitUiState(force: true);
      return;
    }
    if (_placingTowerKind != null) {
      _pendingPlacementTile = null;
      _placementMessage = _describePlacement(tile);
      _commitUiState(force: true);
    }
  }

  void sellSelectedTower() {
    _soldThisRun = true;
    if (isNativeBoardEnabled) {
      unawaited(_nativeBridge?.sellTower() ?? Future<void>.value());
      return;
    }
    final TowerEntity? selected = _selectedTower;
    if (selected == null) {
      return;
    }
    _cash += _sellPrice(selected).floor();
    if (_gridValue(selected.gridPosition) == 0) {
      _pendingPathfind = true;
    }
    selected.alive = false;
    _selectedTower = null;
    _commitUiState(force: true);
  }

  void upgradeSelectedTower() {
    if (isNativeBoardEnabled) {
      unawaited(_nativeBridge?.upgradeTower() ?? Future<void>.value());
      return;
    }
    final TowerEntity? selected = _selectedTower;
    if (selected == null) {
      return;
    }
    final TowerKind? nextKind = selected.blueprint.upgrades.isEmpty
        ? null
        : selected.blueprint.upgrades.first;
    if (nextKind == null) {
      return;
    }
    final TowerBlueprint nextBlueprint = towerBlueprints[nextKind]!;
    if (!_config.devFlags.godMode && _cash < nextBlueprint.cost) {
      return;
    }
    if (!_config.devFlags.godMode) {
      _cash -= nextBlueprint.cost;
    }
    _applyTowerUpgrade(selected, nextBlueprint);
    _commitUiState(force: true);
  }

  void updateMapSelection(String value) {
    if (_config.mapSelection == value) {
      return;
    }
    // Selecting a map in the endless picker leaves campaign mode: no win
    // condition, no level recording.
    _activeLevelId = null;
    _totalWaves = 0;
    _config = _config.copyWith(mapSelection: value);
    _publishConfig();
    if (isNativeBoardEnabled) {
      unawaited(_nativeBridge?.setMap(value) ?? Future<void>.value());
      return;
    }
    unawaited(_resetGame());
  }

  void updateDifficulty(Difficulty value) {
    if (_config.difficulty == value) {
      return;
    }
    _config = _config.copyWith(difficulty: value);
    _publishConfig();
    if (isNativeBoardEnabled) {
      unawaited(_nativeBridge?.setDifficulty(value) ?? Future<void>.value());
      return;
    }
    unawaited(_resetGame());
  }

  void updateWaveMode(WaveMode value) {
    if (_config.waveMode == value) {
      return;
    }
    _config = _config.copyWith(waveMode: value);
    _publishConfig();
    if (isNativeBoardEnabled) {
      unawaited(_nativeBridge?.setWaveMode(value) ?? Future<void>.value());
      return;
    }
    unawaited(_resetGame());
  }

  void toggleMute() {
    _config = _config.copyWith(muted: !_config.muted);
    _publishConfig();
    if (isNativeBoardEnabled) {
      unawaited(
        _nativeBridge?.setToggle('toggleMute', _config.muted) ??
            Future<void>.value(),
      );
    }
    _commitUiState(force: true);
  }

  void toggleEffects() {
    _config = _config.copyWith(effectsEnabled: !_config.effectsEnabled);
    _publishConfig();
    if (isNativeBoardEnabled) {
      unawaited(
        _nativeBridge?.setToggle('toggleEffects', _config.effectsEnabled) ??
            Future<void>.value(),
      );
    }
    if (!_config.effectsEnabled) {
      _particles.clear();
      _beamTraces.clear();
      _pulseEffects.clear();
    }
    _commitUiState(force: true);
  }

  void toggleHealthBars() {
    _config = _config.copyWith(healthBars: !_config.healthBars);
    _publishConfig();
    if (isNativeBoardEnabled) {
      unawaited(
        _nativeBridge?.setToggle('toggleHealthBars', _config.healthBars) ??
            Future<void>.value(),
      );
    }
    _commitUiState(force: true);
  }

  void toggleAutoSend() {
    _config = _config.copyWith(autoSend: !_config.autoSend);
    _publishConfig();
    if (isNativeBoardEnabled) {
      unawaited(
        _nativeBridge?.setToggle('toggleAutoSend', _config.autoSend) ??
            Future<void>.value(),
      );
    }
    _commitUiState(force: true);
  }

  void toggleAdaptiveQuality() {
    _config = _config.copyWith(adaptiveQuality: !_config.adaptiveQuality);
    if (!_config.adaptiveQuality) {
      _resolvedQuality = _config.quality;
    }
    _publishConfig();
    if (isNativeBoardEnabled) {
      unawaited(
        _nativeBridge?.setToggle(
              'toggleAdaptiveQuality',
              _config.adaptiveQuality,
            ) ??
            Future<void>.value(),
      );
    }
    _commitUiState(force: true);
  }

  void updateQuality(PerformanceQuality quality) {
    if (_config.quality == quality) {
      return;
    }
    _config = _config.copyWith(quality: quality);
    _resolvedQuality = quality;
    _publishConfig();
    if (isNativeBoardEnabled) {
      unawaited(_nativeBridge?.setQuality(quality) ?? Future<void>.value());
    }
    _commitUiState(force: true);
  }

  Future<bool> importMapString(String value) async {
    if (isNativeBoardEnabled) {
      return await (_nativeBridge?.importMapString(value) ??
          Future.value(false));
    }
    try {
      final MapDefinition decoded = _mapCatalog!.decodeCompressedMap(
        'custom',
        value.trim(),
      );
      _customMap = decoded;
      _config = _config.copyWith(mapSelection: 'custom');
      _publishConfig();
      await _resetGame();
      return true;
    } catch (_) {
      return false;
    }
  }

  String exportCurrentMapString() {
    if (isNativeBoardEnabled) {
      return _lastExportedMap ?? _config.mapSelection;
    }
    final MapDefinition map = _currentMapSnapshot();
    return _mapCatalog!.encodeCustomMap(map);
  }

  void render(Canvas canvas) {
    if (isNativeBoardEnabled) {
      return;
    }
    _render(canvas);
  }

  void _publishConfig() {
    if (configListenable.value == _config) {
      return;
    }
    configListenable.value = _config;
  }

  void _publishShellState({bool force = false}) {
    final String signature =
        '$_activeScreen|$_initializing|${_loadError ?? ''}';
    if (!force && signature == _shellSignature) {
      return;
    }
    _shellSignature = signature;
    shellStateListenable.value = ShellState(
      activeScreen: _activeScreen,
      isInitializing: _initializing,
      loadError: _loadError,
    );
  }

  void _updatePerformance(double dt) {
    final double frameTimeMs = dt.clamp(0.001, 0.25) * 1000;
    _smoothedFrameTimeMs = (_smoothedFrameTimeMs * 0.9) + frameTimeMs * 0.1;
    if (_config.adaptiveQuality) {
      if (_smoothedFrameTimeMs > 24 &&
          _resolvedQuality.index < PerformanceQuality.values.length - 1) {
        _resolvedQuality =
            PerformanceQuality.values[_resolvedQuality.index + 1];
      } else if (_smoothedFrameTimeMs < 17 &&
          _resolvedQuality.index > _config.quality.index) {
        _resolvedQuality =
            PerformanceQuality.values[_resolvedQuality.index - 1];
      } else if (_smoothedFrameTimeMs < 15) {
        _resolvedQuality = _config.quality;
      }
    } else {
      _resolvedQuality = _config.quality;
    }
    _performance = PerformanceStats(
      fps: 1000 / _smoothedFrameTimeMs,
      frameTimeMs: _smoothedFrameTimeMs,
      quality: _resolvedQuality,
      activeEnemies: _enemies.length,
      activeTowers: _towers.where((TowerEntity tower) => tower.alive).length,
      activeMissiles: _missiles.length,
      activeParticles: _particles.length,
      activeBeams: _beamTraces.length,
      activePulses: _pulseEffects.length,
      pendingPathJobs: _pendingPathJobs,
      uiRebuilds: _uiRebuilds,
    );
  }

  int get _maxParticlesForCurrentQuality => switch (_resolvedQuality) {
    PerformanceQuality.high => 240,
    PerformanceQuality.balanced => 120,
    PerformanceQuality.battery => 48,
  };

  int get _maxBeamTracesForCurrentQuality => switch (_resolvedQuality) {
    PerformanceQuality.high => _maxBeamTracesHigh,
    PerformanceQuality.balanced => _maxBeamTracesBalanced,
    PerformanceQuality.battery => _maxBeamTracesBattery,
  };

  int get _maxPulsesForCurrentQuality => switch (_resolvedQuality) {
    PerformanceQuality.high => _maxPulsesHigh,
    PerformanceQuality.balanced => _maxPulsesBalanced,
    PerformanceQuality.battery => _maxPulsesBattery,
  };

  bool get _shouldRenderHealthBars =>
      _config.healthBars && _resolvedQuality != PerformanceQuality.battery;

  @override
  void dispose() {
    _disposed = true;
    unawaited(_nativeSnapshotSubscription?.cancel() ?? Future<void>.value());
    _nativeAudioTimer?.cancel();
    _nativeAudioTimer = null;
    unawaited(_nativeBridge?.dispose() ?? Future<void>.value());
    unawaited(_sfx.dispose());
    shellStateListenable.dispose();
    uiStateListenable.dispose();
    configListenable.dispose();
    progression.dispose();
    _staticBoardPicture?.dispose();
    _enemySquarePicture?.dispose();
    _enemyArrowPicture?.dispose();
    _enemyTankPicture?.dispose();
    _enemyTauntPicture?.dispose();
    for (final ui.Picture picture in _towerBodyPictures.values) {
      picture.dispose();
    }
    unawaited(_worker.dispose());
    super.dispose();
  }

  void _handleNativeSnapshot(NativeGameSnapshot snapshot) {
    if (snapshot.runId < _lastNativeRunId) {
      return;
    }
    if (snapshot.runId == _lastNativeRunId && snapshot.tick < _lastNativeTick) {
      return;
    }
    _lastNativeRunId = snapshot.runId;
    _lastNativeTick = snapshot.tick;
    _lastExportedMap = snapshot.exportMap;
    _activeScreen = snapshot.activeScreen;
    _paused = snapshot.hud.paused;
    _defeat = snapshot.defeatVisible;
    _victory = snapshot.victoryVisible;
    _stars = snapshot.stars;
    _totalWaves = snapshot.totalWaves;
    if (_victory) {
      _recordVictoryOnce(
        health: snapshot.hud.health,
        maxHealth: snapshot.hud.maxHealth,
        kills: snapshot.runStats.kills,
        wave: snapshot.hud.wave,
        towersBuilt: snapshot.runStats.built,
      );
    } else if (_defeat) {
      _recordDefeatOnce(
        kills: snapshot.runStats.kills,
        wave: snapshot.hud.wave,
      );
    }
    _performance = PerformanceStats(
      fps: snapshot.performance.fps,
      frameTimeMs: snapshot.performance.frameTimeMs,
      quality:
          PerformanceQuality.values[snapshot.config.quality.clamp(
            0,
            PerformanceQuality.values.length - 1,
          )],
      activeEnemies: 0,
      activeTowers: 0,
      activeMissiles: 0,
      activeParticles: 0,
      activeBeams: 0,
      activePulses: 0,
      pendingPathJobs: 0,
      uiRebuilds: _uiRebuilds,
    );
    _config = GameConfig(
      mapSelection: snapshot.config.mapId,
      difficulty:
          Difficulty.values[snapshot.config.difficulty.clamp(
            0,
            Difficulty.values.length - 1,
          )],
      waveMode:
          WaveMode.values[snapshot.config.waveMode.clamp(
            0,
            WaveMode.values.length - 1,
          )],
      muted: snapshot.config.muted,
      effectsEnabled: snapshot.config.effects,
      healthBars: snapshot.config.healthBars,
      autoSend: snapshot.config.autoSend,
      adaptiveQuality: snapshot.config.adaptiveQuality,
      quality:
          PerformanceQuality.values[snapshot.config.quality.clamp(
            0,
            PerformanceQuality.values.length - 1,
          )],
      devFlags: DevFlags(
        showFps: snapshot.config.showFps,
        godMode: snapshot.config.godMode,
        firingDisabled: snapshot.config.firingDisabled,
        zoom: 18,
      ),
    );
    _runStats = RunStats(
      built: snapshot.runStats.built,
      kills: snapshot.runStats.kills,
      leaks: snapshot.runStats.leaks,
      totalDamage: snapshot.runStats.totalDamage,
    );
    _uiState = AppUiState(
      wave: snapshot.hud.wave,
      waveState: snapshot.hud.waveState,
      health: snapshot.hud.health,
      maxHealth: snapshot.hud.maxHealth,
      cash: snapshot.hud.cash,
      selectionStatus: snapshot.selection?.status ?? 'Selected: None',
      threatLabel: 'Threat: Native',
      pills: <String>[],
      selectionInfo: snapshot.selection == null
          ? null
          : SelectionInfo(
              title: snapshot.selection!.title,
              titleColor: snapshot.selection!.titleColor,
              cost: snapshot.selection!.cost,
              sellPrice: snapshot.selection!.sellPrice,
              upgradePrice: snapshot.selection!.upgradePrice,
              upgradeDelta: snapshot.selection!.upgradeDelta,
              damage: snapshot.selection!.damage,
              dps: snapshot.selection!.dps,
              damageTypeLabel: snapshot.selection!.damageTypeLabel,
              range: snapshot.selection!.range,
              cooldownSeconds: snapshot.selection!.cooldownSeconds,
              targeting: snapshot.selection!.targeting,
              effect: snapshot.selection!.effect,
              placementReason: snapshot.selection!.placementReason,
              canSell: snapshot.selection!.canSell,
              canUpgrade: snapshot.selection!.canUpgrade,
            ),
      pendingPlacement: snapshot.pendingPlacement == null
          ? null
          : PendingPlacementInfo(
              id: snapshot.pendingPlacement!.id,
              title: snapshot.pendingPlacement!.title,
              cost: snapshot.pendingPlacement!.cost,
              anchorX: snapshot.pendingPlacement!.anchorX,
              anchorY: snapshot.pendingPlacement!.anchorY,
              placementAllowed: snapshot.pendingPlacement!.placementAllowed,
              placementAffordable:
                  snapshot.pendingPlacement!.placementAffordable,
              showPlaceAction: snapshot.pendingPlacement!.showPlaceAction,
              remainingTicks: snapshot.pendingPlacement!.remainingTicks,
              statusText: snapshot.pendingPlacement!.statusText,
            ),
      runStats: _runStats,
      isPaused: snapshot.hud.paused,
      canAdvanceWave: false,
      isMuted: snapshot.config.muted,
      effectsEnabled: snapshot.config.effects,
      healthBarsEnabled: snapshot.config.healthBars,
      defeat: snapshot.defeatVisible,
      performance: _performance,
      victory: snapshot.victoryVisible,
      stars: snapshot.stars,
      totalWaves: snapshot.totalWaves,
    );
    _initialized = true;
    _loadError = null;
    _publishConfig();
    _publishShellState(force: true);
    _uiRebuilds++;
    uiStateListenable.value = _uiState;
  }

  Future<void> _preloadAudio() async {
    try {
      await FlameAudio.audioCache.loadAll(<String>[
        soundAsset('boom.wav'),
        soundAsset('missile.wav'),
        soundAsset('pop.wav'),
        soundAsset('railgun.wav'),
        soundAsset('sniper.wav'),
        soundAsset('spark.wav'),
        soundAsset('taunt.wav'),
      ]);
    } catch (_) {}
  }

  Future<void> _initializeNativeAudio() async {
    if (!_nativeAudioEnabled) {
      return;
    }
    try {
      await _sfx.init();
      // Decode every clip once, keyed by sound id name; voice counts give the
      // busier effects more overlap headroom.
      await Future.wait(<Future<void>>[
        _sfx.load(NativeSoundId.boom.name, soundAsset('boom.wav'), voices: 3),
        _sfx.load(NativeSoundId.missile.name, soundAsset('missile.wav'), voices: 3),
        _sfx.load(NativeSoundId.pop.name, soundAsset('pop.wav'), voices: 4),
        _sfx.load(NativeSoundId.railgun.name, soundAsset('railgun.wav'), voices: 2),
        _sfx.load(NativeSoundId.sniper.name, soundAsset('sniper.wav'), voices: 2),
        _sfx.load(NativeSoundId.spark.name, soundAsset('spark.wav'), voices: 3),
        _sfx.load(NativeSoundId.taunt.name, soundAsset('taunt.wav'), voices: 2),
      ]);
    } catch (_) {
      // Non-fatal: audio simply stays silent.
    }
  }

  void _drainNativeAudioEvents() {
    final NativeGameBridge? bridge = _nativeBridge;
    if (!_nativeAudioEnabled || bridge == null || _config.muted) {
      bridge?.consumeAudioEvents();
      return;
    }
    final List<NativeAudioEvent> events = bridge.consumeAudioEvents();
    if (events.isEmpty) {
      return;
    }
    // Coalesce: a single drain can contain many identical events (e.g. several
    // towers firing or a cluster of kills). Playing each one would flood the
    // audio thread and stack identical SFX. Instead play each distinct sound at
    // most once per drain, at the loudest requested volume.
    final Map<NativeSoundId, double> loudest = <NativeSoundId, double>{};
    for (final NativeAudioEvent event in events) {
      final double volume = event.volume.clamp(0.0, 1.0).toDouble();
      final double? existing = loudest[event.soundId];
      if (existing == null || volume > existing) {
        loudest[event.soundId] = volume;
      }
    }
    loudest.forEach((NativeSoundId soundId, double volume) {
      _sfx.play(soundId.name, volume: volume);
    });
  }
}
