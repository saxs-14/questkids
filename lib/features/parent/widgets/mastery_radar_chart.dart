import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class MasteryRadarChart extends StatelessWidget {
  final Map<String, dynamic> breakdown;
  const MasteryRadarChart({super.key, required this.breakdown});

  @override
  Widget build(BuildContext context) {
    const subjects = [
      'Mathematics',
      'English',
      'Natural Sciences',
      'Social Sciences',
      'Technology'
    ];
    final values = subjects.map((s) {
      final list =
          (breakdown[s] as List?)?.map((v) => (v as num).toDouble()).toList() ??
              [];
      if (list.isEmpty) return 0.0;
      return (list.reduce((a, b) => a + b) / list.length).clamp(0.0, 100.0);
    }).toList();

    return SizedBox(
      height: 220,
      child: RadarChart(RadarChartData(
        dataSets: [
          RadarDataSet(
            dataEntries: values.map((v) => RadarEntry(value: v)).toList(),
            fillColor: AppColors.primary.withValues(alpha: 0.2),
            borderColor: AppColors.primary,
            borderWidth: 2,
            entryRadius: 3,
          )
        ],
        radarShape: RadarShape.polygon,
        radarBackgroundColor: Colors.transparent,
        borderData: FlBorderData(show: false),
        radarBorderData: const BorderSide(color: Colors.transparent),
        titlePositionPercentageOffset: 0.2,
        getTitle: (i, angle) {
          if (i >= subjects.length) return const RadarChartTitle(text: '');
          return RadarChartTitle(text: subjects[i].split(' ').first, angle: 0);
        },
        titleTextStyle: AppTextStyles.bodySmall.copyWith(fontSize: 10),
        tickCount: 4,
        ticksTextStyle: AppTextStyles.bodySmall
            .copyWith(fontSize: 8, color: AppColors.textSecondary),
        tickBorderData: const BorderSide(color: Colors.transparent),
        gridBorderData: BorderSide(
            color: AppColors.primary.withValues(alpha: 0.2), width: 1),
      )),
    );
  }
}
