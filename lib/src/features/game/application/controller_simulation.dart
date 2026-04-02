part of 'controller.dart';

extension _Simulation on GameController {
  Future<void> _refreshProceduralMapForViewport() async {
    if (_activeMap == null ||
        !proceduralMapNames.contains(_config.mapSelection)) {
      return;
    }
    if (_viewport.isEmpty) {
      return;
    }
    _activeMap = await _generateProceduralMap(_config.mapSelection);
    _previewTile = null;
    _selectedTower = null;
    _placingTowerKind = null;
    _placementMessage = '';
    _pendingPathfind = false;
    await _recalculatePaths();
    _recalculateBoardMetrics();
    _commitUiState(force: true);
  }

  Future<void> _resetGame() async {
    final MapDefinition map = await _loadSelectedMap();
    _activeMap = map;
    _recalculateBoardMetrics();

    _enemies.clear();
    _towers.clear();
    _pendingTowers.clear();
    _missiles.clear();
    _particles.clear();
    _beamTraces.clear();
    _pulseEffects.clear();
    _tempSpawns.clear();
    _queuedEnemies.clear();

    _health = 40;
    _cash = 55;
    switch (_config.difficulty) {
      case Difficulty.relaxed:
        _health = 55;
        _cash = 75;
        break;
      case Difficulty.normal:
        break;
      case Difficulty.hard:
        _health = 30;
        _cash = 45;
        break;
    }

    if (proceduralMapNames.contains(_config.mapSelection) &&
        _config.mapSelection.endsWith('3')) {
      _cash = 65;
    }

    _maxHealth = _health;
    _wave = 0;
    _runStats = const RunStats();
    _paused = true;
    _defeat = false;
    _waitingForWave = false;
    _pendingPathfind = false;
    _spawnCooldown = 0;
    _spawnCooldownMax = 0;
    _waveCooldown = 0;
    _waveCooldownMax = switch (_config.difficulty) {
      Difficulty.relaxed => 150,
      Difficulty.normal => 120,
      Difficulty.hard => 90,
    };
    _accumulator = 0;
    _selectedTower = null;
    _placingTowerKind = null;
    _previewTile = null;
    _placementMessage = '';
    await _recalculatePaths();
    _nextWave();
    _commitUiState(force: true);
  }

  Future<MapDefinition> _loadSelectedMap() async {
    final String name = _config.mapSelection;
    if (name == 'custom' && _customMap != null) {
      return _customMap!;
    }
    if (authoredMapNames.contains(name)) {
      return _mapCatalog!.decodeByName(name);
    }
    return _generateProceduralMap(name);
  }

  Future<MapDefinition> _generateProceduralMap(String name) {
    return _worker.generateProceduralMap(
      name: name,
      viewportWidth: _viewport.width,
      viewportHeight: _viewport.height,
      zoom: 18,
    );
  }

  void _tick() {
    if (_paused || _defeat || _activeMap == null) {
      _decayVisualEffects();
      _tickSoundCooldowns();
      return;
    }

    _tickSoundCooldowns();

    if (_spawnCooldown > 0) {
      _spawnCooldown--;
    }
    if (_waitingForWave && _waveCooldown > 0) {
      _waveCooldown--;
    }

    if (_queuedEnemies.isNotEmpty && _spawnCooldown == 0) {
      _spawnQueuedEnemy();
      _spawnCooldown = _spawnCooldownMax;
    }

    for (int index = _enemies.length - 1; index >= 0; index--) {
      final EnemyEntity enemy = _enemies[index];
      _steerEnemy(enemy);
      _updateEnemyEffects(enemy);
      _moveEnemy(enemy);
      _runEnemyBehavior(enemy);
      if (_outsideBoard(enemy.position)) {
        enemy.alive = false;
      }
      if (_atTileCenter(enemy.position, _activeMap!.exit)) {
        _handleEnemyExit(enemy);
      }
      if (!enemy.alive) {
        _enemies.removeAt(index);
      }
    }

    _rebuildEnemyBuckets();

    for (int index = _towers.length - 1; index >= 0; index--) {
      final TowerEntity tower = _towers[index];
      if (!tower.alive) {
        _towers.removeAt(index);
        continue;
      }
      _targetTower(tower);
      if (tower.cooldown > 0) {
        tower.cooldown--;
      }
      tower.flash = math.max(0, tower.flash - 0.16);
      tower.recoil = math.max(0, tower.recoil - 0.18);
    }

    for (int index = _missiles.length - 1; index >= 0; index--) {
      final MissileEntity missile = _missiles[index];
      _steerMissile(missile);
      _updateMissile(missile);
      if (_missileReachedTarget(missile)) {
        _explodeMissile(missile);
      }
      if (_outsideBoard(missile.position) || !missile.alive) {
        _missiles.removeAt(index);
      }
    }

    for (int index = _particles.length - 1; index >= 0; index--) {
      final ParticleEntity particle = _particles[index];
      particle.velocity.add(particle.acceleration);
      particle.velocity
        ..x *= particle.drag
        ..y = particle.velocity.y * particle.drag + particle.gravity;
      particle.position.add(particle.velocity);
      particle.angle += particle.angularVelocity;
      particle.lifespan -= particle.decay;
      if (particle.lifespan <= 0) {
        _particles.removeAt(index);
      }
    }

    _decayVisualEffects();

    if (_pendingTowers.isNotEmpty) {
      _towers.addAll(_pendingTowers);
      _pendingTowers.clear();
    }

    _tempSpawns.removeWhere((TempSpawn spawn) => spawn.ticks <= 0);

    if (_health <= 0 && !_defeat) {
      _defeat = true;
      _paused = true;
    }

    if (!_defeat &&
        ((_waitingForWave && _waveCooldown == 0) ||
            (_config.autoSend && _queuedEnemies.isEmpty))) {
      _waitingForWave = false;
      _waveCooldown = 0;
      _nextWave();
    }

    if (!_defeat && _noMoreEnemies() && !_waitingForWave) {
      _waveCooldown = _waveCooldownMax;
      _waitingForWave = true;
    }

    if (_pendingPathfind) {
      _pendingPathfind = false;
      unawaited(_recalculatePaths());
    }

    _commitUiState();
  }

  void _tickSoundCooldowns() {
    if (_soundCooldowns.isEmpty) {
      return;
    }
    final List<String> expired = <String>[];
    _soundCooldowns.forEach((String key, int value) {
      if (value <= 1) {
        expired.add(key);
      } else {
        _soundCooldowns[key] = value - 1;
      }
    });
    for (final String key in expired) {
      _soundCooldowns.remove(key);
    }
  }

  void _decayVisualEffects() {
    for (int index = _beamTraces.length - 1; index >= 0; index--) {
      _beamTraces[index].alpha -= 0.1;
      if (_beamTraces[index].alpha <= 0) {
        _beamTraces.removeAt(index);
      }
    }
    for (int index = _pulseEffects.length - 1; index >= 0; index--) {
      _pulseEffects[index].alpha -= _pulseEffects[index].decay;
      if (_pulseEffects[index].alpha <= 0) {
        _pulseEffects.removeAt(index);
      }
    }
  }

  bool _noMoreEnemies() => _enemies.isEmpty && _queuedEnemies.isEmpty;

  void _nextWave() {
    final WaveTemplate wave = _config.waveMode == WaveMode.endless
        ? _randomWave()
        : _scriptedWave();
    _spawnCooldownMax = wave.spawnCooldown;
    for (final WaveGroup group in wave.groups) {
      for (int count = 0; count < group.count; count++) {
        _queuedEnemies.addAll(group.sequence);
      }
    }
    _wave++;
  }

  WaveTemplate _scriptedWave() {
    final List<WaveTemplate> source = switch (_config.waveMode) {
      WaveMode.preset => presetWaves,
      WaveMode.custom => _activeMap?.customWaves ?? defaultCustomWaves,
      WaveMode.endless => presetWaves,
    };
    return source[math.min(_wave, source.length - 1)];
  }

  WaveTemplate _randomWave() {
    final List<WaveTemplate> candidates = <WaveTemplate>[];
    void add(int minWave, WaveTemplate wave, {int? maxWave}) {
      final bool inRange = maxWave == null
          ? _wave >= minWave
          : _wave >= minWave && _wave < maxWave;
      if (inRange) {
        candidates.add(wave);
      }
    }

    add(
      0,
      const WaveTemplate(
        spawnCooldown: 40,
        groups: <WaveGroup>[
          WaveGroup(sequence: <EnemyKind>[EnemyKind.weak], count: 50),
        ],
      ),
      maxWave: 3,
    );
    add(
      2,
      const WaveTemplate(
        spawnCooldown: 20,
        groups: <WaveGroup>[
          WaveGroup(sequence: <EnemyKind>[EnemyKind.weak], count: 25),
        ],
      ),
      maxWave: 4,
    );
    add(
      2,
      const WaveTemplate(
        spawnCooldown: 30,
        groups: <WaveGroup>[
          WaveGroup(sequence: <EnemyKind>[EnemyKind.weak], count: 25),
          WaveGroup(sequence: <EnemyKind>[EnemyKind.strong], count: 25),
        ],
      ),
      maxWave: 7,
    );
    add(
      2,
      const WaveTemplate(
        spawnCooldown: 20,
        groups: <WaveGroup>[
          WaveGroup(sequence: <EnemyKind>[EnemyKind.strong], count: 25),
        ],
      ),
      maxWave: 7,
    );
    add(
      3,
      const WaveTemplate(
        spawnCooldown: 40,
        groups: <WaveGroup>[
          WaveGroup(sequence: <EnemyKind>[EnemyKind.fast], count: 25),
        ],
      ),
      maxWave: 7,
    );
    add(
      4,
      const WaveTemplate(
        spawnCooldown: 20,
        groups: <WaveGroup>[
          WaveGroup(sequence: <EnemyKind>[EnemyKind.fast], count: 50),
        ],
      ),
      maxWave: 14,
    );
    add(
      5,
      const WaveTemplate(
        spawnCooldown: 20,
        groups: <WaveGroup>[
          WaveGroup(sequence: <EnemyKind>[EnemyKind.strong], count: 50),
          WaveGroup(sequence: <EnemyKind>[EnemyKind.fast], count: 25),
        ],
      ),
      maxWave: 6,
    );
    add(
      8,
      const WaveTemplate(
        spawnCooldown: 20,
        groups: <WaveGroup>[
          WaveGroup(
            sequence: <EnemyKind>[
              EnemyKind.medic,
              EnemyKind.strong,
              EnemyKind.strong,
            ],
            count: 25,
          ),
        ],
      ),
      maxWave: 12,
    );
    add(
      10,
      const WaveTemplate(
        spawnCooldown: 20,
        groups: <WaveGroup>[
          WaveGroup(
            sequence: <EnemyKind>[
              EnemyKind.medic,
              EnemyKind.strong,
              EnemyKind.strong,
            ],
            count: 50,
          ),
        ],
      ),
      maxWave: 13,
    );
    add(
      10,
      const WaveTemplate(
        spawnCooldown: 30,
        groups: <WaveGroup>[
          WaveGroup(
            sequence: <EnemyKind>[
              EnemyKind.medic,
              EnemyKind.strong,
              EnemyKind.strong,
            ],
            count: 50,
          ),
          WaveGroup(sequence: <EnemyKind>[EnemyKind.fast], count: 50),
        ],
      ),
      maxWave: 13,
    );
    add(
      10,
      const WaveTemplate(
        spawnCooldown: 5,
        groups: <WaveGroup>[
          WaveGroup(sequence: <EnemyKind>[EnemyKind.fast], count: 50),
        ],
      ),
      maxWave: 13,
    );
    add(
      12,
      const WaveTemplate(
        spawnCooldown: 20,
        groups: <WaveGroup>[
          WaveGroup(
            sequence: <EnemyKind>[
              EnemyKind.medic,
              EnemyKind.strong,
              EnemyKind.strong,
            ],
            count: 50,
          ),
          WaveGroup(sequence: <EnemyKind>[EnemyKind.strongFast], count: 50),
        ],
      ),
      maxWave: 16,
    );
    add(
      12,
      const WaveTemplate(
        spawnCooldown: 10,
        groups: <WaveGroup>[
          WaveGroup(sequence: <EnemyKind>[EnemyKind.strong], count: 50),
          WaveGroup(sequence: <EnemyKind>[EnemyKind.strongFast], count: 50),
        ],
      ),
      maxWave: 16,
    );
    add(
      12,
      const WaveTemplate(
        spawnCooldown: 10,
        groups: <WaveGroup>[
          WaveGroup(
            sequence: <EnemyKind>[EnemyKind.medic, EnemyKind.strongFast],
            count: 50,
          ),
        ],
      ),
      maxWave: 16,
    );
    add(
      12,
      const WaveTemplate(
        spawnCooldown: 10,
        groups: <WaveGroup>[
          WaveGroup(sequence: <EnemyKind>[EnemyKind.strong], count: 25),
          WaveGroup(sequence: <EnemyKind>[EnemyKind.stronger], count: 25),
          WaveGroup(sequence: <EnemyKind>[EnemyKind.strongFast], count: 50),
        ],
      ),
      maxWave: 16,
    );
    add(
      12,
      const WaveTemplate(
        spawnCooldown: 10,
        groups: <WaveGroup>[
          WaveGroup(sequence: <EnemyKind>[EnemyKind.strong], count: 25),
          WaveGroup(sequence: <EnemyKind>[EnemyKind.medic], count: 25),
          WaveGroup(sequence: <EnemyKind>[EnemyKind.strongFast], count: 50),
        ],
      ),
      maxWave: 16,
    );
    add(
      12,
      const WaveTemplate(
        spawnCooldown: 20,
        groups: <WaveGroup>[
          WaveGroup(
            sequence: <EnemyKind>[
              EnemyKind.medic,
              EnemyKind.stronger,
              EnemyKind.stronger,
            ],
            count: 50,
          ),
        ],
      ),
      maxWave: 16,
    );
    add(
      12,
      const WaveTemplate(
        spawnCooldown: 10,
        groups: <WaveGroup>[
          WaveGroup(
            sequence: <EnemyKind>[
              EnemyKind.medic,
              EnemyKind.stronger,
              EnemyKind.strong,
            ],
            count: 50,
          ),
        ],
      ),
      maxWave: 16,
    );
    add(
      12,
      const WaveTemplate(
        spawnCooldown: 10,
        groups: <WaveGroup>[
          WaveGroup(
            sequence: <EnemyKind>[EnemyKind.medic, EnemyKind.strong],
            count: 50,
          ),
          WaveGroup(
            sequence: <EnemyKind>[EnemyKind.medic, EnemyKind.strongFast],
            count: 50,
          ),
        ],
      ),
      maxWave: 16,
    );
    add(
      12,
      const WaveTemplate(
        spawnCooldown: 5,
        groups: <WaveGroup>[
          WaveGroup(sequence: <EnemyKind>[EnemyKind.strongFast], count: 100),
        ],
      ),
      maxWave: 16,
    );
    add(
      12,
      const WaveTemplate(
        spawnCooldown: 20,
        groups: <WaveGroup>[
          WaveGroup(sequence: <EnemyKind>[EnemyKind.stronger], count: 50),
        ],
      ),
      maxWave: 16,
    );
    add(
      13,
      const WaveTemplate(
        spawnCooldown: 40,
        groups: <WaveGroup>[
          WaveGroup(
            sequence: <EnemyKind>[
              EnemyKind.tank,
              EnemyKind.stronger,
              EnemyKind.stronger,
              EnemyKind.stronger,
            ],
            count: 10,
          ),
        ],
      ),
      maxWave: 20,
    );
    add(
      13,
      const WaveTemplate(
        spawnCooldown: 10,
        groups: <WaveGroup>[
          WaveGroup(
            sequence: <EnemyKind>[
              EnemyKind.medic,
              EnemyKind.stronger,
              EnemyKind.stronger,
            ],
            count: 50,
          ),
        ],
      ),
      maxWave: 20,
    );
    add(
      13,
      const WaveTemplate(
        spawnCooldown: 40,
        groups: <WaveGroup>[
          WaveGroup(sequence: <EnemyKind>[EnemyKind.tank], count: 25),
        ],
      ),
      maxWave: 20,
    );
    add(
      13,
      const WaveTemplate(
        spawnCooldown: 20,
        groups: <WaveGroup>[
          WaveGroup(
            sequence: <EnemyKind>[
              EnemyKind.tank,
              EnemyKind.stronger,
              EnemyKind.stronger,
            ],
            count: 50,
          ),
        ],
      ),
      maxWave: 20,
    );
    add(
      13,
      const WaveTemplate(
        spawnCooldown: 20,
        groups: <WaveGroup>[
          WaveGroup(
            sequence: <EnemyKind>[EnemyKind.tank, EnemyKind.medic],
            count: 50,
          ),
          WaveGroup(sequence: <EnemyKind>[EnemyKind.strongFast], count: 25),
        ],
      ),
      maxWave: 20,
    );
    add(
      14,
      const WaveTemplate(
        spawnCooldown: 20,
        groups: <WaveGroup>[
          WaveGroup(
            sequence: <EnemyKind>[
              EnemyKind.tank,
              EnemyKind.stronger,
              EnemyKind.stronger,
            ],
            count: 50,
          ),
        ],
      ),
      maxWave: 20,
    );
    add(
      14,
      const WaveTemplate(
        spawnCooldown: 20,
        groups: <WaveGroup>[
          WaveGroup(
            sequence: <EnemyKind>[
              EnemyKind.tank,
              EnemyKind.medic,
              EnemyKind.medic,
            ],
            count: 50,
          ),
        ],
      ),
      maxWave: 20,
    );
    add(
      14,
      const WaveTemplate(
        spawnCooldown: 20,
        groups: <WaveGroup>[
          WaveGroup(
            sequence: <EnemyKind>[EnemyKind.tank, EnemyKind.medic],
            count: 50,
          ),
          WaveGroup(sequence: <EnemyKind>[EnemyKind.strongFast], count: 25),
        ],
      ),
      maxWave: 20,
    );
    add(
      14,
      const WaveTemplate(
        spawnCooldown: 10,
        groups: <WaveGroup>[
          WaveGroup(sequence: <EnemyKind>[EnemyKind.tank], count: 50),
          WaveGroup(sequence: <EnemyKind>[EnemyKind.strongFast], count: 25),
        ],
      ),
      maxWave: 20,
    );
    add(
      14,
      const WaveTemplate(
        spawnCooldown: 10,
        groups: <WaveGroup>[
          WaveGroup(sequence: <EnemyKind>[EnemyKind.faster], count: 50),
        ],
      ),
      maxWave: 20,
    );
    add(
      14,
      const WaveTemplate(
        spawnCooldown: 20,
        groups: <WaveGroup>[
          WaveGroup(sequence: <EnemyKind>[EnemyKind.tank], count: 50),
          WaveGroup(sequence: <EnemyKind>[EnemyKind.faster], count: 25),
        ],
      ),
      maxWave: 20,
    );
    add(
      17,
      const WaveTemplate(
        spawnCooldown: 20,
        groups: <WaveGroup>[
          WaveGroup(
            sequence: <EnemyKind>[
              EnemyKind.taunt,
              EnemyKind.stronger,
              EnemyKind.stronger,
              EnemyKind.stronger,
            ],
            count: 25,
          ),
        ],
      ),
      maxWave: 25,
    );
    add(
      17,
      const WaveTemplate(
        spawnCooldown: 20,
        groups: <WaveGroup>[
          WaveGroup(
            sequence: <EnemyKind>[
              EnemyKind.spawner,
              EnemyKind.stronger,
              EnemyKind.stronger,
              EnemyKind.stronger,
            ],
            count: 25,
          ),
        ],
      ),
      maxWave: 25,
    );
    add(
      17,
      const WaveTemplate(
        spawnCooldown: 20,
        groups: <WaveGroup>[
          WaveGroup(
            sequence: <EnemyKind>[
              EnemyKind.taunt,
              EnemyKind.tank,
              EnemyKind.tank,
              EnemyKind.tank,
            ],
            count: 25,
          ),
        ],
      ),
      maxWave: 25,
    );
    add(
      17,
      const WaveTemplate(
        spawnCooldown: 40,
        groups: <WaveGroup>[
          WaveGroup(
            sequence: <EnemyKind>[
              EnemyKind.taunt,
              EnemyKind.tank,
              EnemyKind.tank,
              EnemyKind.tank,
            ],
            count: 25,
          ),
        ],
      ),
      maxWave: 25,
    );
    add(
      19,
      const WaveTemplate(
        spawnCooldown: 20,
        groups: <WaveGroup>[
          WaveGroup(sequence: <EnemyKind>[EnemyKind.spawner], count: 1),
          WaveGroup(sequence: <EnemyKind>[EnemyKind.tank], count: 20),
          WaveGroup(sequence: <EnemyKind>[EnemyKind.stronger], count: 25),
        ],
      ),
    );
    add(
      19,
      const WaveTemplate(
        spawnCooldown: 20,
        groups: <WaveGroup>[
          WaveGroup(sequence: <EnemyKind>[EnemyKind.spawner], count: 1),
          WaveGroup(sequence: <EnemyKind>[EnemyKind.faster], count: 25),
        ],
      ),
    );
    add(
      23,
      const WaveTemplate(
        spawnCooldown: 20,
        groups: <WaveGroup>[
          WaveGroup(
            sequence: <EnemyKind>[
              EnemyKind.taunt,
              EnemyKind.medic,
              EnemyKind.tank,
            ],
            count: 25,
          ),
        ],
      ),
    );
    add(
      23,
      const WaveTemplate(
        spawnCooldown: 20,
        groups: <WaveGroup>[
          WaveGroup(sequence: <EnemyKind>[EnemyKind.spawner], count: 2),
          WaveGroup(
            sequence: <EnemyKind>[
              EnemyKind.taunt,
              EnemyKind.medic,
              EnemyKind.tank,
            ],
            count: 25,
          ),
        ],
      ),
    );
    add(
      23,
      const WaveTemplate(
        spawnCooldown: 10,
        groups: <WaveGroup>[
          WaveGroup(sequence: <EnemyKind>[EnemyKind.spawner], count: 1),
          WaveGroup(sequence: <EnemyKind>[EnemyKind.faster], count: 100),
        ],
      ),
    );
    add(
      23,
      const WaveTemplate(
        spawnCooldown: 5,
        groups: <WaveGroup>[
          WaveGroup(sequence: <EnemyKind>[EnemyKind.faster], count: 100),
        ],
      ),
    );
    add(
      23,
      const WaveTemplate(
        spawnCooldown: 20,
        groups: <WaveGroup>[
          WaveGroup(sequence: <EnemyKind>[EnemyKind.tank], count: 100),
          WaveGroup(sequence: <EnemyKind>[EnemyKind.faster], count: 50),
          WaveGroup(
            sequence: <EnemyKind>[
              EnemyKind.taunt,
              EnemyKind.tank,
              EnemyKind.tank,
              EnemyKind.tank,
            ],
            count: 50,
          ),
        ],
      ),
    );
    add(
      23,
      const WaveTemplate(
        spawnCooldown: 10,
        groups: <WaveGroup>[
          WaveGroup(
            sequence: <EnemyKind>[
              EnemyKind.taunt,
              EnemyKind.stronger,
              EnemyKind.tank,
              EnemyKind.stronger,
            ],
            count: 50,
          ),
          WaveGroup(sequence: <EnemyKind>[EnemyKind.faster], count: 50),
        ],
      ),
    );
    add(
      25,
      const WaveTemplate(
        spawnCooldown: 5,
        groups: <WaveGroup>[
          WaveGroup(
            sequence: <EnemyKind>[
              EnemyKind.taunt,
              EnemyKind.medic,
              EnemyKind.tank,
            ],
            count: 50,
          ),
          WaveGroup(sequence: <EnemyKind>[EnemyKind.faster], count: 50),
        ],
      ),
    );
    add(
      25,
      const WaveTemplate(
        spawnCooldown: 5,
        groups: <WaveGroup>[
          WaveGroup(
            sequence: <EnemyKind>[
              EnemyKind.taunt,
              EnemyKind.faster,
              EnemyKind.faster,
              EnemyKind.faster,
            ],
            count: 50,
          ),
        ],
      ),
    );
    add(
      25,
      const WaveTemplate(
        spawnCooldown: 10,
        groups: <WaveGroup>[
          WaveGroup(
            sequence: <EnemyKind>[
              EnemyKind.taunt,
              EnemyKind.tank,
              EnemyKind.tank,
              EnemyKind.tank,
            ],
            count: 50,
          ),
          WaveGroup(sequence: <EnemyKind>[EnemyKind.faster], count: 50),
        ],
      ),
    );
    add(
      30,
      const WaveTemplate(
        spawnCooldown: 5,
        groups: <WaveGroup>[
          WaveGroup(
            sequence: <EnemyKind>[
              EnemyKind.taunt,
              EnemyKind.faster,
              EnemyKind.faster,
              EnemyKind.faster,
            ],
            count: 50,
          ),
        ],
      ),
    );
    add(
      30,
      const WaveTemplate(
        spawnCooldown: 5,
        groups: <WaveGroup>[
          WaveGroup(
            sequence: <EnemyKind>[
              EnemyKind.taunt,
              EnemyKind.tank,
              EnemyKind.tank,
              EnemyKind.tank,
            ],
            count: 50,
          ),
        ],
      ),
    );
    add(
      30,
      const WaveTemplate(
        spawnCooldown: 5,
        groups: <WaveGroup>[
          WaveGroup(
            sequence: <EnemyKind>[
              EnemyKind.taunt,
              EnemyKind.medic,
              EnemyKind.tank,
              EnemyKind.tank,
            ],
            count: 50,
          ),
        ],
      ),
    );
    add(
      30,
      const WaveTemplate(
        spawnCooldown: 1,
        groups: <WaveGroup>[
          WaveGroup(sequence: <EnemyKind>[EnemyKind.faster], count: 200),
        ],
      ),
    );
    add(
      35,
      const WaveTemplate(
        spawnCooldown: 0,
        groups: <WaveGroup>[
          WaveGroup(
            sequence: <EnemyKind>[EnemyKind.taunt, EnemyKind.faster],
            count: 200,
          ),
        ],
      ),
    );

    WaveTemplate chosen = candidates[_random.nextInt(candidates.length)];
    if (_config.difficulty == Difficulty.relaxed) {
      chosen = WaveTemplate(
        spawnCooldown: math.max(chosen.spawnCooldown, 20),
        groups: chosen.groups
            .map(
              (WaveGroup group) => WaveGroup(
                sequence: group.sequence,
                count: math.max(1, (group.count * 0.85).floor()),
              ),
            )
            .toList(growable: false),
      );
    } else if (_config.difficulty == Difficulty.hard) {
      chosen = WaveTemplate(
        spawnCooldown: math.max(0, chosen.spawnCooldown - 5),
        groups: chosen.groups
            .map(
              (WaveGroup group) => WaveGroup(
                sequence: group.sequence,
                count: (group.count * 1.2).ceil(),
              ),
            )
            .toList(growable: false),
      );
    }
    return chosen;
  }

  Future<void> _recalculatePaths() async {
    final MapDefinition map = _activeMap!;
    _pendingPathJobs++;
    _performance = PerformanceStats(
      fps: _performance.fps,
      frameTimeMs: _performance.frameTimeMs,
      quality: _performance.quality,
      activeEnemies: _performance.activeEnemies,
      activeTowers: _performance.activeTowers,
      activeMissiles: _performance.activeMissiles,
      activeParticles: _performance.activeParticles,
      activeBeams: _performance.activeBeams,
      activePulses: _performance.activePulses,
      pendingPathJobs: _pendingPathJobs,
      uiRebuilds: _performance.uiRebuilds,
    );
    try {
      final PathingResult result = await _worker.recalculatePaths(map, _towers);
      _distanceMap = result.distanceMap;
      _pathMap = result.pathMap;
    } finally {
      _pendingPathJobs = math.max(0, _pendingPathJobs - 1);
    }
  }

  List<List<bool>> _buildWalkMap(
    int cols,
    int rows,
    List<List<int>> grid,
    List<TowerEntity> towers,
  ) {
    final List<List<bool>> occupied = List<List<bool>>.generate(
      cols,
      (_) => List<bool>.filled(rows, false, growable: false),
      growable: false,
    );
    for (final TowerEntity tower in towers) {
      if (!tower.alive) {
        continue;
      }
      occupied[tower.gridPosition.x][tower.gridPosition.y] = true;
    }
    return List<List<bool>>.generate(
      cols,
      (int x) => List<bool>.generate(rows, (int y) {
        if (grid[x][y] == 1 || grid[x][y] == 3) {
          return false;
        }
        return !occupied[x][y];
      }, growable: false),
      growable: false,
    );
  }

  Set<String> _visitMap(
    GridPoint exit,
    List<List<bool>> walkMap,
    int cols,
    int rows,
  ) {
    final Set<String> visited = <String>{exit.toString()};
    final List<GridPoint> frontier = <GridPoint>[exit];
    while (frontier.isNotEmpty) {
      final GridPoint current = frontier.removeAt(0);
      for (final GridPoint next in _orthogonalNeighbors(current, cols, rows)) {
        final String key = next.toString();
        if (!walkMap[next.x][next.y] || visited.contains(key)) {
          continue;
        }
        frontier.add(next);
        visited.add(key);
      }
    }
    return visited;
  }

  Iterable<GridPoint> _orthogonalNeighbors(
    GridPoint point,
    int cols,
    int rows,
  ) sync* {
    if (point.x > 0) {
      yield GridPoint(point.x - 1, point.y);
    }
    if (point.y > 0) {
      yield GridPoint(point.x, point.y - 1);
    }
    if (point.x < cols - 1) {
      yield GridPoint(point.x + 1, point.y);
    }
    if (point.y < rows - 1) {
      yield GridPoint(point.x, point.y + 1);
    }
  }

  int _gridValue(GridPoint tile) => _activeMap!.grid[tile.x][tile.y];

  TowerEntity? _towerAt(GridPoint tile) {
    for (final TowerEntity tower in _towers) {
      if (tower.alive && tower.gridPosition == tile) {
        return tower;
      }
    }
    for (final TowerEntity tower in _pendingTowers) {
      if (tower.alive && tower.gridPosition == tile) {
        return tower;
      }
    }
    return null;
  }

  bool _walkable(GridPoint tile) {
    final int gridValue = _gridValue(tile);
    if (gridValue == 1 || gridValue == 3) {
      return false;
    }
    return _towerAt(tile) == null;
  }

  bool _emptyTile(GridPoint tile) {
    if (!_walkable(tile)) {
      return false;
    }
    if (_activeMap!.spawnpoints.contains(tile) || _activeMap!.exit == tile) {
      return false;
    }
    return true;
  }

  bool _placeable(GridPoint tile) {
    final MapDefinition map = _activeMap!;
    final List<List<bool>> walkMap = _buildWalkMap(
      map.cols,
      map.rows,
      map.grid,
      _towers.where((TowerEntity tower) => tower.alive).toList(growable: false),
    );
    walkMap[tile.x][tile.y] = false;
    final Set<String> visitMap = _visitMap(
      map.exit,
      walkMap,
      map.cols,
      map.rows,
    );

    for (final GridPoint spawn in map.spawnpoints) {
      if (!visitMap.contains(spawn.toString())) {
        return false;
      }
    }
    for (final EnemyEntity enemy in _enemies) {
      final GridPoint point = _gridFromWorld(enemy.position);
      if (point == tile) {
        continue;
      }
      if (!visitMap.contains(point.toString())) {
        return false;
      }
    }
    return true;
  }

  bool _canPlace(GridPoint tile) {
    if (_placingTowerKind == null) {
      return false;
    }
    final int gridValue = _gridValue(tile);
    if (gridValue == 3) {
      return _towerAt(tile) == null;
    }
    if (gridValue == 1 || gridValue == 2 || gridValue == 4) {
      return false;
    }
    if (!_emptyTile(tile) || !_placeable(tile)) {
      return false;
    }
    return true;
  }

  String _describePlacement(GridPoint tile) {
    if (_placingTowerKind == null) {
      return '';
    }
    final int gridValue = _gridValue(tile);
    if (gridValue == 1) {
      return 'Blocked by terrain.';
    }
    if (gridValue == 2 || gridValue == 4) {
      return 'Path tiles cannot hold towers.';
    }
    if (gridValue == 3) {
      return _towerAt(tile) == null
          ? 'Tower-only socket available.'
          : 'Another tower already occupies this tile.';
    }
    if (_towerAt(tile) != null) {
      return 'Another tower already occupies this tile.';
    }
    if (_activeMap!.spawnpoints.contains(tile)) {
      return 'Spawn tiles cannot hold towers.';
    }
    if (_activeMap!.exit == tile) {
      return 'The exit tile must stay open.';
    }
    if (!_placeable(tile)) {
      return 'Placement would block enemy pathing.';
    }
    return 'Valid placement.';
  }

  void _buyTower(GridPoint tile) {
    final TowerBlueprint blueprint = towerBlueprints[_placingTowerKind]!;
    if (!_config.devFlags.godMode && _cash < blueprint.cost) {
      _placementMessage = 'Not enough cash.';
      return;
    }
    if (!_config.devFlags.godMode) {
      _cash -= blueprint.cost;
    }
    final TowerEntity tower = _createTower(tile, blueprint);
    _selectedTower = tower;
    _placementMessage = '';
    _placingTowerKind = null;
    if (_gridValue(tile) == 0) {
      _pendingPathfind = true;
    }
    _runStats = _runStats.copyWith(built: _runStats.built + 1);
    _pendingTowers.add(tower);
  }

  TowerEntity _createTower(GridPoint tile, TowerBlueprint blueprint) {
    return TowerEntity(
      blueprint: blueprint,
      gridPosition: tile,
      position: _centerOfTile(tile),
    );
  }

  void _applyTowerUpgrade(TowerEntity tower, TowerBlueprint nextBlueprint) {
    tower.blueprint = nextBlueprint;
    tower.totalCost += nextBlueprint.cost;
    tower.beamDuration = 0;
    tower.lastTarget = null;
  }

  double _sellPrice(TowerEntity tower) =>
      tower.totalCost * GameController._sellConst;

  void _spawnQueuedEnemy() {
    final EnemyKind kind = _queuedEnemies.removeAt(0);
    for (final GridPoint spawn in _activeMap!.spawnpoints) {
      _enemies.add(_spawnEnemy(kind, spawn));
    }
    for (final TempSpawn spawn in _tempSpawns) {
      if (spawn.ticks <= 0) {
        continue;
      }
      spawn.ticks--;
      _enemies.add(_spawnEnemy(kind, spawn.point));
    }
  }

  EnemyEntity _spawnEnemy(EnemyKind kind, GridPoint tile) {
    final EnemyEntity enemy = EnemyEntity(
      blueprint: enemyBlueprints[kind]!,
      position: _centerOfTile(tile),
    );
    enemy.initialize();
    return enemy;
  }

  void _rebuildEnemyBuckets() {
    _enemyBuckets.clear();
    for (final EnemyEntity enemy in _enemies) {
      if (!enemy.alive) {
        continue;
      }
      final GridPoint point = _gridFromWorld(enemy.position);
      if (!_insideGrid(point)) {
        continue;
      }
      final int key = _bucketKey(point.x, point.y);
      (_enemyBuckets[key] ??= <EnemyEntity>[]).add(enemy);
    }
  }

  int _bucketKey(int x, int y) => (x << 16) ^ y;

  void _collectEnemiesInRange(
    Vector2 center,
    double rangeInTiles,
    List<EnemyEntity> result, {
    List<EnemyEntity>? exclude,
  }) {
    result.clear();
    final GridPoint tile = _gridFromWorld(center);
    final int radius = math.max(1, rangeInTiles.ceil() + 1);
    final double radiusPx = (rangeInTiles + 1) * _tileSize;
    final double radiusSquared = radiusPx * radiusPx;
    for (int x = tile.x - radius; x <= tile.x + radius; x++) {
      if (_activeMap == null || x < 0 || x >= _activeMap!.cols) {
        continue;
      }
      for (int y = tile.y - radius; y <= tile.y + radius; y++) {
        if (y < 0 || y >= _activeMap!.rows) {
          continue;
        }
        final List<EnemyEntity>? bucket = _enemyBuckets[_bucketKey(x, y)];
        if (bucket == null) {
          continue;
        }
        for (final EnemyEntity enemy in bucket) {
          if (!enemy.alive) {
            continue;
          }
          if (exclude != null && exclude.contains(enemy)) {
            continue;
          }
          if (_distanceSquaredOffset(enemy.position, center) < radiusSquared) {
            result.add(enemy);
          }
        }
      }
    }
  }

  void _steerEnemy(EnemyEntity enemy) {
    final GridPoint tile = _gridFromWorld(enemy.position);
    if (!_insideGrid(tile)) {
      return;
    }
    final int direction = _pathMap[tile.x][tile.y];
    if (!_atTileCenter(enemy.position, tile) || direction == 0) {
      return;
    }
    final double speed = enemy.speed * _tileSize / 24;
    switch (direction) {
      case 1:
        enemy.velocity.setValues(-speed, 0);
        break;
      case 2:
        enemy.velocity.setValues(0, -speed);
        break;
      case 3:
        enemy.velocity.setValues(speed, 0);
        break;
      case 4:
        enemy.velocity.setValues(0, speed);
        break;
      default:
        break;
    }
  }

  void _updateEnemyEffects(EnemyEntity enemy) {
    for (int index = enemy.effects.length - 1; index >= 0; index--) {
      final StatusEffectInstance effect = enemy.effects[index];
      switch (effect.kind) {
        case EffectKind.slow:
          break;
        case EffectKind.poison:
          _dealDamage(enemy, 1, DamageType.poison, null);
          break;
        case EffectKind.regen:
          if (enemy.health < enemy.maxHealth && _random.nextDouble() < 0.2) {
            enemy.health = math.min(enemy.maxHealth, enemy.health + 1);
          }
          break;
      }
      effect.duration--;
      if (effect.duration <= 0) {
        if (effect.kind == EffectKind.slow && effect.storedSpeed != null) {
          enemy.speed = effect.storedSpeed!;
        }
        enemy.effects.removeAt(index);
      }
    }
  }

  void _moveEnemy(EnemyEntity enemy) {
    final double maxSpeed = math.min(
      96 / _tileSize,
      enemy.speed * _tileSize / 24,
    );
    if (enemy.velocity.length > maxSpeed) {
      _limitVector(enemy.velocity, maxSpeed);
    }
    enemy.position.add(enemy.velocity);
    enemy.hitFlash = math.max(0, enemy.hitFlash - 0.08);
  }

  void _runEnemyBehavior(EnemyEntity enemy) {
    switch (enemy.blueprint.behavior) {
      case EnemyBehavior.basic:
      case EnemyBehavior.arrowhead:
      case EnemyBehavior.tank:
      case EnemyBehavior.taunt:
        return;
      case EnemyBehavior.medic:
        _collectEnemiesInRange(enemy.position, 2, _enemyQueryBuffer);
        for (final EnemyEntity target in _enemyQueryBuffer) {
          _applyEffect(target, EffectKind.regen, 1);
        }
        return;
      case EnemyBehavior.spawner:
        return;
    }
  }

  void _handleEnemyExit(EnemyEntity enemy) {
    if (!_config.devFlags.godMode) {
      _health -= enemy.damage;
    }
    _runStats = _runStats.copyWith(leaks: _runStats.leaks + enemy.damage);
    enemy.alive = false;
  }

  void _targetTower(TowerEntity tower) {
    if (_enemies.isEmpty) {
      return;
    }
    switch (tower.blueprint.behavior) {
      case TowerBehavior.areaStatus:
        _targetAreaTower(tower);
        return;
      case TowerBehavior.direct:
      case TowerBehavior.beam:
      case TowerBehavior.splashOnHit:
      case TowerBehavior.chain:
        _targetSingleTower(tower);
        return;
      case TowerBehavior.missile:
      case TowerBehavior.missileSilo:
        _targetMissileTower(tower);
        return;
      case TowerBehavior.clusterBomb:
        _targetSingleTower(tower);
        return;
    }
  }

  void _targetSingleTower(TowerEntity tower) {
    _collectEnemiesInRange(
      tower.position,
      tower.blueprint.range,
      _enemyQueryBuffer,
    );
    if (_enemyQueryBuffer.isEmpty) {
      return;
    }
    _enemyTauntBuffer.clear();
    for (final EnemyEntity enemy in _enemyQueryBuffer) {
      if (enemy.blueprint.taunt) {
        _enemyTauntBuffer.add(enemy);
      }
    }
    final List<EnemyEntity> candidates =
        _enemyTauntBuffer.isNotEmpty ? _enemyTauntBuffer : _enemyQueryBuffer;
    final EnemyEntity target =
        tower.blueprint.targetingMode == TargetingMode.strongest
        ? _strongestEnemy(candidates)
        : _firstEnemy(candidates);

    if (tower.cooldown == 0 || tower.blueprint.follow) {
      tower.angle = math.atan2(
        target.position.y - tower.position.y,
        target.position.x - tower.position.x,
      );
    }
    if (_config.devFlags.firingDisabled || tower.cooldown != 0) {
      return;
    }

    _resetTowerCooldown(tower);
    tower.flash = 1;
    tower.recoil = 1;
    tower.analytics.shots++;

    switch (tower.blueprint.behavior) {
      case TowerBehavior.direct:
        _fireDirectTower(tower, target);
        return;
      case TowerBehavior.beam:
        _fireBeamTower(tower, target);
        return;
      case TowerBehavior.splashOnHit:
        _fireSplashTower(tower, target);
        return;
      case TowerBehavior.clusterBomb:
        _fireClusterTower(tower, target);
        return;
      case TowerBehavior.chain:
        _fireChainTower(tower, target);
        return;
      case TowerBehavior.areaStatus:
      case TowerBehavior.missile:
      case TowerBehavior.missileSilo:
        return;
    }
  }

  void _targetAreaTower(TowerEntity tower) {
    _collectEnemiesInRange(
      tower.position,
      tower.blueprint.range,
      _enemyQueryBuffer,
    );
    if (_config.devFlags.firingDisabled ||
        _enemyQueryBuffer.isEmpty ||
        tower.cooldown != 0) {
      return;
    }
    _resetTowerCooldown(tower);
    _spawnPulse(
      center: tower.position.toOffset(),
      color: tower.blueprint.color.withAlpha((0.27 * 255).round()),
      radius: (tower.blueprint.range * 2 + 1) * _tileSize / 2,
      filled: true,
      decay: 0.08,
    );
    for (final EnemyEntity enemy in _enemyQueryBuffer) {
      switch (tower.blueprint.damageType) {
        case DamageType.slow:
          _applyEffect(enemy, EffectKind.slow, 40);
          break;
        case DamageType.poison:
          _applyEffect(enemy, EffectKind.poison, 60);
          break;
        default:
          break;
      }
    }
  }

  void _targetMissileTower(TowerEntity tower) {
    _collectEnemiesInRange(
      tower.position,
      tower.blueprint.range,
      _enemyQueryBuffer,
    );
    if (_enemyQueryBuffer.isEmpty) {
      return;
    }
    _enemyTauntBuffer.clear();
    for (final EnemyEntity enemy in _enemyQueryBuffer) {
      if (enemy.blueprint.taunt) {
        _enemyTauntBuffer.add(enemy);
      }
    }
    final EnemyEntity target = _nearestEnemy(
      _enemyTauntBuffer.isNotEmpty ? _enemyTauntBuffer : _enemyQueryBuffer,
      tower.position,
    );
    if (tower.cooldown == 0 || tower.blueprint.follow) {
      tower.angle = math.atan2(
        target.position.y - tower.position.y,
        target.position.x - tower.position.x,
      );
    }
    if (_config.devFlags.firingDisabled || tower.cooldown != 0) {
      return;
    }
    _resetTowerCooldown(tower);
    final MissileEntity missile = MissileEntity(
      position: tower.position.clone(),
      target: target,
      source: tower,
      color: tower.blueprint.kind == TowerKind.missileSilo
          ? const Color(0xFF4183D7)
          : const Color(0xFFCF000F),
      secondaryColor: tower.blueprint.secondaryColor,
      damageMin: tower.blueprint.damageMin,
      damageMax: tower.blueprint.damageMax,
      blastRadius: tower.blueprint.kind == TowerKind.missileSilo ? 2 : 1,
      topSpeed: tower.blueprint.kind == TowerKind.missileSilo
          ? (6 * 24) / _tileSize
          : (4 * 24) / _tileSize,
      acceleration: tower.blueprint.kind == TowerKind.missileSilo ? 0.7 : 0.6,
      range: tower.blueprint.range,
    );
    _missiles.add(missile);
    _playTowerSound(tower.blueprint.sound);
  }

  void _fireDirectTower(TowerEntity tower, EnemyEntity target) {
    final double damage = _randomDamage(
      tower.blueprint.damageMin,
      tower.blueprint.damageMax,
    ).roundToDouble();
    _dealDamage(target, damage, tower.blueprint.damageType, tower);
    _spawnBeamTrace(
      tower.position.toOffset(),
      target.position.toOffset(),
      tower.blueprint.color,
      tower.blueprint.weight,
    );
    _playTowerSound(tower.blueprint.sound);
  }

  void _fireBeamTower(TowerEntity tower, EnemyEntity target) {
    if (tower.lastTarget == target) {
      tower.beamDuration++;
    } else {
      tower.lastTarget = target;
      tower.beamDuration = 0;
    }
    final double damage =
        _randomDamage(tower.blueprint.damageMin, tower.blueprint.damageMax) *
        math.pow(tower.beamDuration, 2);
    _dealDamage(target, damage, tower.blueprint.damageType, tower);
    _spawnBeamTrace(
      tower.position.toOffset(),
      target.position.toOffset(),
      tower.blueprint.flashColor,
      tower.blueprint.weight,
    );
  }

  void _fireSplashTower(TowerEntity tower, EnemyEntity target) {
    final double damage = _randomDamage(
      tower.blueprint.damageMin,
      tower.blueprint.damageMax,
    ).roundToDouble();
    _dealDamage(target, damage, tower.blueprint.damageType, tower);
    _spawnBeamTrace(
      tower.position.toOffset(),
      target.position.toOffset(),
      tower.blueprint.color,
      tower.blueprint.weight,
    );
    final double blastRadius = tower.blueprint.kind == TowerKind.railgun
        ? 1
        : 1;
    _applySplashDamage(
      target.position,
      blastRadius: blastRadius,
      minDamage: tower.blueprint.damageMin,
      maxDamage: tower.blueprint.damageMax,
      type: tower.blueprint.damageType,
      source: tower,
      minFalloff: tower.blueprint.kind == TowerKind.railgun ? 0.35 : 0.35,
      color: tower.blueprint.kind == TowerKind.railgun
          ? tower.blueprint.color
          : const Color(0xFFDBAA66),
      particleKind: tower.blueprint.kind == TowerKind.railgun
          ? ParticleKind.shrapnel
          : ParticleKind.bomb,
    );
    _playTowerSound(tower.blueprint.sound);
  }

  void _fireClusterTower(TowerEntity tower, EnemyEntity target) {
    _spawnBeamTrace(
      tower.position.toOffset(),
      target.position.toOffset(),
      tower.blueprint.color,
      tower.blueprint.weight,
    );
    _spawnPulse(
      center: target.position.toOffset(),
      color: const Color(0x6EDBAA66),
      radius: _tileSize * 1.25,
      filled: true,
      decay: 0.08,
    );
    _spawnExplosionParticles(
      target.position.toOffset(),
      ParticleKind.bomb,
      GameController._particleAmount,
    );
    const int segments = 3;
    final double angle0 = _random.nextDouble() * math.pi * 2;
    for (int i = 0; i < segments; i++) {
      final double angle = math.pi * 2 / segments * i + angle0;
      final Offset center = Offset(
        target.position.x + math.cos(angle) * 2 * _tileSize,
        target.position.y + math.sin(angle) * 2 * _tileSize,
      );
      _applySplashDamage(
        Vector2(center.dx, center.dy),
        blastRadius: 1,
        minDamage: tower.blueprint.damageMin,
        maxDamage: tower.blueprint.damageMax,
        type: tower.blueprint.damageType,
        source: tower,
        minFalloff: 0.25,
        color: const Color(0x6EDBAA66),
        particleKind: ParticleKind.bomb,
      );
    }
  }

  void _fireChainTower(TowerEntity tower, EnemyEntity target) {
    double damage = _randomDamage(
      tower.blueprint.damageMin,
      tower.blueprint.damageMax,
    ).roundToDouble();
    double weight = tower.blueprint.weight;
    EnemyEntity current = target;
    final List<EnemyEntity> hit = <EnemyEntity>[];
    _playTowerSound(tower.blueprint.sound);
    _spawnBeamTrace(
      tower.position.toOffset(),
      current.position.toOffset(),
      tower.blueprint.color,
      weight,
    );
    while (damage > 1) {
      _dealDamage(current, damage, tower.blueprint.damageType, tower);
      hit.add(current);
      _collectEnemiesInRange(
        current.position,
        tower.blueprint.range,
        _enemyChainCandidates,
        exclude: hit,
      );
      final EnemyEntity? next = _nearestEnemyOrNull(
        _enemyChainCandidates,
        current.position,
      );
      if (next == null) {
        break;
      }
      weight = math.max(1, weight - 1);
      final Offset pivot = Offset(
        _lerp(current.position.x, next.position.x, _random.nextDouble()),
        _lerp(current.position.y, next.position.y, _random.nextDouble()),
      );
      _beamTraces.add(
        _BeamTrace(
          start: current.position.toOffset(),
          end: pivot,
          color: tower.blueprint.color,
          strokeWidth: weight,
          alpha: 1,
        ),
      );
      _beamTraces.add(
        _BeamTrace(
          start: pivot,
          end: next.position.toOffset(),
          color: tower.blueprint.color,
          strokeWidth: weight,
          alpha: 1,
        ),
      );
      current = next;
      damage /= 2;
    }
  }

  void _steerMissile(MissileEntity missile) {
    if (!missile.target.alive) {
      _collectEnemiesInRange(
        missile.position,
        missile.range,
        _enemyQueryBuffer,
      );
      final EnemyEntity? replacement = _nearestEnemyOrNull(
        _enemyQueryBuffer,
        missile.position,
      );
      if (replacement == null) {
        missile.alive = false;
        return;
      }
      missile.target = replacement;
    }
    final Vector2 desired = (missile.target.position - missile.position)
      ..normalize()
      ..scale(missile.topSpeed);
    final Vector2 steer = desired - missile.velocity;
    if (steer.length > missile.acceleration) {
      _limitVector(steer, missile.acceleration);
    }
    missile.accelerationVector.add(steer);
  }

  void _updateMissile(MissileEntity missile) {
    missile.velocity.add(missile.accelerationVector);
    if (missile.velocity.length > missile.topSpeed) {
      _limitVector(missile.velocity, missile.topSpeed);
    }
    missile.position.add(missile.velocity);
    missile.accelerationVector.setZero();
    if (_config.effectsEnabled) {
      if (missile.trailCooldown <= 0) {
        _spawnSmokeTrail(missile.position.toOffset(), missile.velocity.clone());
        missile.trailCooldown = 2;
      } else {
        missile.trailCooldown--;
      }
    }
    if (missile.lifetime > 0) {
      missile.lifetime--;
    } else {
      _explodeMissile(missile);
    }
  }

  bool _missileReachedTarget(MissileEntity missile) {
    if (!missile.alive || !missile.target.alive) {
      return false;
    }
    final double radius = missile.target.blueprint.radius * _tileSize;
    return _distanceSquared(missile.position, missile.target.position) <
        radius * radius;
  }

  void _explodeMissile(MissileEntity missile) {
    if (!missile.alive) {
      return;
    }
    missile.alive = false;
    _applySplashDamage(
      missile.position,
      blastRadius: missile.blastRadius,
      minDamage: missile.damageMin,
      maxDamage: missile.damageMax,
      type: DamageType.explosion,
      source: missile.source,
      minFalloff: 0.2,
      color: missile.color.withAlpha((0.5 * 255).round()),
      particleKind: ParticleKind.fire,
    );
    _playSound(soundAsset('boom.wav'));
  }

  void _applySplashDamage(
    Vector2 center, {
    required double blastRadius,
    required double minDamage,
    required double maxDamage,
    required DamageType type,
    required TowerEntity source,
    required double minFalloff,
    required Color color,
    required ParticleKind particleKind,
  }) {
    _spawnPulse(
      center: center.toOffset(),
      color: color,
      radius: (blastRadius + 0.5) * _tileSize,
      filled: true,
      decay: 0.08,
    );
    _spawnExplosionParticles(
      center.toOffset(),
      particleKind,
      GameController._particleAmount,
    );
    _collectEnemiesInRange(center, blastRadius, _enemyQueryBuffer);
    for (final EnemyEntity enemy in _enemyQueryBuffer) {
      final double distance = (enemy.position - center).length;
      final double falloff = _clamp(
        1 - distance / ((blastRadius + 1) * _tileSize),
        minFalloff,
        1,
      );
      final double damage = _randomDamage(minDamage, maxDamage) * falloff;
      _dealDamage(enemy, damage.roundToDouble(), type, source);
    }
  }

  void _applyEffect(EnemyEntity enemy, EffectKind kind, int duration) {
    if (_hasDamageImmunity(enemy, switch (kind) {
      EffectKind.slow => DamageType.slow,
      EffectKind.poison => DamageType.poison,
      EffectKind.regen => DamageType.regen,
    })) {
      return;
    }
    if (enemy.effects.any(
      (StatusEffectInstance effect) => effect.kind == kind,
    )) {
      return;
    }
    final StatusEffectInstance effect = StatusEffectInstance(
      kind: kind,
      duration: duration,
    );
    if (kind == EffectKind.slow) {
      effect.storedSpeed = enemy.speed;
      enemy.speed = enemy.speed / 2;
    }
    enemy.effects.add(effect);
  }

  void _dealDamage(
    EnemyEntity enemy,
    double amount,
    DamageType type,
    TowerEntity? source,
  ) {
    if (!enemy.alive) {
      return;
    }
    final double multiplier = _damageMultiplier(enemy, type);
    final double applied = math.max(0, amount * multiplier);
    enemy.hitFlash = math.min(1, enemy.hitFlash + 0.45);
    if (source != null) {
      enemy.lastHitBy = source;
      source.analytics.damage += math.min(applied, enemy.health).round();
      _runStats = _runStats.copyWith(
        totalDamage: _runStats.totalDamage + math.min(applied, enemy.health),
      );
    }
    enemy.health -= applied;
    if (enemy.health <= 0) {
      _onEnemyKilled(enemy);
    }
  }

  void _onEnemyKilled(EnemyEntity enemy) {
    if (!enemy.alive) {
      return;
    }
    _cash += enemy.blueprint.cash;
    _runStats = _runStats.copyWith(kills: _runStats.kills + 1);
    if (enemy.lastHitBy != null) {
      enemy.lastHitBy!.analytics.kills++;
    }
    enemy.alive = false;
    if (enemy.blueprint.kind == EnemyKind.spawner) {
      final GridPoint tile = _gridFromWorld(enemy.position);
      if (tile != _activeMap!.exit &&
          !_tempSpawns.any((TempSpawn spawn) => spawn.point == tile)) {
        _tempSpawns.add(
          TempSpawn(point: tile, ticks: GameController._tempSpawnCount),
        );
      }
    }
    _playEnemySound(enemy.blueprint.sound);
  }

  double _damageMultiplier(EnemyEntity enemy, DamageType type) {
    if (_hasDamageImmunity(enemy, type)) {
      return 0;
    }
    if (enemy.blueprint.resistances.contains(type)) {
      return 1 - GameController._resistance;
    }
    if (enemy.blueprint.weaknesses.contains(type)) {
      return 1 + GameController._weakness;
    }
    return 1;
  }

  bool _hasDamageImmunity(EnemyEntity enemy, DamageType type) {
    return enemy.blueprint.immunities.contains(type);
  }

  EnemyEntity _firstEnemy(List<EnemyEntity> candidates) {
    double bestProgress = -double.infinity;
    EnemyEntity chosen = candidates.first;
    for (final EnemyEntity enemy in candidates) {
      final GridPoint tile = _gridFromWorld(enemy.position);
      if (!_insideGrid(tile)) {
        continue;
      }
      final int? distance = _distanceMap[tile.x][tile.y];
      double progress = distance == null
          ? -double.infinity
          : -distance.toDouble();
      final Offset center = _centerOfTile(tile).toOffset();
      final Offset current = enemy.position.toOffset();
      progress += 1 - ((current - center).distance / math.max(_tileSize, 1));
      if (progress > bestProgress) {
        bestProgress = progress;
        chosen = enemy;
      }
    }
    return chosen;
  }

  EnemyEntity _strongestEnemy(List<EnemyEntity> candidates) {
    EnemyEntity chosen = candidates.first;
    for (final EnemyEntity enemy in candidates) {
      if (enemy.health > chosen.health) {
        chosen = enemy;
      }
    }
    return chosen;
  }

  EnemyEntity _nearestEnemy(List<EnemyEntity> candidates, Vector2 position) {
    return _nearestEnemyOrNull(candidates, position)!;
  }

  EnemyEntity? _nearestEnemyOrNull(
    List<EnemyEntity> candidates,
    Vector2 position,
  ) {
    EnemyEntity? chosen;
    double lowestDistance = double.infinity;
    for (final EnemyEntity enemy in candidates) {
      final double distance = _distanceSquared(enemy.position, position);
      if (distance < lowestDistance) {
        lowestDistance = distance;
        chosen = enemy;
      }
    }
    return chosen;
  }

  void _resetTowerCooldown(TowerEntity tower) {
    tower.cooldown = _randomInt(
      tower.blueprint.cooldownMin,
      tower.blueprint.cooldownMax,
    );
  }

  double _randomDamage(double min, double max) {
    if (min == max) {
      return min;
    }
    return min + _random.nextDouble() * (max - min);
  }

  int _randomInt(int min, int max) {
    if (max <= min) {
      return min;
    }
    return min + _random.nextInt(max - min + 1);
  }

  double _distanceSquared(Vector2 a, Vector2 b) {
    final double dx = a.x - b.x;
    final double dy = a.y - b.y;
    return dx * dx + dy * dy;
  }

  double _distanceSquaredOffset(Vector2 a, Vector2 b) => _distanceSquared(a, b);

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  double _clamp(double value, double min, double max) =>
      math.max(min, math.min(max, value));

  void _limitVector(Vector2 vector, double maxLength) {
    if (vector.length <= maxLength || maxLength <= 0) {
      return;
    }
    vector
      ..normalize()
      ..scale(maxLength);
  }
}
