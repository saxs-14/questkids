import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum AppButtonVariant { primary, secondary, danger }

/// Shared button used across auth, profile, and dialog flows so loading
/// state, icon layout, and the danger (destructive-action) style are
/// defined once instead of duplicated per screen.
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool fullWidth;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.fullWidth = true,
  });

  @override
  Widget build(BuildContext context) {
    final spinnerColor = variant == AppButtonVariant.primary
        ? Colors.white
        : (variant == AppButtonVariant.danger
            ? AppColors.error
            : AppColors.primary);

    final content = isLoading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              color: spinnerColor,
              strokeWidth: 2,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: 8),
              ],
              Text(label),
            ],
          );

    final onTap = isLoading ? null : onPressed;

    final button = switch (variant) {
      AppButtonVariant.primary => ElevatedButton(
          onPressed: onTap,
          child: content,
        ),
      AppButtonVariant.secondary => OutlinedButton(
          onPressed: onTap,
          child: content,
        ),
      AppButtonVariant.danger => OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.error,
            side: const BorderSide(color: AppColors.error, width: 1.5),
          ),
          child: content,
        ),
    };

    if (!fullWidth) return button;
    return SizedBox(width: double.infinity, height: 52, child: button);
  }
}
