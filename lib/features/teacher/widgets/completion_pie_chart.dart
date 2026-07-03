import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class CompletionPieChart extends StatelessWidget {
  final int completed;
  final int attempted;
  const CompletionPieChart(
      {super.key, required this.completed, required this.attempted});

  @override
  Widget build(BuildContext context) {
    if (attempted == 0)
      return Center(child: Text('No data yet', style: AppTextStyles.bodySmall));
    final failed = (attempted - completed).clamp(0, attempted);
    final pct = (completed / attempted * 100).toStringAsFixed(1);

    return SizedBox(
      height: 180,
      child: PieChart(PieChartData(
        sections: [
          PieChartSectionData(
              value: completed.toDouble(),
              color: AppColors.primary,
              title: 'Done\n$pct%',
              titleStyle: AppTextStyles.bodySmall
                  .copyWith(color: Colors.white, fontSize: 11),
              radius: 70),
          PieChartSectionData(
              value: failed.toDouble(),
              color: AppColors.primary.withValues(alpha: 0.2),
              title: 'Incomplete',
              titleStyle: AppTextStyles.bodySmall.copyWith(fontSize: 10),
              radius: 60),
        ],
        sectionsSpace: 2,
        centerSpaceRadius: 30,
      )),
    );
  }
}
