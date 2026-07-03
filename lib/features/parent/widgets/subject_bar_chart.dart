import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class SubjectBarChart extends StatelessWidget {
  final Map<String, dynamic> breakdown;
  const SubjectBarChart({super.key, required this.breakdown});

  Color _color(String subject) {
    switch (subject) {
      case 'Mathematics':
        return AppColors.math;
      case 'Natural Sciences':
        return AppColors.science;
      case 'English':
        return AppColors.english;
      case 'Social Sciences':
        return AppColors.socialSciences;
      case 'Technology':
        return AppColors.technology;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (breakdown.isEmpty)
      return Center(child: Text('No data yet', style: AppTextStyles.bodySmall));
    final entries = breakdown.entries.toList();
    final groups = entries.asMap().entries.map((e) {
      final subj = e.value.key;
      final list =
          (e.value.value as List).map((v) => (v as num).toDouble()).toList();
      final avg =
          list.isEmpty ? 0.0 : list.reduce((a, b) => a + b) / list.length;
      return BarChartGroupData(x: e.key, barRods: [
        BarChartRodData(
            toY: avg,
            color: _color(subj),
            width: 18,
            borderRadius: BorderRadius.circular(6)),
      ]);
    }).toList();

    return SizedBox(
      height: 180,
      child: BarChart(BarChartData(
        maxY: 100,
        barGroups: groups,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
              sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (v, _) {
              final i = v.toInt();
              if (i >= entries.length) return const SizedBox();
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(entries[i].key.split(' ').first,
                    style: AppTextStyles.bodySmall.copyWith(fontSize: 10)),
              );
            },
          )),
        ),
        barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
          getTooltipItem: (g, _, r, __) => BarTooltipItem(
              '${entries[g.x].key}\n${r.toY.toStringAsFixed(1)}%',
              AppTextStyles.bodySmall.copyWith(color: Colors.white)),
        )),
      )),
    );
  }
}
