import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class RoleSelector extends StatelessWidget {
  final String selectedRole;
  final ValueChanged<String> onRoleChanged;

  const RoleSelector({
    super.key,
    required this.selectedRole,
    required this.onRoleChanged,
  });

  static const roles = [
    {
      'value': 'parent',
      'label': 'Parent',
      'icon': '👨‍👩‍👧',
      'desc': 'I monitor my child'
    },
    {
      'value': 'teacher',
      'label': 'Teacher',
      'icon': '🧑‍🏫',
      'desc': 'I manage a class'
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('I am a...', style: AppTextStyles.h4),
        const SizedBox(height: 12),
        Row(
          children: roles.map((role) {
            final isSelected = selectedRole == role['value'];
            return Expanded(
              child: GestureDetector(
                onTap: () => onRoleChanged(role['value']!),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.primary.withValues(alpha: 0.2),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(role['icon']!, style: const TextStyle(fontSize: 28)),
                      const SizedBox(height: 6),
                      Text(
                        role['label']!,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color:
                              isSelected ? Colors.white : AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        role['desc']!,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: isSelected
                              ? Colors.white70
                              : AppColors.textSecondary,
                          fontSize: 10,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
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
