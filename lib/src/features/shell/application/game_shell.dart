import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../game/application/controller.dart';
import '../../game/domain/models.dart';
import '../presentation/game_theme.dart';
import '../presentation/screens/game_screen.dart';
import '../presentation/screens/home_screen.dart';
import '../presentation/screens/leaderboard_screen.dart';
import '../presentation/screens/map_selector_screen.dart';
import '../presentation/screens/settings_screen.dart';
import '../presentation/screens/shop_screen.dart';
import '../presentation/screens/world_map_screen.dart';
import '../../progression/domain/campaign.dart';

class GameShell extends StatefulWidget {
  const GameShell({required this.controller, super.key});

  final GameController controller;

  @override
  State<GameShell> createState() => _GameShellState();
}

class _GameShellState extends State<GameShell> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameColors.background,
      body: SafeArea(
        child: ValueListenableBuilder<ShellState>(
          valueListenable: widget.controller.shellStateListenable,
          builder: (BuildContext context, ShellState shellState, _) {
            if (shellState.isInitializing) {
              return const _BootScreen();
            }
            if (shellState.loadError != null) {
              return DecoratedBox(
                decoration: const BoxDecoration(gradient: GameGradients.screen),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(
                          Icons.error_outline_rounded,
                          color: GameColors.danger,
                          size: 36,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          shellState.loadError!,
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            final Widget screen;
            switch (shellState.activeScreen) {
              case 'leaderboard':
                screen = LeaderboardScreen(
                  onBack: () => widget.controller.setActiveScreen('home'),
                  profileListenable:
                      widget.controller.progression.profileListenable,
                );
                break;
              case 'settings':
                screen = ValueListenableBuilder<GameConfig>(
                  valueListenable: widget.controller.configListenable,
                  builder: (BuildContext context, GameConfig _, __) {
                    return SettingsScreen(
                      controller: widget.controller,
                      onBack: () => widget.controller.setActiveScreen('home'),
                      onImportMap: () => _showImportDialog(context),
                      onExportMap: () => _exportMap(context),
                      onOpenMapEditor: _openMapEditor,
                    );
                  },
                );
                break;
              case 'shop':
                screen = ShopScreen(
                  progression: widget.controller.progression,
                  onBack: () => widget.controller.setActiveScreen('world'),
                );
                break;
              case 'world':
                screen = WorldMapScreen(
                  profileListenable:
                      widget.controller.progression.profileListenable,
                  onBack: () => widget.controller.setActiveScreen('home'),
                  onEndless: () => widget.controller.setActiveScreen('map'),
                  onShop: () => widget.controller.setActiveScreen('shop'),
                  onSelectLevel: (CampaignLevel level) async {
                    await widget.controller.startCampaignLevel(level);
                    widget.controller.setActiveScreen('game');
                  },
                );
                break;
              case 'map':
                screen = ValueListenableBuilder<GameConfig>(
                  valueListenable: widget.controller.configListenable,
                  builder: (BuildContext context, GameConfig config, __) {
                    return MapSelectorScreen(
                      config: config,
                      onBack: () => widget.controller.setActiveScreen('home'),
                      onSelectMap: widget.controller.updateMapSelection,
                      onStartRun: () async {
                        await widget.controller.startEndlessRun();
                        widget.controller.setActiveScreen('game');
                      },
                    );
                  },
                );
                break;
              case 'game':
                screen = GameScreen(
                  controller: widget.controller,
                  onBackToMap: () => widget.controller.setActiveScreen(
                    widget.controller.activeLevelId != null ? 'world' : 'map',
                  ),
                  onWorldMap: () => widget.controller.setActiveScreen('world'),
                  onShowIntel: () => _showIntelSheet(context),
                );
                break;
              default:
                screen = HomeScreen(
                  onPlay: () => widget.controller.setActiveScreen('world'),
                  onLeaderboard: () =>
                      widget.controller.setActiveScreen('leaderboard'),
                  onSettings: () =>
                      widget.controller.setActiveScreen('settings'),
                );
            }
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (Widget child, Animation<double> anim) {
                return FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.025),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                );
              },
              layoutBuilder:
                  (Widget? currentChild, List<Widget> previousChildren) {
                    return Stack(
                      alignment: Alignment.topCenter,
                      children: <Widget>[
                        ...previousChildren,
                        if (currentChild != null) currentChild,
                      ],
                    );
                  },
              child: KeyedSubtree(
                key: ValueKey<String>(shellState.activeScreen),
                child: screen,
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _showIntelSheet(BuildContext context) async {
    final info = widget.controller.uiState.selectionInfo;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _DialogCard(
              child: info == null
                  ? Row(
                      children: const <Widget>[
                        Icon(
                          Icons.touch_app_rounded,
                          color: GameColors.muted,
                          size: 20,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'No turret selected. Tap a placed turret or choose '
                            'one from the arsenal.',
                            style: TextStyle(color: GameColors.muted),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Container(
                              width: 10,
                              height: 26,
                              decoration: BoxDecoration(
                                color: info.titleColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                info.title,
                                style: TextStyle(
                                  color: info.titleColor,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            _IntelTag(
                              label: info.damageTypeLabel,
                              color: info.titleColor,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            _IntelStat(
                              label: 'DAMAGE',
                              value: info.damage,
                            ),
                            _IntelStat(
                              label: 'DPS',
                              value: info.dps.toStringAsFixed(1),
                            ),
                            _IntelStat(
                              label: 'RANGE',
                              value: info.range.toStringAsFixed(1),
                            ),
                            _IntelStat(
                              label: 'COOLDOWN',
                              value: '${info.cooldownSeconds.toStringAsFixed(2)}s',
                            ),
                            _IntelStat(
                              label: 'COST',
                              value: '\$${info.cost.toStringAsFixed(0)}',
                            ),
                            _IntelStat(
                              label: 'SELL',
                              value: '\$${info.sellPrice.toStringAsFixed(0)}',
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _IntelLine(
                          icon: Icons.gps_fixed_rounded,
                          label: 'Targeting',
                          value: info.targeting,
                        ),
                        _IntelLine(
                          icon: Icons.auto_awesome_rounded,
                          label: 'Effect',
                          value: info.effect,
                        ),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showImportDialog(BuildContext context) async {
    final TextEditingController input = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Import Map'),
          content: TextField(
            controller: input,
            minLines: 4,
            maxLines: 8,
            decoration: const InputDecoration(
              hintText: 'Paste compressed map string or raw JSON',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                await widget.controller.importMapString(input.text);
                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text('Import'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _exportMap(BuildContext context) async {
    final String value = widget.controller.exportCurrentMapString();
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Map copied to clipboard')));
  }

  Future<void> _openMapEditor() async {
    await launchUrl(
      Uri.parse('https://balacode.github.io/tower-defense-map-editor/'),
      mode: LaunchMode.externalApplication,
    );
  }
}

class _DialogCard extends StatelessWidget {
  const _DialogCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: GameGradients.panel,
        borderRadius: BorderRadius.circular(GameSpace.radiusLg),
        border: Border.all(color: GameColors.borderStrong),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x80000000),
            blurRadius: 26,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

class _IntelTag extends StatelessWidget {
  const _IntelTag({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(GameSpace.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 9,
          letterSpacing: 1.0,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _IntelStat extends StatelessWidget {
  const _IntelStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
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
            value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
          ),
          Text(
            label,
            style: const TextStyle(
              color: GameColors.muted,
              fontSize: 8,
              letterSpacing: 1.0,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _IntelLine extends StatelessWidget {
  const _IntelLine({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 14, color: GameColors.accentBright),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(
              color: GameColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: GameColors.text, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

/// Branded boot screen shown while the controller initialises.
class _BootScreen extends StatelessWidget {
  const _BootScreen();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: GameGradients.screen),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 70,
              height: 70,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: <Color>[Color(0xFF173352), Color(0xFF0C1B2E)],
                ),
                border: Border.all(color: GameColors.accent, width: 2),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: GameColors.accent.withValues(alpha: 0.4),
                    blurRadius: 24,
                    spreadRadius: -4,
                  ),
                ],
              ),
              child: const Icon(
                Icons.shield_rounded,
                color: GameColors.accentBright,
                size: 34,
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'FORWARD DEFENSE GRID',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 14,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            const SizedBox(
              width: 120,
              child: LinearProgressIndicator(
                minHeight: 3,
                backgroundColor: GameColors.panelStrong,
                valueColor: AlwaysStoppedAnimation<Color>(GameColors.accent),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'INITIALISING SYSTEMS',
              style: TextStyle(
                color: GameColors.muted,
                fontSize: 9,
                letterSpacing: 2.0,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
