import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/repositories/leaderboard_repository.dart';
import '../../../data/models/leaderboard_entry_model.dart';
import '../../../providers/auth_provider.dart';
import '../widgets/leaderboard_entry_tile.dart';
import '../widgets/own_rank_banner.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final _repo = LeaderboardRepository();
  late String _grade;
  late String _uid;
  late String _avatarEmoji;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _grade = user?.grade ?? 'Grade 1';
    _uid = user?.uid ?? '';
    _avatarEmoji = user?.avatarEmoji ?? '🦁';
  }

  @override
  Widget build(BuildContext context) {
    return _GradeBoard(
      grade: _grade,
      uid: _uid,
      avatarEmoji: _avatarEmoji,
      repo: _repo,
    );
  }
}

class _GradeBoard extends StatefulWidget {
  final String grade;
  final String uid;
  final String avatarEmoji;
  final LeaderboardRepository repo;

  const _GradeBoard({
    required this.grade,
    required this.uid,
    required this.avatarEmoji,
    required this.repo,
  });

  @override
  State<_GradeBoard> createState() => _GradeBoardState();
}

class _GradeBoardState extends State<_GradeBoard> {
  String _period = 'weekly';
  // null == "Overall" (all subjects combined).
  String? _subject;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              _PeriodChip(
                label: 'This Week',
                selected: _period == 'weekly',
                onTap: () => setState(() => _period = 'weekly'),
              ),
              const SizedBox(width: 8),
              _PeriodChip(
                label: 'All Time',
                selected: _period == 'allTime',
                onTap: () => setState(() => _period = 'allTime'),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _PeriodChip(
                label: 'Overall',
                selected: _subject == null,
                onTap: () => setState(() => _subject = null),
              ),
              for (final subject in AppConstants.subjects) ...[
                const SizedBox(width: 8),
                _PeriodChip(
                  label: subject,
                  selected: _subject == subject,
                  onTap: () => setState(() => _subject = subject),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 4),
        FutureBuilder<int?>(
          future: widget.repo.getOwnRank(widget.uid, widget.grade,
              period: _period, subject: _subject),
          builder: (_, snap) => OwnRankBanner(
            rank: snap.data,
            xp: 0,
            avatarEmoji: widget.avatarEmoji,
          ),
        ),
        Expanded(
          child: StreamBuilder<List<LeaderboardEntry>>(
            stream: widget.repo.watchGradeLeaderboard(widget.grade,
                period: _period, subject: _subject),
            builder: (_, snap) {
              if (snap.hasError) {
                return Center(
                    child: Text('Error loading leaderboard',
                        style: AppTextStyles.bodyMedium));
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final entries = snap.data!;
              if (entries.isEmpty) {
                return _EmptyState(period: _period, grade: widget.grade);
              }
              return ListView.builder(
                padding: const EdgeInsets.only(top: 8, bottom: 24),
                itemCount: entries.length,
                itemBuilder: (_, i) => LeaderboardEntryTile(
                  entry: entries[i],
                  isOwnEntry: entries[i].uid == widget.uid,
                  animationIndex: i,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PeriodChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PeriodChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? AppColors.primary : AppColors.textSecondary),
        ),
        child: Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String period;
  final String grade;

  const _EmptyState({required this.period, required this.grade});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🏆', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 12),
          Text('No rankings yet', style: AppTextStyles.h3),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              period == 'weekly'
                  ? 'Be the first to earn XP this week!'
                  : 'Complete quests to appear on the all-time board!',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
