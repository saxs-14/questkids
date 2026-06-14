import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/quiz_provider.dart';
import '../../dashboard/widgets/subject_chip.dart';
import '../widgets/activity_card.dart';
import 'quiz_screen.dart';

class QuestsScreen extends StatefulWidget {
  final bool embedded;
  const QuestsScreen({super.key, this.embedded = false});

  @override
  State<QuestsScreen> createState() => _QuestsScreenState();
}

class _QuestsScreenState extends State<QuestsScreen> {
  final _subjects = [
    {'label': 'All',             'emoji': '📚', 'color': AppColors.primary},
    {'label': 'Math',            'emoji': '🔢', 'color': AppColors.math},
    {'label': 'Science',         'emoji': '🔬', 'color': AppColors.science},
    {'label': 'English',         'emoji': '📖', 'color': AppColors.english},
    {'label': 'Social Sciences', 'emoji': '🌍',
     'color': AppColors.socialSciences},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().user;
      if (user != null) {
        context.read<QuizProvider>().loadActivities(user.grade);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final quiz = context.watch<QuizProvider>();
    final user = context.read<AuthProvider>().user;

    Widget body;
    if (quiz.state == QuizState.loading) {
      body = const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading quests...'),
          ],
        ),
      );
    } else if (quiz.state == QuizState.error) {
      body = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('😕', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(quiz.errorMessage ?? 'Something went wrong',
                style: AppTextStyles.bodyMedium),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () =>
                  quiz.loadActivities(user?.grade ?? 'Grade 4'),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    } else {
      body = Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: SizedBox(
              height: 44,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _subjects.length,
                itemBuilder: (_, i) {
                  final s = _subjects[i];
                  return SubjectChip(
                    subject: s['label'] as String,
                    emoji: s['emoji'] as String,
                    color: s['color'] as Color,
                    isSelected: quiz.selectedSubject == s['label'],
                    onTap: () =>
                        quiz.setSubjectFilter(s['label'] as String),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  '${quiz.filteredActivities.length} quests available',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
          Expanded(
            child: quiz.filteredActivities.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('🗺️',
                            style: TextStyle(fontSize: 64)),
                        const SizedBox(height: 16),
                        Text('No quests found', style: AppTextStyles.h3),
                        Text(
                          'Try a different subject',
                          style: AppTextStyles.bodyMedium
                              .copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: quiz.filteredActivities.length,
                    itemBuilder: (_, i) {
                      final activity = quiz.filteredActivities[i];
                      return ActivityCard(
                        activity: activity,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ChangeNotifierProvider.value(
                                value: quiz,
                                child:
                                    QuizScreen(activity: activity),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      );
    }

    if (widget.embedded) return body;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quests'),
        automaticallyImplyLeading: false,
      ),
      body: body,
    );
  }
}
