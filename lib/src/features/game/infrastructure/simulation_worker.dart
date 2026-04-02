import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;

import '../domain/content.dart';
import 'maps.dart';
import '../domain/models.dart';

class PathingResult {
  const PathingResult({
    required this.distanceMap,
    required this.pathMap,
    required this.walkMap,
  });

  final List<List<int?>> distanceMap;
  final List<List<int>> pathMap;
  final List<List<bool>> walkMap;
}

class SimulationWorker {
  SimulationWorker();

  Isolate? _isolate;
  SendPort? _sendPort;
  ReceivePort? _receivePort;
  int _nextId = 0;
  final Map<int, Completer<Object?>> _pending = <int, Completer<Object?>>{};

  Future<void> start() async {
    if (_sendPort != null) {
      return;
    }
    _receivePort = ReceivePort();
    final Completer<SendPort> readyPort = Completer<SendPort>();
    _receivePort!.listen((dynamic message) {
      if (message is SendPort) {
        if (!readyPort.isCompleted) {
          readyPort.complete(message);
        }
        return;
      }
      final Map<Object?, Object?> payload = message as Map<Object?, Object?>;
      final int id = payload['id']! as int;
      final Completer<Object?>? completer = _pending.remove(id);
      if (completer == null) {
        return;
      }
      final Object? error = payload['error'];
      if (error != null) {
        completer.completeError(StateError('$error'));
        return;
      }
      completer.complete(payload['result']);
    });
    _isolate = await Isolate.spawn(_workerMain, _receivePort!.sendPort);
    _sendPort = await readyPort.future;
  }

  Future<MapDefinition> generateProceduralMap({
    required String name,
    required double viewportWidth,
    required double viewportHeight,
    required int zoom,
  }) async {
    final Object? result = await _request(
      'generateProceduralMap',
      <String, Object?>{
        'name': name,
        'viewportWidth': viewportWidth,
        'viewportHeight': viewportHeight,
        'zoom': zoom,
      },
    );
    return mapDefinitionFromJson(
      name,
      (result as Map<Object?, Object?>).cast<String, dynamic>(),
    );
  }

  Future<PathingResult> recalculatePaths(
    MapDefinition map,
    Iterable<TowerEntity> towers,
  ) async {
    final Object? result = await _request(
      'recalculatePaths',
      <String, Object?>{
        'map': map.toJsonCompatible(),
        'towers': towers
            .where((TowerEntity tower) => tower.alive)
            .map<List<int>>((TowerEntity tower) => <int>[
                  tower.gridPosition.x,
                  tower.gridPosition.y,
                ])
            .toList(growable: false),
      },
    );
    final Map<Object?, Object?> data = result as Map<Object?, Object?>;
    return PathingResult(
      distanceMap: _cast2d<int?>(
        data['distanceMap']! as List<dynamic>,
        (dynamic value) => value == null ? null : (value as num).toInt(),
      ),
      pathMap: _cast2d<int>(
        data['pathMap']! as List<dynamic>,
        (dynamic value) => (value as num).toInt(),
      ),
      walkMap: _cast2d<bool>(
        data['walkMap']! as List<dynamic>,
        (dynamic value) => value as bool,
      ),
    );
  }

  Future<void> dispose() async {
    if (_sendPort != null) {
      _sendPort!.send(<String, Object?>{'type': 'dispose'});
    }
    _sendPort = null;
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _receivePort?.close();
    _receivePort = null;
    for (final Completer<Object?> completer in _pending.values) {
      completer.completeError(StateError('Simulation worker disposed'));
    }
    _pending.clear();
  }

  Future<Object?> _request(String type, Map<String, Object?> payload) async {
    await start();
    final int id = _nextId++;
    final Completer<Object?> completer = Completer<Object?>();
    _pending[id] = completer;
    _sendPort!.send(<String, Object?>{
      'id': id,
      'type': type,
      'payload': payload,
    });
    return completer.future;
  }
}

List<List<T>> _cast2d<T>(
  List<dynamic> raw,
  T Function(dynamic value) cast,
) {
  return raw
      .map<List<T>>(
        (dynamic column) => (column as List<dynamic>)
            .map<T>((dynamic value) => cast(value))
            .toList(growable: false),
      )
      .toList(growable: false);
}

void _workerMain(SendPort mainSendPort) {
  final ReceivePort workerPort = ReceivePort();
  mainSendPort.send(workerPort.sendPort);
  workerPort.listen((dynamic message) {
    final Map<Object?, Object?> request = message as Map<Object?, Object?>;
    if (request['type'] == 'dispose') {
      workerPort.close();
      return;
    }
    final int id = request['id']! as int;
    try {
      final String type = request['type']! as String;
      final Map<Object?, Object?> payload =
          request['payload']! as Map<Object?, Object?>;
      final Object result = switch (type) {
        'generateProceduralMap' =>
          _generateProceduralMap(
            payload['name']! as String,
            (payload['viewportWidth']! as num).toDouble(),
            (payload['viewportHeight']! as num).toDouble(),
            payload['zoom']! as int,
          ),
        'recalculatePaths' =>
          _recalculatePaths(
            mapDefinitionFromJson(
              'worker',
              (payload['map']! as Map<Object?, Object?>).cast<String, dynamic>(),
            ),
            (payload['towers']! as List<dynamic>)
                .map<GridPoint>(
                  (dynamic item) => GridPoint(
                    (item as List<dynamic>)[0] as int,
                    item[1] as int,
                  ),
                )
                .toList(growable: false),
          ),
        _ => throw StateError('Unknown worker request: $type'),
      };
      mainSendPort.send(<String, Object?>{'id': id, 'result': result});
    } catch (error) {
      mainSendPort.send(<String, Object?>{'id': id, 'error': '$error'});
    }
  });
}

Map<String, dynamic> _generateProceduralMap(
  String name,
  double viewportWidth,
  double viewportHeight,
  int zoom,
) {
  final math.Random random = math.Random();
  final int spawnCount = name.endsWith('3') ? 3 : 2;
  final double wallCover = switch (name) {
    'empty2' || 'empty3' => 0,
    'sparse2' || 'sparse3' => 0.1,
    'dense2' || 'dense3' => 0.2,
    'solid2' || 'solid3' => 0.3,
    _ => 0.1,
  };

  final int cols = math.max(14, (viewportWidth / zoom).floor());
  final int rows = math.max(8, (viewportHeight / zoom).floor());

  final List<List<int>> grid = List<List<int>>.generate(
    cols,
    (_) => List<int>.generate(
      rows,
      (_) => random.nextDouble() < wallCover ? 1 : 0,
      growable: false,
    ),
    growable: false,
  );

  final GridPoint exit = _randomEmptyTile(
    random,
    grid,
    cols,
    rows,
    null,
    const <GridPoint>{},
  );
  for (final GridPoint neighbor in _orthogonalNeighbors(exit, cols, rows)) {
    grid[neighbor.x][neighbor.y] = 0;
  }

  final List<List<bool>> walkMap =
      (_recalculatePaths(
        MapDefinition(
          name: name,
          display: List<List<String>>.generate(
            cols,
            (_) => List<String>.filled(rows, 'empty', growable: false),
            growable: false,
          ),
          displayDirection: List<List<int>>.generate(
            cols,
            (_) => List<int>.filled(rows, 0, growable: false),
            growable: false,
          ),
          grid: grid,
          metadata: List<List<dynamic>>.generate(
            cols,
            (_) => List<dynamic>.filled(rows, null, growable: false),
            growable: false,
          ),
          paths: List<List<int>>.generate(
            cols,
            (_) => List<int>.filled(rows, 0, growable: false),
            growable: false,
          ),
          exit: exit,
          spawnpoints: const <GridPoint>[],
          background: const <int>[0, 0, 0],
          border: 255,
          borderAlpha: 31,
          cols: cols,
          rows: rows,
          customWaves: defaultCustomWaves,
        ),
        const <GridPoint>[],
      )['walkMap']! as List<dynamic>)
          .map<List<bool>>(
            (dynamic column) => (column as List<dynamic>)
                .map<bool>((dynamic value) => value as bool)
                .toList(growable: false),
          )
          .toList(growable: false);
  final Set<String> visited = _visitMap(exit, walkMap, cols, rows);
  final List<GridPoint> spawnpoints = <GridPoint>[];
  while (spawnpoints.length < spawnCount) {
    GridPoint spawn = _randomEmptyTile(
      random,
      grid,
      cols,
      rows,
      exit,
      spawnpoints.toSet(),
    );
    int tries = 0;
    while (!visited.contains('${spawn.x},${spawn.y}') ||
        spawn.distanceTo(exit) < 15) {
      spawn = _randomEmptyTile(
        random,
        grid,
        cols,
        rows,
        exit,
        spawnpoints.toSet(),
      );
      tries++;
      if (tries > 200) {
        break;
      }
    }
    spawnpoints.add(spawn);
  }

  final List<List<String>> display = List<List<String>>.generate(
    cols,
    (int x) => List<String>.generate(
      rows,
      (int y) => grid[x][y] == 1 ? 'wall' : 'empty',
      growable: false,
    ),
    growable: false,
  );

  return MapDefinition(
    name: name,
    display: display,
    displayDirection: List<List<int>>.generate(
      cols,
      (_) => List<int>.filled(rows, 0, growable: false),
      growable: false,
    ),
    grid: grid,
    metadata: List<List<dynamic>>.generate(
      cols,
      (_) => List<dynamic>.filled(rows, null, growable: false),
      growable: false,
    ),
    paths: List<List<int>>.generate(
      cols,
      (_) => List<int>.filled(rows, 0, growable: false),
      growable: false,
    ),
    exit: exit,
    spawnpoints: spawnpoints,
    background: const <int>[0, 0, 0],
    border: 255,
    borderAlpha: 31,
    cols: cols,
    rows: rows,
    customWaves: defaultCustomWaves,
  ).toJsonCompatible();
}

Map<String, Object> _recalculatePaths(MapDefinition map, List<GridPoint> towers) {
  final List<List<bool>> occupied = List<List<bool>>.generate(
    map.cols,
    (_) => List<bool>.filled(map.rows, false, growable: false),
    growable: false,
  );
  for (final GridPoint tower in towers) {
    if (tower.x >= 0 &&
        tower.x < map.cols &&
        tower.y >= 0 &&
        tower.y < map.rows) {
      occupied[tower.x][tower.y] = true;
    }
  }

  final List<List<bool>> walkMap = List<List<bool>>.generate(
    map.cols,
    (int x) => List<bool>.generate(
      map.rows,
      (int y) {
        if (map.grid[x][y] == 1 || map.grid[x][y] == 3) {
          return false;
        }
        return !occupied[x][y];
      },
      growable: false,
    ),
    growable: false,
  );

  final List<List<int?>> distanceMap = List<List<int?>>.generate(
    map.cols,
    (_) => List<int?>.filled(map.rows, null, growable: false),
    growable: false,
  );
  final List<List<int>> pathMap = List<List<int>>.generate(
    map.cols,
    (_) => List<int>.filled(map.rows, 0, growable: false),
    growable: false,
  );

  final List<GridPoint> queue = <GridPoint>[map.exit];
  final List<List<bool>> visited = List<List<bool>>.generate(
    map.cols,
    (_) => List<bool>.filled(map.rows, false, growable: false),
    growable: false,
  );
  final List<List<GridPoint?>> cameFrom = List<List<GridPoint?>>.generate(
    map.cols,
    (_) => List<GridPoint?>.filled(map.rows, null, growable: false),
    growable: false,
  );
  visited[map.exit.x][map.exit.y] = true;
  distanceMap[map.exit.x][map.exit.y] = 0;

  for (int head = 0; head < queue.length; head++) {
    final GridPoint current = queue[head];
    final int nextDistance = distanceMap[current.x][current.y]! + 1;
    for (final GridPoint next in _orthogonalNeighbors(
      current,
      map.cols,
      map.rows,
    )) {
      if (!walkMap[next.x][next.y] || visited[next.x][next.y]) {
        continue;
      }
      visited[next.x][next.y] = true;
      cameFrom[next.x][next.y] = current;
      distanceMap[next.x][next.y] = nextDistance;
      queue.add(next);
    }
  }

  for (int x = 0; x < map.cols; x++) {
    for (int y = 0; y < map.rows; y++) {
      final GridPoint? next = cameFrom[x][y];
      if (next == null) {
        continue;
      }
      final int dx = next.x - x;
      final int dy = next.y - y;
      if (dx < 0) {
        pathMap[x][y] = 1;
      } else if (dy < 0) {
        pathMap[x][y] = 2;
      } else if (dx > 0) {
        pathMap[x][y] = 3;
      } else if (dy > 0) {
        pathMap[x][y] = 4;
      }
      if (map.grid[x][y] == 2) {
        pathMap[x][y] = map.paths[x][y];
      }
    }
  }

  return <String, Object>{
    'distanceMap': distanceMap,
    'pathMap': pathMap,
    'walkMap': walkMap,
  };
}

GridPoint _randomEmptyTile(
  math.Random random,
  List<List<int>> grid,
  int cols,
  int rows,
  GridPoint? exit,
  Set<GridPoint> reserved,
) {
  while (true) {
    final GridPoint tile = GridPoint(random.nextInt(cols), random.nextInt(rows));
    if (grid[tile.x][tile.y] != 0) {
      continue;
    }
    if (exit != null && tile == exit) {
      continue;
    }
    if (reserved.contains(tile)) {
      continue;
    }
    return tile;
  }
}

Set<String> _visitMap(
  GridPoint exit,
  List<List<bool>> walkMap,
  int cols,
  int rows,
) {
  final Set<String> visited = <String>{'${exit.x},${exit.y}'};
  final List<GridPoint> frontier = <GridPoint>[exit];
  for (int head = 0; head < frontier.length; head++) {
    final GridPoint current = frontier[head];
    for (final GridPoint next in _orthogonalNeighbors(current, cols, rows)) {
      final String key = '${next.x},${next.y}';
      if (!walkMap[next.x][next.y] || visited.contains(key)) {
        continue;
      }
      frontier.add(next);
      visited.add(key);
    }
  }
  return visited;
}

Iterable<GridPoint> _orthogonalNeighbors(GridPoint point, int cols, int rows) sync* {
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
