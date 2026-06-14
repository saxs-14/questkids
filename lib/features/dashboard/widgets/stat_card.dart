import 'package:flutter/material.dart';
import '../../../core/theme/app_text_styles.dart';

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String emoji;
  final Color color;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.emoji,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 8),
            Text(
              value,
              style: AppTextStyles.h3.copyWith(color: color),
            ),
            Text(
              label,
              style: AppTextStyles.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
