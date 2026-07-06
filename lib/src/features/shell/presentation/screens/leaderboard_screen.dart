import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../progression/domain/campaign.dart';
import '../../../progression/domain/profile.dart';
import '../game_theme.dart';
import 'screen_chrome.dart';

/// Local records board, backed by the persisted [PlayerProfile]. Shows lifetime
/// stats: best wave, fastest clear, total kills, stars and campaign progress.
class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({
    required this.onBack,
    required this.profileListenable,
    super.key,
  });

  final VoidCallback onBack;
  final ValueListenable<PlayerProfile> profileListenable;

  @override
  Widget build(BuildContext context) {
    return TacticalBackground(
      key: const ValueKey<String>('leaderboard'),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Padding(
              padding: const EdgeInsets.all(GameSpace.md),
              child: ValueListenableBuilder<PlayerProfile>(
                valueListenable: profileListenable,
                builder: (BuildContext context, PlayerProfile profile, _) {
                  return GlassPanel(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        ScreenHeader(
                          eyebrow: 'SERVICE RECORD',
                          title: 'Records',
                          onBack: onBack,
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: <Widget>[
                            _RecordTile(
                              icon: Icons.waves_rounded,
                              color: GameColors.accentBright,
                              label: 'Best wave reached',
                              value: profile.bestWaveReached == 0
                                  ? '—'
                                  : '${profile.bestWaveReached}',
                            ),
                            _RecordTile(
                              icon: Icons.timer_rounded,
                              color: GameColors.success,
                              label: 'Fastest level clear',
                              value: profile.fastestClearSeconds == null
                                  ? '—'
                                  : _formatDuration(
                                      profile.fastestClearSeconds!,
                                    ),
                            ),
                            _RecordTile(
                              icon: Icons.track_changes_rounded,
                              color: GameColors.warning,
                              label: 'Total kills',
                              value: '${profile.totalKills}',
                            ),
                            _RecordTile(
                              icon: Icons.star_rounded,
                              color: GameColors.gold,
                              label: 'Stars earned',
                              value:
                                  '${profile.totalStars}/${Campaign.levelCount * 3}',
                            ),
                            _RecordTile(
                              icon: Icons.flag_rounded,
                              color: GameColors.accent,
                              label: 'Levels cleared',
                              value:
                                  '${profile.levelsCleared}/${Campaign.levelCount}',
                            ),
                            _RecordTile(
                              icon: Icons.diamond_rounded,
                              color: GameColors.crystal,
                              label: 'Crystals',
                              value: '${profile.crystals}',
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: GameColors.panelStrong,
                            borderRadius:
                                BorderRadius.circular(GameSpace.radiusMd),
                            border: Border.all(color: GameColors.border),
                          ),
                          child: Row(
                            children: <Widget>[
                              Icon(
                                profile.isCampaignComplete
                                    ? Icons.workspace_premium_rounded
                                    : Icons.insights_rounded,
                                color: profile.isCampaignComplete
                                    ? GameColors.gold
                                    : GameColors.accentBright,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  profile.isCampaignComplete
                                      ? 'Campaign complete. Replay levels to perfect your star rating.'
                                      : 'Clear campaign levels and survive longer to raise these records.',
                                  style: const TextStyle(
                                    color: GameColors.muted,
                                    fontSize: 12,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _formatDuration(int seconds) {
    final int m = seconds ~/ 60;
    final int s = seconds % 60;
    if (m == 0) {
      return '${s}s';
    }
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 232,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[color.withValues(alpha: 0.10), GameColors.panel],
        ),
        borderRadius: BorderRadius.circular(GameSpace.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(GameSpace.radiusSm),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    color: GameColors.muted,
                    fontSize: 8.5,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
