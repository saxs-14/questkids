import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_text_styles.dart';

class TeacherInsightCard extends StatefulWidget {
  final Map<String, dynamic> classData;
  const TeacherInsightCard({super.key, required this.classData});

  @override
  State<TeacherInsightCard> createState() => _TeacherInsightCardState();
}

class _TeacherInsightCardState extends State<TeacherInsightCard> {
  String? _insight;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final fn = FirebaseFunctions.instanceFor(region: 'us-central1');
      final result = await fn.httpsCallable('getTeacherInsight').call({
        'subjectAvg': widget.classData['subjectAvg'] ?? {},
        'totalLearners': widget.classData['totalLearners'] ?? 0,
        'completionRate': widget.classData['completionRate'] ?? 0,
        'weakTopics': (widget.classData['weakTopics'] as List?)
                ?.map((w) => (w as Map)['subject'])
                .toList() ??
            [],
      });
      if (mounted) {
        setState(() {
          _insight = (result.data as Map)['text'] as String?;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _insight = 'Review the subject breakdown above to identify learners who need extra support.';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF5C35F5), Color(0xFF7C3AED)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('🤖', style: TextStyle(fontSize: 28)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('AI Class Insight',
              style: AppTextStyles.h4.copyWith(color: Colors.white)),
          const SizedBox(height: 4),
          if (_loading)
            const LinearProgressIndicator(
                backgroundColor: Colors.white24, color: Colors.white)
          else
            Text(_insight ?? 'No insight available.',
                style: AppTextStyles.bodySmall.copyWith(color: Colors.white70)),
        ])),
      ]),
    );
  }
}
