import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../game/application/controller.dart';
import '../../game/domain/models.dart';
import '../../game/rendering/tower_defense_flame_game.dart';
import '../presentation/game_theme.dart';
import '../presentation/screens/game_screen.dart';
import '../presentation/screens/home_screen.dart';
import '../presentation/screens/leaderboard_screen.dart';
import '../presentation/screens/map_selector_screen.dart';
import '../presentation/screens/settings_screen.dart';

class GameShell extends StatefulWidget {
  const GameShell({required this.controller, super.key});

  final GameController controller;

  @override
  State<GameShell> createState() => _GameShellState();
}

class _GameShellState extends State<GameShell> {
  late final TowerDefenseFlameGame _game;

  @override
  void initState() {
    super.initState();
    _game = TowerDefenseFlameGame(controller: widget.controller);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameColors.background,
      body: SafeArea(
        child: ValueListenableBuilder<ShellState>(
          valueListenable: widget.controller.shellStateListenable,
          builder: (BuildContext context, ShellState shellState, _) {
            if (shellState.isInitializing) {
              return const Center(child: CircularProgressIndicator());
            }
            if (shellState.loadError != null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    shellState.loadError!,
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            switch (shellState.activeScreen) {
              case 'leaderboard':
                return LeaderboardScreen(
                  onBack: () => widget.controller.setActiveScreen('home'),
                );
              case 'settings':
                return ValueListenableBuilder<GameConfig>(
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
              case 'map':
                return ValueListenableBuilder<GameConfig>(
                  valueListenable: widget.controller.configListenable,
                  builder: (BuildContext context, GameConfig config, __) {
                    return MapSelectorScreen(
                      config: config,
                      onBack: () => widget.controller.setActiveScreen('home'),
                      onSelectMap: widget.controller.updateMapSelection,
                      onStartRun: () async {
                        await widget.controller.restartGame();
                        widget.controller.setActiveScreen('game');
                      },
                    );
                  },
                );
              case 'game':
                return GameScreen(
                  controller: widget.controller,
                  game: _game,
                  onBackToMap: () => widget.controller.setActiveScreen('map'),
                  onShowIntel: () => _showIntelSheet(context),
                  onShowDevPanel: () => _showDevPanel(context),
                );
              default:
                return HomeScreen(
                  onPlay: () => widget.controller.setActiveScreen('map'),
                  onLeaderboard: () =>
                      widget.controller.setActiveScreen('leaderboard'),
                  onSettings: () =>
                      widget.controller.setActiveScreen('settings'),
                );
            }
          },
        ),
      ),
    );
  }

  Future<void> _showIntelSheet(BuildContext context) async {
    final info = widget.controller.uiState.selectionInfo;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: GameColors.panel,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _DialogCard(
              child: info == null
                  ? const Text(
                      'No tower selected. Tap a placed tower or choose one from the dock.',
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          info.title,
                          style: TextStyle(
                            color: info.titleColor,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text('Cost: \$${info.cost.toStringAsFixed(0)}'),
                        Text('Sell: \$${info.sellPrice.toStringAsFixed(0)}'),
                        Text(
                          'Upgrade: ${info.upgradePrice == null ? 'N/A' : '\$${info.upgradePrice!.toStringAsFixed(0)}'}',
                        ),
                        Text('Damage: ${info.damage}'),
                        Text('DPS: ${info.dps.toStringAsFixed(2)}'),
                        Text('Type: ${info.damageTypeLabel}'),
                        Text('Range: ${info.range}'),
                        Text(
                          'Cooldown: ${info.cooldownSeconds.toStringAsFixed(2)}s',
                        ),
                        const SizedBox(height: 10),
                        Text('Targeting: ${info.targeting}'),
                        Text('Effect: ${info.effect}'),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showDevPanel(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            final config = widget.controller.config;
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 36,
                vertical: 80,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: _DialogCard(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            const Expanded(
                              child: Text(
                                'Developer Controls',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close_rounded, size: 16),
                              splashRadius: 18,
                              constraints: const BoxConstraints.tightFor(
                                width: 28,
                                height: 28,
                              ),
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        SwitchListTile(
                          dense: true,
                          visualDensity: const VisualDensity(
                            horizontal: -2,
                            vertical: -3,
                          ),
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Show FPS',
                            style: TextStyle(fontSize: 13),
                          ),
                          value: config.devFlags.showFps,
                          onChanged: (_) {
                            widget.controller.toggleShowFps();
                            setState(() {});
                          },
                        ),
                        SwitchListTile(
                          dense: true,
                          visualDensity: const VisualDensity(
                            horizontal: -2,
                            vertical: -3,
                          ),
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'God Mode',
                            style: TextStyle(fontSize: 13),
                          ),
                          value: config.devFlags.godMode,
                          onChanged: (_) {
                            widget.controller.toggleGodMode();
                            setState(() {});
                          },
                        ),
                        SwitchListTile(
                          dense: true,
                          visualDensity: const VisualDensity(
                            horizontal: -2,
                            vertical: -3,
                          ),
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Disable Tower Fire',
                            style: TextStyle(fontSize: 13),
                          ),
                          value: config.devFlags.firingDisabled,
                          onChanged: (_) {
                            widget.controller.toggleFiringDisabled();
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
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
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xF0122A45), Color(0xFF0E2137)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x2E7A9CD2)),
      ),
      child: Padding(padding: const EdgeInsets.all(14), child: child),
    );
  }
}
