import 'dart:async';

import 'package:flutter/material.dart';

import '../../../game/application/controller.dart';
import '../../../game/presentation/native_game_board.dart';
import '../../../game/domain/models.dart';
import '../../../progression/application/progression_controller.dart';
import '../../../progression/domain/campaign.dart';
import '../../../progression/domain/objectives.dart';
import '../game_theme.dart';
import 'screen_chrome.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({
    required this.controller,
    required this.onBackToMap,
    required this.onWorldMap,
    required this.onShowIntel,
    super.key,
  });

  final GameController controller;
  final VoidCallback onBackToMap;
  final VoidCallback onWorldMap;
  final VoidCallback onShowIntel;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  Future<void> _showTimedTowerDialog({
    required AppUiState state,
    required bool enabled,
    required String title,
    required String confirmLabel,
    required Widget content,
    required Future<void> Function() onConfirm,
  }) async {
    if (!enabled || state.selectionInfo == null || state.defeat) {
      return;
    }
    final bool autoPaused = !state.isPaused;
    if (autoPaused) {
      widget.controller.togglePause();
    }
    if (!mounted) {
      return;
    }
    bool confirmed = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return _TimedDecisionDialog(
          title: title,
          confirmLabel: confirmLabel,
          content: content,
          onConfirm: () async {
            confirmed = true;
            await onConfirm();
          },
        );
      },
    );
    if (autoPaused && mounted && widget.controller.uiState.isPaused) {
      widget.controller.togglePause();
    }
    if (confirmed) {
      setState(() {});
    }
  }

  Future<void> _showUpgradeDialog(AppUiState state) async {
    final SelectionInfo? info = state.selectionInfo;
    if (info == null) {
      return;
    }
    final String compactDelta = info.upgradeDelta
        .replaceAll('damage ', 'DMG ')
        .replaceAll('range ', 'RNG ')
        .replaceAll('cooldown ', 'CD ');
    await _showTimedTowerDialog(
      state: state,
      enabled: info.canUpgrade,
      title: 'Upgrade Turret',
      confirmLabel: 'Upgrade',
      onConfirm: () async {
        widget.controller.upgradeSelectedTower();
      },
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            info.title,
            style: TextStyle(
              color: info.titleColor,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          _UpgradeRow(
            label: 'DMG',
            from: info.damage,
            to: _extractUpgradeValue(compactDelta, 'DMG', info.damage),
          ),
          _UpgradeRow(
            label: 'RNG',
            from: info.range.toStringAsFixed(1),
            to: _extractUpgradeValue(
              compactDelta,
              'RNG',
              info.range.toStringAsFixed(1),
            ),
          ),
          _UpgradeRow(
            label: 'CD',
            from: '${info.cooldownSeconds.toStringAsFixed(2)}s',
            to: _extractUpgradeValue(
              compactDelta,
              'CD',
              '${info.cooldownSeconds.toStringAsFixed(2)}s',
            ),
          ),
          const SizedBox(height: 12),
          _CostRow(
            label: 'Upgrade cost',
            value: '\$${info.upgradePrice?.toStringAsFixed(0) ?? 'N/A'}',
          ),
        ],
      ),
    );
  }

  Future<void> _showSellDialog(AppUiState state) async {
    final SelectionInfo? info = state.selectionInfo;
    if (info == null) {
      return;
    }
    await _showTimedTowerDialog(
      state: state,
      enabled: info.canSell,
      title: 'Sell Turret',
      confirmLabel: 'Sell',
      onConfirm: () async {
        widget.controller.sellSelectedTower();
      },
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            info.title,
            style: TextStyle(
              color: info.titleColor,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          _CostRow(
            label: 'Total invested',
            value: '\$${info.cost.toStringAsFixed(0)}',
            muted: true,
          ),
          _CostRow(
            label: 'Sell return',
            value: '\$${info.sellPrice.toStringAsFixed(0)}',
          ),
          const SizedBox(height: 8),
          const Text(
            'Selling refunds 75% of the total build + upgrade cost.',
            style: TextStyle(color: GameColors.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.sizeOf(context);
    final double railWidth = (screenSize.width * 0.09).clamp(78.0, 98.0);
    return Container(
      key: const ValueKey<String>('game'),
      decoration: const BoxDecoration(gradient: GameGradients.screen),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SizedBox(
                width: railWidth,
                child: _TowerRail(
                  controller: widget.controller,
                  onBackToMap: widget.onBackToMap,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  children: <Widget>[
                    ValueListenableBuilder<AppUiState>(
                      valueListenable: widget.controller.uiStateListenable,
                      builder: (BuildContext context, AppUiState state, _) {
                        return _TopBar(
                          state: state,
                          onUpgrade: state.selectionInfo?.canUpgrade == true
                              ? () => _showUpgradeDialog(state)
                              : null,
                          onSell: state.selectionInfo?.canSell == true
                              ? () => _showSellDialog(state)
                              : null,
                          onPause: widget.controller.togglePause,
                          onIntel: widget.onShowIntel,
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Stack(
                        children: <Widget>[
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(
                                GameSpace.radiusLg,
                              ),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: GameColors.borderStrong,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    GameSpace.radiusLg,
                                  ),
                                ),
                                child: const ColoredBox(
                                  color: GameColors.background,
                                  child: NativeGameBoard(),
                                ),
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: ValueListenableBuilder<AppUiState>(
                              valueListenable:
                                  widget.controller.uiStateListenable,
                              builder:
                                  (BuildContext context, AppUiState state, _) {
                                    return Stack(
                                      children: <Widget>[
                                        if (widget
                                            .controller
                                            .isNativeBoardEnabled)
                                          _NativePlacementOverlay(
                                            state: state,
                                            onCancel: widget
                                                .controller
                                                .cancelPlacement,
                                            onPlace: widget
                                                .controller
                                                .confirmPendingPlacement,
                                          ),
                                        if (state.totalWaves > 0 &&
                                            state.wave >= state.totalWaves &&
                                            !state.defeat &&
                                            !state.victory)
                                          const Positioned(
                                            top: 10,
                                            left: 0,
                                            right: 0,
                                            child: Center(child: _BossBanner()),
                                          ),
                                        if (state.defeat)
                                          _OverlayScrim(
                                            child: _DefeatCard(
                                              controller: widget.controller,
                                              state: state,
                                            ),
                                          ),
                                        if (state.victory)
                                          _OverlayScrim(
                                            child: _VictoryCard(
                                              controller: widget.controller,
                                              state: state,
                                              onWorldMap: widget.onWorldMap,
                                            ),
                                          ),
                                      ],
                                    );
                                  },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverlayScrim extends StatelessWidget {
  const _OverlayScrim({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0xB3040810),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(14),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Top HUD bar
// ---------------------------------------------------------------------------

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.state,
    required this.onUpgrade,
    required this.onSell,
    required this.onPause,
    required this.onIntel,
  });

  final AppUiState state;
  final VoidCallback? onUpgrade;
  final VoidCallback? onSell;
  final VoidCallback onPause;
  final VoidCallback onIntel;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: GameGradients.panel,
        borderRadius: BorderRadius.circular(GameSpace.radiusMd),
        border: Border.all(color: GameColors.borderStrong),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x66000000), blurRadius: 16, offset: Offset(0, 8)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          children: <Widget>[
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: <Widget>[
                    _HealthReadout(
                      health: state.health,
                      maxHealth: state.maxHealth,
                    ),
                    const _Sep(),
                    _StatReadout(
                      icon: Icons.attach_money_rounded,
                      color: GameColors.cash,
                      value: '${state.cash}',
                    ),
                    const _Sep(),
                    _StatReadout(
                      icon: Icons.waves_rounded,
                      color: GameColors.accentBright,
                      value: state.totalWaves > 0
                          ? '${state.wave}/${state.totalWaves}'
                          : '${state.wave}',
                    ),
                    const _Sep(),
                    _StatReadout(
                      icon: Icons.track_changes_rounded,
                      color: GameColors.success,
                      value: '${state.runStats.kills}',
                    ),
                    const SizedBox(width: 10),
                    _WaveStatePill(label: state.waveState),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            _ActionButton(
              icon: Icons.upgrade_rounded,
              tint: GameColors.success,
              onPressed: onUpgrade,
            ),
            const SizedBox(width: 6),
            _ActionButton(
              icon: Icons.sell_rounded,
              tint: GameColors.warning,
              onPressed: onSell,
            ),
            const SizedBox(width: 6),
            _ActionButton(
              icon: state.isPaused
                  ? Icons.play_arrow_rounded
                  : Icons.pause_rounded,
              tint: GameColors.accentBright,
              filled: true,
              onPressed: onPause,
            ),
            const SizedBox(width: 6),
            _ActionButton(
              icon: Icons.info_outline_rounded,
              tint: GameColors.muted,
              onPressed: onIntel,
            ),
          ],
        ),
      ),
    );
  }
}

class _Sep extends StatelessWidget {
  const _Sep();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 16,
      margin: const EdgeInsets.symmetric(horizontal: 9),
      color: GameColors.border,
    );
  }
}

class _StatReadout extends StatelessWidget {
  const _StatReadout({
    required this.icon,
    required this.color,
    required this.value,
  });
  final IconData icon;
  final Color color;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _HealthReadout extends StatelessWidget {
  const _HealthReadout({required this.health, required this.maxHealth});
  final int health;
  final int maxHealth;

  @override
  Widget build(BuildContext context) {
    final double frac = maxHealth <= 0
        ? 0
        : (health / maxHealth).clamp(0.0, 1.0);
    final Color color = frac > 0.5
        ? GameColors.health
        : (frac > 0.25 ? GameColors.warning : GameColors.danger);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(Icons.favorite_rounded, size: 14, color: color),
        const SizedBox(width: 5),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '$health/$maxHealth',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: SizedBox(
                width: 52,
                height: 4,
                child: LinearProgressIndicator(
                  value: frac,
                  backgroundColor: GameColors.panelStrong,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _WaveStatePill extends StatelessWidget {
  const _WaveStatePill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: GameColors.accentSoft,
        borderRadius: BorderRadius.circular(GameSpace.radiusSm),
        border: Border.all(color: GameColors.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: GameColors.accentBright,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.tint,
    required this.onPressed,
    this.filled = false,
  });

  final IconData icon;
  final Color tint;
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Material(
        color: filled ? tint.withValues(alpha: 0.18) : GameColors.panelSoft,
        borderRadius: BorderRadius.circular(GameSpace.radiusSm),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(GameSpace.radiusSm),
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(GameSpace.radiusSm),
              border: Border.all(
                color: enabled
                    ? tint.withValues(alpha: 0.45)
                    : GameColors.border,
              ),
            ),
            child: Icon(icon, size: 17, color: enabled ? tint : GameColors.faint),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Left tower rail / store
// ---------------------------------------------------------------------------

class _TowerRail extends StatelessWidget {
  const _TowerRail({required this.controller, required this.onBackToMap});
  final GameController controller;
  final VoidCallback onBackToMap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Material(
          color: GameColors.panelSoft,
          borderRadius: BorderRadius.circular(GameSpace.radiusMd),
          child: InkWell(
            onTap: onBackToMap,
            borderRadius: BorderRadius.circular(GameSpace.radiusMd),
            child: Container(
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(GameSpace.radiusMd),
                border: Border.all(color: GameColors.borderStrong),
              ),
              child: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.arrow_back_rounded, size: 13),
                    SizedBox(width: 4),
                    Text(
                      'EXIT',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: GameGradients.panel,
              borderRadius: BorderRadius.circular(GameSpace.radiusLg),
              border: Border.all(color: GameColors.borderStrong),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
              child: Column(
                children: <Widget>[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: GameColors.panelStrong,
                      borderRadius: BorderRadius.circular(GameSpace.radiusSm),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(
                          Icons.storefront_rounded,
                          color: GameColors.success,
                          size: 11,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'ARSENAL',
                          style: TextStyle(
                            color: GameColors.muted,
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: ValueListenableBuilder<AppUiState>(
                      valueListenable: controller.uiStateListenable,
                      builder: (BuildContext context, AppUiState state, _) {
                        final bool isPlacing = state.selectionStatus
                            .startsWith('Placing: ');
                        final String? selectedTitle = isPlacing
                            ? state.selectionInfo?.title
                            : null;
                        return ListView.separated(
                          padding: EdgeInsets.zero,
                          itemCount: controller.storeBlueprints.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 6),
                          itemBuilder: (BuildContext context, int index) {
                            final TowerBlueprint blueprint =
                                controller.storeBlueprints[index];
                            return _TowerChip(
                              blueprint: blueprint,
                              selected: selectedTitle == blueprint.title,
                              affordable: state.cash >= blueprint.cost,
                              onTap: () => controller.selectBuildTower(
                                blueprint.kind,
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TowerChip extends StatelessWidget {
  const _TowerChip({
    required this.blueprint,
    required this.selected,
    required this.affordable,
    required this.onTap,
  });

  final TowerBlueprint blueprint;
  final bool selected;
  final bool affordable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color accent = GameColors.forDamageType(blueprint.damageType);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(GameSpace.radiusMd),
        child: Ink(
          decoration: BoxDecoration(
            gradient: selected
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      accent.withValues(alpha: 0.30),
                      GameColors.panelSoft,
                    ],
                  )
                : null,
            color: selected ? null : GameColors.panelSoft,
            borderRadius: BorderRadius.circular(GameSpace.radiusMd),
            border: Border.all(
              color: selected ? accent : GameColors.border,
              width: selected ? 1.6 : 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: selected ? 0.9 : 0.18),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: accent.withValues(alpha: selected ? 1 : 0.5),
                    width: 1.2,
                  ),
                ),
                child: Icon(
                  towerKindIcon(blueprint.kind),
                  color: selected ? const Color(0xFF04121F) : accent,
                  size: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                blueprint.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: GameColors.text,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 1.5,
                ),
                decoration: BoxDecoration(
                  color: affordable
                      ? GameColors.cash.withValues(alpha: 0.16)
                      : GameColors.danger.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '\$${blueprint.cost}',
                  style: TextStyle(
                    color: affordable ? GameColors.cash : GameColors.danger,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _extractUpgradeValue(String delta, String label, String fallback) {
  final RegExpMatch? match = RegExp('$label\\s+([^,]+)').firstMatch(delta);
  return match == null ? fallback : match.group(1)!.trim();
}

// ---------------------------------------------------------------------------
// Dialog content helpers
// ---------------------------------------------------------------------------

class _UpgradeRow extends StatelessWidget {
  const _UpgradeRow({required this.label, required this.from, required this.to});
  final String label;
  final String from;
  final String to;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 34,
            child: Text(
              label,
              style: const TextStyle(
                color: GameColors.muted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(from, style: const TextStyle(fontSize: 11)),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Icon(
              Icons.arrow_forward_rounded,
              size: 12,
              color: GameColors.accentBright,
            ),
          ),
          Text(
            to,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: GameColors.success,
            ),
          ),
        ],
      ),
    );
  }
}

class _CostRow extends StatelessWidget {
  const _CostRow({
    required this.label,
    required this.value,
    this.muted = false,
  });
  final String label;
  final String value;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(color: GameColors.muted, fontSize: 11),
          ),
          Text(
            value,
            style: TextStyle(
              color: muted ? GameColors.text : GameColors.cash,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Defeat / victory cards
// ---------------------------------------------------------------------------

class _DefeatCard extends StatelessWidget {
  const _DefeatCard({required this.controller, required this.state});
  final GameController controller;
  final AppUiState state;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: GlassPanel(
        glow: true,
        borderColor: GameColors.danger.withValues(alpha: 0.6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: GameColors.danger.withValues(alpha: 0.15),
                border: Border.all(
                  color: GameColors.danger.withValues(alpha: 0.6),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.gpp_bad_rounded,
                color: GameColors.danger,
                size: 30,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'GRID OVERRUN',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            _StatGrid(
              entries: <MapEntry<String, String>>[
                MapEntry('Wave', '${state.wave}'),
                MapEntry('Towers', '${state.runStats.built}'),
                MapEntry('Kills', '${state.runStats.kills}'),
                MapEntry('Damage', '${state.runStats.totalDamage.round()}'),
                MapEntry('Leaks', '${state.runStats.leaks}'),
              ],
            ),
            const SizedBox(height: 16),
            TacticalButton(
              label: 'Retry',
              icon: Icons.refresh_rounded,
              variant: TacticalButtonVariant.primary,
              onPressed: () async => controller.restartGame(),
            ),
            const SizedBox(height: 8),
            TacticalButton(
              label: controller.activeLevelId != null
                  ? 'Theatre Map'
                  : 'Battlefields',
              icon: Icons.map_rounded,
              variant: TacticalButtonVariant.ghost,
              onPressed: () => controller.setActiveScreen(
                controller.activeLevelId != null ? 'world' : 'map',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.entries});
  final List<MapEntry<String, String>> entries;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: <Widget>[
        for (final MapEntry<String, String> e in entries)
          Container(
            width: 96,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: GameColors.panelStrong,
              borderRadius: BorderRadius.circular(GameSpace.radiusSm),
              border: Border.all(color: GameColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  e.value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  e.key.toUpperCase(),
                  style: const TextStyle(
                    color: GameColors.muted,
                    fontSize: 8,
                    letterSpacing: 1.0,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _VictoryCard extends StatelessWidget {
  const _VictoryCard({
    required this.controller,
    required this.state,
    required this.onWorldMap,
  });

  final GameController controller;
  final AppUiState state;
  final VoidCallback onWorldMap;

  @override
  Widget build(BuildContext context) {
    final LevelResult? result = controller.lastLevelResult;
    final int stars = state.stars > 0 ? state.stars : (result?.stars ?? 1);
    final String? levelId = controller.activeLevelId;
    final CampaignLevel? current = levelId == null
        ? null
        : Campaign.levelById(levelId);
    final CampaignLevel? next = levelId == null
        ? null
        : Campaign.nextLevel(levelId);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: GlassPanel(
        glow: true,
        borderColor: GameColors.success.withValues(alpha: 0.6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'OBJECTIVE SECURED',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                color: GameColors.success,
              ),
            ),
            if (current != null) ...<Widget>[
              const SizedBox(height: 2),
              Text(
                current.name,
                style: const TextStyle(color: GameColors.muted, fontSize: 12),
              ),
            ],
            const SizedBox(height: 12),
            _AnimatedStars(stars: stars),
            const SizedBox(height: 12),
            if ((result?.crystalsAwarded ?? 0) > 0)
              ResourceBadge(
                icon: Icons.diamond_rounded,
                color: GameColors.crystal,
                label: '+${result!.crystalsAwarded} crystals',
              )
            else
              const Text(
                'No new crystals — beat your best for more',
                style: TextStyle(color: GameColors.muted, fontSize: 11),
              ),
            const SizedBox(height: 10),
            Text(
              'Kills ${state.runStats.kills}   ·   Towers ${state.runStats.built}',
              style: const TextStyle(fontSize: 11, color: GameColors.muted),
            ),
            if ((result?.newObjectives.isNotEmpty ?? false)) ...<Widget>[
              const SizedBox(height: 10),
              for (final BonusObjective objective in result!.newObjectives)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(
                        Icons.emoji_events_rounded,
                        size: 15,
                        color: GameColors.gold,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '${objective.label}  +${objective.crystalReward}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: GameColors.gold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 14),
            if (next != null)
              TacticalButton(
                label: 'Next: ${next.name}',
                icon: Icons.arrow_forward_rounded,
                variant: TacticalButtonVariant.primary,
                onPressed: () async => controller.startCampaignLevel(next),
              )
            else
              const Text(
                'Campaign complete — well played, Commander.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: GameColors.success,
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: TacticalButton(
                    label: 'Replay',
                    icon: Icons.refresh_rounded,
                    dense: true,
                    onPressed: () async => controller.restartGame(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TacticalButton(
                    label: 'Map',
                    icon: Icons.map_rounded,
                    dense: true,
                    variant: TacticalButtonVariant.ghost,
                    onPressed: onWorldMap,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedStars extends StatelessWidget {
  const _AnimatedStars({required this.stars});
  final int stars;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        for (int i = 1; i <= 3; i++)
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: Duration(milliseconds: 280 + i * 160),
            curve: Curves.elasticOut,
            builder: (BuildContext context, double t, Widget? child) {
              return Transform.scale(
                scale: i <= stars ? t : 1,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Icon(
                    i <= stars
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 38,
                    color: i <= stars ? GameColors.gold : GameColors.faint,
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

/// Top-of-board call-out shown while the final (boss) wave is active.
class _BossBanner extends StatelessWidget {
  const _BossBanner();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.6, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOut,
      builder: (BuildContext context, double t, Widget? child) {
        return Opacity(opacity: t, child: child);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: <Color>[Color(0xFF7A1E2B), Color(0xFFB23A2E)],
          ),
          borderRadius: BorderRadius.circular(GameSpace.radiusMd),
          border: Border.all(color: const Color(0x88FFD0C0)),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.warning_amber_rounded,
              size: 18,
              color: Color(0xFFFFE0B2),
            ),
            SizedBox(width: 8),
            Text(
              'FINAL WAVE — HOLD THE LINE',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 1.4,
                fontSize: 12,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Placement popup overlay
// ---------------------------------------------------------------------------

class _NativePlacementOverlay extends StatelessWidget {
  const _NativePlacementOverlay({
    required this.state,
    required this.onCancel,
    required this.onPlace,
  });

  final AppUiState state;
  final VoidCallback onCancel;
  final VoidCallback onPlace;

  @override
  Widget build(BuildContext context) {
    final PendingPlacementInfo? pending = state.pendingPlacement;
    if (pending == null || pending.id.isEmpty) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          const double popupWidth = 176;
          const double popupMinLeft = 8;
          const double popupMinTop = 8;
          const double popupBottomGap = 12;
          const double estimatedPopupHeight = 78;

          final double maxLeft = clampDoubleValue(
            constraints.maxWidth - popupWidth - 8,
            popupMinLeft,
            constraints.maxWidth,
          );
          final double left = clampDoubleValue(
            pending.anchorX - popupWidth / 2,
            popupMinLeft,
            maxLeft,
          );
          final double maxTop = clampDoubleValue(
            constraints.maxHeight - estimatedPopupHeight - popupMinTop,
            popupMinTop,
            constraints.maxHeight,
          );
          final bool fitsAbove =
              pending.anchorY - popupBottomGap - estimatedPopupHeight >=
              popupMinTop;
          final double preferredTop = fitsAbove
              ? pending.anchorY - estimatedPopupHeight - popupBottomGap
              : pending.anchorY + popupBottomGap;
          final double top = clampDoubleValue(
            preferredTop,
            popupMinTop,
            maxTop,
          );

          return Stack(
            children: <Widget>[
              Positioned(
                left: left,
                top: top,
                child: _PlacementPopupCard(
                  title: pending.title,
                  cost: pending.cost,
                  selectionStatus: state.selectionStatus,
                  placementReason: pending.statusText.isEmpty
                      ? state.selectionInfo?.placementReason ?? ''
                      : pending.statusText,
                  secondsLeft: pending.remainingTicks <= 0
                      ? null
                      : ((pending.remainingTicks + 59) ~/ 60),
                  canPlace: pending.showPlaceAction,
                  onCancel: onCancel,
                  onPlace: onPlace,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PlacementPopupCard extends StatelessWidget {
  const _PlacementPopupCard({
    required this.title,
    required this.cost,
    required this.selectionStatus,
    required this.placementReason,
    required this.secondsLeft,
    required this.canPlace,
    required this.onCancel,
    required this.onPlace,
  });

  final String title;
  final double cost;
  final String selectionStatus;
  final String placementReason;
  final int? secondsLeft;
  final bool canPlace;
  final VoidCallback onCancel;
  final VoidCallback onPlace;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: GameGradients.panelStrong,
        borderRadius: BorderRadius.circular(GameSpace.radiusMd),
        border: Border.all(
          color: canPlace ? GameColors.accent : GameColors.borderStrong,
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x88000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 132, maxWidth: 176),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: GameColors.text,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '\$${cost.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: GameColors.cash,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                placementReason.isEmpty ? selectionStatus : placementReason,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: GameColors.muted,
                  fontSize: 8.5,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (secondsLeft != null) ...<Widget>[
                    Icon(
                      Icons.timer_rounded,
                      size: 10,
                      color: GameColors.warning,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${secondsLeft}s',
                      style: const TextStyle(
                        color: GameColors.warning,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  _PopupActionButton(
                    label: 'Cancel',
                    foregroundColor: GameColors.muted,
                    onPressed: onCancel,
                  ),
                  const SizedBox(width: 6),
                  _PopupActionButton(
                    label: 'Deploy',
                    foregroundColor: const Color(0xFF04121F),
                    backgroundColor: canPlace
                        ? GameColors.accent
                        : GameColors.faint,
                    onPressed: canPlace ? onPlace : null,
                    bold: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PopupActionButton extends StatelessWidget {
  const _PopupActionButton({
    required this.label,
    required this.foregroundColor,
    required this.onPressed,
    this.backgroundColor = Colors.transparent,
    this.bold = false,
  });

  final String label;
  final Color foregroundColor;
  final Color backgroundColor;
  final bool bold;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final TextStyle style = TextStyle(
      color: foregroundColor,
      fontSize: 9,
      fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
    );
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(GameSpace.radiusSm),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(GameSpace.radiusSm),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          child: Text(label, style: style),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Timed decision dialog (upgrade / sell)
// ---------------------------------------------------------------------------

class _TimedDecisionDialog extends StatefulWidget {
  const _TimedDecisionDialog({
    required this.title,
    required this.confirmLabel,
    required this.content,
    required this.onConfirm,
  });

  final String title;
  final String confirmLabel;
  final Widget content;
  final Future<void> Function() onConfirm;

  @override
  State<_TimedDecisionDialog> createState() => _TimedDecisionDialogState();
}

class _TimedDecisionDialogState extends State<_TimedDecisionDialog> {
  late int _secondsLeft;
  Timer? _timer;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _secondsLeft = 7;
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted) {
        return;
      }
      if (_secondsLeft <= 1) {
        timer.cancel();
        Navigator.of(context).pop();
        return;
      }
      setState(() {
        _secondsLeft--;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: GameColors.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(GameSpace.radiusLg),
        side: const BorderSide(color: GameColors.borderStrong),
      ),
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            widget.content,
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                const Icon(
                  Icons.timer_rounded,
                  size: 12,
                  color: GameColors.warning,
                ),
                const SizedBox(width: 4),
                Text(
                  'Auto-resume in ${_secondsLeft}s',
                  style: const TextStyle(
                    color: GameColors.warning,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy
              ? null
              : () async {
                  setState(() {
                    _busy = true;
                  });
                  await widget.onConfirm();
                  if (!context.mounted) {
                    return;
                  }
                  Navigator.of(context).pop();
                },
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
