import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Chunky animated progress bar for XP-to-next-level, Trail completion,
/// and similar "fraction done" displays. [value] is 0.0-1.0; the fill
/// animates to the new value whenever it changes rather than snapping,
/// so gaining XP reads as visible progress.
class AppProgressBar extends StatelessWidget {
  final double value;
  final Color? color;
  final double height;
  final String? label;

  const AppProgressBar({
    super.key,
    required this.value,
    this.color,
    this.height = 14,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final fillColor = color ?? AppColors.primary;
    final clamped = value.clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label!, style: AppTextStyles.bodySmall),
          const SizedBox(height: 6),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(height),
          child: Container(
            height: height,
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : fillColor.withValues(alpha: 0.15),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: clamped),
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                builder: (context, animatedValue, _) => FractionallySizedBox(
                  widthFactor: animatedValue,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(height),
                      gradient: LinearGradient(
                        colors: [
                          Color.alphaBlend(
                              AppColors.glossHighlight, fillColor),
                          fillColor,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Circular variant for compact HUD placements (e.g. a level ring around
/// an avatar). Same animate-on-change behaviour as [AppProgressBar].
class AppProgressRing extends StatelessWidget {
  final double value;
  final double size;
  final double strokeWidth;
  final Color? color;
  final Widget? child;

  const AppProgressRing({
    super.key,
    required this.value,
    this.size = 56,
    this.strokeWidth = 5,
    this.color,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final ringColor = color ?? AppColors.primary;
    final clamped = value.clamp(0.0, 1.0);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: 1,
              strokeWidth: strokeWidth,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : ringColor.withValues(alpha: 0.15),
            ),
          ),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: clamped),
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, animatedValue, _) => SizedBox.expand(
              child: CircularProgressIndicator(
                value: animatedValue,
                strokeWidth: strokeWidth,
                strokeCap: StrokeCap.round,
                color: ringColor,
              ),
            ),
          ),
          if (child != null) child!,
        ],
      ),
    );
  }
}
