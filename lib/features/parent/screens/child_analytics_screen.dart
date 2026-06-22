import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/parent_repository.dart';
import '../widgets/mastery_radar_chart.dart';
import '../widgets/score_trend_chart.dart';
import '../widgets/subject_bar_chart.dart';
import '../widgets/time_spent_chart.dart';

class ChildAnalyticsScreen extends StatefulWidget {
  final UserModel child;
  const ChildAnalyticsScreen({super.key, required this.child});

  @override
  State<ChildAnalyticsScreen> createState() => _ChildAnalyticsScreenState();
}

class _ChildAnalyticsScreenState extends State<ChildAnalyticsScreen> {
  final _repo = ParentRepository();
  Map<String, dynamic> _analytics = {};
  Map<String, double> _weeklyTrend = {};
  Map<String, int> _timeSpent = {};
  bool _loading = true;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final now = DateTime.now();
    final from30 = now.subtract(const Duration(days: 30));
    final results = await Future.wait([
      _repo.getChildAnalytics(widget.child.uid, from30, now),
      _repo.getWeeklyScoreTrend(widget.child.uid),
      _repo.getTimeSpentBySubject(widget.child.uid),
    ]);
    if (mounted) {
      setState(() {
        _analytics = Map<String, dynamic>.from(results[0] as Map? ?? {});
        _weeklyTrend = Map<String, double>.from(results[1] as Map? ?? {});
        _timeSpent = Map<String, int>.from(results[2] as Map? ?? {});
        _loading = false;
      });
    }
  }

  Future<void> _exportPdf() async {
    setState(() => _exporting = true);
    try {
      final pdf = pw.Document();
      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('${widget.child.name} — Analytics Report',
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.Text('Grade: ${widget.child.grade} | ${DateTime.now().toString().split('.').first}',
                style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey)),
            pw.SizedBox(height: 20),
            pw.Text('Last 30 Days Summary',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Row(children: [
              pw.Expanded(child: pw.Column(children: [
                pw.Text('Games', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
                pw.Text('${_analytics['totalGames'] ?? 0}',
                    style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              ])),
              pw.Expanded(child: pw.Column(children: [
                pw.Text('Avg Score', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
                pw.Text('${(_analytics['avgScore'] ?? 0.0).toStringAsFixed(1)}%',
                    style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              ])),
              pw.Expanded(child: pw.Column(children: [
                pw.Text('XP Earned', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
                pw.Text('${_analytics['pointsEarned'] ?? 0}',
                    style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              ])),
            ]),
            pw.SizedBox(height: 24),
            pw.Text('Subject Breakdown',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            ...(_analytics['subjectBreakdown'] as Map? ?? {}).entries.map((e) {
              final list = (e.value as List).map((v) => (v as num).toDouble()).toList();
              final avg = list.isEmpty ? 0.0 : list.reduce((a, b) => a + b) / list.length;
              return pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Row(children: [
                  pw.Expanded(child: pw.Text(e.key, style: const pw.TextStyle(fontSize: 11))),
                  pw.Text('${avg.toStringAsFixed(1)}% (${list.length} games)',
                      style: const pw.TextStyle(fontSize: 11)),
                ]),
              );
            }),
          ],
        ),
      ));

      final bytes = await pdf.save();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/questkids_${widget.child.name.replaceAll(' ', '_')}.pdf');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
          [XFile(file.path)], text: 'QuestKids report for ${widget.child.name}');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Widget _chartCard({required String title, required String subtitle, required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E1E2E)
            : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: AppTextStyles.h4),
        Text(subtitle, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 16),
        child,
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final breakdown = Map<String, dynamic>.from(_analytics['subjectBreakdown'] ?? {});

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header row
          Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Center(child: Text(widget.child.avatarEmoji, style: const TextStyle(fontSize: 24))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.child.name, style: AppTextStyles.h3),
              Text('${widget.child.grade} • Last 30 days',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
            ])),
            ElevatedButton.icon(
              onPressed: _exporting ? null : _exportPdf,
              icon: _exporting
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.picture_as_pdf, size: 18),
              label: const Text('PDF'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            ),
          ]),
          const SizedBox(height: 16),

          // Summary chips
          Row(children: [
            _StatChip(label: '${_analytics['totalGames'] ?? 0}', sub: 'Games'),
            const SizedBox(width: 8),
            _StatChip(label: '${(_analytics['avgScore'] ?? 0.0).toStringAsFixed(1)}%', sub: 'Avg Score'),
            const SizedBox(width: 8),
            _StatChip(label: '${_analytics['pointsEarned'] ?? 0}', sub: 'XP'),
          ]),
          const SizedBox(height: 16),

          _chartCard(
            title: 'XP by Subject',
            subtitle: 'Average score per subject (last 30 days)',
            child: SubjectBarChart(breakdown: breakdown),
          ),
          _chartCard(
            title: 'Score Trend',
            subtitle: '8-week rolling average',
            child: ScoreTrendChart(weeklyData: _weeklyTrend),
          ),
          _chartCard(
            title: 'Subject Mastery',
            subtitle: 'All-time performance across core subjects',
            child: MasteryRadarChart(breakdown: breakdown),
          ),
          _chartCard(
            title: 'Time Spent',
            subtitle: 'Minutes per subject (last 30 days)',
            child: TimeSpentChart(timeData: _timeSpent),
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
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: [
          Text(label, style: AppTextStyles.h3.copyWith(color: AppColors.primary)),
          Text(sub, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
        ]),
      ),
    );
  }
}
