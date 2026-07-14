import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/quest_boy_mascot.dart';

class RecommendationCard extends StatelessWidget {
  final String recommendation;
  final bool isLoading;

  const RecommendationCard({
    super.key,
    required this.recommendation,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFFE234).withValues(alpha: 0.18),
            AppColors.primary.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFFB800).withValues(alpha: 0.40),
        ),
      ),
      child: isLoading
          ? Row(
              children: [
                const QuestBoyMascot(
                    size: 28, glow: false, state: QuestBoyState.knowledge),
                const SizedBox(width: 10),
                Text(
                  'QuestBot is looking at your progress... ✨',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const QuestBoyMascot(size: 36, state: QuestBoyState.waving),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'QuestBot says ✨',
                        style: AppTextStyles.label.copyWith(
                          color: const Color(0xFFCC8800),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        recommendation,
                        style: AppTextStyles.bodyMedium.copyWith(height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
