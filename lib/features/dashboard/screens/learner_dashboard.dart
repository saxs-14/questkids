import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/profile_avatar_picker.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/widgets/responsive_scaffold.dart';
import '../../grade4/grade4_hub.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../../offline/widgets/offline_banner.dart';
import '../../offline/widgets/sync_button.dart';
import '../../offline/screens/offline_screen.dart';
import '../../quests/screens/quests_screen.dart';
import '../../rewards/screens/rewards_screen.dart';
import '../../ai_tutor/screens/ai_tutor_screen.dart';
import '../widgets/stat_card.dart';
import '../widgets/subject_chip.dart';
import '../widgets/level_progress_bar.dart';
import '../widgets/streak_banner.dart';

class LearnerDashboard extends StatefulWidget {
  const LearnerDashboard({super.key});

  @override
  State<LearnerDashboard> createState() => _LearnerDashboardState();
}

class _LearnerDashboardState extends State<LearnerDashboard> {
  int _selectedIndex = 0;
  String _selectedSubject = 'All';

  final _subjects = [
    {'label': 'All',            'emoji': '📚', 'color': AppColors.primary},
    {'label': 'Math',           'emoji': '🔢', 'color': AppColors.math},
    {'label': 'Science',        'emoji': '🔬', 'color': AppColors.science},
    {'label': 'English',        'emoji': '📖', 'color': AppColors.english},
    {'label': 'Social Sciences','emoji': '🌍', 'color': AppColors.socialSciences},
  ];

  final _demoQuests = [
    {
      'title': 'Multiplication Tables',
      'subject': 'Math',
      'difficulty': 'Medium',
      'points': 20,
      'color': AppColors.math,
      'emoji': '🔢',
    },
    {
      'title': 'The Water Cycle',
      'subject': 'Science',
      'difficulty': 'Easy',
      'points': 10,
      'color': AppColors.science,
      'emoji': '🔬',
    },
    {
      'title': 'Parts of Speech',
      'subject': 'English',
      'difficulty': 'Hard',
      'points': 30,
      'color': AppColors.english,
      'emoji': '📖',
    },
    {
      'title': 'SA Provinces',
      'subject': 'Social Sciences',
      'difficulty': 'Easy',
      'points': 10,
      'color': AppColors.socialSciences,
      'emoji': '🌍',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = context.watch<ThemeProvider>();
    final user = auth.user;

    return ResponsiveScaffold(
      selectedIndex: _selectedIndex,
      onDestinationSelected: (i) => setState(() => _selectedIndex = i),
      destinations: const [
        ResponsiveDestination(
            icon: Icons.home_outlined,
            activeIcon: Icons.home,
            label: 'Home'),
        ResponsiveDestination(
            icon: Icons.explore_outlined,
            activeIcon: Icons.explore,
            label: 'Quests'),
        ResponsiveDestination(
            icon: Icons.emoji_events_outlined,
            activeIcon: Icons.emoji_events,
            label: 'Rewards'),
        ResponsiveDestination(
            icon: Icons.smart_toy_outlined,
            activeIcon: Icons.smart_toy,
            label: 'QuestBot'),
        ResponsiveDestination(
            icon: Icons.person_outline,
            activeIcon: Icons.person,
            label: 'Profile'),
        ResponsiveDestination(
            icon: Icons.offline_pin_outlined,
            activeIcon: Icons.offline_pin,
            label: 'Offline'),
      ],
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hi, ${user?.name.split(' ').first ?? 'Learner'} 👋',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            Text(
              user?.grade ?? 'Grade 1',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        elevation: 2,
        actions: [
          IconButton(
            icon: Icon(theme.isDark ? Icons.wb_sunny : Icons.nightlight_round),
            onPressed: theme.toggleTheme,
          ),
          const SyncButton(),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              Navigator.push(
                context, 
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => setState(() => _selectedIndex = 4),
              child: CircleAvatar(
                backgroundColor: Colors.white24,
                backgroundImage: user?.avatarUrl != null
                    ? NetworkImage(user!.avatarUrl!)
                    : null,
                child: user?.avatarUrl == null
                    ? Text(
                        user?.name.isNotEmpty == true
                            ? user!.name[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700),
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                user?.grade == 'Grade 4'
                    ? Grade4Hub(user: user)
                    : _HomeTab(
                        subjects: _subjects,
                        demoQuests: _demoQuests,
                        selectedSubject: _selectedSubject,
                        onSubjectChanged: (s) => setState(() => _selectedSubject = s),
                        user: user,
                      ),
                const _QuestsTab(),
                const _RewardsTab(),
                const _AiTutorTab(),
                _ProfileTab(user: user),
                const _OfflineTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  final List<Map<String, dynamic>> subjects;
  final List<Map<String, dynamic>> demoQuests;
  final String selectedSubject;
  final ValueChanged<String> onSubjectChanged;
  final dynamic user;

  const _HomeTab({
    required this.subjects,
    required this.demoQuests,
    required this.selectedSubject,
    required this.onSubjectChanged,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final filtered = selectedSubject == 'All'
        ? demoQuests
        : demoQuests
            .where((q) => q['subject'] == selectedSubject)
            .toList();

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Level Progress
          LevelProgressBar(
            level: 1,
            totalPoints: user?.totalPoints ?? 0,
            progress: ((user?.totalPoints ?? 0) % 100) / 100,
          ),
          const SizedBox(height: 16),

          // Streak
          StreakBanner(streakDays: user?.streakDays ?? 0),
          const SizedBox(height: 16),

          // Stats Row
          Row(
            children: [
              StatCard(
                label: 'Points',
                value: '${user?.totalPoints ?? 0}',
                emoji: '⭐',
                color: AppColors.gold,
              ),
              const SizedBox(width: 12),
              StatCard(
                label: 'Streak',
                value: '${user?.streakDays ?? 0}d',
                emoji: '🔥',
                color: AppColors.orange,
              ),
              const SizedBox(width: 12),
              const StatCard(
                label: 'Badges',
                value: '0',
                emoji: '🏅',
                color: AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Subject Filter
          Text('Subjects', style: AppTextStyles.h3),
          const SizedBox(height: 12),
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: subjects.length,
              itemBuilder: (_, i) {
                final s = subjects[i];
                final isSelected = s['label'] == selectedSubject;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: SubjectChip(
                    subject: s['label'] as String,
                    emoji: s['emoji'] as String,
                    color: s['color'] as Color,
                    isSelected: isSelected,
                    onTap: () => onSubjectChanged(s['label'] as String),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),

          // Available Quests
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Available Quests', style: AppTextStyles.h3),
              Text('${filtered.length}',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 12),
          
          filtered.isEmpty
              ? Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.1)),
                  ),
                  child: Column(
                    children: [
                      const Text('🔍', style: TextStyle(fontSize: 48)),
                      const SizedBox(height: 12),
                      Text('No quests available',
                          style: AppTextStyles.h4),
                      const SizedBox(height: 8),
                      Text('Check back soon!',
                          style: AppTextStyles.bodyMedium
                              .copyWith(color: AppColors.textSecondary)),
                    ],
                  ),
                )
              : GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isMobile ? 1 : 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: isMobile ? 1.5 : 2,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final quest = filtered[i];
                    return _QuestCardWidget(quest: quest);
                  },
                ),
        ],
      ),
    );
  }
}

class _QuestCardWidget extends StatelessWidget {
  final Map<String, dynamic> quest;

  const _QuestCardWidget({required this.quest});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (quest['color'] as Color).withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(quest['emoji'], style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      quest['title'],
                      style: AppTextStyles.h4,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      quest['subject'],
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: (quest['color'] as Color).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  quest['difficulty'],
                  style: AppTextStyles.bodySmall.copyWith(
                    color: quest['color'] as Color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Row(
                children: [
                  const Text('⭐', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 4),
                  Text(
                    '${quest['points']}',
                    style: AppTextStyles.bodySmall
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const QuestsScreen()),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: quest['color'] as Color,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Start Quest',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestsTab extends StatelessWidget {
  const _QuestsTab();

  @override
  Widget build(BuildContext context) {
    return const QuestsScreen(embedded: true);
  }
}

class _RewardsTab extends StatelessWidget {
  const _RewardsTab();

  @override
  Widget build(BuildContext context) {
    return const RewardsScreen(embedded: true);
  }
}

class _AiTutorTab extends StatelessWidget {
  const _AiTutorTab();

  @override
  Widget build(BuildContext context) {
    return const AiTutorScreen(embedded: true);
  }
}

class _ProfileTab extends StatelessWidget {
  final dynamic user;
  const _ProfileTab({required this.user});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final isMobile = MediaQuery.of(context).size.width < 600;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          const ProfileAvatarPicker(radius: 60),
          const SizedBox(height: 16),
          Text(user?.name ?? 'Learner', style: AppTextStyles.h2),
          Text(user?.grade ?? 'Grade 1',
              style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
            ),
            child: Column(
              children: [
                _StatRowWidget(
                  icon: Icons.star,
                  label: 'Total Points',
                  value: '${user?.totalPoints ?? 0}',
                ),
                const Divider(),
                _StatRowWidget(
                  icon: Icons.local_fire_department,
                  label: 'Current Streak',
                  value: '${user?.streakDays ?? 0} days',
                ),
                const Divider(),
                _StatRowWidget(
                  icon: Icons.school,
                  label: 'Grade',
                  value: user?.grade ?? 'Not set',
                ),
                const Divider(),
                _StatRowWidget(
                  icon: Icons.cake,
                  label: 'Member Since',
                  value: _formatDate(user?.createdAt),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          OutlinedButton.icon(
            onPressed: () {
              auth.signOut();
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                (route) => false,
              );
            },
            icon: const Icon(Icons.logout, color: AppColors.error),
            label: const Text('Sign Out',
                style: TextStyle(color: AppColors.error)),
            style: OutlinedButton.styleFrom(
              minimumSize: Size(isMobile ? double.infinity : 200, 50),
              side: const BorderSide(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _StatRowWidget extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatRowWidget({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.bodySmall.copyWith(fontSize: 11)),
              const SizedBox(height: 4),
              Text(value, style: AppTextStyles.bodyMedium),
            ],
          ),
          const Spacer(),
          const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
        ],
      ),
    );
  }
}

class _OfflineTab extends StatelessWidget {
  const _OfflineTab();

  @override
  Widget build(BuildContext context) {
    return const OfflineScreen(embedded: true);
  }
}
