import 'package:flutter/material.dart';

import '../game_theme.dart';
import 'screen_chrome.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    required this.onPlay,
    required this.onLeaderboard,
    required this.onSettings,
    super.key,
  });

  final VoidCallback onPlay;
  final VoidCallback onLeaderboard;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return TacticalBackground(
      child: SafeArea(
        child: Center(
          key: const ValueKey<String>('home'),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              // Three tiers:
              //   tiny   — very short landscape phone (< 340 px available height)
              //   compact — typical landscape phone
              //   full    — tablet / desktop
              final bool tiny = constraints.maxHeight < 340;
              final bool compact =
                  constraints.maxHeight < 500 || constraints.maxWidth < 900;

              return ConstrainedBox(
                constraints: BoxConstraints(maxWidth: compact ? 400 : 520),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: tiny ? 10 : (compact ? 16 : 28),
                    vertical: tiny ? 4 : (compact ? 10 : 28),
                  ),
                  child: CornerTicks(
                    child: GlassPanel(
                      glow: true,
                      padding: EdgeInsets.fromLTRB(
                        tiny ? 14 : (compact ? 22 : 34),
                        tiny ? 10 : (compact ? 18 : 34),
                        tiny ? 14 : (compact ? 22 : 34),
                        tiny ? 10 : (compact ? 16 : 30),
                      ),
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            if (!tiny) _Insignia(size: compact ? 52 : 84),
                            if (!tiny) SizedBox(height: compact ? 10 : 18),
                            _EyebrowRow(fontSize: compact ? 9 : 10.5),
                            SizedBox(height: tiny ? 4 : (compact ? 6 : 10)),
                            Text(
                              'FORWARD DEFENSE\nGRID',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: tiny ? 18 : (compact ? 22 : 34),
                                fontWeight: FontWeight.w900,
                                height: 1.05,
                                letterSpacing: 0.8,
                              ),
                            ),
                            if (!tiny) ...<Widget>[
                              SizedBox(height: compact ? 8 : 12),
                              Text(
                                'Deploy turrets, hold the line, and break '
                                'every wave before it reaches the core.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: GameColors.muted,
                                  fontSize: compact ? 11 : 13,
                                  height: 1.35,
                                ),
                              ),
                            ],
                            SizedBox(height: tiny ? 10 : (compact ? 16 : 26)),
                            TacticalButton(
                              label: 'DEPLOY',
                              icon: Icons.play_arrow_rounded,
                              variant: TacticalButtonVariant.primary,
                              dense: compact || tiny,
                              onPressed: onPlay,
                            ),
                            SizedBox(height: tiny ? 6 : (compact ? 8 : 10)),
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: TacticalButton(
                                    label: 'Records',
                                    icon: Icons.military_tech_rounded,
                                    dense: true,
                                    onPressed: onLeaderboard,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TacticalButton(
                                    label: 'Settings',
                                    icon: Icons.tune_rounded,
                                    dense: true,
                                    onPressed: onSettings,
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
              );
            },
          ),
        ),
      ),
    );
  }
}

class _EyebrowRow extends StatelessWidget {
  const _EyebrowRow({required this.fontSize});
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Container(
          width: 12,
          height: 2,
          color: GameColors.accent,
          margin: const EdgeInsets.only(right: 6),
        ),
        Text(
          'TACTICAL GRID // COMMAND',
          style: kEyebrowStyle.copyWith(fontSize: fontSize),
        ),
        Container(
          width: 12,
          height: 2,
          color: GameColors.accent,
          margin: const EdgeInsets.only(left: 6),
        ),
      ],
    );
  }
}

/// A stylised radar/insignia mark built from primitives.
class _Insignia extends StatelessWidget {
  const _Insignia({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(
            colors: <Color>[Color(0xFF173352), Color(0xFF0C1B2E)],
          ),
          border: Border.all(color: GameColors.accent, width: 2),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: GameColors.accent.withValues(alpha: 0.4),
              blurRadius: 20,
              spreadRadius: -4,
            ),
          ],
        ),
        child: Icon(
          Icons.shield_rounded,
          color: GameColors.accentBright,
          size: size * 0.48,
        ),
      ),
    );
  }
}
