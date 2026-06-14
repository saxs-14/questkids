import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/reward_model.dart';

class BadgeEarnedDialog extends StatefulWidget {
  final BadgeModel badge;
  final VoidCallback onDismiss;

  const BadgeEarnedDialog({
    super.key,
    required this.badge,
    required this.onDismiss,
  });

  @override
  State<BadgeEarnedDialog> createState() =>
      _BadgeEarnedDialogState();
}

class _BadgeEarnedDialogState extends State<BadgeEarnedDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600));
    _scaleAnim = Tween<double>(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeIn));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: ScaleTransition(
          scale: _scaleAnim,
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.5),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🎉',
                    style: TextStyle(fontSize: 48)),
                const SizedBox(height: 8),
                Text(
                  'Badge Earned!',
                  style: AppTextStyles.h2
                      .copyWith(color: Colors.white),
                ),
                const SizedBox(height: 24),
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(widget.badge.icon,
                        style: const TextStyle(fontSize: 52)),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.badge.name,
                  style: AppTextStyles.h3
                      .copyWith(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.badge.description,
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                ElevatedButton(
                  onPressed: widget.onDismiss,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    'Awesome! 🚀',
                    style: AppTextStyles.button
                        .copyWith(color: AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
