import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/user_model.dart';

class ChildCard extends StatelessWidget {
  final UserModel child;
  final VoidCallback onTap;

  const ChildCard({
    super.key,
    required this.child,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              child: Text(
                child.name.isNotEmpty
                    ? child.name[0].toUpperCase()
                    : '?',
                style: AppTextStyles.h3
                    .copyWith(color: AppColors.primary),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(child.name, style: AppTextStyles.h4),
                  Text(
                    '${child.grade} • ${child.totalPoints} pts',
                    style: AppTextStyles.bodySmall,
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: (child.totalPoints % 100) / 100,
                      backgroundColor:
                          AppColors.primary.withValues(alpha: 0.15),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.primary),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              children: [
                const Text('🔥', style: TextStyle(fontSize: 20)),
                Text(
                  '${child.streakDays}d',
                  style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.orange,
                      fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right,
                color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
