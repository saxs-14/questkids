import 'package:flutter/material.dart';

import '../../../core/theme/app_text_styles.dart';

class WeakTopicList extends StatelessWidget {
  final List<Map<String, dynamic>> weakTopics;
  const WeakTopicList({super.key, required this.weakTopics});

  @override
  Widget build(BuildContext context) {
    if (weakTopics.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          const Text('✅', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Text('All subjects above 60% — great class performance!',
              style: AppTextStyles.bodyMedium),
        ]),
      );
    }

    return Column(
      children: weakTopics.map((t) {
        final avg = (t['avg'] as double);
        final color = avg < 40 ? Colors.red.shade400 : Colors.amber.shade600;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(children: [
            Text(avg < 40 ? '🔴' : '🟡', style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(
                child: Text(t['subject'] as String? ?? '',
                    style: AppTextStyles.bodyMedium
                        .copyWith(fontWeight: FontWeight.w600))),
            Text('${avg.toStringAsFixed(1)}%',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: color, fontWeight: FontWeight.w700)),
          ]),
        );
      }).toList(),
    );
  }
}
