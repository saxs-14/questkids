import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_text_styles.dart';

class ClassSubjectChart extends StatelessWidget {
  final Map<String, double> subjectAvg;
  const ClassSubjectChart({super.key, required this.subjectAvg});

  Color _barColor(double avg) {
    if (avg < 60) return Colors.red.shade400;
    if (avg < 80) return Colors.amber.shade600;
    return Colors.green.shade500;
  }

  @override
  Widget build(BuildContext context) {
    if (subjectAvg.isEmpty) return Center(child: Text('No data yet', style: AppTextStyles.bodySmall));
    final entries = subjectAvg.entries.toList();
    return SizedBox(
      height: 180,
      child: BarChart(BarChartData(
        maxY: 100,
        barGroups: entries.asMap().entries.map((e) => BarChartGroupData(
          x: e.key,
          barRods: [BarChartRodData(
              toY: e.value.value, color: _barColor(e.value.value),
              width: 20, borderRadius: BorderRadius.circular(6))],
        )).toList(),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true,
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
        barTouchData: BarTouchData(touchTooltipData: BarTouchTooltipData(
          getTooltipItem: (g, _, r, __) => BarTooltipItem(
            '${entries[g.x].key}\n${r.toY.toStringAsFixed(1)}%',
            AppTextStyles.bodySmall.copyWith(color: Colors.white)),
        )),
      )),
    );
  }
}
