// Single-source-of-truth guard: the native C++ catalog (TowerCatalog.cpp) is the
// gameplay authority, while the Dart catalog (content.dart) feeds the store/dock UI.
// They are maintained in two languages and previously drifted (a 0-damage Machine
// Gun shipped because the tables disagreed). This test parses both source files and
// fails if any tower's cost / damage / range / cooldown disagree — so drift is
// caught at CI time without a runtime FFI change.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

class _TowerStats {
  const _TowerStats({
    required this.cost,
    required this.damageMin,
    required this.damageMax,
    required this.range,
    required this.cooldownMin,
    required this.cooldownMax,
  });

  final double cost;
  final double damageMin;
  final double damageMax;
  final double range;
  final double cooldownMin;
  final double cooldownMax;

  @override
  String toString() =>
      'cost=$cost dmg=$damageMin-$damageMax range=$range cd=$cooldownMin-$cooldownMax';
}

double _num(String raw) => double.parse(raw.replaceAll('f', '').trim());

Map<String, _TowerStats> _parseDart(String src) {
  final Map<String, _TowerStats> out = <String, _TowerStats>{};
  // Entry starts are map keys `TowerKind.name: TowerBlueprint(`; this never
  // matches `upgrades: [TowerKind.x]` references (no `: TowerBlueprint(` after).
  final RegExp entry = RegExp(r'TowerKind\.(\w+):\s*TowerBlueprint\(');
  final List<RegExpMatch> starts = entry.allMatches(src).toList();
  for (int i = 0; i < starts.length; i++) {
    final String name = starts[i].group(1)!;
    final int from = starts[i].end;
    final int to = i + 1 < starts.length ? starts[i + 1].start : src.length;
    final String body = src.substring(from, to);
    double field(String key) {
      final Match? m = RegExp('$key:\\s*([\\d.]+)').firstMatch(body);
      if (m == null) {
        fail('Dart blueprint $name missing field "$key"');
      }
      return _num(m.group(1)!);
    }

    out[name] = _TowerStats(
      cost: field('cost'),
      damageMin: field('damageMin'),
      damageMax: field('damageMax'),
      range: field('range'),
      cooldownMin: field('cooldownMin'),
      cooldownMax: field('cooldownMax'),
    );
  }
  return out;
}

Map<String, _TowerStats> _parseCpp(String src) {
  final Map<String, _TowerStats> out = <String, _TowerStats>{};
  // Each catalog entry begins: "<kindId>", "<title>", <cost>, <dmgMin>f,
  // <dmgMax>f, <range>f, <cdMin>, <cdMax>,  (field order in TowerCatalogEntry).
  final RegExp entry = RegExp(
    r'"(\w+)"\s*,\s*"[^"]*"\s*,\s*'
    r'(\d+)\s*,\s*'
    r'([\d.]+)f?\s*,\s*'
    r'([\d.]+)f?\s*,\s*'
    r'([\d.]+)f?\s*,\s*'
    r'(\d+)\s*,\s*'
    r'(\d+)\s*,',
  );
  for (final RegExpMatch m in entry.allMatches(src)) {
    out[m.group(1)!] = _TowerStats(
      cost: _num(m.group(2)!),
      damageMin: _num(m.group(3)!),
      damageMax: _num(m.group(4)!),
      range: _num(m.group(5)!),
      cooldownMin: _num(m.group(6)!),
      cooldownMax: _num(m.group(7)!),
    );
  }
  return out;
}

void main() {
  test('Dart store catalog matches native C++ catalog (no drift)', () {
    final Map<String, _TowerStats> dart = _parseDart(
      File('lib/src/features/game/domain/content.dart').readAsStringSync(),
    );
    final Map<String, _TowerStats> cpp = _parseCpp(
      File('android/app/src/main/cpp/engine/content/TowerCatalog.cpp')
          .readAsStringSync(),
    );

    // Sanity: both parsers found the full 20-tower roster.
    expect(dart.length, 20, reason: 'Parsed Dart towers: ${dart.keys}');
    expect(cpp.length, 20, reason: 'Parsed C++ towers: ${cpp.keys}');

    for (final String kind in cpp.keys) {
      expect(dart.containsKey(kind), isTrue, reason: 'Dart missing tower "$kind"');
      final _TowerStats c = cpp[kind]!;
      final _TowerStats d = dart[kind]!;
      expect(
        d.toString(),
        c.toString(),
        reason: 'Tower "$kind" stats differ between Dart and C++ catalogs',
      );
    }
  });
}
