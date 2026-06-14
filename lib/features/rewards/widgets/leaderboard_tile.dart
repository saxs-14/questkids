import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/user_model.dart';

class LeaderboardTile extends StatelessWidget {
  final UserModel user;
  final int rank;
  final bool isCurrentUser;

  const LeaderboardTile({
    super.key,
    required this.user,
    required this.rank,
    required this.isCurrentUser,
  });

  Color get _rankColor {
    if (rank == 1) return AppColors.gold;
    if (rank == 2) return const Color(0xFFC0C0C0);
    if (rank == 3) return const Color(0xFFCD7F32);
    return AppColors.textSecondary;
  }

  String get _rankEmoji {
    if (rank == 1) return '🥇';
    if (rank == 2) return '🥈';
    if (rank == 3) return '🥉';
    return '#$rank';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? AppColors.primary.withValues(alpha: 0.1)
            : Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrentUser
              ? AppColors.primary
              : Colors.transparent,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: isCurrentUser
                ? AppColors.primary.withValues(alpha: 0.15)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: rank <= 3
                ? Text(_rankEmoji,
                    style: const TextStyle(fontSize: 24))
                : Text(
                    _rankEmoji,
                    style: AppTextStyles.h4
                        .copyWith(color: _rankColor),
                    textAlign: TextAlign.center,
                  ),
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
            child: Text(
              user.name.isNotEmpty
                  ? user.name[0].toUpperCase()
                  : '?',
              style: AppTextStyles.h4
                  .copyWith(color: AppColors.primary),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      user.name,
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isCurrentUser
                            ? AppColors.primary
                            : null,
                      ),
                    ),
                    if (isCurrentUser) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('You',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ],
                ),
                Text(user.grade,
                    style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${user.totalPoints}',
                style: AppTextStyles.h4
                    .copyWith(color: AppColors.gold),
              ),
              Row(
                children: [
                  const Text('🔥',
                      style: TextStyle(fontSize: 11)),
                  Text(' ${user.streakDays}d',
                      style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.orange)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
