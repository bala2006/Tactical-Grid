import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../application/controller.dart';

class TowerDefenseFlameGame extends FlameGame {
  TowerDefenseFlameGame({required this.controller});

  final GameController controller;

  @override
  Color backgroundColor() => Colors.transparent;

  @override
  void update(double dt) {
    super.update(dt);
    controller.step(dt);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    controller.render(canvas);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    controller.setViewport(Size(size.x, size.y));
  }
}
