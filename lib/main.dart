import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/features/shell/presentation/tower_defense_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const TowerDefenseApp());
}
