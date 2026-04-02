import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:towerdefense/src/features/shell/application/game_shell.dart';
import 'package:towerdefense/src/features/shell/presentation/tower_defense_app.dart';

void main() {
  testWidgets('Tower defense app boots', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const TowerDefenseApp());
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(GameShell), findsOneWidget);
  });
}
