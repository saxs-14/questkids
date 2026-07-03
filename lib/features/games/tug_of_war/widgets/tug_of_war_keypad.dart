import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Numeric keypad for Tug of War.
///
/// Layout (3 columns):
///   1  2  3
///   4  5  6
///   7  8  9
///   ❌  0  ✅
///
/// [lastAnswerCorrect] drives the ✅ button flash:
///   null  = default colour
///   true  = green flash
///   false = red flash
class TugOfWarKeypad extends StatelessWidget {
  final String currentInput;
  final bool enabled;
  final ValueChanged<String> onDigit;
  final VoidCallback onClear;
  final VoidCallback onConfirm;
  final bool? lastAnswerCorrect;

  const TugOfWarKeypad({
    super.key,
    required this.currentInput,
    required this.onDigit,
    required this.onClear,
    required this.onConfirm,
    this.enabled = true,
    this.lastAnswerCorrect,
  });

  @override
  Widget build(BuildContext context) {
    final confirmColor = switch (lastAnswerCorrect) {
      true => AppColors.green,
      false => AppColors.error,
      _ => AppColors.blue,
    };

    return Column(
      children: [
        // Answer display
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: enabled ? Colors.white : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: switch (lastAnswerCorrect) {
                true => AppColors.green,
                false => AppColors.error,
                _ => Colors.grey.shade300,
              },
              width: 2,
            ),
          ),
          child: Text(
            currentInput.isEmpty ? '—' : currentInput,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: enabled ? AppColors.textPrimary : AppColors.textSecondary,
              letterSpacing: 4,
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Keys grid
        for (final row in _rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: row.map((key) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: _KeyButton(
                      label: key,
                      enabled: enabled,
                      color: switch (key) {
                        '❌' => AppColors.error,
                        '✅' => confirmColor,
                        _ => AppColors.blue.withAlpha(220),
                      },
                      onTap: () {
                        if (!enabled) return;
                        switch (key) {
                          case '❌':
                            onClear();
                          case '✅':
                            onConfirm();
                          default:
                            onDigit(key);
                        }
                      },
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  static const _rows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['❌', '0', '✅'],
  ];
}

class _KeyButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final Color color;
  final VoidCallback onTap;

  const _KeyButton({
    required this.label,
    required this.enabled,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled ? color : Colors.grey.shade300,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 48,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: label.length == 1 ? 20 : 18,
                fontWeight: FontWeight.bold,
                color: enabled ? Colors.white : Colors.grey.shade600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
