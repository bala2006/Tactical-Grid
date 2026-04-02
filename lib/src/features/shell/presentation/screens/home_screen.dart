import 'package:flutter/material.dart';

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
    return Container(
      key: const ValueKey<String>('home'),
      decoration: screenBackgroundDecoration(),
      child: Center(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool compact =
                constraints.maxHeight < 560 || constraints.maxWidth < 1100;
            return ConstrainedBox(
              constraints: BoxConstraints(maxWidth: compact ? 340 : 460),
              child: Padding(
                padding: EdgeInsets.all(compact ? 14 : 24),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    Positioned(
                      left: compact ? -12 : -26,
                      top: compact ? -16 : -24,
                      child: Container(
                        width: compact ? 86 : 118,
                        height: compact ? 86 : 118,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0E3650),
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                    Positioned(
                      right: compact ? -10 : -16,
                      bottom: compact ? -10 : -18,
                      child: Container(
                        width: compact ? 78 : 94,
                        height: compact ? 78 : 94,
                        decoration: BoxDecoration(
                          color: const Color(0xFF194230),
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                    ),
                    DecoratedBox(
                      decoration: solidScreenCardDecoration(),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          compact ? 18 : 24,
                          compact ? 18 : 24,
                          compact ? 18 : 24,
                          compact ? 16 : 20,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Text(
                              'TACTICAL GRID',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: const Color(0xFF8EB8D7),
                                fontSize: compact ? 9.5 : 11,
                                letterSpacing: 2.6,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: compact ? 8 : 10),
                            Text(
                              'Forward Defense Grid',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: compact ? 22 : 28,
                                fontWeight: FontWeight.w800,
                                height: 1.05,
                              ),
                            ),
                            SizedBox(height: compact ? 10 : 12),
                            Text(
                              'Enter command and prepare the next defense run.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: const Color(0xFF8FAAC0),
                                fontSize: compact ? 11 : 13,
                                height: 1.35,
                              ),
                            ),
                            SizedBox(height: compact ? 18 : 22),
                            screenActionButton(
                              compact: compact,
                              icon: Icons.play_arrow_rounded,
                              label: 'Play',
                              primary: true,
                              onPressed: onPlay,
                            ),
                            SizedBox(height: compact ? 10 : 12),
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: screenActionButton(
                                    compact: compact,
                                    icon: Icons.emoji_events_outlined,
                                    label: 'Leaderboard',
                                    onPressed: onLeaderboard,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: screenActionButton(
                                    compact: compact,
                                    icon: Icons.settings_rounded,
                                    label: 'Settings',
                                    onPressed: onSettings,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
