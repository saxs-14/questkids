import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/reward_model.dart';

class BadgeCard extends StatelessWidget {
  final BadgeModel badge;
  final bool isNew;

  const BadgeCard({
    super.key,
    required this.badge,
    this.isNew = false,
  });

  Color get _categoryColor {
    switch (badge.category) {
      case 'milestone':
        return AppColors.primary;
      case 'achievement':
        return AppColors.gold;
      case 'streak':
        return AppColors.orange;
      case 'subject':
        return AppColors.science;
      case 'points':
        return AppColors.green;
      case 'level':
        return AppColors.blue;
      case 'special':
        return AppColors.accent;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _categoryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isNew
                  ? _categoryColor
                  : _categoryColor.withValues(alpha: 0.3),
              width: isNew ? 2.5 : 1.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(badge.icon, style: const TextStyle(fontSize: 36)),
              const SizedBox(height: 8),
              Text(
                badge.name,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: _categoryColor,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                badge.description,
                style: AppTextStyles.bodySmall,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (isNew)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _categoryColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'NEW',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
