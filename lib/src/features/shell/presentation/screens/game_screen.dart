import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../../game/application/controller.dart';
import '../../../game/presentation/native_game_board.dart';
import '../../../game/domain/models.dart';
import '../../../game/rendering/tower_defense_flame_game.dart';
import '../game_theme.dart';
import 'screen_chrome.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({
    required this.controller,
    required this.game,
    required this.onBackToMap,
    required this.onShowIntel,
    required this.onShowDevPanel,
    super.key,
  });

  final GameController controller;
  final TowerDefenseFlameGame game;
  final VoidCallback onBackToMap;
  final VoidCallback onShowIntel;
  final VoidCallback onShowDevPanel;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  Offset? _lastBoardPointer;

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
      title: 'Upgrade Tower',
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
          const SizedBox(height: 10),
          Text(
            'DMG ${info.damage}  -->  ${_extractUpgradeValue(compactDelta, 'DMG', info.damage)}',
            style: const TextStyle(fontSize: 11),
          ),
          Text(
            'RNG ${info.range.toStringAsFixed(1)}  -->  ${_extractUpgradeValue(compactDelta, 'RNG', info.range.toStringAsFixed(1))}',
            style: const TextStyle(fontSize: 11),
          ),
          Text(
            'CD ${info.cooldownSeconds.toStringAsFixed(2)}s  -->  ${_extractUpgradeValue(compactDelta, 'CD', '${info.cooldownSeconds.toStringAsFixed(2)}s')}',
            style: const TextStyle(fontSize: 11),
          ),
          const SizedBox(height: 10),
          Text(
            compactDelta,
            style: const TextStyle(
              color: Color(0xFF9CCEFF),
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Upgrade cost: \$${info.upgradePrice?.toStringAsFixed(0) ?? 'N/A'}',
            style: const TextStyle(
              color: Color(0xFF64FF8C),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
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
      title: 'Sell Tower',
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
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Text('Total invested: \$${info.cost.toStringAsFixed(0)}'),
          Text(
            'Sell return: \$${info.sellPrice.toStringAsFixed(0)}',
            style: const TextStyle(
              color: Color(0xFF64FF8C),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Selling refunds 75% of the total build + upgrade cost.',
            style: TextStyle(color: Color(0xFF9CCEFF)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.sizeOf(context);
    final double railWidth = (screenSize.width * 0.085).clamp(72.0, 88.0);
    return Container(
      key: const ValueKey<String>('game'),
      color: GameColors.background,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 4),
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
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                children: <Widget>[
                  ValueListenableBuilder<AppUiState>(
                    valueListenable: widget.controller.uiStateListenable,
                    builder: (BuildContext context, AppUiState state, _) {
                      return Row(
                        children: <Widget>[
                          Expanded(child: _HudBar(state: state)),
                          const SizedBox(width: 6),
                          _HeaderActionButton(
                            icon: Icons.upgrade_rounded,
                            label: 'Upgrade',
                            onPressed: state.selectionInfo?.canUpgrade == true
                                ? () => _showUpgradeDialog(state)
                                : null,
                          ),
                          const SizedBox(width: 6),
                          _HeaderActionButton(
                            icon: Icons.sell_rounded,
                            label: 'Sell',
                            onPressed: state.selectionInfo?.canSell == true
                                ? () => _showSellDialog(state)
                                : null,
                          ),
                          const SizedBox(width: 6),
                          _HeaderActionButton(
                            icon: state.isPaused
                                ? Icons.play_arrow_rounded
                                : Icons.pause_rounded,
                            label: state.isPaused ? 'Play' : 'Pause',
                            onPressed: widget.controller.togglePause,
                          ),
                          const SizedBox(width: 6),
                          _HeaderActionButton(
                            icon: Icons.restart_alt_rounded,
                            label: 'Restart',
                            onPressed: () async {
                              await widget.controller.restartGame();
                            },
                          ),
                          const SizedBox(width: 6),
                          _FloatingAction(
                            icon: Icons.info_outline_rounded,
                            onPressed: widget.onShowIntel,
                          ),
                          const SizedBox(width: 6),
                          _FloatingAction(
                            icon: Icons.settings_input_component_rounded,
                            onPressed: widget.onShowDevPanel,
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Stack(
                      children: <Widget>[
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: ColoredBox(
                              color: GameColors.background,
                              child: widget.controller.isNativeBoardEnabled
                                  ? const NativeGameBoard()
                                  : GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTapUp: (TapUpDetails details) {
                                        widget.controller.handleBoardTap(
                                          details.localPosition,
                                        );
                                      },
                                      onPanStart: (DragStartDetails details) {
                                        _lastBoardPointer =
                                            details.localPosition;
                                        widget.controller.updateBoardPointer(
                                          details.localPosition,
                                        );
                                      },
                                      onPanUpdate: (DragUpdateDetails details) {
                                        _lastBoardPointer =
                                            details.localPosition;
                                        widget.controller.updateBoardPointer(
                                          details.localPosition,
                                        );
                                      },
                                      onPanEnd: (DragEndDetails details) {
                                        final Offset? position =
                                            _lastBoardPointer;
                                        if (position != null) {
                                          widget.controller.handleBoardTap(
                                            position,
                                          );
                                        }
                                      },
                                      onPanCancel: () {
                                        _lastBoardPointer = null;
                                      },
                                      child: RepaintBoundary(
                                        child: GameWidget(game: widget.game),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: ValueListenableBuilder<AppUiState>(
                            valueListenable:
                                widget.controller.uiStateListenable,
                            builder: (
                              BuildContext context,
                              AppUiState state,
                              _,
                            ) {
                              return Stack(
                                children: <Widget>[
                                  if (state.performance.fps > 0 &&
                                      widget.controller.config.devFlags.showFps)
                                    Positioned(
                                      left: 8,
                                      top: 8,
                                      child: _PerfChip(
                                        stats: state.performance,
                                      ),
                                    ),
                                  if (state.defeat)
                                    Positioned.fill(
                                      child: ColoredBox(
                                        color: Colors.black54,
                                        child: Center(
                                          child: _DefeatCard(
                                            controller: widget.controller,
                                            state: state,
                                          ),
                                        ),
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
    );
  }
}

class _HudMetric {
  const _HudMetric({
    required this.icon,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String value;
  final Color color;
}

class _HudBar extends StatelessWidget {
  const _HudBar({required this.state});
  final AppUiState state;

  @override
  Widget build(BuildContext context) {
    final List<_HudMetric> metrics = <_HudMetric>[
      _HudMetric(
        icon: Icons.favorite_rounded,
        value: '${state.health}/${state.maxHealth}',
        color: const Color(0xFFFF7E79),
      ),
      _HudMetric(
        icon: Icons.attach_money_rounded,
        value: '\$${state.cash}',
        color: const Color(0xFF64FF8C),
      ),
      _HudMetric(
        icon: Icons.waves_rounded,
        value: '${state.wave}',
        color: const Color(0xFF79D8FF),
      ),
      _HudMetric(
        icon: Icons.track_changes_rounded,
        value: '${state.runStats.kills}',
        color: const Color(0xFFB5FF82),
      ),
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF11293F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A5474)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: <Widget>[
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: metrics
                      .map(
                        (_HudMetric metric) => _HudMetricView(metric: metric),
                      )
                      .toList(growable: false),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1C445F),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                state.waveState,
                style: const TextStyle(
                  color: Color(0xFF9CCEFF),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PerfChip extends StatelessWidget {
  const _PerfChip({required this.stats});

  final PerformanceStats stats;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xCC0B1D2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A5474)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Text(
          '${stats.fps.toStringAsFixed(0)} FPS  ${stats.frameTimeMs.toStringAsFixed(1)}ms  ${stats.quality.name}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _HudMetricView extends StatelessWidget {
  const _HudMetricView({required this.metric});
  final _HudMetric metric;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(metric.icon, size: 13, color: metric.color),
          const SizedBox(width: 3),
          Text(
            metric.value,
            style: TextStyle(
              color: metric.color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Container(width: 1, height: 12, color: metric.color.withAlpha(120)),
        ],
      ),
    );
  }
}

class _TowerRail extends StatelessWidget {
  const _TowerRail({
    required this.controller,
    required this.onBackToMap,
  });
  final GameController controller;
  final VoidCallback onBackToMap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        FilledButton(
          onPressed: onBackToMap,
          style: FilledButton.styleFrom(
            elevation: 0,
            backgroundColor: const Color(0xFF11293F),
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(40),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Color(0xFF2A5474)),
            ),
          ),
          child: const FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '← Back',
              maxLines: 1,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: DecoratedBox(
            decoration: solidScreenCardDecoration().copyWith(
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
              child: Column(
                children: <Widget>[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16344D),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.storefront_rounded,
                          color: Color(0xFF9DE68A),
                          size: 9,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Store',
                          style: TextStyle(
                            color: Color(0xFF8EB8D7),
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
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
                        final bool isPlacing = state.selectionStatus.startsWith('Placing: ');
                        final String? selectedTitle = isPlacing
                            ? state.selectionInfo?.title
                            : null;
                        return ListView.separated(
                          padding: EdgeInsets.zero,
                          itemCount: controller.storeBlueprints.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 6),
                          itemBuilder: (BuildContext context, int index) {
                            final TowerBlueprint blueprint =
                                controller.storeBlueprints[index];
                            final bool selected =
                                selectedTitle == blueprint.title;
                            final Color backgroundColor = selected
                                ? const Color(0xFF234766)
                                : const Color(0xFF1A3E5B);
                            final Color foregroundColor = Colors.white;
                            final Color priceChipColor = selected
                                ? const Color(0xFF1D3C58)
                                : const Color(0xFF16344D);
                            final Color priceTextColor = selected
                                ? const Color(0xFFA9D5FF)
                                : const Color(0xFF8EB8D7);
                            return FilledButton.tonal(
                              onPressed: () async {
                                await controller.selectBuildTower(blueprint.kind);
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: backgroundColor,
                                foregroundColor: foregroundColor,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 8,
                                ),
                                minimumSize: const Size.fromHeight(64),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(
                                    color: selected
                                        ? const Color(0xFF79B9FF)
                                        : const Color(0xFF2A5474),
                                    width: selected ? 1.6 : 1,
                                  ),
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 120),
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: blueprint.color.withAlpha(
                                        selected ? 230 : 190,
                                      ),
                                      shape: BoxShape.circle,
                                      border: selected
                                          ? Border.all(
                                              color: const Color(0xFFAED7FF),
                                              width: 1.4,
                                            )
                                          : null,
                                    ),
                                    alignment: Alignment.center,
                                    child: Icon(
                                      _towerIcon(blueprint.kind),
                                      color: Colors.white,
                                      size: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    blueprint.title,
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: foregroundColor,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w700,
                                      height: 1.15,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 1.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: priceChipColor,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '\$${blueprint.cost}',
                                      style: TextStyle(
                                        color: priceTextColor,
                                        fontSize: 7.8,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
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

IconData _towerIcon(TowerKind kind) {
  return switch (kind) {
    TowerKind.gun || TowerKind.machineGun => Icons.radio_button_checked,
    TowerKind.laser || TowerKind.beamEmitter => Icons.bolt_rounded,
    TowerKind.slow || TowerKind.poison => Icons.ac_unit_rounded,
    TowerKind.sniper || TowerKind.railgun => Icons.gps_fixed_rounded,
    TowerKind.rocket || TowerKind.missileSilo => Icons.rocket_launch_rounded,
    TowerKind.bomb || TowerKind.clusterBomb => Icons.blur_on_rounded,
    TowerKind.tesla || TowerKind.plasma => Icons.offline_bolt_rounded,
  };
}

class _DefeatCard extends StatelessWidget {
  const _DefeatCard({required this.controller, required this.state});
  final GameController controller;
  final AppUiState state;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xF0122A45), Color(0xFF0E2137)],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0x2E7A9CD2)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text(
                'Run Compromised',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Text('Reached wave ${state.wave}'),
              Text('Towers built: ${state.runStats.built}'),
              Text('Kills: ${state.runStats.kills}'),
              Text('Damage dealt: ${state.runStats.totalDamage.round()}'),
              Text('Leaks: ${state.runStats.leaks}'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async => controller.restartGame(),
                child: const Text('Retry'),
              ),
              TextButton(
                onPressed: () => controller.setActiveScreen('map'),
                child: const Text('Back To Map Select'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FloatingAction extends StatelessWidget {
  const _FloatingAction({required this.icon, required this.onPressed});
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      child: FilledButton(
        style: FilledButton.styleFrom(
          elevation: 0,
          backgroundColor: const Color(0xFF11293F),
          foregroundColor: Colors.white,
          minimumSize: const Size(40, 40),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFF2A5474)),
          ),
        ),
        onPressed: onPressed,
        child: Icon(icon, size: 16),
      ),
    );
  }
}

class _HeaderActionButton extends StatelessWidget {
  const _HeaderActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        elevation: 0,
        backgroundColor: const Color(0xFF11293F),
        foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(0xFF11293F),
        disabledForegroundColor: Colors.white38,
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFF2A5474)),
        ),
        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 14),
      label: Text(label),
    );
  }
}

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
      backgroundColor: const Color(0xFF11293F),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            widget.content,
            const SizedBox(height: 16),
            Text(
              'Decision timeout: ${_secondsLeft}s',
              style: const TextStyle(
                color: Color(0xFFFFC16B),
                fontSize: 10,
              ),
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

String _extractUpgradeValue(String delta, String label, String fallback) {
  final RegExpMatch? match = RegExp('$label\\s+([^,]+)').firstMatch(delta);
  return match == null ? fallback : match.group(1)!.trim();
}
