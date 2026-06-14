import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/services/rewards_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/rewards_provider.dart';
import '../widgets/badge_card.dart';
import '../widgets/locked_badge_card.dart';
import '../../dashboard/widgets/level_progress_bar.dart';
import '../../dashboard/widgets/streak_banner.dart';
import '../../dashboard/widgets/stat_card.dart';

class RewardsScreen extends StatefulWidget {
  final bool embedded;
  const RewardsScreen({super.key, this.embedded = false});

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = context.read<AuthProvider>().user?.uid;
      if (uid != null) {
        context.read<RewardsProvider>()
          ..loadRewards(uid)
          ..watchRewards(uid);
      }
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rewards = context.watch<RewardsProvider>();
    final user = context.read<AuthProvider>().user;

    if (rewards.isLoading) {
      if (widget.embedded) {
        return const Center(child: CircularProgressIndicator());
      }
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final tabView = TabBarView(
      controller: _tabCtrl,
      children: [
        _OverviewTab(rewards: rewards, user: user),
        _BadgesTab(rewards: rewards),
        _HistoryTab(rewards: rewards),
      ],
    );

    if (widget.embedded) {
      return Column(
        children: [
          Material(
            color: Theme.of(context).primaryColor,
            child: TabBar(
              controller: _tabCtrl,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              indicatorColor: Colors.white,
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Badges'),
                Tab(text: 'History'),
              ],
            ),
          ),
          Expanded(child: tabView),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rewards'),
        automaticallyImplyLeading: false,
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Badges'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: tabView,
    );
  }
}

class _OverviewTab extends StatelessWidget {
  final RewardsProvider rewards;
  final dynamic user;

  const _OverviewTab({required this.rewards, required this.user});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LevelProgressBar(
            level: rewards.level,
            totalPoints: rewards.totalPoints,
            progress: rewards.levelProgress,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(rewards.levelEmoji,
                    style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 10),
                Text(
                  rewards.levelTitle,
                  style: AppTextStyles.h3
                      .copyWith(color: AppColors.primary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          StreakBanner(streakDays: rewards.streakDays),
          const SizedBox(height: 20),
          Row(
            children: [
              StatCard(
                label: 'Total Points',
                value: '${rewards.totalPoints}',
                emoji: '⭐',
                color: AppColors.gold,
              ),
              const SizedBox(width: 12),
              StatCard(
                label: 'Quests Done',
                value: '${rewards.questsCompleted}',
                emoji: '🎯',
                color: AppColors.primary,
              ),
              const SizedBox(width: 12),
              StatCard(
                label: 'Badges',
                value: '${rewards.badges.length}',
                emoji: '🏅',
                color: AppColors.orange,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Subject Progress', style: AppTextStyles.h3),
          const SizedBox(height: 12),
          _SubjectProgress(
            subject: 'Math',
            emoji: '🔢',
            color: AppColors.math,
            count: rewards.subjectCounts['Math'] ?? 0,
          ),
          const SizedBox(height: 8),
          _SubjectProgress(
            subject: 'Science',
            emoji: '🔬',
            color: AppColors.science,
            count: rewards.subjectCounts['Science'] ?? 0,
          ),
          const SizedBox(height: 8),
          _SubjectProgress(
            subject: 'English',
            emoji: '📖',
            color: AppColors.english,
            count: rewards.subjectCounts['English'] ?? 0,
          ),
          const SizedBox(height: 8),
          _SubjectProgress(
            subject: 'Social Sciences',
            emoji: '🌍',
            color: AppColors.socialSciences,
            count: rewards.subjectCounts['Social Sciences'] ?? 0,
          ),
        ],
      ),
    );
  }
}

class _SubjectProgress extends StatelessWidget {
  final String subject;
  final String emoji;
  final Color color;
  final int count;

  const _SubjectProgress({
    required this.subject,
    required this.emoji,
    required this.color,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    Text(subject,
                        style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w700)),
                    Text('$count quests',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: color)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (count / 10).clamp(0.0, 1.0),
                    backgroundColor: color.withValues(alpha: 0.15),
                    valueColor:
                        AlwaysStoppedAnimation<Color>(color),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgesTab extends StatelessWidget {
  final RewardsProvider rewards;
  const _BadgesTab({required this.rewards});

  @override
  Widget build(BuildContext context) {
    final earnedIds =
        rewards.badges.map((b) => b.id).toSet();
    final locked = RewardsService.allBadges
        .where((b) => !earnedIds.contains(b['id']))
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Earned', style: AppTextStyles.h3),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${rewards.badges.length}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          rewards.badges.isEmpty
              ? Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color:
                            AppColors.primary.withValues(alpha: 0.1)),
                  ),
                  child: Column(
                    children: [
                      const Text('🏅',
                          style: TextStyle(fontSize: 48)),
                      const SizedBox(height: 12),
                      Text('No badges yet',
                          style: AppTextStyles.h4),
                      Text(
                        'Complete quests to earn badges!',
                        style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: rewards.badges.length,
                  itemBuilder: (_, i) => BadgeCard(
                    badge: rewards.badges[i],
                    isNew: rewards.newlyEarnedBadges
                        .any((b) => b.id == rewards.badges[i].id),
                  ),
                ),
          const SizedBox(height: 24),
          Text('Locked', style: AppTextStyles.h3),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            itemCount: locked.length,
            itemBuilder: (_, i) =>
                LockedBadgeCard(badgeData: locked[i]),
          ),
        ],
      ),
    );
  }
}

class _HistoryTab extends StatelessWidget {
  final RewardsProvider rewards;
  const _HistoryTab({required this.rewards});

  @override
  Widget build(BuildContext context) {
    if (rewards.progressHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📋', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text('No history yet', style: AppTextStyles.h3),
            Text(
              'Complete a quest to see it here!',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: rewards.progressHistory.length,
      itemBuilder: (_, i) {
        final p = rewards.progressHistory[i];
        return _HistoryTile(progress: p);
      },
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final dynamic progress;
  const _HistoryTile({required this.progress});

  Color get _scoreColor {
    if (progress.score >= 80) return AppColors.green;
    if (progress.score >= 60) return AppColors.orange;
    return AppColors.error;
  }

  String get _subjectEmoji {
    switch (progress.subject) {
      case 'Math': return '🔢';
      case 'Science': return '🔬';
      case 'English': return '📖';
      case 'Social Sciences': return '🌍';
      default: return '📚';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(_subjectEmoji,
              style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  progress.activityTitle,
                  style: AppTextStyles.bodyLarge
                      .copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  progress.subject,
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _scoreColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${progress.score}%',
                  style: TextStyle(
                    color: _scoreColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '+${progress.pointsEarned} pts',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
