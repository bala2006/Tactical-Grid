part of 'controller.dart';

class _BeamTrace {
  _BeamTrace({
    required this.start,
    required this.end,
    required this.color,
    required this.strokeWidth,
    required this.alpha,
  });

  final Offset start;
  final Offset end;
  final Color color;
  final double strokeWidth;
  double alpha;
}

class _PulseEffect {
  _PulseEffect({
    required this.center,
    required this.color,
    required this.radius,
    required this.filled,
    required this.decay,
  });

  final Offset center;
  final Color color;
  final double radius;
  final bool filled;
  final double decay;
  double alpha = 1;
}

extension _Render on GameController {
  Paint _solidPaint(Color color) {
    return _fillPaint
      ..style = PaintingStyle.fill
      ..shader = null
      ..color = color
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.butt;
  }

  Paint _solidShaderPaint(Rect rect, Gradient gradient) {
    return _gradientPaint
      ..style = PaintingStyle.fill
      ..color = Colors.white
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.butt
      ..shader = gradient.createShader(rect);
  }

  Paint _linePaint(
    Color color, {
    double width = 1,
    StrokeCap cap = StrokeCap.butt,
  }) {
    return _strokePaint
      ..shader = null
      ..color = color
      ..strokeWidth = width
      ..strokeCap = cap;
  }

  Paint _effectFill(Color color) {
    return _effectPaint
      ..style = PaintingStyle.fill
      ..shader = null
      ..color = color
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.butt;
  }

  void _invalidateStaticBoardPicture() {
    _staticBoardPicture?.dispose();
    _staticBoardPicture = null;
  }

  ui.Picture _buildStaticBoardPicture(MapDefinition map) {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    _drawBackdrop(canvas, map);
    _drawTiles(canvas, map);
    for (final GridPoint spawn in map.spawnpoints) {
      _drawObjectiveMarker(
        canvas,
        spawn,
        const Color(0xFF548E54),
        const Color(0xFFB2D07A),
      );
    }
    _drawObjectiveMarker(
      canvas,
      map.exit,
      const Color(0xFF90463A),
      const Color(0xFFE8AD78),
    );
    _drawGridOverlay(canvas, map);
    return recorder.endRecording();
  }

  void _render(Canvas canvas) {
    final Rect fullRect = Offset.zero & _viewport;
    canvas.drawRect(
      fullRect,
      _solidShaderPaint(
        fullRect,
        const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF10192E), Color(0xFF0B1222)],
        ),
      ),
    );

    if (_loadError != null) {
      _drawLabel(canvas, 'Load failed\n$_loadError', fullRect.center);
      return;
    }
    if (!isReady) {
      _drawLabel(canvas, 'Loading battlefield...', fullRect.center);
      return;
    }

    final MapDefinition map = _activeMap!;
    _staticBoardPicture ??= _buildStaticBoardPicture(map);
    canvas.drawPicture(_staticBoardPicture!);
    for (final TempSpawn spawn in _tempSpawns) {
      _drawObjectiveMarker(
        canvas,
        spawn.point,
        const Color(0xFF78587C),
        const Color(0xFFD0968A),
      );
    }

    for (final _PulseEffect pulse in _pulseEffects) {
      final Color color = pulse.color.withAlpha(
        (pulse.alpha * 255).clamp(0, 255).round(),
      );
      final Paint paint = pulse.filled
          ? _effectFill(color)
          : _linePaint(color, width: math.max(1, _tileSize * 0.06));
      canvas.drawCircle(pulse.center, pulse.radius, paint);
    }

    if (_placingTowerKind != null &&
        _previewTile != null &&
        _insideGrid(_previewTile!)) {
      final TowerBlueprint previewBlueprint =
          towerBlueprints[_placingTowerKind]!;
      _drawRange(
        canvas,
        previewBlueprint,
        _centerOfTile(_previewTile!).toOffset(),
      );
      final bool canPlace = _canPlace(_previewTile!);
      final Paint fill = _effectFill(
        canPlace ? const Color(0x466AAA68) : const Color(0x5AB0563E),
      );
      final Rect tileRect = _tileRect(_previewTile!);
      canvas.drawRect(tileRect, fill);
      _drawTower(
        canvas,
        TowerEntity(
          blueprint: previewBlueprint,
          gridPosition: _previewTile!,
          position: _centerOfTile(_previewTile!),
        ),
        alpha: 0.7,
      );
      if (!canPlace) {
        final Offset center = _centerOfTile(_previewTile!).toOffset();
        final Paint xPaint = _linePaint(
          const Color(0xFFB0563E),
          width: _tileSize * 0.1,
        );
        canvas.drawLine(
          center + Offset(-_tileSize * 0.25, -_tileSize * 0.25),
          center + Offset(_tileSize * 0.25, _tileSize * 0.25),
          xPaint,
        );
        canvas.drawLine(
          center + Offset(-_tileSize * 0.25, _tileSize * 0.25),
          center + Offset(_tileSize * 0.25, -_tileSize * 0.25),
          xPaint,
        );
      }
    }

    if (_selectedTower != null && _selectedTower!.alive) {
      _drawRange(
        canvas,
        _selectedTower!.blueprint,
        _selectedTower!.position.toOffset(),
      );
    }

    for (final EnemyEntity enemy in _enemies) {
      _drawEnemy(canvas, enemy);
      if (_shouldRenderHealthBars) {
        _drawEnemyHealth(canvas, enemy);
      }
    }

    for (final TowerEntity tower in _towers) {
      _drawTower(canvas, tower);
    }

    for (final ParticleEntity particle in _particles) {
      _drawParticle(canvas, particle);
    }

    for (final MissileEntity missile in _missiles) {
      _drawMissile(canvas, missile);
    }

    for (final _BeamTrace trace in _beamTraces) {
      final Paint paint = _linePaint(
        trace.color.withAlpha((trace.alpha * 255).clamp(0, 255).round()),
        width: trace.strokeWidth,
        cap: StrokeCap.round,
      );
      canvas.drawLine(trace.start, trace.end, paint);
    }
  }

  void _drawBackdrop(Canvas canvas, MapDefinition map) {
    final Rect board = Rect.fromLTWH(
      _boardOffset.dx,
      _boardOffset.dy,
      map.cols * _tileSize,
      map.rows * _tileSize,
    );
    canvas.drawRect(board, _solidPaint(const Color(0xFF030508)));
    final Paint checker = _solidPaint(const Color(0x22070D14));
    for (int x = 0; x < map.cols; x++) {
      for (int y = 0; y < map.rows; y++) {
        if ((x + y).isEven) {
          canvas.drawRect(_tileRect(GridPoint(x, y)), checker);
        }
      }
    }
  }

  void _drawTiles(Canvas canvas, MapDefinition map) {
    for (int x = 0; x < map.cols; x++) {
      for (int y = 0; y < map.rows; y++) {
        final GridPoint tile = GridPoint(x, y);
        final Rect rect = _tileRect(tile);
        final String display = map.display[x][y];
        final int dir = map.displayDirection[x][y];
        switch (display) {
          case 'wall':
          case 'tower':
          case 'sidewalk':
            canvas.drawRect(rect, _solidPaint(const Color(0xFF08475C)));
            canvas.drawRect(
              rect.deflate(_tileSize * 0.08),
              _solidPaint(const Color(0xFF0D5D76)),
            );
            break;
          case 'road':
            canvas.drawRect(rect, _solidPaint(const Color(0xFF04070A)));
            if (dir != 0) {
              final bool vertical = dir == 2 || dir == 4;
              final Rect lane = vertical
                  ? Rect.fromCenter(
                      center: rect.center,
                      width: _tileSize * 0.08,
                      height: _tileSize * 0.36,
                    )
                  : Rect.fromCenter(
                      center: rect.center,
                      width: _tileSize * 0.36,
                      height: _tileSize * 0.08,
                    );
              final RRect rr = RRect.fromRectAndRadius(
                lane,
                Radius.circular(_tileSize * 0.02),
              );
              canvas.drawRRect(rr, _solidPaint(const Color(0xFFB8CBE7)));
            }
            break;
          case 'lCorner':
          case 'rCorner':
            canvas.drawRect(rect, _solidPaint(const Color(0xFF04070A)));
            _drawCornerMark(
              canvas,
              rect.center,
              dir,
              left: display == 'lCorner',
            );
            break;
          case 'grass':
            canvas.drawRect(rect, _solidPaint(const Color(0xFF08475C)));
            break;
          case 'empty':
          default:
            canvas.drawRect(rect, _solidPaint(const Color(0xFF04070A)));
            break;
        }
      }
    }
  }

  void _drawCornerMark(
    Canvas canvas,
    Offset center,
    int dir, {
    required bool left,
  }) {
    if (dir == 0) {
      return;
    }
    canvas.save();
    canvas.translate(center.dx, center.dy);
    final List<double> rotations = left
        ? <double>[0, math.pi / 2, math.pi, math.pi * 3 / 2]
        : <double>[math.pi / 2, math.pi, math.pi * 3 / 2, 0];
    canvas.rotate(rotations[dir - 1]);
    final Path path = Path()
      ..moveTo(-_tileSize * 0.25, -_tileSize * 0.05)
      ..lineTo(-_tileSize * 0.25, _tileSize * 0.05)
      ..lineTo(-_tileSize * 0.05, _tileSize * 0.25)
      ..lineTo(_tileSize * 0.05, _tileSize * 0.25)
      ..close();
    canvas.drawPath(path, _solidPaint(const Color(0xFFFAD201)));
    canvas.restore();
  }

  void _drawGridOverlay(Canvas canvas, MapDefinition map) {
    final Paint paint = Paint()
      ..color = const Color(0x4EE0E8F1)
      ..strokeWidth = 1;
    for (int x = 0; x <= map.cols; x++) {
      final double dx = _boardOffset.dx + x * _tileSize;
      canvas.drawLine(
        Offset(dx, _boardOffset.dy),
        Offset(dx, _boardOffset.dy + map.rows * _tileSize),
        paint,
      );
    }
    for (int y = 0; y <= map.rows; y++) {
      final double dy = _boardOffset.dy + y * _tileSize;
      canvas.drawLine(
        Offset(_boardOffset.dx, dy),
        Offset(_boardOffset.dx + map.cols * _tileSize, dy),
        paint,
      );
    }
  }

  void _drawObjectiveMarker(
    Canvas canvas,
    GridPoint tile,
    Color primary,
    Color secondary,
  ) {
    final Offset center = _centerOfTile(tile).toOffset();
    canvas.drawOval(
      Rect.fromCenter(
        center: center + Offset(0, _tileSize * 0.22),
        width: _tileSize * 0.8,
        height: _tileSize * 0.28,
      ),
      _solidPaint(const Color(0x3C000000)),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          _boardOffset.dx + tile.x * _tileSize + _tileSize * 0.14,
          _boardOffset.dy + tile.y * _tileSize + _tileSize * 0.14,
          _tileSize * 0.72,
          _tileSize * 0.72,
        ),
        Radius.circular(_tileSize * 0.08),
      ),
      _solidPaint(primary.withAlpha(210)),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          _boardOffset.dx + tile.x * _tileSize + _tileSize * 0.28,
          _boardOffset.dy + tile.y * _tileSize + _tileSize * 0.28,
          _tileSize * 0.44,
          _tileSize * 0.44,
        ),
        Radius.circular(_tileSize * 0.05),
      ),
      _solidPaint(secondary.withAlpha(225)),
    );
  }

  void _drawRange(Canvas canvas, TowerBlueprint blueprint, Offset center) {
    final double radius = (blueprint.range + 0.5) * _tileSize;
    canvas.drawRect(
      Rect.fromCenter(center: center, width: radius * 2, height: radius * 2),
      _solidPaint(blueprint.color.withAlpha(16)),
    );
    canvas.drawCircle(
      center,
      radius,
      _linePaint(
        blueprint.color.withAlpha(150),
        width: math.max(1, _tileSize * 0.05),
      ),
    );
  }

  void _drawEnemy(Canvas canvas, EnemyEntity enemy) {
    final Color color = enemy.effects.isNotEmpty
        ? effectBlueprints[enemy.effects.last.kind]!.color
        : enemy.blueprint.color;
    final Color secondary = enemy.blueprint.secondaryColor;
    final Offset center = enemy.position.toOffset();
    final double radius = enemy.blueprint.radius * _tileSize / 2;
    canvas.drawOval(
      Rect.fromCenter(
        center: center + Offset(0, _tileSize * 0.18),
        width: radius * 1.8,
        height: radius * 0.76,
      ),
      _solidPaint(const Color(0x41000000)),
    );

    switch (enemy.blueprint.behavior) {
      case EnemyBehavior.arrowhead:
        final double back = -enemy.blueprint.radius * _tileSize / 3;
        final double front = back + enemy.blueprint.radius * _tileSize;
        final double side = enemy.blueprint.radius * _tileSize * 0.5;
        final Path path = Path()
          ..moveTo(center.dx + back, center.dy - side)
          ..lineTo(center.dx, center.dy)
          ..lineTo(center.dx + back, center.dy + side)
          ..lineTo(center.dx + front, center.dy)
          ..close();
        canvas.drawPath(path, _solidPaint(color));
        if (enemy.blueprint.kind == EnemyKind.faster) {
          final Path accent = Path()
            ..moveTo(center.dx + back + _tileSize * 0.06, center.dy - _tileSize * 0.14)
            ..lineTo(center.dx + front - _tileSize * 0.08, center.dy)
            ..lineTo(center.dx + back + _tileSize * 0.06, center.dy + _tileSize * 0.14)
            ..close();
          canvas.drawPath(accent, _solidPaint(secondary));
        } else {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: center + Offset(back + _tileSize * 0.18, 0),
                width: _tileSize * 0.2,
                height: _tileSize * 0.16,
              ),
              Radius.circular(_tileSize * 0.03),
            ),
            _solidPaint(secondary),
          );
        }
        break;
      case EnemyBehavior.tank:
        final RRect body = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: center,
            width: radius * 2,
            height: radius * 1.4,
          ),
          Radius.circular(_tileSize * 0.16),
        );
        canvas.drawRRect(body, _solidPaint(color));
        canvas.drawRect(
          Rect.fromCenter(
            center: center + Offset(radius * 0.55, 0),
            width: _tileSize * 0.7,
            height: _tileSize * 0.12,
          ),
          _solidPaint(secondary),
        );
        canvas.drawCircle(
          center,
          _tileSize * 0.2,
          _solidPaint(secondary),
        );
        break;
      case EnemyBehavior.taunt:
        final Rect outer = Rect.fromCenter(
          center: center,
          width: radius * 2,
          height: radius * 2,
        );
        canvas.drawRect(outer, _solidPaint(color));
        final Paint border = _linePaint(
          secondary,
          width: math.max(1, _tileSize * 0.05),
        );
        canvas.drawRect(outer.deflate(_tileSize * 0.15), border);
        canvas.drawRect(outer.deflate(_tileSize * 0.22), border);
        break;
      case EnemyBehavior.medic:
      case EnemyBehavior.spawner:
      case EnemyBehavior.basic:
        canvas.drawRect(
          Rect.fromCenter(
            center: center,
            width: radius * 2,
            height: radius * 2,
          ),
          _solidPaint(color),
        );
        break;
    }

    final Paint gloss = _effectFill(
      Colors.white.withAlpha(
        (34 + enemy.hitFlash * 100).round().clamp(0, 255),
      ),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center + Offset(-_tileSize * 0.06, -_tileSize * 0.08),
          width: radius * 0.64,
          height: radius * 0.36,
        ),
        Radius.circular(_tileSize * 0.03),
      ),
      gloss,
    );
  }

  void _drawEnemyHealth(Canvas canvas, EnemyEntity enemy) {
    final double percentLost = 1 - enemy.health / enemy.maxHealth;
    if (percentLost <= 0) {
      return;
    }
    final Offset center = enemy.position.toOffset();
    final Rect rect = Rect.fromLTWH(
      center.dx - _tileSize * 0.35,
      center.dy + _tileSize * 0.2,
      _tileSize * 0.7 * percentLost,
      _tileSize * 0.15,
    );
    canvas.drawRect(rect, _solidPaint(const Color(0xFFCF000F)));
    canvas.drawRect(
      rect,
      _linePaint(Colors.white),
    );
  }

  void _drawTower(Canvas canvas, TowerEntity tower, {double alpha = 1}) {
    final TowerBlueprint blueprint = tower.blueprint;
    final Offset center = tower.position.toOffset();
    final Color color = blueprint.color.withAlpha(
      (255 * alpha).round().clamp(0, 255),
    );
    final Color secondary = blueprint.secondaryColor.withAlpha(
      (255 * alpha).round().clamp(0, 255),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: center + Offset(0, _tileSize * 0.18),
        width: blueprint.radius * _tileSize * 0.95,
        height: blueprint.radius * _tileSize * 0.45,
      ),
      _solidPaint(const Color(0x46000000)),
    );
    if (blueprint.hasBase && !blueprint.baseOnTop) {
      _drawTowerBase(canvas, center, blueprint, color);
    }
    if (blueprint.hasBarrel) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(tower.angle);
      _drawTowerBarrel(canvas, tower, color, secondary);
      if (tower.flash > 0.02) {
        _drawMuzzleFlash(
          canvas,
          tower,
          blueprint.flashColor.withAlpha(
            (alpha * 180 * tower.flash).round().clamp(0, 255),
          ),
        );
      }
      canvas.restore();
    }
    if (blueprint.hasBase && blueprint.baseOnTop) {
      _drawTowerBase(canvas, center, blueprint, color);
    }
  }

  void _drawTowerBase(
    Canvas canvas,
    Offset center,
    TowerBlueprint blueprint,
    Color color,
  ) {
    canvas.drawRect(
      Rect.fromCenter(
        center: center,
        width: blueprint.radius * _tileSize,
        height: blueprint.radius * _tileSize,
      ),
      _solidPaint(color),
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: center + Offset(-_tileSize * 0.08, -_tileSize * 0.1),
        width: blueprint.radius * _tileSize * 0.4,
        height: blueprint.radius * _tileSize * 0.28,
      ),
      _solidPaint(Colors.white.withAlpha(35)),
    );
  }

  void _drawTowerBarrel(
    Canvas canvas,
    TowerEntity tower,
    Color color,
    Color secondary,
  ) {
    final TowerBlueprint blueprint = tower.blueprint;
    switch (blueprint.kind) {
      case TowerKind.sniper:
        final Path path = Path()
          ..moveTo(-_tileSize * 0.24, -_tileSize * 0.32)
          ..lineTo(-_tileSize * 0.24, _tileSize * 0.32)
          ..lineTo(_tileSize * 0.48, 0)
          ..close();
        canvas.drawPath(path, _solidPaint(color));
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: const Offset(-4, 0),
              width: _tileSize * 0.22,
              height: _tileSize * 0.16,
            ),
            Radius.circular(_tileSize * 0.04),
          ),
          _solidPaint(const Color(0xFF948E80)),
        );
        break;
      case TowerKind.railgun:
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: blueprint.length * _tileSize,
            height: blueprint.width * _tileSize,
          ),
          _solidPaint(secondary),
        );
        canvas.drawRect(
          Rect.fromCenter(
            center: const Offset(0, 0),
            width: _tileSize * 0.3,
            height: _tileSize * 0.3,
          ),
          _solidPaint(color),
        );
        break;
      case TowerKind.slow:
      case TowerKind.poison:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: blueprint.length * _tileSize,
              height: blueprint.width * _tileSize,
            ),
            Radius.circular(_tileSize * 0.08),
          ),
          _solidPaint(secondary),
        );
        for (final double offset in <double>[-0.22, 0.0, 0.22]) {
          canvas.drawRect(
            Rect.fromCenter(
              center: Offset(offset * blueprint.length * _tileSize, 0),
              width: _tileSize * 0.12,
              height: _tileSize * 0.12,
            ),
            _solidPaint(const Color(0xFF565F54)),
          );
        }
        break;
      case TowerKind.rocket:
      case TowerKind.missileSilo:
        final double bodyLength = blueprint.length * _tileSize;
        final double railHeight = blueprint.width * _tileSize;
        for (final double y in <double>[-_tileSize * 0.16, _tileSize * 0.16]) {
          canvas.drawRect(
            Rect.fromCenter(
              center: Offset(0, y),
              width: bodyLength,
              height: railHeight,
            ),
            _solidPaint(secondary),
          );
          final Path nose = Path()
            ..moveTo(bodyLength / 2 - _tileSize * 0.04, y - railHeight / 2)
            ..lineTo(bodyLength / 2 + _tileSize * 0.18, y)
            ..lineTo(bodyLength / 2 - _tileSize * 0.04, y + railHeight / 2)
            ..close();
          canvas.drawPath(
            nose,
            _solidPaint(
              blueprint.kind == TowerKind.rocket
                  ? const Color(0xFFD96C57)
                  : const Color(0xFFE0A46A),
            ),
          );
        }
        canvas.drawPath(
          Path()
            ..moveTo(-_tileSize * 0.12, -_tileSize * 0.22)
            ..lineTo(_tileSize * 0.18, -_tileSize * 0.22)
            ..lineTo(_tileSize * 0.28, 0)
            ..lineTo(_tileSize * 0.18, _tileSize * 0.22)
            ..lineTo(-_tileSize * 0.12, _tileSize * 0.22)
            ..close(),
          _solidPaint(color),
        );
        break;
      case TowerKind.tesla:
      case TowerKind.plasma:
        final Path hex = Path();
        for (int index = 0; index < 6; index++) {
          final double angle = math.pi * 2 * index / 6;
          final Offset point = Offset(
            math.cos(angle) * _tileSize * 0.5,
            math.sin(angle) * _tileSize * 0.5,
          );
          if (index == 0) {
            hex.moveTo(point.dx, point.dy);
          } else {
            hex.lineTo(point.dx, point.dy);
          }
        }
        hex.close();
        canvas.drawPath(hex, _solidPaint(secondary));
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: _tileSize * 0.55,
            height: _tileSize * 0.55,
          ),
          _solidPaint(color),
        );
        break;
      default:
        final double recoil = tower.recoil * blueprint.recoilAmount * _tileSize;
        canvas.drawRect(
          Rect.fromLTWH(
            -recoil,
            -blueprint.width * _tileSize / 2,
            blueprint.length * _tileSize,
            blueprint.width * _tileSize,
          ),
          _solidPaint(secondary),
        );
        break;
    }
  }

  void _drawMuzzleFlash(Canvas canvas, TowerEntity tower, Color flashColor) {
    final TowerBlueprint blueprint = tower.blueprint;
    final double spread = blueprint.width * _tileSize * (1.2 + tower.flash);
    final double length =
        blueprint.length * _tileSize + tower.flash * _tileSize * 0.55;
    final Path flash = Path()
      ..moveTo(length, 0)
      ..lineTo(length - spread * 1.2, -spread * 0.7)
      ..lineTo(length - spread * 1.2, spread * 0.7)
      ..close();
    canvas.drawPath(flash, _effectFill(flashColor));
  }

  void _drawMissile(Canvas canvas, MissileEntity missile) {
    canvas.save();
    canvas.translate(missile.position.x, missile.position.y);
    canvas.rotate(math.atan2(missile.velocity.y, missile.velocity.x));
    final double length = _tileSize * 0.6;
    final double width = _tileSize * 0.2;
    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: length, height: width * 2),
      _solidPaint(missile.secondaryColor),
    );
    final Path nose = Path()
      ..moveTo(length / 2, -width)
      ..lineTo(length / 2 + width * 2, 0)
      ..lineTo(length / 2, width)
      ..close();
    canvas.drawPath(nose, _solidPaint(missile.color));
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(-length * 0.12, 0),
        width: length * 0.3,
        height: width * 0.9,
      ),
      _solidPaint(const Color(0xFF6B7688)),
    );
    canvas.restore();
  }

  void _drawParticle(Canvas canvas, ParticleEntity particle) {
    final Paint paint = _effectFill(
      particle.color.withAlpha(particle.lifespan.clamp(0, 255).round()),
    );
    switch (particle.kind) {
      case ParticleKind.shrapnel:
      case ParticleKind.spark:
        canvas.drawRect(
          Rect.fromCenter(
            center: particle.position.toOffset(),
            width: particle.radius * 1.5,
            height: particle.radius * 1.5,
          ),
          paint,
        );
        break;
      case ParticleKind.fire:
      case ParticleKind.bomb:
      case ParticleKind.smoke:
        canvas.drawCircle(particle.position.toOffset(), particle.radius, paint);
        break;
    }
  }

  Rect _tileRect(GridPoint tile) {
    return Rect.fromLTWH(
      _boardOffset.dx + tile.x * _tileSize,
      _boardOffset.dy + tile.y * _tileSize,
      _tileSize,
      _tileSize,
    );
  }

  void _drawLabel(Canvas canvas, String text, Offset center) {
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontFamily: 'SourceCodePro',
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: math.min(_viewport.width - 32, 420));
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  void _spawnBeamTrace(Offset start, Offset end, Color color, double width) {
    if (!_config.effectsEnabled) {
      return;
    }
    if (_beamTraces.length >= _maxBeamTracesForCurrentQuality) {
      _beamTraces.removeAt(0);
    }
    _beamTraces.add(
      _BeamTrace(
        start: start,
        end: end,
        color: color,
        strokeWidth: math.max(1, width),
        alpha: 1,
      ),
    );
  }

  void _spawnPulse({
    required Offset center,
    required Color color,
    required double radius,
    required bool filled,
    required double decay,
  }) {
    if (!_config.effectsEnabled) {
      return;
    }
    if (_pulseEffects.length >= _maxPulsesForCurrentQuality) {
      _pulseEffects.removeAt(0);
    }
    _pulseEffects.add(
      _PulseEffect(
        center: center,
        color: color,
        radius: radius,
        filled: filled,
        decay: decay,
      ),
    );
  }

  void _spawnSmokeTrail(Offset center, Vector2 velocity) {
    if (_particles.length >= _maxParticlesForCurrentQuality) {
      return;
    }
    _particles.add(
      ParticleEntity(
        kind: ParticleKind.smoke,
        position: Vector2(center.dx, center.dy),
        velocity: velocity..scale(-0.08),
        acceleration: Vector2.zero(),
        color: const Color(0xFF888888),
        radius: _tileSize * 0.12,
        drag: 0.95,
        decay: 1.7,
        gravity: 0,
        lifespan: 150,
      ),
    );
  }

  void _spawnExplosionParticles(Offset center, ParticleKind kind, int count) {
    if (!_config.effectsEnabled) {
      return;
    }
    final int budget = math.max(0, _maxParticlesForCurrentQuality - _particles.length);
    final int allowedCount = math.min(
      budget,
      switch (_resolvedQuality) {
        PerformanceQuality.high => count,
        PerformanceQuality.balanced => math.max(6, count ~/ 2),
        PerformanceQuality.battery => math.max(3, count ~/ 4),
      },
    );
    for (int index = 0; index < allowedCount; index++) {
      final double angle = _random.nextDouble() * math.pi * 2;
      final double speed = _random.nextDouble() * 3 + 0.5;
      final Color color = switch (kind) {
        ParticleKind.bomb => const Color(0xFFDBAA66),
        ParticleKind.shrapnel => const Color(0xFF7180A0),
        ParticleKind.spark => const Color(0xFFB0E0FF),
        ParticleKind.smoke => const Color(0xFFAAAAAA),
        ParticleKind.fire => const Color(0xFFFFA43A),
      };
      _particles.add(
        ParticleEntity(
          kind: kind,
          position: Vector2(center.dx, center.dy),
          velocity: Vector2(math.cos(angle) * speed, math.sin(angle) * speed),
          acceleration: Vector2.zero(),
          color: color,
          radius: _tileSize * (_random.nextDouble() * 0.08 + 0.06),
          drag: 0.96,
          decay: 4.2,
          gravity: kind == ParticleKind.smoke ? -0.01 : 0.03,
        ),
      );
    }
  }

  void _playTowerSound(String? sound) {
    if (sound == null || _config.muted) {
      return;
    }
    switch (sound) {
      case 'sniper':
        _playSound(soundAsset('sniper.wav'));
        return;
      case 'railgun':
        _playSound(soundAsset('railgun.wav'));
        return;
      case 'spark':
        _playSound(soundAsset('spark.wav'));
        return;
      case 'missile':
        _playSound(soundAsset('missile.wav'));
        return;
      default:
        return;
    }
  }

  void _playEnemySound(String sound) {
    if (_config.muted) {
      return;
    }
    switch (sound) {
      case 'taunt':
        _playSound(soundAsset('taunt.wav'));
        return;
      default:
        _playSound(soundAsset('pop.wav'));
        return;
    }
  }

  void _playSound(String assetPath) {
    if (_config.muted) {
      return;
    }
    if ((_soundCooldowns[assetPath] ?? 0) > 0) {
      return;
    }
    _soundCooldowns[assetPath] = switch (assetPath) {
      'assets/audio/pop.wav' => 2,
      'assets/audio/spark.wav' => 3,
      'assets/audio/missile.wav' => 4,
      _ => 6,
    };
    unawaited(_safePlaySound(assetPath));
  }

  Future<void> _safePlaySound(String assetPath) async {
    try {
      await FlameAudio.play(assetPath);
    } catch (_) {}
  }
}
