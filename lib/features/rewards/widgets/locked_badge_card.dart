import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class LockedBadgeCard extends StatelessWidget {
  final Map<String, dynamic> badgeData;

  const LockedBadgeCard({super.key, required this.badgeData});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.textSecondary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.textSecondary.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Text(
                badgeData['icon'] as String,
                style: const TextStyle(fontSize: 36),
              ),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock,
                    color: Colors.white, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            badgeData['name'] as String,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            badgeData['description'] as String,
            style: AppTextStyles.bodySmall,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
