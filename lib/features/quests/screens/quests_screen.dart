import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/quiz_provider.dart';
import '../../dashboard/widgets/subject_chip.dart';
import '../../games/core/game_config.dart';
import '../../games/core/game_router.dart';
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

  // ── Game Zone entries grouped by subject ─────────────────────────────────────
  static const _gameZone = [
    _GameEntry(
      subject: 'Mathematics',
      subjectEmoji: '🔢',
      subjectColor: AppColors.math,
      title: 'Multiplication Tug of War',
      description: 'Race against the AI — answer multiplication tables faster!',
      engineEmoji: '🪢',
      configPreset: _Preset.tugOfWar,
    ),
    _GameEntry(
      subject: 'Natural Sciences',
      subjectEmoji: '🔬',
      subjectColor: AppColors.science,
      title: 'Water Cycle Adventure',
      description: 'Guide a water droplet through the water cycle stages.',
      engineEmoji: '💧',
      configPreset: _Preset.waterCycle,
    ),
    _GameEntry(
      subject: 'English',
      subjectEmoji: '📖',
      subjectColor: AppColors.english,
      title: 'Grammar Hero Run',
      description: 'Run and collect the right parts of speech before time runs out!',
      engineEmoji: '🏃',
      configPreset: _Preset.grammarHero,
    ),
    _GameEntry(
      subject: 'Social Sciences',
      subjectEmoji: '🌍',
      subjectColor: AppColors.socialSciences,
      title: 'SA Provinces Explorer',
      description: 'Test your knowledge of South Africa\'s 9 provinces.',
      engineEmoji: '🗺️',
      configPreset: _Preset.saProvinces,
    ),
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

  void _launchGame(_GameEntry entry, String grade) {
    final config = switch (entry.configPreset) {
      _Preset.tugOfWar => GameConfig.multiplicationTables(grade: grade),
      _Preset.waterCycle => GameConfig.waterCycle,
      _Preset.grammarHero => GameConfig.partsOfSpeech,
      _Preset.saProvinces => GameConfig.saProvinces,
    };
    final user = context.read<AuthProvider>().user;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GameRouter(config: config, user: user),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final quiz = context.watch<QuizProvider>();
    final user = context.read<AuthProvider>().user;
    final grade = user?.grade ?? 'grade4';

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
              onPressed: () => quiz.loadActivities(user?.grade ?? 'Grade 4'),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    } else {
      body = Column(
        children: [
          // Subject filter chips
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
                    onTap: () => quiz.setSubjectFilter(s['label'] as String),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              children: [
                // ── Game Zone ─────────────────────────────────────────────────
                const _SectionHeader(
                  title: '🎮 Game Zone',
                  subtitle: 'Interactive games by subject',
                ),
                const SizedBox(height: 8),
                ..._buildGameZone(grade),
                const SizedBox(height: 20),
                // ── Quests ────────────────────────────────────────────────────
                _SectionHeader(
                  title: '📋 Quests',
                  subtitle:
                      '${quiz.filteredActivities.length} available',
                ),
                const SizedBox(height: 8),
                if (quiz.filteredActivities.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Column(
                        children: [
                          const Text('🗺️', style: TextStyle(fontSize: 48)),
                          const SizedBox(height: 12),
                          Text('No quests found', style: AppTextStyles.h3),
                          Text(
                            'Try a different subject',
                            style: AppTextStyles.bodyMedium
                                .copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...quiz.filteredActivities.map(
                    (activity) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ActivityCard(
                        activity: activity,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChangeNotifierProvider.value(
                                value: quiz,
                                child: QuizScreen(activity: activity),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
              ],
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

  List<Widget> _buildGameZone(String grade) {
    final filter = context.read<QuizProvider>().selectedSubject;
    final entries = filter == 'All'
        ? _gameZone
        : _gameZone.where((e) {
            return switch (filter) {
              'Math' => e.subject == 'Mathematics',
              'Science' => e.subject == 'Natural Sciences',
              'English' => e.subject == 'English',
              'Social Sciences' => e.subject == 'Social Sciences',
              _ => true,
            };
          }).toList();

    if (entries.isEmpty) return [];

    // Group by subject
    final grouped = <String, List<_GameEntry>>{};
    for (final e in entries) {
      grouped.putIfAbsent(e.subject, () => []).add(e);
    }

    final widgets = <Widget>[];
    for (final subject in grouped.keys) {
      final group = grouped[subject]!;
      final color = group.first.subjectColor;
      final emoji = group.first.subjectEmoji;

      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 6, top: 4),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text(
                subject,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );

      for (final entry in group) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _GameCard(
              entry: entry,
              onTap: () => _launchGame(entry, grade),
            ),
          ),
        );
      }
    }
    return widgets;
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(title,
            style: AppTextStyles.h3
                .copyWith(color: AppColors.textPrimary)),
        const SizedBox(width: 8),
        Text(subtitle,
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary)),
      ],
    );
  }
}

// ── Game card ─────────────────────────────────────────────────────────────────

class _GameCard extends StatelessWidget {
  final _GameEntry entry;
  final VoidCallback onTap;
  const _GameCard({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: entry.subjectColor.withAlpha(18),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: entry.subjectColor.withAlpha(80)),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: entry.subjectColor.withAlpha(40),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    entry.engineEmoji,
                    style: const TextStyle(fontSize: 26),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      entry.description,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Icon(Icons.play_circle_filled,
                  color: entry.subjectColor, size: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Data types ────────────────────────────────────────────────────────────────

enum _Preset { tugOfWar, waterCycle, grammarHero, saProvinces }

class _GameEntry {
  final String subject;
  final String subjectEmoji;
  final Color subjectColor;
  final String title;
  final String description;
  final String engineEmoji;
  final _Preset configPreset;

  const _GameEntry({
    required this.subject,
    required this.subjectEmoji,
    required this.subjectColor,
    required this.title,
    required this.description,
    required this.engineEmoji,
    required this.configPreset,
  });
}
