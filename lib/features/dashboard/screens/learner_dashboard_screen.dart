import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../providers/auth_provider.dart';

class LearnerDashboardScreen extends StatefulWidget {
  const LearnerDashboardScreen({super.key});

  @override
  State<LearnerDashboardScreen> createState() => _LearnerDashboardScreenState();
}

class _LearnerDashboardScreenState extends State<LearnerDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await auth.signOut();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome, ${user?.name ?? "Learner"}! 👋',
                    style: AppTextStyles.h2.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Grade ${user?.grade ?? "1"}',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          label: 'Points',
                          value: user?.totalPoints.toString() ?? '0',
                          icon: '⭐',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          label: 'Streak',
                          value: user?.streakDays.toString() ?? '0',
                          icon: '🔥',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Quick Actions
            Text('Quick Start', style: AppTextStyles.h3),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: [
                _QuickActionCard(
                  icon: '📚',
                  title: 'Quests',
                  subtitle: 'Start a new quest',
                  onTap: () {},
                ),
                _QuickActionCard(
                  icon: '🎮',
                  title: 'Activities',
                  subtitle: 'Practice skills',
                  onTap: () {},
                ),
                _QuickActionCard(
                  icon: '🏆',
                  title: 'Rewards',
                  subtitle: 'View badges',
                  onTap: () {},
                ),
                _QuickActionCard(
                  icon: '👤',
                  title: 'Profile',
                  subtitle: 'View progress',
                  onTap: () {},
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Recent Activity
            Text('Recent Activity', style: AppTextStyles.h3),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  'No activities yet. Complete a quest to get started!',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTextStyles.h3.copyWith(color: Colors.white),
          ),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.backgroundLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(icon, style: const TextStyle(fontSize: 32)),
            const SizedBox(height: 8),
            Text(title, style: AppTextStyles.bodyMedium),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
