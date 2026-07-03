import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class ActiveTrendChart extends StatelessWidget {
  final List<Map<String, int>> dailyData;
  const ActiveTrendChart({super.key, required this.dailyData});

  @override
  Widget build(BuildContext context) {
    if (dailyData.isEmpty)
      return Center(child: Text('No data yet', style: AppTextStyles.bodySmall));
    final spots = dailyData
        .asMap()
        .entries
        .map(
            (e) => FlSpot(e.key.toDouble(), (e.value['count'] ?? 0).toDouble()))
        .toList();
    final maxY = spots
        .map((s) => s.y)
        .reduce((a, b) => a > b ? a : b)
        .clamp(1.0, double.infinity);

    return SizedBox(
      height: 160,
      child: LineChart(LineChartData(
        maxY: maxY + 1,
        minY: 0,
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
              color: AppColors.primary.withValues(alpha: 0.1), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
              sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 24,
            getTitlesWidget: (v, _) => Text('${v.toInt()}',
                style: AppTextStyles.bodySmall.copyWith(fontSize: 9)),
          )),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
              sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (v, _) {
              final i = v.toInt();
              if (i % 3 != 0 || i >= dailyData.length) return const SizedBox();
              return Text('D${dailyData[i]['day']}',
                  style: AppTextStyles.bodySmall.copyWith(fontSize: 9));
            },
          )),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: const Color(0xFF00897B),
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
                show: true,
                color: const Color(0xFF00897B).withValues(alpha: 0.1)),
          )
        ],
      )),
    );
  }
}
