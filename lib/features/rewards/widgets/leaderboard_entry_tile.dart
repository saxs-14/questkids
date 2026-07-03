import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/leaderboard_entry_model.dart';

class LeaderboardEntryTile extends StatelessWidget {
  final LeaderboardEntry entry;
  final bool isOwnEntry;
  final int animationIndex;

  const LeaderboardEntryTile({
    super.key,
    required this.entry,
    required this.isOwnEntry,
    this.animationIndex = 0,
  });

  String get _trophy {
    switch (entry.rank) {
      case 1:
        return '🥇';
      case 2:
        return '🥈';
      case 3:
        return '🥉';
      default:
        return '${entry.rank}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final highlight = isOwnEntry;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: highlight
            ? AppColors.gold.withValues(alpha: 0.15)
            : (isDark ? const Color(0xFF1E1E2E) : Colors.white),
        borderRadius: BorderRadius.circular(16),
        border: highlight
            ? Border.all(color: AppColors.gold, width: 1.5)
            : Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: entry.rank <= 3
                ? Text(_trophy, style: const TextStyle(fontSize: 22))
                : Text(
                    _trophy,
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child:
                  Text(entry.avatarEmoji, style: const TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.displayName,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: highlight ? AppColors.gold : null,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(entry.grade, style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${entry.xp}',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w800,
                  color: highlight ? AppColors.gold : AppColors.primary,
                ),
              ),
              Text('XP', style: AppTextStyles.bodySmall),
            ],
          ),
        ],
      ),
    )
        .animate(delay: Duration(milliseconds: animationIndex * 30))
        .slideX(begin: 0.3, end: 0, curve: Curves.easeOut)
        .fadeIn();
  }
}
