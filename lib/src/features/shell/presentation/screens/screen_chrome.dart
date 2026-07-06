import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../game/domain/models.dart';
import '../game_theme.dart';

/// ===========================================================================
/// Shared tactical chrome: background, panels, headers, buttons and badges.
/// Every menu screen is composed from these so the game has one coherent,
/// production-grade look. Legacy helper functions are kept (re-skinned) so
/// existing call sites keep compiling.
/// ===========================================================================

// ---------------------------------------------------------------------------
// Animated tactical backdrop
// ---------------------------------------------------------------------------

/// A living command backdrop: a breathing blueprint grid, parallax glows that
/// drift, a soft eased scan sweep, and a field of gently twinkling data-motes.
/// All motion is built from integer-frequency sine/cosine so the loop is
/// perfectly seamless. Cheap enough for menu screens (the game screen draws the
/// native board instead).
class TacticalBackground extends StatefulWidget {
  const TacticalBackground({this.child, super.key});

  final Widget? child;

  @override
  State<TacticalBackground> createState() => _TacticalBackgroundState();
}

class _TacticalBackgroundState extends State<TacticalBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Mote> _motes;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 26),
    )..repeat();

    final math.Random rng = math.Random(7);
    const List<Color> palette = <Color>[
      GameColors.accent,
      GameColors.accentBright,
      GameColors.success,
      GameColors.gold,
    ];
    _motes = List<_Mote>.generate(38, (int i) {
      return _Mote(
        x: rng.nextDouble(),
        y: rng.nextDouble(),
        ax: 0.015 + rng.nextDouble() * 0.05,
        ay: 0.015 + rng.nextDouble() * 0.05,
        r: 0.7 + rng.nextDouble() * 1.9,
        a0: 0.10 + rng.nextDouble() * 0.30,
        phx: rng.nextDouble(),
        phy: rng.nextDouble(),
        pht: rng.nextDouble(),
        fx: 1 + rng.nextInt(3),
        fy: 1 + rng.nextInt(3),
        ft: 1 + rng.nextInt(3),
        color: palette[rng.nextInt(palette.length)],
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: GameGradients.screen),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          return CustomPaint(
            painter: _TacticalGridPainter(t: _controller.value, motes: _motes),
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}

class _Mote {
  const _Mote({
    required this.x,
    required this.y,
    required this.ax,
    required this.ay,
    required this.r,
    required this.a0,
    required this.phx,
    required this.phy,
    required this.pht,
    required this.fx,
    required this.fy,
    required this.ft,
    required this.color,
  });

  final double x;
  final double y;
  final double ax;
  final double ay;
  final double r;
  final double a0;
  final double phx;
  final double phy;
  final double pht;
  final int fx;
  final int fy;
  final int ft;
  final Color color;
}

class _TacticalGridPainter extends CustomPainter {
  _TacticalGridPainter({required this.t, required this.motes});

  final double t;
  final List<_Mote> motes;

  static const double _tau = math.pi * 2;

  @override
  void paint(Canvas canvas, Size size) {
    // Two large parallax glows that slowly drift (seamless, freq 1).
    final Offset g1 = Offset(
      size.width * (0.18 + 0.05 * math.sin(_tau * t)),
      size.height * (0.14 + 0.05 * math.cos(_tau * t)),
    );
    _glow(canvas, size, g1, size.width * 0.55,
        GameColors.accent.withValues(alpha: 0.18));

    final Offset g2 = Offset(
      size.width * (0.86 + 0.05 * math.cos(_tau * t)),
      size.height * (0.9 + 0.05 * math.sin(_tau * t)),
    );
    _glow(canvas, size, g2, size.width * 0.5,
        GameColors.success.withValues(alpha: 0.10));

    // Breathing blueprint grid.
    const double cell = 46;
    final double gridAlpha = 0.6 + 0.4 * math.sin(_tau * t);
    final Paint line = Paint()
      ..color = GameColors.grid.withValues(
        alpha: (GameColors.grid.a) * gridAlpha,
      )
      ..strokeWidth = 1;
    for (double x = 0; x <= size.width; x += cell) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
    for (double y = 0; y <= size.height; y += cell) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }

    // Drifting, twinkling data-motes.
    final Paint motePaint = Paint();
    for (final _Mote m in motes) {
      final double mx =
          (m.x + m.ax * math.sin(_tau * (m.fx * t + m.phx))) * size.width;
      final double my =
          (m.y + m.ay * math.cos(_tau * (m.fy * t + m.phy))) * size.height;
      final double tw = 0.55 + 0.45 * math.sin(_tau * (m.ft * t + m.pht));
      motePaint.color = m.color.withValues(alpha: m.a0 * tw);
      canvas.drawCircle(Offset(mx, my), m.r, motePaint);
    }

    // Soft eased scan sweep (top -> bottom -> top, seamless).
    final double sweepY = size.height * (0.5 - 0.5 * math.cos(_tau * t));
    final Paint scan = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Colors.transparent,
          GameColors.accent.withValues(alpha: 0.08),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, sweepY - 70, size.width, 140));
    canvas.drawRect(Rect.fromLTWH(0, sweepY - 70, size.width, 140), scan);
  }

  void _glow(Canvas canvas, Size size, Offset center, double radius, Color c) {
    final Paint p = Paint()
      ..shader = RadialGradient(
        colors: <Color>[c, Colors.transparent],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawRect(Offset.zero & size, p);
  }

  @override
  bool shouldRepaint(_TacticalGridPainter oldDelegate) => oldDelegate.t != t;
}

// ---------------------------------------------------------------------------
// Motion primitives
// ---------------------------------------------------------------------------

/// Wraps a tappable child with springy press physics: it dips and dims while
/// held, then snaps back. Gives every control a tactile, alive feel.
class PressableScale extends StatefulWidget {
  const PressableScale({
    required this.child,
    this.onTap,
    this.pressedScale = 0.95,
    this.enabled = true,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;
  final bool enabled;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) {
      setState(() => _down = v);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool active = widget.enabled && widget.onTap != null;
    return GestureDetector(
      onTapDown: active ? (_) => _set(true) : null,
      onTapUp: active ? (_) => _set(false) : null,
      onTapCancel: active ? () => _set(false) : null,
      onTap: active ? widget.onTap : null,
      child: AnimatedScale(
        scale: _down ? widget.pressedScale : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: _down ? 0.85 : 1.0,
          duration: const Duration(milliseconds: 110),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Fades + rises its child in once, staggered by [index], so lists and panels
/// assemble themselves instead of snapping into place.
class Entrance extends StatefulWidget {
  const Entrance({
    required this.child,
    this.index = 0,
    this.offset = 18,
    this.duration = const Duration(milliseconds: 460),
    this.baseDelay = const Duration(milliseconds: 40),
    this.stagger = const Duration(milliseconds: 55),
    super.key,
  });

  final Widget child;
  final int index;
  final double offset;
  final Duration duration;
  final Duration baseDelay;
  final Duration stagger;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _anim = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    final int ms = widget.baseDelay.inMilliseconds +
        widget.index * widget.stagger.inMilliseconds;
    Future<void>.delayed(Duration(milliseconds: ms), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (BuildContext context, Widget? child) {
        return Opacity(
          opacity: _anim.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - _anim.value) * widget.offset),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

// ---------------------------------------------------------------------------
// Building blocks
// ---------------------------------------------------------------------------

/// A frosted command panel with a crisp border and depth shadow.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(GameSpace.lg),
    this.radius = GameSpace.radiusLg,
    this.borderColor,
    this.glow = false,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? borderColor;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final Color resolved = borderColor ?? GameColors.borderStrong;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: GameGradients.panel,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: resolved),
        boxShadow: <BoxShadow>[
          const BoxShadow(
            color: Color(0x80000000),
            blurRadius: 26,
            offset: Offset(0, 16),
          ),
          if (glow)
            BoxShadow(
              color: resolved.withValues(alpha: 0.35),
              blurRadius: 24,
              spreadRadius: -6,
            ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Eyebrow + title header with an optional back button and trailing widget.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    required this.eyebrow,
    required this.title,
    this.onBack,
    this.trailing,
    this.titleSize = 20,
    super.key,
  });

  final String eyebrow;
  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;
  final double titleSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        if (onBack != null) ...<Widget>[
          _BackButton(onTap: onBack!),
          const SizedBox(width: GameSpace.md),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 12,
                    height: 2,
                    color: GameColors.accent,
                    margin: const EdgeInsets.only(right: 6, bottom: 3),
                  ),
                  Text(eyebrow, style: kEyebrowStyle),
                ],
              ),
              Text(
                title,
                style: TextStyle(
                  fontSize: titleSize,
                  fontWeight: FontWeight.w800,
                  height: 1.05,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: GameColors.panelSoft,
      borderRadius: BorderRadius.circular(GameSpace.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(GameSpace.radiusMd),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(GameSpace.radiusMd),
            border: Border.all(color: GameColors.borderStrong),
          ),
          child: const Icon(Icons.arrow_back_rounded, size: 18),
        ),
      ),
    );
  }
}

enum TacticalButtonVariant { primary, secondary, ghost, danger }

/// The single button used across menus, with a few intent-driven variants.
class TacticalButton extends StatelessWidget {
  const TacticalButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = TacticalButtonVariant.secondary,
    this.expand = true,
    this.dense = false,
    super.key,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final TacticalButtonVariant variant;
  final bool expand;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    late Color bg;
    late Color fg;
    late Color border;
    Gradient? gradient;
    switch (variant) {
      case TacticalButtonVariant.primary:
        gradient = GameGradients.accent(GameColors.accent);
        bg = GameColors.accent;
        fg = const Color(0xFF04121F);
        border = GameColors.accentBright;
        break;
      case TacticalButtonVariant.secondary:
        bg = GameColors.panelSoft;
        fg = GameColors.text;
        border = GameColors.borderStrong;
        break;
      case TacticalButtonVariant.ghost:
        bg = Colors.transparent;
        fg = GameColors.accentBright;
        border = GameColors.border;
        break;
      case TacticalButtonVariant.danger:
        bg = GameColors.danger.withValues(alpha: 0.16);
        fg = GameColors.danger;
        border = GameColors.danger.withValues(alpha: 0.6);
        break;
    }

    final Widget content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (icon != null) ...<Widget>[
          Icon(icon, size: dense ? 16 : 19, color: fg),
          SizedBox(width: dense ? 6 : 9),
        ],
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: fg,
              fontSize: dense ? 12 : 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ],
    );

    return PressableScale(
      enabled: enabled,
      onTap: onPressed,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Container(
          decoration: BoxDecoration(
            gradient: gradient,
            color: gradient == null ? bg : null,
            borderRadius: BorderRadius.circular(GameSpace.radiusMd),
            border: Border.all(color: border, width: 1.2),
            boxShadow: gradient != null
                ? <BoxShadow>[
                    BoxShadow(
                      color: GameColors.accent.withValues(alpha: 0.45),
                      blurRadius: 16,
                      spreadRadius: -4,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: dense ? 12 : 18,
              vertical: dense ? 9 : 14,
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}

/// A compact resource readout: icon + value, used for cash, stars, crystals.
class ResourceBadge extends StatelessWidget {
  const ResourceBadge({
    required this.icon,
    required this.color,
    required this.label,
    this.dense = false,
    super.key,
  });

  final IconData icon;
  final Color color;
  final String label;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 9 : 11,
        vertical: dense ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: GameColors.panelStrong,
        borderRadius: BorderRadius.circular(GameSpace.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: color, size: dense ? 15 : 17),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: dense ? 12 : 13,
              color: GameColors.text,
            ),
          ),
        ],
      ),
    );
  }
}

/// A row of star pips (filled/outline), used by the campaign + victory UI.
class StarRow extends StatelessWidget {
  const StarRow({required this.stars, this.size = 16, this.gap = 1, super.key});

  final int stars;
  final double size;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 1; i <= 3; i++)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: gap),
            child: Icon(
              i <= stars ? Icons.star_rounded : Icons.star_outline_rounded,
              size: size,
              color: i <= stars ? GameColors.gold : GameColors.faint,
            ),
          ),
      ],
    );
  }
}

/// Small uppercase section divider label.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: <Widget>[
          Text(
            text,
            style: const TextStyle(
              color: GameColors.muted,
              fontSize: 10,
              letterSpacing: 2.0,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Divider(color: GameColors.border, height: 1)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mechanic-driven helpers (shared by store, intel, shop)
// ---------------------------------------------------------------------------

String damageTypeLabel(DamageType type) {
  switch (type) {
    case DamageType.physical:
      return 'Kinetic';
    case DamageType.energy:
      return 'Energy';
    case DamageType.explosion:
      return 'Explosive';
    case DamageType.poison:
      return 'Toxin';
    case DamageType.slow:
      return 'Control';
    case DamageType.piercing:
      return 'Piercing';
    case DamageType.regen:
      return 'Regen';
  }
}

IconData towerKindIcon(TowerKind kind) {
  return switch (kind) {
    TowerKind.gun || TowerKind.machineGun => Icons.radio_button_checked,
    TowerKind.gatling || TowerKind.vulcanCiws => Icons.cyclone_rounded,
    TowerKind.laser || TowerKind.beamEmitter => Icons.bolt_rounded,
    TowerKind.slow || TowerKind.poison => Icons.ac_unit_rounded,
    TowerKind.sniper || TowerKind.railgun => Icons.gps_fixed_rounded,
    TowerKind.rocket || TowerKind.missileSilo => Icons.rocket_launch_rounded,
    TowerKind.mortar || TowerKind.siegeHowitzer => Icons.arrow_outward_rounded,
    TowerKind.interceptor || TowerKind.aegisBattery => Icons.travel_explore_rounded,
    TowerKind.bomb || TowerKind.clusterBomb => Icons.blur_on_rounded,
    TowerKind.tesla || TowerKind.plasma => Icons.offline_bolt_rounded,
  };
}

String difficultyLabel(Difficulty difficulty) {
  switch (difficulty) {
    case Difficulty.relaxed:
      return 'Relaxed';
    case Difficulty.normal:
      return 'Normal';
    case Difficulty.hard:
      return 'Hard';
  }
}

Color difficultyColor(Difficulty difficulty) {
  switch (difficulty) {
    case Difficulty.relaxed:
      return GameColors.success;
    case Difficulty.normal:
      return GameColors.accent;
    case Difficulty.hard:
      return GameColors.danger;
  }
}

// ---------------------------------------------------------------------------
// Legacy compatibility helpers (re-skinned to the new system)
// ---------------------------------------------------------------------------

BoxDecoration screenBackgroundDecoration() {
  return const BoxDecoration(gradient: GameGradients.screen);
}

BoxDecoration solidScreenCardDecoration() {
  return BoxDecoration(
    gradient: GameGradients.panel,
    borderRadius: BorderRadius.circular(GameSpace.radiusLg),
    border: Border.all(color: GameColors.borderStrong),
    boxShadow: const <BoxShadow>[
      BoxShadow(color: Color(0x80000000), blurRadius: 26, offset: Offset(0, 16)),
    ],
  );
}

Widget screenActionButton({
  required bool compact,
  required IconData icon,
  required String label,
  required VoidCallback onPressed,
  bool primary = false,
}) {
  return TacticalButton(
    label: label,
    icon: icon,
    onPressed: onPressed,
    dense: compact,
    variant: primary
        ? TacticalButtonVariant.primary
        : TacticalButtonVariant.secondary,
  );
}

Widget screenDropdownField<T>({
  required String label,
  required T initialValue,
  required List<DropdownMenuItem<T>> items,
  required ValueChanged<T?> onChanged,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: GameColors.muted,
          fontSize: 10,
          letterSpacing: 1.6,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 6),
      DropdownButtonFormField<T>(
        initialValue: initialValue,
        items: items,
        onChanged: onChanged,
        borderRadius: BorderRadius.circular(GameSpace.radiusMd),
        dropdownColor: GameColors.panelStrong,
        decoration: const InputDecoration(isDense: true),
      ),
    ],
  );
}

/// Decorative HUD-style corner ticks for hero panels.
class CornerTicks extends StatelessWidget {
  const CornerTicks({required this.child, this.color, super.key});

  final Widget child;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _CornerTickPainter(color ?? GameColors.accent),
      child: child,
    );
  }
}

class _CornerTickPainter extends CustomPainter {
  _CornerTickPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    const double len = 14;
    const double inset = 6;
    // top-left
    canvas.drawLine(const Offset(inset, inset),
        const Offset(inset + len, inset), p);
    canvas.drawLine(const Offset(inset, inset),
        const Offset(inset, inset + len), p);
    // top-right
    canvas.drawLine(Offset(size.width - inset, inset),
        Offset(size.width - inset - len, inset), p);
    canvas.drawLine(Offset(size.width - inset, inset),
        Offset(size.width - inset, inset + len), p);
    // bottom-left
    canvas.drawLine(Offset(inset, size.height - inset),
        Offset(inset + len, size.height - inset), p);
    canvas.drawLine(Offset(inset, size.height - inset),
        Offset(inset, size.height - inset - len), p);
    // bottom-right
    canvas.drawLine(Offset(size.width - inset, size.height - inset),
        Offset(size.width - inset - len, size.height - inset), p);
    canvas.drawLine(Offset(size.width - inset, size.height - inset),
        Offset(size.width - inset, size.height - inset - len), p);
  }

  @override
  bool shouldRepaint(_CornerTickPainter oldDelegate) =>
      oldDelegate.color != color;
}

double clampDoubleValue(double value, double lower, double upper) {
  return math.min(math.max(value, lower), upper);
}
