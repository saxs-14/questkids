import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Premium-2D card: rounded, soft ambient shadow, optional accent-colored
/// left rail (used throughout the app for subject/category coding, e.g.
/// AppColors.math on a Maths Quest card) and an optional press-scale when
/// [onTap] is given, matching AppButton's press feedback so tappable
/// surfaces feel consistent across the app.
class AppCard extends StatefulWidget {
  final Widget child;
  final Color? accentColor;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;

  const AppCard({
    super.key,
    required this.child,
    this.accentColor,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.margin,
  });

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    final card = AnimatedContainer(
      duration:
          reduceMotion ? Duration.zero : const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      margin: widget.margin,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(20),
        border: widget.accentColor != null
            ? Border(
                left: BorderSide(color: widget.accentColor!, width: 4),
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: isDark ? AppColors.shadowSoftDark : AppColors.shadowSoft,
            offset: const Offset(0, 3),
            blurRadius: 12,
          ),
        ],
      ),
      child: widget.child,
    );

    if (widget.onTap == null) return card;

    return AnimatedScale(
      scale: !reduceMotion && _pressed ? 0.98 : 1.0,
      duration:
          reduceMotion ? Duration.zero : const Duration(milliseconds: 100),
      curve: Curves.easeOut,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: card,
      ),
    );
  }
}
