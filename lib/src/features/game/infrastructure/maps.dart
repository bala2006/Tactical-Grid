import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/content.dart';
import 'lz_string.dart';
import '../domain/models.dart';

class MapCatalog {
  MapCatalog._(this._encodedMaps);

  final Map<String, String> _encodedMaps;

  static Future<MapCatalog> load() async {
    final raw = await rootBundle.loadString(mapsAssetPath);
    final matches = RegExp(
      r"maps\.(\w+)\s*=\s*toMap\('([^']+)'\);",
    ).allMatches(raw);
    final encoded = <String, String>{};
    for (final match in matches) {
      encoded[match.group(1)!] = match.group(2)!;
    }
    return MapCatalog._(encoded);
  }

  bool contains(String name) => _encodedMaps.containsKey(name);

  MapDefinition decodeByName(String name) {
    final encoded = _encodedMaps[name];
    if (encoded == null) {
      throw StateError('Unknown authored map: $name');
    }
    return decodeCompressedMap(name, encoded);
  }

  MapDefinition decodeCompressedMap(String name, String encoded) {
    final jsonString = LzString.decompressFromBase64(encoded);
    if (jsonString == null || jsonString.isEmpty) {
      throw StateError('Unable to decode map data for $name');
    }
    final dynamic decoded = jsonDecode(jsonString);
    return mapDefinitionFromJson(name, decoded as Map<String, dynamic>);
  }

  String encodeCustomMap(MapDefinition map) {
    return LzString.compressToBase64(jsonEncode(map.toJsonCompatible()));
  }
}

MapDefinition mapDefinitionFromJson(String name, Map<String, dynamic> json) {
  List<List<T>> cast2d<T>(dynamic raw, T Function(dynamic value) cast) {
    final source = raw as List<dynamic>;
    return source
        .map(
          (dynamic column) => (column as List<dynamic>)
              .map<T>((dynamic value) => cast(value))
              .toList(growable: false),
        )
        .toList(growable: false);
  }

  final customWaves = json['waves'] == null
      ? null
      : parseWaveTemplates((json['waves'] as List<dynamic>).cast<dynamic>());

  return MapDefinition(
    name: name,
    display: cast2d<String>(
      json['display'],
      (dynamic value) => value as String,
    ),
    displayDirection: cast2d<int>(
      json['displayDir'],
      (dynamic value) => (value as num).toInt(),
    ),
    grid: cast2d<int>(json['grid'], (dynamic value) => (value as num).toInt()),
    metadata: cast2d<dynamic>(json['metadata'], (dynamic value) => value),
    paths: cast2d<int>(
      json['paths'],
      (dynamic value) => (value as num).toInt(),
    ),
    exit: GridPoint(
      (json['exit'] as List<dynamic>)[0] as int,
      (json['exit'] as List<dynamic>)[1] as int,
    ),
    spawnpoints: (json['spawnpoints'] as List<dynamic>)
        .map(
          (dynamic value) =>
              GridPoint((value as List<dynamic>)[0] as int, value[1] as int),
        )
        .toList(growable: false),
    background: (json['bg'] as List<dynamic>)
        .map<int>((dynamic value) => value as int)
        .toList(growable: false),
    border: (json['border'] as num).toInt(),
    borderAlpha: (json['borderAlpha'] as num).toInt(),
    cols: (json['cols'] as num).toInt(),
    rows: (json['rows'] as num).toInt(),
    customWaves: customWaves,
  );
}
