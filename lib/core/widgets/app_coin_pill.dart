import 'package:flutter/material.dart';
import '../constants/labels.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// A small "Gold" pill: coin icon + amount. Used in the HUD, the Trading
/// Post balance display, and anywhere a compact currency readout is
/// needed. Animates the displayed number counting up/down when [amount]
/// changes, so a Gold-earning moment reads as a real gain, not a jump-cut.
class AppCoinPill extends StatelessWidget {
  final int amount;
  final bool compact;

  const AppCoinPill({super.key, required this.amount, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 14,
        vertical: compact ? 5 : 8,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.alphaBlend(AppColors.glossHighlight, AppColors.gold),
            AppColors.goldDark,
          ],
        ),
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowSoft,
            offset: Offset(0, 2),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🪙', style: TextStyle(fontSize: compact ? 13 : 16)),
          SizedBox(width: compact ? 4 : 6),
          TweenAnimationBuilder<int>(
            tween: IntTween(begin: 0, end: amount),
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 500),
            curve: Curves.easeOut,
            builder: (context, value, _) => Text(
              '$value',
              style: AppTextStyles.hudNumber.copyWith(
                color: AppColors.textPrimary,
                fontSize: compact ? 13 : 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Standalone label text for [QuestLabels.gold], for places that spell out
/// "Gold" next to a number rather than using the coin emoji pill (e.g. the
/// Trading Post balance header).
class AppGoldLabel extends StatelessWidget {
  final int amount;
  const AppGoldLabel({super.key, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Text(
      QuestLabels.goldAmount(amount),
      style: AppTextStyles.h3.copyWith(color: AppColors.goldDark),
    );
  }
}
