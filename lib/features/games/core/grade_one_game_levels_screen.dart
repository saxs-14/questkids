import 'package:flutter/material.dart';

import '../../../core/constants/game_catalog.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/game_level_progress_service.dart';
import '../../../data/models/user_model.dart';
import 'game_config.dart';
import 'game_router.dart';
import 'game_theme.dart';

class GradeOneGameLevelsScreen extends StatefulWidget {
  final GameCatalogEntry entry;
  final UserModel user;

  const GradeOneGameLevelsScreen({
    super.key,
    required this.entry,
    required this.user,
  });

  @override
  State<GradeOneGameLevelsScreen> createState() => _GradeOneGameLevelsScreenState();
}

class _GradeOneGameLevelsScreenState extends State<GradeOneGameLevelsScreen> {
  final _progressService = GameLevelProgressService();
  GameLevelProgress? _progress;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final progress = await _progressService.get(widget.user.uid, widget.entry.id);
    if (mounted) {
      setState(() {
        _progress = progress;
        _loading = false;
      });
    }
  }

  Future<void> _playLevel(int level) async {
    final progress = _progress ?? GameLevelProgress.fromMap(widget.entry.id, null);
    if (level != progress.currentLevel || progress.completed) return;

    final config = GameConfig(
      engineType: widget.entry.engineType,
      subject: widget.entry.subject,
      grade: widget.entry.grade,
      topicId: widget.entry.topicId,
      subtopicId: widget.entry.subtopicId,
      difficulty: _difficultyForLevel(level),
      questionCount: 5 + level,
      timeLimitSeconds: 0,
      extras: {
        ...widget.entry.extras,
        'level': level,
        'levelCount': 10,
      },
      catalogId: widget.entry.id,
    );

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          body: SafeArea(
            child: GameRouter(config: config, user: widget.user),
          ),
        ),
      ),
    );

    await _loadProgress();
  }

  String _difficultyForLevel(int level) {
    if (level <= 3) return 'easy';
    if (level <= 6) return 'medium';
    return 'hard';
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final progress = _progress ?? GameLevelProgress.fromMap(entry.id, null);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: Text(entry.title), centerTitle: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [entry.color, entry.color.withValues(alpha: 0.70)],
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      children: [
                        Text(entry.emoji, style: const TextStyle(fontSize: 52)),
                        const SizedBox(height: 8),
                        Text(
                          '10-Level Adventure',
                          style: GameTheme.display(24, color: Colors.white),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          progress.completed
                              ? 'All 10 levels completed!'
                              : 'Level ' + progress.currentLevel.toString() +
                                  ' is ready. Complete each level to unlock the next.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 14),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            minHeight: 9,
                            value: progress.highestCompletedLevel / 10,
                            backgroundColor: Colors.white30,
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                      itemCount: 10,
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 230,
                        mainAxisExtent: 150,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemBuilder: (context, index) {
                        final level = index + 1;
                        final unlocked = !progress.completed && level == progress.currentLevel;
                        final completed = level <= progress.highestCompletedLevel;
                        return _LevelCard(
                          level: level,
                          completed: completed,
                          unlocked: unlocked,
                          bestScore: completed && level == progress.highestCompletedLevel
                              ? progress.bestScore
                              : null,
                          onTap: unlocked ? () => _playLevel(level) : null,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  final int level;
  final bool completed;
  final bool unlocked;
  final int? bestScore;
  final VoidCallback? onTap;

  const _LevelCard({
    required this.level,
    required this.completed,
    required this.unlocked,
    required this.bestScore,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = completed
        ? AppColors.green
        : unlocked
            ? AppColors.primary
            : Colors.grey;

    return Card(
      elevation: unlocked ? 5 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                completed
                    ? Icons.check_circle_rounded
                    : unlocked
                        ? Icons.play_circle_fill_rounded
                        : Icons.lock_rounded,
                size: 34,
                color: accent,
              ),
              const SizedBox(height: 8),
              Text(
                'LEVEL ' + level.toString(),
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: accent,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                completed
                    ? 'Completed' + (bestScore == null ? '' : ' • ' + bestScore.toString() + '%')
                    : unlocked
                        ? 'Tap to play'
                        : 'Locked',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
