import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../core/game_engine.dart';

/// Full-screen result shown after a Tug of War session ends.
class GameResultOverlay extends StatelessWidget {
  final GameSessionResult result;
  final int playerScore;
  final int opponentScore;
  final String opponentName;
  final VoidCallback onPlayAgain;
  final VoidCallback onContinue;

  const GameResultOverlay({
    super.key,
    required this.result,
    required this.playerScore,
    required this.opponentScore,
    required this.opponentName,
    required this.onPlayAgain,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final isWin = result.result == 'win' || result.result == 'complete';
    final isPerfect = result.result == 'complete';

    return Scaffold(
      backgroundColor:
          isWin ? AppColors.blue.withAlpha(230) : AppColors.accent.withAlpha(230),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Banner emoji + title
                Text(
                  isPerfect ? '🏆' : (isWin ? '🎉' : '😓'),
                  style: const TextStyle(fontSize: 72),
                ),
                const SizedBox(height: 12),
                Text(
                  isPerfect
                      ? 'PERFECT MATCH!'
                      : (isWin ? 'YOU WON!' : 'BETTER LUCK NEXT TIME'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 1.5,
                  ),
                ),

                const SizedBox(height: 24),

                // Score card
                _ResultCard(children: [
                  _ScoreLine(
                    label: 'Score',
                    value: '$playerScore – $opponentScore',
                    valueStyle: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Divider(height: 20),
                  _ScoreLine(
                    label: 'Accuracy',
                    value: '${(result.accuracy * 100).round()}%',
                  ),
                  _ScoreLine(
                    label: 'XP Earned',
                    value: '+${result.xpEarned} XP',
                    valueColor: AppColors.gold,
                  ),
                  _ScoreLine(
                    label: 'Coins',
                    value: '+${result.coinsEarned} 🪙',
                    valueColor: AppColors.gold,
                  ),
                  if (isPerfect) ...[
                    const Divider(height: 20),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.military_tech, color: AppColors.gold),
                        SizedBox(width: 6),
                        Text(
                          'Perfect Match Badge Unlocked!',
                          style: TextStyle(
                            color: AppColors.gold,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ]),

                const SizedBox(height: 32),

                // Buttons
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onPlayAgain,
                    icon: const Icon(Icons.replay),
                    label: const Text(
                      'Play Again',
                      style: TextStyle(fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onContinue,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text(
                      'Continue',
                      style: TextStyle(fontSize: 16),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white, width: 2),
                      padding: const EdgeInsets.symmetric(vertical: 14),
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

class _ResultCard extends StatelessWidget {
  final List<Widget> children;
  const _ResultCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _ScoreLine extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final TextStyle? valueStyle;

  const _ScoreLine({
    required this.label,
    required this.value,
    this.valueColor,
    this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 16, color: AppColors.textSecondary)),
          Text(
            value,
            style: valueStyle ??
                TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: valueColor ?? AppColors.textPrimary,
                ),
          ),
        ],
      ),
    );
  }
}
