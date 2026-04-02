import 'package:flutter/material.dart';

import '../../game/application/controller.dart';
import '../application/game_shell.dart';
import 'game_theme.dart';

class TowerDefenseApp extends StatefulWidget {
  const TowerDefenseApp({super.key});

  @override
  State<TowerDefenseApp> createState() => _TowerDefenseAppState();
}

class _TowerDefenseAppState extends State<TowerDefenseApp> {
  late final GameController _controller;

  @override
  void initState() {
    super.initState();
    _controller = GameController()..initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Forward Defense Grid',
      debugShowCheckedModeBanner: false,
      theme: buildGameTheme(),
      home: GameShell(controller: _controller),
    );
  }
}
