import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/responsive_scaffold.dart';
import '../../../providers/auth_provider.dart';
import '../widgets/stat_card.dart';

class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({super.key});

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  int _selectedIndex = 0;

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
            icon: Icons.group_outlined,
            activeIcon: Icons.group,
            label: 'Class'),
        ResponsiveDestination(
            icon: Icons.assignment_outlined,
            activeIcon: Icons.assignment,
            label: 'Activities'),
        ResponsiveDestination(
            icon: Icons.person_outline,
            activeIcon: Icons.person,
            label: 'Profile'),
      ],
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hi, ${user?.name.split(' ').first ?? 'Teacher'} 👋',
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const Text('Teacher Dashboard',
                style: TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
                theme.isDark ? Icons.wb_sunny : Icons.nightlight_round),
            onPressed: theme.toggleTheme,
          ),
          IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () {}),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CircleAvatar(
              backgroundColor: Colors.white24,
              child: Text(
                user?.name.isNotEmpty == true
                    ? user!.name[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _TeacherHomeTab(user: user),
          const _ClassTab(),
          const _ActivitiesTab(),
          _TeacherProfileTab(user: user),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Activity',
            style: TextStyle(color: Colors.white)),
      ),
    );
  }
}

class _TeacherHomeTab extends StatelessWidget {
  final dynamic user;
  const _TeacherHomeTab({required this.user});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              StatCard(
                  label: 'Learners',
                  value: '0',
                  emoji: '👩‍🎓',
                  color: AppColors.primary),
              SizedBox(width: 12),
              StatCard(
                  label: 'Activities',
                  value: '0',
                  emoji: '📝',
                  color: AppColors.blue),
              SizedBox(width: 12),
              StatCard(
                  label: 'Completed',
                  value: '0',
                  emoji: '✅',
                  color: AppColors.green),
            ],
          ),
          const SizedBox(height: 24),
          Text('My Class', style: AppTextStyles.h3),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.1)),
            ),
            child: Column(
              children: [
                const Text('🧑‍🏫',
                    style: TextStyle(fontSize: 48)),
                const SizedBox(height: 12),
                Text('No learners yet', style: AppTextStyles.h4),
                Text(
                  'Create activities and share\nyour class code',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Recent Activity', style: AppTextStyles.h3),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.blue.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: AppColors.blue.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Text('📋',
                    style: TextStyle(fontSize: 32)),
                const SizedBox(width: 12),
                Text(
                  'No recent class activity',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ClassTab extends StatelessWidget {
  const _ClassTab();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('👩‍🎓', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text('Class Management', style: AppTextStyles.h3),
          Text('Coming in Step 13',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _ActivitiesTab extends StatelessWidget {
  const _ActivitiesTab();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('📝', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text('Activity Builder', style: AppTextStyles.h3),
          Text('Coming in Step 9',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _TeacherProfileTab extends StatelessWidget {
  final dynamic user;
  const _TeacherProfileTab({required this.user});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          CircleAvatar(
            radius: 50,
            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
            child: Text(
              user?.name.isNotEmpty == true
                  ? user!.name[0].toUpperCase()
                  : '?',
              style: AppTextStyles.score
                  .copyWith(color: AppColors.primary),
            ),
          ),
          const SizedBox(height: 16),
          Text(user?.name ?? 'Teacher', style: AppTextStyles.h2),
          const Text('Teacher Account',
              style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 32),
          ListTile(
            leading: const Icon(Icons.email_outlined,
                color: AppColors.primary),
            title: Text('Email', style: AppTextStyles.bodySmall),
            subtitle: Text(user?.email ?? '',
                style: AppTextStyles.bodyMedium),
          ),
          const Divider(),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => auth.signOut(),
            icon: const Icon(Icons.logout, color: AppColors.error),
            label: const Text('Sign Out',
                style: TextStyle(color: AppColors.error)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}
