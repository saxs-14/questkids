import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class GradeSelector extends StatelessWidget {
  final String selectedGrade;
  final ValueChanged<String> onGradeChanged;

  const GradeSelector({
    super.key,
    required this.selectedGrade,
    required this.onGradeChanged,
  });

  static const grades = [
    'Grade 1',
    'Grade 2',
    'Grade 3',
    'Grade 4',
    'Grade 5',
    'Grade 6',
    'Grade 7',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Grade', style: AppTextStyles.h4),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: grades.map((grade) {
            final isSelected = selectedGrade == grade;
            return GestureDetector(
              onTap: () => onGradeChanged(grade),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.primary.withValues(alpha: 0.2),
                    width: 2,
                  ),
                ),
                child: Text(
                  grade,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: isSelected
                        ? Colors.white
                        : (Theme.of(context).brightness == Brightness.dark
                            ? AppColors.textDark
                            : AppColors.textPrimary),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
