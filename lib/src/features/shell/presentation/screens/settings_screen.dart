import 'package:flutter/material.dart';

import '../../../game/domain/content.dart';
import '../../../game/application/controller.dart';
import '../../../game/domain/models.dart';
import '../game_theme.dart';
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
    return TacticalBackground(
      key: const ValueKey<String>('settings'),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Padding(
              padding: const EdgeInsets.all(GameSpace.md),
              child: GlassPanel(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      ScreenHeader(
                        eyebrow: 'CONFIGURATION',
                        title: 'Settings',
                        onBack: onBack,
                      ),
                      const SizedBox(height: 18),
                      const SectionLabel('ENDLESS PARAMETERS'),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: screenDropdownField<Difficulty>(
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
                                if (value != null) {
                                  controller.updateDifficulty(value);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: screenDropdownField<WaveMode>(
                              label: 'Wave Mode',
                              initialValue: config.waveMode,
                              items: WaveMode.values
                                  .map(
                                    (WaveMode value) =>
                                        DropdownMenuItem<WaveMode>(
                                          value: value,
                                          child: Text(waveModeLabels[value]!),
                                        ),
                                  )
                                  .toList(growable: false),
                              onChanged: (WaveMode? value) {
                                if (value != null) {
                                  controller.updateWaveMode(value);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Difficulty and wave mode apply to Endless runs. '
                        'Campaign levels use their own fixed difficulty and a '
                        'set number of waves.',
                        style: TextStyle(
                          color: GameColors.faint,
                          fontSize: 11,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const SectionLabel('PERFORMANCE'),
                      screenDropdownField<PerformanceQuality>(
                        label: 'Quality',
                        initialValue: config.quality,
                        items: PerformanceQuality.values
                            .map(
                              (PerformanceQuality value) =>
                                  DropdownMenuItem<PerformanceQuality>(
                                    value: value,
                                    child: Text(_qualityLabel(value)),
                                  ),
                            )
                            .toList(growable: false),
                        onChanged: (PerformanceQuality? value) {
                          if (value != null) controller.updateQuality(value);
                        },
                      ),
                      const SizedBox(height: 14),
                      _ToggleTile(
                        icon: Icons.auto_awesome_rounded,
                        title: 'Visual Effects',
                        subtitle: 'Particles, beams, and impact flashes',
                        value: config.effectsEnabled,
                        onChanged: (_) => controller.toggleEffects(),
                      ),
                      _ToggleTile(
                        icon: Icons.favorite_rounded,
                        title: 'Health Bars',
                        subtitle: 'Show damage bars over enemies',
                        value: config.healthBars,
                        onChanged: (_) => controller.toggleHealthBars(),
                      ),
                      _ToggleTile(
                        icon: Icons.volume_up_rounded,
                        title: 'Mute Audio',
                        subtitle: 'Silence all sound effects',
                        value: config.muted,
                        onChanged: (_) => controller.toggleMute(),
                      ),
                      _ToggleTile(
                        icon: Icons.send_rounded,
                        title: 'Auto-send Waves',
                        subtitle: 'Launch the next wave automatically',
                        value: config.autoSend,
                        onChanged: (_) => controller.toggleAutoSend(),
                      ),
                      _ToggleTile(
                        icon: Icons.speed_rounded,
                        title: 'Adaptive Quality',
                        subtitle: 'Auto-tune effects to keep framerate steady',
                        value: config.adaptiveQuality,
                        onChanged: (_) => controller.toggleAdaptiveQuality(),
                      ),
                      const SizedBox(height: 18),
                      const SectionLabel('MAP UTILITIES'),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: <Widget>[
                          SizedBox(
                            width: 150,
                            child: TacticalButton(
                              label: 'Import Map',
                              icon: Icons.download_rounded,
                              dense: true,
                              onPressed: onImportMap,
                            ),
                          ),
                          SizedBox(
                            width: 150,
                            child: TacticalButton(
                              label: 'Export Map',
                              icon: Icons.upload_rounded,
                              dense: true,
                              onPressed: onExportMap,
                            ),
                          ),
                          SizedBox(
                            width: 150,
                            child: TacticalButton(
                              label: 'Map Editor',
                              icon: Icons.grid_on_rounded,
                              dense: true,
                              variant: TacticalButtonVariant.ghost,
                              onPressed: onOpenMapEditor,
                            ),
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

  static String _qualityLabel(PerformanceQuality quality) {
    switch (quality) {
      case PerformanceQuality.high:
        return 'High';
      case PerformanceQuality.balanced:
        return 'Balanced';
      case PerformanceQuality.battery:
        return 'Battery Saver';
    }
  }
}

class _ToggleTile extends StatelessWidget {
  const _ToggleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onChanged(!value),
          borderRadius: BorderRadius.circular(GameSpace.radiusMd),
          child: Ink(
            decoration: BoxDecoration(
              color: GameColors.panelSoft,
              borderRadius: BorderRadius.circular(GameSpace.radiusMd),
              border: Border.all(
                color: value ? GameColors.border : GameColors.border,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: <Widget>[
                Icon(
                  icon,
                  size: 18,
                  color: value ? GameColors.accentBright : GameColors.faint,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: GameColors.faint,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(value: value, onChanged: onChanged),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
