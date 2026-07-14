import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/repositories/leaderboard_repository.dart';
import '../../../data/models/leaderboard_entry_model.dart';
import '../../../providers/auth_provider.dart';
import '../widgets/leaderboard_entry_tile.dart';
import '../widgets/own_rank_banner.dart';

class LeaderboardScreen extends StatefulWidget {
  /// When set, shows only the "My Class" board for this teacher, bypassing
  /// AuthProvider (a teacher isn't a learner, so has no grade/own rank) --
  /// used by the Teacher Dashboard's "View Leaderboard" quick action.
  final String? teacherUid;

  const LeaderboardScreen({super.key, this.teacherUid});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _repo = LeaderboardRepository();
  late String _grade;
  late String _uid;
  late String _avatarEmoji;
  String? _teacherUid;

  @override
  void initState() {
    super.initState();
    if (widget.teacherUid != null) {
      _grade = '';
      _uid = '';
      _avatarEmoji = '👩‍🏫';
      _teacherUid = widget.teacherUid;
      _tabCtrl = TabController(length: 1, vsync: this);
    } else {
      final user = context.read<AuthProvider>().user;
      _grade = user?.grade ?? 'Grade 1';
      _uid = user?.uid ?? '';
      _avatarEmoji = user?.avatarEmoji ?? '🦁';
      _teacherUid = user?.linkedTeacherUid;
      _tabCtrl =
          TabController(length: _teacherUid != null ? 2 : 1, vsync: this);
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: AppColors.primary,
          child: TabBar(
            controller: _tabCtrl,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            indicatorColor: Colors.white,
            tabs: [
              if (widget.teacherUid == null) const Tab(text: 'Grade'),
              if (_teacherUid != null) const Tab(text: 'My Class'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              if (widget.teacherUid == null)
                _GradeBoard(
                  grade: _grade,
                  uid: _uid,
                  avatarEmoji: _avatarEmoji,
                  repo: _repo,
                ),
              if (_teacherUid != null)
                _ClassBoard(
                  teacherUid: _teacherUid!,
                  uid: _uid,
                  avatarEmoji: _avatarEmoji,
                  repo: _repo,
                ),
            ],
          ),
        ),
      ],
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
        FutureBuilder<int?>(
          future:
              widget.repo.getOwnRank(widget.uid, widget.grade, period: _period),
          builder: (_, snap) => OwnRankBanner(
            rank: snap.data,
            xp: 0,
            avatarEmoji: widget.avatarEmoji,
          ),
        ),
        Expanded(
          child: StreamBuilder<List<LeaderboardEntry>>(
            stream: widget.repo
                .watchGradeLeaderboard(widget.grade, period: _period),
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

class _ClassBoard extends StatelessWidget {
  final String teacherUid;
  final String uid;
  final String avatarEmoji;
  final LeaderboardRepository repo;

  const _ClassBoard({
    required this.teacherUid,
    required this.uid,
    required this.avatarEmoji,
    required this.repo,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<LeaderboardEntry>>(
      stream: repo.watchClassLeaderboard(teacherUid),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final entries = snap.data!;
        if (entries.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🏫', style: TextStyle(fontSize: 56)),
                const SizedBox(height: 12),
                Text('No classmates yet', style: AppTextStyles.h3),
                Text(
                  'Your class leaderboard will appear here.',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          );
        }
        final ownRaw = entries.where((e) => e.uid == uid);
        final ownEntry = ownRaw.isNotEmpty ? ownRaw.first : null;
        return Column(
          children: [
            const SizedBox(height: 8),
            OwnRankBanner(
              rank: ownEntry?.rank,
              xp: ownEntry?.xp ?? 0,
              avatarEmoji: avatarEmoji,
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(top: 8, bottom: 24),
                itemCount: entries.length,
                itemBuilder: (_, i) => LeaderboardEntryTile(
                  entry: entries[i],
                  isOwnEntry: entries[i].uid == uid,
                  animationIndex: i,
                ),
              ),
            ),
          ],
        );
      },
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
