import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class ScoreTrendChart extends StatelessWidget {
  final Map<String, double> weeklyData;
  const ScoreTrendChart({super.key, required this.weeklyData});

  @override
  Widget build(BuildContext context) {
    if (weeklyData.isEmpty) return Center(child: Text('No data yet', style: AppTextStyles.bodySmall));
    final keys = weeklyData.keys.toList();
    final spots = weeklyData.entries.toList().asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.value))
        .toList();

    return SizedBox(
      height: 180,
      child: LineChart(LineChartData(
        maxY: 100,
        minY: 0,
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: 25,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: AppColors.primary.withValues(alpha: 0.1), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(
            showTitles: true, reservedSize: 30, interval: 25,
            getTitlesWidget: (v, _) =>
                Text('${v.toInt()}%', style: AppTextStyles.bodySmall.copyWith(fontSize: 9)),
          )),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (v, _) {
              final i = v.toInt();
              if (i < 0 || i >= keys.length) return const SizedBox();
              return Text(keys[i], style: AppTextStyles.bodySmall.copyWith(fontSize: 9));
            },
          )),
        ),
        lineBarsData: [LineChartBarData(
          spots: spots,
          isCurved: true,
          color: AppColors.primary,
          barWidth: 3,
          dotData: FlDotData(getDotPainter: (_, __, ___, ____) =>
              FlDotCirclePainter(radius: 4, color: AppColors.primary)),
          belowBarData: BarAreaData(
              show: true, color: AppColors.primary.withValues(alpha: 0.1)),
        )],
      )),
    );
  }
}
