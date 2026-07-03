import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/repositories/teacher_repository.dart';
import '../widgets/active_trend_chart.dart';
import '../widgets/class_subject_chart.dart';
import '../widgets/completion_pie_chart.dart';
import '../widgets/teacher_insight_card.dart';
import '../widgets/weak_topic_list.dart';

class ClassAnalyticsScreen extends StatefulWidget {
  final String teacherUid;
  const ClassAnalyticsScreen({super.key, required this.teacherUid});

  @override
  State<ClassAnalyticsScreen> createState() => _ClassAnalyticsScreenState();
}

class _ClassAnalyticsScreenState extends State<ClassAnalyticsScreen> {
  final _repo = TeacherRepository();
  Map<String, dynamic> _classData = {};
  List<Map<String, int>> _dailyActive = [];
  bool _loading = true;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      _repo.getClassAnalytics(widget.teacherUid),
      _repo.getDailyActiveLearners(widget.teacherUid),
    ]);
    if (mounted) {
      setState(() {
        _classData = results[0] as Map<String, dynamic>;
        _dailyActive = results[1] as List<Map<String, int>>;
        _loading = false;
      });
    }
  }

  Future<void> _exportCsv() async {
    setState(() => _exporting = true);
    try {
      final rows = await _repo.exportClassProgress(widget.teacherUid);
      final csv = const ListToCsvConverter().convert([
        ['Name', 'Grade', 'Subject', 'Score', 'XP', 'Date', 'Time (s)'],
        ...rows.map((r) => [
              r['name'],
              r['grade'],
              r['subject'],
              r['score'],
              r['xp'],
              r['date'],
              r['timeSecs']
            ]),
      ]);
      if (kIsWeb) {
        final bytes = Uint8List.fromList(utf8.encode(csv));
        await Share.shareXFiles([
          XFile.fromData(bytes,
              name: 'class_progress.csv', mimeType: 'text/csv')
        ]);
      } else {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/class_progress.csv');
        await file.writeAsString(csv);
        await Share.shareXFiles([XFile(file.path)]);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Widget _card(
      {required String title,
      required String subtitle,
      required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E1E2E)
            : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: AppTextStyles.h4),
        Text(subtitle,
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 16),
        child,
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final subjectAvg = Map<String, double>.from(_classData['subjectAvg'] ?? {});
    final weakTopics =
        List<Map<String, dynamic>>.from(_classData['weakTopics'] ?? []);
    final completed = (_classData['totalCompleted'] as int?) ?? 0;
    final attempted = (_classData['totalAttempted'] as int?) ?? 0;

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _StatChip(
                label: '${_classData['totalLearners'] ?? 0}', sub: 'Learners'),
            const SizedBox(width: 8),
            _StatChip(label: '$attempted', sub: 'Quests'),
            const SizedBox(width: 8),
            _StatChip(
              label:
                  '${((_classData['completionRate'] ?? 0.0) * 100).toStringAsFixed(0)}%',
              sub: 'Completion',
            ),
          ]),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            OutlinedButton.icon(
              onPressed: _exporting ? null : _exportCsv,
              icon: _exporting
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.file_present, size: 18),
              label: const Text('Export CSV'),
            ),
          ]),
          const SizedBox(height: 12),
          TeacherInsightCard(classData: _classData),
          const SizedBox(height: 16),
          _card(
            title: 'Class Average by Subject',
            subtitle: 'Red <60%, Amber 60–79%, Green 80%+',
            child: ClassSubjectChart(subjectAvg: subjectAvg),
          ),
          _card(
            title: 'Quest Completion Rate',
            subtitle: 'Last 30 days',
            child:
                CompletionPieChart(completed: completed, attempted: attempted),
          ),
          _card(
            title: 'Weak Topics',
            subtitle: 'Subjects where class average is below 60%',
            child: WeakTopicList(weakTopics: weakTopics),
          ),
          _card(
            title: 'Active Learners Daily',
            subtitle: 'Learners who completed at least 1 quest (last 14 days)',
            child: ActiveTrendChart(dailyData: _dailyActive),
          ),
        ]),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String sub;
  const _StatChip({required this.label, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: [
          Text(label,
              style: AppTextStyles.h3
                  .copyWith(color: AppColors.primary, fontSize: 18)),
          Text(sub,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary, fontSize: 11)),
        ]),
      ),
    );
  }
}
