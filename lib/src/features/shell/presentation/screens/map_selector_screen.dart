import 'package:flutter/material.dart';

import '../../../game/domain/content.dart';
import '../../../game/domain/models.dart';
import '../game_theme.dart';
import 'screen_chrome.dart';

class MapSelectorScreen extends StatelessWidget {
  const MapSelectorScreen({
    required this.config,
    required this.onBack,
    required this.onStartRun,
    required this.onSelectMap,
    super.key,
  });

  final GameConfig config;
  final VoidCallback onBack;
  final Future<void> Function() onStartRun;
  final ValueChanged<String> onSelectMap;

  @override
  Widget build(BuildContext context) {
    return TacticalBackground(
      key: const ValueKey<String>('map'),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(GameSpace.md),
          child: GlassPanel(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                ScreenHeader(
                  eyebrow: 'ENDLESS MODE',
                  title: 'Select Battlefield',
                  onBack: onBack,
                  trailing: TacticalButton(
                    label: 'Start Run',
                    icon: Icons.play_arrow_rounded,
                    variant: TacticalButtonVariant.primary,
                    expand: false,
                    onPressed: onStartRun,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: GameColors.panelStrong,
                    borderRadius: BorderRadius.circular(GameSpace.radiusMd),
                    border: Border.all(color: GameColors.border),
                  ),
                  child: const Row(
                    children: <Widget>[
                      Icon(
                        Icons.all_inclusive_rounded,
                        color: GameColors.accentBright,
                        size: 18,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Survive as long as you can. Difficulty, wave mode, and '
                          'audio are tuned on the Settings screen.',
                          style: TextStyle(
                            color: GameColors.muted,
                            fontSize: 11.5,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: selectableMapNames.map((String name) {
                        final bool selected = config.mapSelection == name;
                        return _MapTile(
                          name: mapLabels[name] ?? name,
                          procedural: proceduralMapNames.contains(name),
                          selected: selected,
                          onTap: () => onSelectMap(name),
                        );
                      }).toList(growable: false),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MapTile extends StatelessWidget {
  const _MapTile({
    required this.name,
    required this.procedural,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final bool procedural;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color accent = procedural ? GameColors.success : GameColors.accent;
    return SizedBox(
      width: 168,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(GameSpace.radiusMd),
          child: Ink(
            decoration: BoxDecoration(
              gradient: selected
                  ? GameGradients.accent(GameColors.accent)
                  : LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        accent.withValues(alpha: 0.08),
                        GameColors.panel,
                      ],
                    ),
              borderRadius: BorderRadius.circular(GameSpace.radiusMd),
              border: Border.all(
                color: selected
                    ? GameColors.accentBright
                    : accent.withValues(alpha: 0.32),
                width: selected ? 1.6 : 1,
              ),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.map_rounded,
                      size: 16,
                      color: selected ? const Color(0xFF04121F) : accent,
                    ),
                    const Spacer(),
                    if (selected)
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 16,
                        color: Color(0xFF04121F),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: selected ? const Color(0xFF04121F) : GameColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  procedural ? 'PROCEDURAL' : 'AUTHORED',
                  style: TextStyle(
                    fontSize: 8.5,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? const Color(0xCC04121F)
                        : accent.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
