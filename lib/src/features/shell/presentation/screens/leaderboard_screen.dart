import 'package:flutter/material.dart';

import 'screen_chrome.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({required this.onBack, super.key});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('leaderboard'),
      decoration: screenBackgroundDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: DecoratedBox(
              decoration: solidScreenCardDecoration(),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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
                                'Leaderboard',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16344D),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'No leaderboard service is connected yet.',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'When scores are wired up, this screen can show best wave, fastest clear, and total kills.',
                            style: TextStyle(
                              color: Color(0xFF8FAAC0),
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
