import 'package:flutter/material.dart';
import '../../../core/theme/app_text_styles.dart';

class SubjectChip extends StatelessWidget {
  final String subject;
  final String emoji;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const SubjectChip({
    super.key,
    required this.subject,
    required this.emoji,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isSelected ? color : color.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(
              subject,
              style: AppTextStyles.bodyMedium.copyWith(
                color: isSelected ? Colors.white : color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
