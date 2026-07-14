import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

enum AppButtonVariant { primary, secondary, danger }

/// Shared button used across auth, profile, dialog and game-HUD flows.
///
/// Premium-2D "chunky glossy component" treatment: a soft ambient shadow
/// below, a thin gloss highlight along the top edge, and a springy
/// press-scale that respects the platform's reduced-motion setting. The
/// public API is unchanged from the previous ElevatedButton/OutlinedButton
/// wrapper so no call site needs to change.
class AppButton extends StatefulWidget {
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
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _pressed = false;

  bool get _enabled => !widget.isLoading && widget.onPressed != null;

  void _setPressed(bool v) {
    if (_pressed == v) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final (Color bg, Color bgDark, Color fg, Color? border) = switch (
        widget.variant) {
      AppButtonVariant.primary => (
          AppColors.primary,
          AppColors.primaryDark,
          AppColors.textLight,
          null,
        ),
      AppButtonVariant.secondary => (
          isDark ? AppColors.cardDark : Colors.white,
          isDark ? AppColors.cardDark : Colors.white,
          AppColors.primary,
          AppColors.primary,
        ),
      AppButtonVariant.danger => (
          isDark ? AppColors.cardDark : Colors.white,
          isDark ? AppColors.cardDark : Colors.white,
          AppColors.error,
          AppColors.error,
        ),
    };

    final content = widget.isLoading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(color: fg, strokeWidth: 2.5),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 18, color: fg),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  widget.label,
                  style: AppTextStyles.button.copyWith(color: fg),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );

    final scale = !reduceMotion && _pressed && _enabled ? 0.96 : 1.0;
    final liftShadow = !_pressed && _enabled
        ? [
            BoxShadow(
              color: isDark ? AppColors.shadowSoftDark : AppColors.shadowSoft,
              offset: const Offset(0, 4),
              blurRadius: 10,
            ),
          ]
        : const <BoxShadow>[];

    final button = AnimatedScale(
      scale: scale,
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 100),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        height: widget.fullWidth ? 56 : null,
        padding: widget.fullWidth
            ? null
            : const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: border != null ? Border.all(color: border, width: 2) : null,
          boxShadow: liftShadow,
          gradient: widget.variant == AppButtonVariant.primary
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color.alphaBlend(AppColors.glossHighlight, bg),
                    bgDark,
                  ],
                )
              : null,
          color: widget.variant == AppButtonVariant.primary ? null : bg,
        ),
        alignment: Alignment.center,
        child: content,
      ),
    );

    final result = Opacity(
      opacity: _enabled ? 1.0 : 0.55,
      child: MouseRegion(
        cursor:
            _enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          onTapDown: _enabled ? (_) => _setPressed(true) : null,
          onTapUp: _enabled ? (_) => _setPressed(false) : null,
          onTapCancel: _enabled ? () => _setPressed(false) : null,
          onTap: _enabled ? widget.onPressed : null,
          child: Semantics(
            button: true,
            enabled: _enabled,
            label: widget.label,
            child: button,
          ),
        ),
      ),
    );

    if (!widget.fullWidth) return result;
    return SizedBox(width: double.infinity, child: result);
  }
}
