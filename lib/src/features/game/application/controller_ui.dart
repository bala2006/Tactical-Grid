part of 'controller.dart';

extension _Ui on GameController {
  void _recalculateBoardMetrics() {
    if (_activeMap == null || _viewport.isEmpty) {
      return;
    }
    _invalidateStaticBoardPicture();
    final double fitTile = math.min(
      _viewport.width / _activeMap!.cols,
      _viewport.height / _activeMap!.rows,
    );
    _tileSize = fitTile;
    final double boardWidth = _activeMap!.cols * _tileSize;
    final double boardHeight = _activeMap!.rows * _tileSize;
    _boardOffset = Offset(
      (_viewport.width - boardWidth) / 2,
      (_viewport.height - boardHeight) / 2,
    );
  }

  GridPoint? _gridFromOffset(Offset localPosition) {
    if (_activeMap == null) {
      return null;
    }
    final double x = localPosition.dx - _boardOffset.dx;
    final double y = localPosition.dy - _boardOffset.dy;
    if (x < 0 || y < 0) {
      return null;
    }
    final int col = (x / _tileSize).floor();
    final int row = (y / _tileSize).floor();
    final GridPoint point = GridPoint(col, row);
    if (!_insideGrid(point)) {
      return null;
    }
    return point;
  }

  GridPoint _gridFromWorld(Vector2 position) {
    final int col = ((position.x - _boardOffset.dx) / _tileSize).floor();
    final int row = ((position.y - _boardOffset.dy) / _tileSize).floor();
    return GridPoint(col, row);
  }

  bool _insideGrid(GridPoint point) {
    return _activeMap != null &&
        point.x >= 0 &&
        point.y >= 0 &&
        point.x < _activeMap!.cols &&
        point.y < _activeMap!.rows;
  }

  bool _outsideBoard(Vector2 position) {
    if (_activeMap == null) {
      return true;
    }
    final double width = _activeMap!.cols * _tileSize;
    final double height = _activeMap!.rows * _tileSize;
    return position.x < _boardOffset.dx ||
        position.y < _boardOffset.dy ||
        position.x > _boardOffset.dx + width ||
        position.y > _boardOffset.dy + height;
  }

  bool _atTileCenter(Vector2 position, GridPoint tile) {
    final Vector2 center = _centerOfTile(tile);
    final double tolerance = _tileSize / 24;
    return position.x > center.x - tolerance &&
        position.x < center.x + tolerance &&
        position.y > center.y - tolerance &&
        position.y < center.y + tolerance;
  }

  Vector2 _centerOfTile(GridPoint tile) {
    return Vector2(
      _boardOffset.dx + tile.x * _tileSize + _tileSize / 2,
      _boardOffset.dy + tile.y * _tileSize + _tileSize / 2,
    );
  }

  void _commitUiState({bool force = false}) {
    final AppUiState next = _buildUiState();
    final String signature = _signatureForState(next);
    if (!force && signature == _uiSignature) {
      return;
    }
    _uiState = next;
    _uiSignature = signature;
    _uiRebuilds++;
    _publishUiState(next);
  }

  void _publishUiState(AppUiState next) {
    if (_disposed) {
      return;
    }
    _pendingUiState = next;
    if (_uiPublishScheduled) {
      return;
    }
    _uiPublishScheduled = true;
    final SchedulerPhase phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      scheduleMicrotask(_flushPublishedUiState);
      return;
    }
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _flushPublishedUiState();
    });
  }

  void _flushPublishedUiState() {
    if (_disposed) {
      return;
    }
    _uiPublishScheduled = false;
    final AppUiState? next = _pendingUiState;
    _pendingUiState = null;
    if (next == null) {
      return;
    }
    uiStateListenable.value = next;
  }

  AppUiState _buildUiState() {
    final TowerBlueprint? placingBlueprint = _placingTowerKind == null
        ? null
        : towerBlueprints[_placingTowerKind];
    final SelectionInfo? selectionInfo = _selectedTower != null
        ? _selectionInfoForTower(_selectedTower!, placing: false)
        : placingBlueprint != null
        ? _selectionInfoForBlueprint(placingBlueprint)
        : null;

    final List<String> pills = <String>[];
    if (_paused) {
      pills.add('Paused');
    }
    if (_config.muted) {
      pills.add('Muted');
    }
    if (_config.autoSend) {
      pills.add('Auto-send');
    }
    if (_config.devFlags.firingDisabled) {
      pills.add('Firing Off');
    }
    if (_config.effectsEnabled) {
      pills.add('Effects On');
    }
    if (_config.healthBars) {
      pills.add('HP Bars');
    }
    if (_config.devFlags.godMode) {
      pills.add('God Mode');
    }

    PendingPlacementInfo? pendingPlacement;
    if (_pendingPlacementTile != null && placingBlueprint != null) {
      final GridPoint tile = _pendingPlacementTile!;
      pendingPlacement = PendingPlacementInfo(
        id: '${tile.x},${tile.y}:${placingBlueprint.kind.name}',
        title: placingBlueprint.title,
        cost: placingBlueprint.cost.toDouble(),
        anchorX: _boardOffset.dx + (tile.x + 0.5) * _tileSize,
        anchorY: _boardOffset.dy + (tile.y + 0.5) * _tileSize,
        placementAllowed: _canPlace(tile),
        placementAffordable:
            _config.devFlags.godMode || _cash >= placingBlueprint.cost,
        showPlaceAction:
            _canPlace(tile) &&
            (_config.devFlags.godMode || _cash >= placingBlueprint.cost),
        remainingTicks: 0,
        statusText: _placementMessage.isEmpty
            ? 'Choose a tile.'
            : _placementMessage,
      );
    }

    return AppUiState(
      wave: _wave,
      waveState: _waitingForWave && _waveCooldown > 0
          ? 'Next contact in ${(_waveCooldown / 60).ceil()}s'
          : (_queuedEnemies.isNotEmpty ? 'Engaged' : 'Standby'),
      health: _health,
      maxHealth: _maxHealth,
      cash: _cash,
      selectionStatus: _selectedTower != null
          ? 'Selected: ${_selectedTower!.blueprint.title}'
          : placingBlueprint != null
          ? 'Placing: ${placingBlueprint.title}'
          : 'Selected: None',
      threatLabel:
          'Threat: ${_queuedEnemies.isNotEmpty || _enemies.isNotEmpty ? 'Engaged' : 'Clear'}',
      pills: pills,
      selectionInfo: selectionInfo,
      pendingPlacement: pendingPlacement,
      runStats: _runStats,
      isPaused: _paused,
      canAdvanceWave: _waitingForWave && _queuedEnemies.isEmpty && !_defeat,
      isMuted: _config.muted,
      effectsEnabled: _config.effectsEnabled,
      healthBarsEnabled: _shouldRenderHealthBars,
      defeat: _defeat,
      performance: _performance,
    );
  }

  SelectionInfo _selectionInfoForTower(
    TowerEntity tower, {
    required bool placing,
  }) {
    final TowerBlueprint blueprint = tower.blueprint;
    final TowerKind? nextKind = blueprint.upgrades.isEmpty
        ? null
        : blueprint.upgrades.first;
    final TowerBlueprint? nextBlueprint = nextKind == null
        ? null
        : towerBlueprints[nextKind];
    return SelectionInfo(
      title: blueprint.title,
      titleColor: blueprint.color,
      cost: tower.totalCost,
      sellPrice: _sellPrice(tower),
      upgradePrice: nextBlueprint?.cost.toDouble(),
      upgradeDelta: nextBlueprint == null
          ? 'No more upgrades'
          : _describeUpgradeDelta(blueprint, nextBlueprint),
      damage: _rangeText(blueprint.damageMin, blueprint.damageMax),
      dps: _towerDps(blueprint),
      damageTypeLabel: blueprint.damageType.name.toUpperCase(),
      range: blueprint.range,
      cooldownSeconds: _cooldownSeconds(blueprint),
      targeting: blueprint.targetingText,
      effect: blueprint.effectText,
      placementReason: placing ? _placementMessage : '',
      canSell: !placing,
      canUpgrade:
          !placing &&
          nextBlueprint != null &&
          (_config.devFlags.godMode || _cash >= nextBlueprint.cost),
    );
  }

  SelectionInfo _selectionInfoForBlueprint(TowerBlueprint blueprint) {
    return SelectionInfo(
      title: blueprint.title,
      titleColor: blueprint.color,
      cost: blueprint.cost.toDouble(),
      sellPrice: 0,
      upgradePrice: null,
      upgradeDelta: blueprint.upgrades.isEmpty
          ? 'No more upgrades'
          : 'Preview only',
      damage: _rangeText(blueprint.damageMin, blueprint.damageMax),
      dps: _towerDps(blueprint),
      damageTypeLabel: blueprint.damageType.name.toUpperCase(),
      range: blueprint.range,
      cooldownSeconds: _cooldownSeconds(blueprint),
      targeting: blueprint.targetingText,
      effect: blueprint.effectText,
      placementReason: '',
      canSell: false,
      canUpgrade: false,
    ).copyWithPlacement(
      placementReason: _previewTile == null
          ? 'Choose a tile.'
          : _describePlacement(_previewTile!),
      canSell: false,
      canUpgrade: false,
    );
  }

  String _describeUpgradeDelta(TowerBlueprint blueprint, TowerBlueprint next) {
    final List<String> parts = <String>[];
    if (next.damageMin != blueprint.damageMin ||
        next.damageMax != blueprint.damageMax) {
      parts.add('damage ${_rangeText(next.damageMin, next.damageMax)}');
    }
    if (next.range != blueprint.range) {
      parts.add('range ${next.range}');
    }
    if (next.cooldownMin != blueprint.cooldownMin ||
        next.cooldownMax != blueprint.cooldownMax) {
      parts.add('cooldown ${_cooldownSeconds(next).toStringAsFixed(2)}s');
    }
    return parts.isEmpty ? 'Stat shift' : parts.join(', ');
  }

  String _rangeText(double min, double max) {
    if ((min - max).abs() < 0.0001) {
      return min == min.roundToDouble()
          ? min.round().toString()
          : min.toStringAsFixed(3);
    }
    final String a = min == min.roundToDouble()
        ? min.round().toString()
        : min.toStringAsFixed(3);
    final String b = max == max.roundToDouble()
        ? max.round().toString()
        : max.toStringAsFixed(3);
    return '$a-$b';
  }

  double _cooldownSeconds(TowerBlueprint blueprint) {
    return (blueprint.cooldownMin + blueprint.cooldownMax) / 120;
  }

  double _towerDps(TowerBlueprint blueprint) {
    final double cooldown = _cooldownSeconds(blueprint);
    final double average = (blueprint.damageMin + blueprint.damageMax) / 2;
    if (cooldown <= 0) {
      return average * 60;
    }
    return average / cooldown;
  }

  String _signatureForState(AppUiState state) {
    final SelectionInfo? selection = state.selectionInfo;
    final bool showPerf = _config.devFlags.showFps;
    return <Object?>[
      state.wave,
      state.waveState,
      state.health,
      state.maxHealth,
      state.cash,
      state.pills.join('|'),
      state.runStats.built,
      state.runStats.kills,
      state.runStats.leaks,
      state.runStats.totalDamage.round(),
      state.isPaused,
      state.canAdvanceWave,
      state.isMuted,
      state.effectsEnabled,
      state.healthBarsEnabled,
      state.defeat,
      if (showPerf) state.performance.fps.toStringAsFixed(0),
      if (showPerf) state.performance.frameTimeMs.toStringAsFixed(1),
      if (showPerf) state.performance.quality.name,
      if (showPerf) state.performance.activeEnemies,
      if (showPerf) state.performance.activeMissiles,
      if (showPerf) state.performance.activeParticles,
      if (showPerf) state.performance.pendingPathJobs,
      selection?.title,
      selection?.cost,
      selection?.sellPrice,
      selection?.upgradePrice,
      selection?.upgradeDelta,
      selection?.damage,
      selection?.dps.toStringAsFixed(2),
      selection?.damageTypeLabel,
      selection?.range,
      selection?.cooldownSeconds.toStringAsFixed(2),
      selection?.targeting,
      selection?.effect,
      selection?.placementReason,
      selection?.canSell,
      selection?.canUpgrade,
      state.pendingPlacement?.id,
      state.pendingPlacement?.anchorX.toStringAsFixed(1),
      state.pendingPlacement?.anchorY.toStringAsFixed(1),
    ].join('~');
  }

  MapDefinition _currentMapSnapshot() {
    final MapDefinition map = _activeMap!;
    return MapDefinition(
      name: 'custom',
      display: map.display
          .map(
            (List<String> column) => List<String>.from(column, growable: false),
          )
          .toList(growable: false),
      displayDirection: map.displayDirection
          .map((List<int> column) => List<int>.from(column, growable: false))
          .toList(growable: false),
      grid: map.grid
          .map((List<int> column) => List<int>.from(column, growable: false))
          .toList(growable: false),
      metadata: map.metadata
          .map(
            (List<dynamic> column) =>
                List<dynamic>.from(column, growable: false),
          )
          .toList(growable: false),
      paths: _pathMap
          .map((List<int> column) => List<int>.from(column, growable: false))
          .toList(growable: false),
      exit: map.exit,
      spawnpoints: List<GridPoint>.from(map.spawnpoints, growable: false),
      background: List<int>.from(map.background, growable: false),
      border: map.border,
      borderAlpha: map.borderAlpha,
      cols: map.cols,
      rows: map.rows,
      customWaves: map.customWaves ?? defaultCustomWaves,
    );
  }
}

extension on SelectionInfo {
  SelectionInfo copyWithPlacement({
    required String placementReason,
    required bool canSell,
    required bool canUpgrade,
  }) {
    return SelectionInfo(
      title: title,
      titleColor: titleColor,
      cost: cost,
      sellPrice: sellPrice,
      upgradePrice: upgradePrice,
      upgradeDelta: upgradeDelta,
      damage: damage,
      dps: dps,
      damageTypeLabel: damageTypeLabel,
      range: range,
      cooldownSeconds: cooldownSeconds,
      targeting: targeting,
      effect: effect,
      placementReason: placementReason,
      canSell: canSell,
      canUpgrade: canUpgrade,
    );
  }
}
