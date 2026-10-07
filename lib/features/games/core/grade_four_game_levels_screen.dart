import 'package:flutter/material.dart';
import '../../../core/constants/game_catalog.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/game_level_progress_service.dart';
import 'game_config.dart';
import 'game_router.dart';
import 'game_theme.dart';

/// Grade 4 structured 10-level adventure using real catalog game engines.
class GradeFourGameLevelsScreen extends StatefulWidget {
  final UserModel user;
  const GradeFourGameLevelsScreen({super.key, required this.user});

  @override
  State<GradeFourGameLevelsScreen> createState() => _GradeFourGameLevelsScreenState();
}

class _GradeFourGameLevelsScreenState extends State<GradeFourGameLevelsScreen> {
  static const _levelCatalogIds = <String>[
    'math_g4_fractions',
    'math_g4_geometry',
    'math_g4_measurement',
    'math_g4_data',
    'math_g4_decimals',
    'math_g4_multiplication',
    'ns_g4_ecosystem',
    'ns_g4_energy',
    'ss_g4_maps',
    'ss_g4_provinces',
    'ss_g4_climate',
  ];

  final _progressService = GameLevelProgressService();
  GameLevelProgress? _progress;
  bool _loading = true;

  List<GameCatalogEntry> get _entries => _levelCatalogIds.map((id) {
        return GameCatalog.all.firstWhere(
          (entry) => entry.id == id,
          orElse: () => throw StateError('Missing Grade 4 catalog entry: $id'),
        );
      }).toList(growable: false);

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final progress = await _progressService.get(
      widget.user.uid,
      _levelCatalogIds.first,
    );
    if (mounted) {
      setState(() {
        _progress = progress;
        _loading = false;
      });
    }
  }

  Future<void> _playLevel(int level) async {
    final progress =
        _progress ?? GameLevelProgress.fromMap(_levelCatalogIds.first, null);
    if (progress.completed || level != progress.currentLevel) return;

    final entry = _entries[level - 1];
    final config = GameConfig(
      engineType: entry.engineType,
      subject: entry.subject,
      grade: entry.grade,
      topicId: entry.topicId,
      subtopicId: entry.subtopicId,
      difficulty: _difficultyForLevel(level),
      questionCount: 5 + level,
      timeLimitSeconds: 0,
      extras: {
        ...entry.extras,
        'level': level,
        'levelCount': 10,
        'progressionCatalogId': _levelCatalogIds.first,
      },
      catalogId: entry.id,
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
    if (level <= 7) return 'medium';
    return 'hard';
  }

  @override
  Widget build(BuildContext context) {
    final progress =
        _progress ?? GameLevelProgress.fromMap(_levelCatalogIds.first, null);
    final theme = Theme.of(context);
    final entries = _entries;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Grade 4 Adventure'),
        centerTitle: true,
      ),
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
                        colors: [
                          AppColors.primary,
                          AppColors.primary.withValues(alpha: 0.68),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      children: [
                        const Text('🚀', style: TextStyle(fontSize: 52)),
                        const SizedBox(height: 8),
                        Text(
                          '10-Level Grade 4 Quest',
                          style: GameTheme.display(24, color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          progress.completed
                              ? 'Adventure complete! You mastered all 10 levels.'
                              : 'Complete Level ${progress.currentLevel} to unlock the next challenge.',
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
                            valueColor:
                                const AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                      itemCount: 10,
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 250,
                        mainAxisExtent: 174,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemBuilder: (context, index) {
                        final level = index + 1;
                        final entry = entries[index];
                        final unlocked =
                            !progress.completed && level == progress.currentLevel;
                        final completed =
                            level <= progress.highestCompletedLevel;

                        return _GradeFourLevelCard(
                          level: level,
                          entry: entry,
                          completed: completed,
                          unlocked: unlocked,
                          bestScore: completed &&
                                  level == progress.highestCompletedLevel
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

class _GradeFourLevelCard extends StatelessWidget {
  final int level;
  final GameCatalogEntry entry;
  final bool completed;
  final bool unlocked;
  final int? bestScore;
  final VoidCallback? onTap;

  const _GradeFourLevelCard({
    required this.level,
    required this.entry,
    required this.completed,
    required this.unlocked,
    required this.bestScore,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent =
        completed ? AppColors.green : unlocked ? entry.color : Colors.grey;

    return Card(
      elevation: unlocked ? 5 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(entry.emoji, style: const TextStyle(fontSize: 34)),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    completed
                        ? Icons.check_circle_rounded
                        : unlocked
                            ? Icons.play_circle_fill_rounded
                            : Icons.lock_rounded,
                    size: 20,
                    color: accent,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'LEVEL $level',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: accent,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                entry.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                completed
                    ? 'Completed${bestScore == null ? '' : ' • $bestScore%'}'
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
