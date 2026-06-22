import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class TimeSpentChart extends StatelessWidget {
  final Map<String, int> timeData;
  const TimeSpentChart({super.key, required this.timeData});

  Color _color(String subject) {
    switch (subject) {
      case 'Mathematics': return AppColors.math;
      case 'Natural Sciences': return AppColors.science;
      case 'English': return AppColors.english;
      case 'Social Sciences': return AppColors.socialSciences;
      case 'Technology': return AppColors.technology;
      default: return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (timeData.isEmpty) return Center(child: Text('No data yet', style: AppTextStyles.bodySmall));
    final sorted = timeData.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final maxMins = (sorted.first.value / 60).ceilToDouble().clamp(1.0, double.infinity);

    return SizedBox(
      height: 160,
      child: BarChart(BarChartData(
        maxY: maxMins,
        barGroups: sorted.asMap().entries.map((e) {
          final mins = e.value.value / 60;
          return BarChartGroupData(x: e.key, barRods: [
            BarChartRodData(
                toY: mins, color: _color(e.value.key), width: 22,
                borderRadius: BorderRadius.circular(6)),
          ]);
        }).toList(),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(
            showTitles: true, reservedSize: 36,
            getTitlesWidget: (v, _) =>
                Text('${v.toInt()}m', style: AppTextStyles.bodySmall.copyWith(fontSize: 9)),
          )),
          bottomTitles: AxisTitles(sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (v, _) {
              final i = v.toInt();
              if (i >= sorted.length) return const SizedBox();
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(sorted[i].key.split(' ').first,
                    style: AppTextStyles.bodySmall.copyWith(fontSize: 10)),
              );
            },
          )),
        ),
        barTouchData: BarTouchData(touchTooltipData: BarTouchTooltipData(
          getTooltipItem: (group, _, rod, __) => BarTooltipItem(
            '${sorted[group.x].key}\n${rod.toY.toInt()} min',
            AppTextStyles.bodySmall.copyWith(color: Colors.white)),
        )),
      )),
    );
  }
}
