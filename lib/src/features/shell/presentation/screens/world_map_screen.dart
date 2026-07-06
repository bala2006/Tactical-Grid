import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../game/domain/content.dart' show mapLabels;
import '../../../progression/domain/campaign.dart';
import '../../../progression/domain/profile.dart';
import '../game_theme.dart';
import 'screen_chrome.dart';

/// Deployment saga: the campaign as one continuous winding trail that flows
/// left → right (no regions, no four-level blocks). Mission nodes ride a
/// meandering rope path; the trail "fills in" as missions are cleared, the
/// difficulty heats the colour up the climb, Elite Ops stand out as milestones,
/// and the current objective pulses.
class WorldMapScreen extends StatelessWidget {
  const WorldMapScreen({
    required this.profileListenable,
    required this.onBack,
    required this.onSelectLevel,
    required this.onEndless,
    required this.onShop,
    super.key,
  });

  final ValueListenable<PlayerProfile> profileListenable;
  final VoidCallback onBack;
  final Future<void> Function(CampaignLevel level) onSelectLevel;
  final VoidCallback onEndless;
  final VoidCallback onShop;

  @override
  Widget build(BuildContext context) {
    return TacticalBackground(
      key: const ValueKey<String>('world'),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(GameSpace.sm),
          child: ValueListenableBuilder<PlayerProfile>(
            valueListenable: profileListenable,
            builder: (BuildContext context, PlayerProfile profile, _) {
              final double progress =
                  profile.totalStars / (Campaign.levelCount * 3);

              String? currentId;
              for (final CampaignLevel level in Campaign.missions) {
                if (profile.isLevelUnlocked(level.id) &&
                    profile.starsFor(level.id) == 0) {
                  currentId = level.id;
                  break;
                }
              }

              return GlassPanel(
                padding: const EdgeInsets.fromLTRB(14, 12, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    ScreenHeader(
                      eyebrow: 'CAMPAIGN',
                      title: 'Deployment',
                      titleSize: 19,
                      onBack: onBack,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          ResourceBadge(
                            icon: Icons.star_rounded,
                            color: GameColors.gold,
                            label:
                                '${profile.totalStars}/${Campaign.levelCount * 3}',
                            dense: true,
                          ),
                          const SizedBox(width: 6),
                          ResourceBadge(
                            icon: Icons.diamond_rounded,
                            color: GameColors.crystal,
                            label: '${profile.crystals}',
                            dense: true,
                          ),
                          const SizedBox(width: 10),
                          TacticalButton(
                            label: 'Armory',
                            icon: Icons.storefront_rounded,
                            dense: true,
                            expand: false,
                            onPressed: onShop,
                          ),
                          const SizedBox(width: 6),
                          TacticalButton(
                            label: 'Endless',
                            icon: Icons.all_inclusive_rounded,
                            dense: true,
                            expand: false,
                            variant: TacticalButtonVariant.ghost,
                            onPressed: onEndless,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 11),
                    _ProgressStrip(
                      progress: progress,
                      cleared: profile.levelsCleared,
                      total: Campaign.levelCount,
                    ),
                    const SizedBox(height: 10),
                    const Divider(color: GameColors.border, height: 1),
                    const SizedBox(height: 4),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(GameSpace.radiusMd),
                        child: _SagaTrail(
                          profile: profile,
                          currentId: currentId,
                          onSelectLevel: onSelectLevel,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ProgressStrip extends StatelessWidget {
  const _ProgressStrip({
    required this.progress,
    required this.cleared,
    required this.total,
  });
  final double progress;
  final int cleared;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Text(
              'MISSIONS CLEARED',
              style: TextStyle(
                color: GameColors.muted,
                fontSize: 9,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$cleared/$total',
              style: const TextStyle(
                color: GameColors.text,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            Text(
              '${(progress * 100).round()}%',
              style: const TextStyle(
                color: GameColors.gold,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress.clamp(0, 1),
            minHeight: 6,
            backgroundColor: GameColors.panelStrong,
            valueColor: const AlwaysStoppedAnimation<Color>(GameColors.gold),
          ),
        ),
      ],
    );
  }
}

Color _missionAccent(CampaignLevel level) {
  if (level.isElite) {
    return GameColors.gold;
  }
  return difficultyColor(level.difficulty);
}

/// The horizontally-scrolling winding trail of mission nodes.
class _SagaTrail extends StatelessWidget {
  const _SagaTrail({
    required this.profile,
    required this.currentId,
    required this.onSelectLevel,
  });

  final PlayerProfile profile;
  final String? currentId;
  final Future<void> Function(CampaignLevel level) onSelectLevel;

  static const double _stepX = 156;
  static const double _padX = 78;
  static const double _nodeBoxWidth = 132;

  @override
  Widget build(BuildContext context) {
    final List<CampaignLevel> missions = Campaign.missions;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double h = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 260;
        final double centerY = h * 0.40;
        final double amplitude = math.min(h * 0.22, 84);
        final double width = _padX * 2 + _stepX * (missions.length - 1);

        // Node anchor points along a left→right sine wave.
        final List<Offset> points = <Offset>[
          for (int i = 0; i < missions.length; i++)
            Offset(
              _padX + _stepX * i,
              centerY - amplitude * math.sin(i * 0.8 + 0.4),
            ),
        ];
        final List<bool> segmentActive = <bool>[
          for (int i = 0; i < missions.length - 1; i++)
            profile.starsFor(missions[i].id) > 0,
        ];

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: width,
            height: h,
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Positioned.fill(
                  child: CustomPaint(
                    painter: _TrailPainter(
                      points: points,
                      segmentActive: segmentActive,
                    ),
                  ),
                ),
                for (int i = 0; i < missions.length; i++)
                  Positioned(
                    left: points[i].dx - _nodeBoxWidth / 2,
                    top: points[i].dy - (missions[i].isElite ? 24 : 21),
                    width: _nodeBoxWidth,
                    child: _TrailNode(
                      level: missions[i],
                      stars: profile.starsFor(missions[i].id),
                      unlocked: profile.isLevelUnlocked(missions[i].id),
                      isCurrent: missions[i].id == currentId,
                      onSelectLevel: onSelectLevel,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Paints the meandering rope path: solid where cleared, dashed ahead.
class _TrailPainter extends CustomPainter {
  _TrailPainter({required this.points, required this.segmentActive});

  final List<Offset> points;
  final List<bool> segmentActive;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) {
      return;
    }
    final Paint solid = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..color = GameColors.accentBright;
    final Paint solidGlow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.round
      ..color = GameColors.accent.withValues(alpha: 0.18);
    final Paint dashed = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = GameColors.borderStrong;

    for (int i = 0; i < points.length - 1; i++) {
      final Offset p0 = points[i];
      final Offset p1 = points[i + 1];
      final double dx = p1.dx - p0.dx;
      final Path segment = Path()
        ..moveTo(p0.dx, p0.dy)
        ..cubicTo(
          p0.dx + dx * 0.5,
          p0.dy,
          p1.dx - dx * 0.5,
          p1.dy,
          p1.dx,
          p1.dy,
        );
      if (segmentActive[i]) {
        canvas.drawPath(segment, solidGlow);
        canvas.drawPath(segment, solid);
      } else {
        _drawDashed(canvas, segment, dashed);
      }
    }
  }

  void _drawDashed(
    Canvas canvas,
    Path path,
    Paint paint, {
    double dash = 11,
    double gap = 8,
  }) {
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final double next = distance + dash;
        canvas.drawPath(
          metric.extractPath(distance, math.min(next, metric.length)),
          paint,
        );
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_TrailPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.segmentActive != segmentActive;
}

/// A single station on the trail: a node circle with a compact label beneath,
/// pulsing when it is the current objective.
class _TrailNode extends StatefulWidget {
  const _TrailNode({
    required this.level,
    required this.stars,
    required this.unlocked,
    required this.isCurrent,
    required this.onSelectLevel,
  });

  final CampaignLevel level;
  final int stars;
  final bool unlocked;
  final bool isCurrent;
  final Future<void> Function(CampaignLevel level) onSelectLevel;

  @override
  State<_TrailNode> createState() => _TrailNodeState();
}

class _TrailNodeState extends State<_TrailNode>
    with SingleTickerProviderStateMixin {
  AnimationController? _pulse;

  @override
  void initState() {
    super.initState();
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant _TrailNode oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCurrent != oldWidget.isCurrent) {
      _syncPulse();
    }
  }

  void _syncPulse() {
    if (widget.isCurrent && _pulse == null) {
      _pulse = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1300),
      )..repeat(reverse: true);
    } else if (!widget.isCurrent && _pulse != null) {
      _pulse!.dispose();
      _pulse = null;
    }
  }

  @override
  void dispose() {
    _pulse?.dispose();
    super.dispose();
  }

  void _deploy() {
    if (widget.unlocked) {
      widget.onSelectLevel(widget.level);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = _missionAccent(widget.level);
    final String mapLabel = mapLabels[widget.level.mapId] ?? widget.level.mapId;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _circle(accent),
        const SizedBox(height: 5),
        Text(
          widget.level.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 11,
            color: widget.unlocked ? GameColors.text : GameColors.faint,
          ),
        ),
        Text(
          '${widget.level.totalWaves}w · $mapLabel',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: GameColors.muted,
            fontSize: 8.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        if (!widget.unlocked)
          const Icon(Icons.lock_rounded, size: 13, color: GameColors.faint)
        else if (widget.stars > 0) ...<Widget>[
          StarRow(stars: widget.stars, size: 12),
          const SizedBox(height: 4),
          _DeployButton(label: 'REPLAY', primary: false, onTap: _deploy),
        ] else
          _DeployButton(label: 'DEPLOY', primary: true, onTap: _deploy),
      ],
    );
  }

  Widget _circle(Color accent) {
    final bool locked = !widget.unlocked;
    final bool cleared = widget.stars > 0;
    final bool perfect = widget.stars >= 3;
    final bool elite = widget.level.isElite;
    final double size = elite ? 48 : 42;
    final Color ring = locked
        ? GameColors.border
        : (widget.isCurrent ? GameColors.accentBright : accent);

    Widget core = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: locked ? GameColors.panelStrong : null,
        gradient: locked
            ? null
            : RadialGradient(
                colors: <Color>[
                  Color.lerp(accent, Colors.white, cleared ? 0.25 : 0.0)!,
                  Color.lerp(accent, GameColors.panel, cleared ? 0.45 : 0.78)!,
                ],
              ),
        border: Border.all(color: ring, width: widget.isCurrent ? 3 : 2.4),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: locked
          ? const Icon(Icons.lock_rounded, size: 17, color: GameColors.faint)
          : (elite
                ? Icon(
                    perfect
                        ? Icons.military_tech_rounded
                        : Icons.shield_rounded,
                    size: 24,
                    color: perfect ? GameColors.gold : Colors.white,
                  )
                : (perfect
                      ? const Icon(Icons.star_rounded,
                          size: 22, color: GameColors.gold)
                      : Text(
                          '${widget.level.order + 1}',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                            color: cleared ? Colors.white : GameColors.text,
                          ),
                        ))),
    );

    if (widget.isCurrent && _pulse != null) {
      core = AnimatedBuilder(
        animation: _pulse!,
        builder: (BuildContext context, Widget? child) {
          final double t = _pulse!.value;
          return DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: GameColors.accentBright
                      .withValues(alpha: 0.22 + 0.4 * t),
                  blurRadius: 10 + 14 * t,
                  spreadRadius: 1 + 3 * t,
                ),
              ],
            ),
            child: child,
          );
        },
        child: core,
      );
    }

    return core;
  }
}

class _DeployButton extends StatelessWidget {
  const _DeployButton({
    required this.label,
    required this.primary,
    required this.onTap,
  });

  final String label;
  final bool primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color fg = primary ? const Color(0xFF04121F) : GameColors.accentBright;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Ink(
          decoration: BoxDecoration(
            gradient: primary ? GameGradients.accent(GameColors.accent) : null,
            color: primary ? null : GameColors.panelStrong,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: primary
                  ? GameColors.accentBright
                  : GameColors.accentBright.withValues(alpha: 0.5),
            ),
            boxShadow: primary
                ? <BoxShadow>[
                    BoxShadow(
                      color: GameColors.accent.withValues(alpha: 0.5),
                      blurRadius: 8,
                      spreadRadius: -2,
                    ),
                  ]
                : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                primary
                    ? Icons.play_arrow_rounded
                    : Icons.refresh_rounded,
                size: 13,
                color: fg,
              ),
              const SizedBox(width: 3),
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontSize: 9,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
