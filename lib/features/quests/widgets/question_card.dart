import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/activity_model.dart';

class QuestionCard extends StatefulWidget {
  final QuestionModel question;
  final int? selectedIndex;
  final bool isRevealed;
  final ValueChanged<int> onOptionSelected;

  const QuestionCard({
    super.key,
    required this.question,
    required this.selectedIndex,
    required this.isRevealed,
    required this.onOptionSelected,
  });

  @override
  State<QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<QuestionCard> {
  int? _pressedIndex;

  Color _getOptionColor(int index) {
    if (!widget.isRevealed) {
      return widget.selectedIndex == index
          ? AppColors.primary
          : Colors.transparent;
    }
    if (index == widget.question.correctIndex) return AppColors.green;
    if (index == widget.selectedIndex) return AppColors.error;
    return Colors.transparent;
  }

  Color _getOptionTextColor(int index) {
    if (!widget.isRevealed && widget.selectedIndex == index)
      return Colors.white;
    if (widget.isRevealed && index == widget.question.correctIndex)
      return Colors.white;
    if (widget.isRevealed &&
        index == widget.selectedIndex &&
        index != widget.question.correctIndex) {
      return Colors.white;
    }
    return AppColors.textPrimary;
  }

  Widget _getOptionIcon(int index) {
    if (!widget.isRevealed) {
      return Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: widget.selectedIndex == index
                ? Colors.white
                : AppColors.primary.withValues(alpha: 0.3),
            width: 2,
          ),
          color: widget.selectedIndex == index
              ? Colors.white.withValues(alpha: 0.2)
              : Colors.transparent,
        ),
        child: Center(
          child: Text(
            ['A', 'B', 'C', 'D'][index],
            style: TextStyle(
              color: widget.selectedIndex == index
                  ? Colors.white
                  : AppColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      );
    }
    if (index == widget.question.correctIndex) {
      return const Icon(Icons.check_circle, color: Colors.white, size: 28);
    }
    if (index == widget.selectedIndex) {
      return const Icon(Icons.cancel, color: Colors.white, size: 28);
    }
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
            color: AppColors.textSecondary.withValues(alpha: 0.3), width: 2),
      ),
      child: Center(
        child: Text(
          ['A', 'B', 'C', 'D'][index],
          style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 13),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Question text box
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: Text(
            widget.question.question,
            style: AppTextStyles.h4,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 20),

        // Answer options with press-scale bounce
        ...List.generate(widget.question.options.length, (i) {
          final isPressed = _pressedIndex == i;
          return GestureDetector(
            onTapDown: widget.isRevealed
                ? null
                : (_) => setState(() => _pressedIndex = i),
            onTapUp: widget.isRevealed
                ? null
                : (_) {
                    setState(() => _pressedIndex = null);
                    widget.onOptionSelected(i);
                  },
            onTapCancel: () => setState(() => _pressedIndex = null),
            child: AnimatedScale(
              scale: isPressed ? 0.95 : 1.0,
              duration: const Duration(milliseconds: 100),
              curve: Curves.easeInOut,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _getOptionColor(i),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: widget.isRevealed
                        ? (i == widget.question.correctIndex
                            ? AppColors.green
                            : i == widget.selectedIndex
                                ? AppColors.error
                                : AppColors.primary.withValues(alpha: 0.1))
                        : (widget.selectedIndex == i
                            ? AppColors.primary
                            : AppColors.primary.withValues(alpha: 0.2)),
                    width: 2,
                  ),
                  boxShadow: isPressed
                      ? []
                      : [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                child: Row(
                  children: [
                    _getOptionIcon(i),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.question.options[i],
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: _getOptionTextColor(i),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),

        // Explanation box
        if (widget.isRevealed && widget.question.explanation != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.blue.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('💡', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.question.explanation!,
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.blue),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
