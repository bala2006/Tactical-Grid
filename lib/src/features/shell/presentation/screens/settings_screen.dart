import 'package:flutter/material.dart';

import '../../../game/domain/content.dart';
import '../../../game/application/controller.dart';
import '../../../game/domain/models.dart';
import 'screen_chrome.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    required this.controller,
    required this.onBack,
    required this.onImportMap,
    required this.onExportMap,
    required this.onOpenMapEditor,
    super.key,
  });

  final GameController controller;
  final VoidCallback onBack;
  final VoidCallback onImportMap;
  final VoidCallback onExportMap;
  final VoidCallback onOpenMapEditor;

  @override
  Widget build(BuildContext context) {
    final GameConfig config = controller.config;
    return Container(
      key: const ValueKey<String>('settings'),
      decoration: screenBackgroundDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: DecoratedBox(
              decoration: solidScreenCardDecoration(),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          IconButton.outlined(
                            onPressed: onBack,
                            icon: const Icon(Icons.arrow_back_rounded),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'TACTICAL GRID',
                                  style: TextStyle(
                                    color: Color(0xFF8EB8D7),
                                    fontSize: 10,
                                    letterSpacing: 2.4,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Settings',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      screenDropdownField<Difficulty>(
                        label: 'Difficulty',
                        initialValue: config.difficulty,
                        items: Difficulty.values
                            .map(
                              (Difficulty value) =>
                                  DropdownMenuItem<Difficulty>(
                                    value: value,
                                    child: Text(difficultyLabels[value]!),
                                  ),
                            )
                            .toList(growable: false),
                        onChanged: (Difficulty? value) {
                          if (value != null) controller.updateDifficulty(value);
                        },
                      ),
                      const SizedBox(height: 12),
                      screenDropdownField<WaveMode>(
                        label: 'Wave Mode',
                        initialValue: config.waveMode,
                        items: WaveMode.values
                            .map(
                              (WaveMode value) => DropdownMenuItem<WaveMode>(
                                value: value,
                                child: Text(waveModeLabels[value]!),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (WaveMode? value) {
                          if (value != null) controller.updateWaveMode(value);
                        },
                      ),
                      const SizedBox(height: 12),
                      screenDropdownField<PerformanceQuality>(
                        label: 'Quality',
                        initialValue: config.quality,
                        items: PerformanceQuality.values
                            .map(
                              (PerformanceQuality value) =>
                                  DropdownMenuItem<PerformanceQuality>(
                                    value: value,
                                    child: Text(value.name),
                                  ),
                            )
                            .toList(growable: false),
                        onChanged: (PerformanceQuality? value) {
                          if (value != null) controller.updateQuality(value);
                        },
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Effects'),
                        value: config.effectsEnabled,
                        onChanged: (_) => controller.toggleEffects(),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Health Bars'),
                        value: config.healthBars,
                        onChanged: (_) => controller.toggleHealthBars(),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Mute'),
                        value: config.muted,
                        onChanged: (_) => controller.toggleMute(),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Auto-send'),
                        value: config.autoSend,
                        onChanged: (_) => controller.toggleAutoSend(),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Adaptive Quality'),
                        value: config.adaptiveQuality,
                        onChanged: (_) => controller.toggleAdaptiveQuality(),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          OutlinedButton(
                            onPressed: onImportMap,
                            child: const Text('Import Map'),
                          ),
                          OutlinedButton(
                            onPressed: onExportMap,
                            child: const Text('Export Map'),
                          ),
                          OutlinedButton(
                            onPressed: onOpenMapEditor,
                            child: const Text('Map Editor'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
