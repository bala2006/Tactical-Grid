import 'package:flutter/material.dart';

import '../../../game/domain/content.dart';
import '../../../game/domain/models.dart';
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
    return Container(
      key: const ValueKey<String>('map'),
      decoration: screenBackgroundDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: DecoratedBox(
          decoration: solidScreenCardDecoration(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    IconButton.outlined(
                      onPressed: onBack,
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'TACTICAL GRID',
                            style: TextStyle(
                              color: Color(0xFF8EB8D7),
                              fontSize: 10,
                              letterSpacing: 2.4,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Select Map',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF79B9FF),
                        foregroundColor: const Color(0xFF072033),
                        textStyle: const TextStyle(fontWeight: FontWeight.w800),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      onPressed: onStartRun,
                      child: const Text('Start Run'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16344D),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Text(
                    'Choose the battlefield. Difficulty, wave mode, audio, effects, and map utilities are available on the Settings screen.',
                    style: TextStyle(
                      color: Color(0xFF8FAAC0),
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: selectableMapNames
                          .map((String name) {
                            final bool selected = config.mapSelection == name;
                            return SizedBox(
                              width: 160,
                              child: FilledButton(
                                onPressed: () => onSelectMap(name),
                                style: FilledButton.styleFrom(
                                  elevation: 0,
                                  backgroundColor: selected
                                      ? const Color(0xFF79B9FF)
                                      : const Color(0xFF1A3E5B),
                                  foregroundColor: selected
                                      ? const Color(0xFF072033)
                                      : Colors.white,
                                  padding: const EdgeInsets.all(14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                    side: BorderSide(
                                      color: selected
                                          ? const Color(0xFF9CCEFF)
                                          : const Color(0xFF2A5474),
                                    ),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      mapLabels[name] ?? name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          })
                          .toList(growable: false),
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
