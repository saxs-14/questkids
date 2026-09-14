import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/profile_settings_tile.dart';
import '../../../providers/auth_provider.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final user = context.watch<AuthProvider>().user;

    // Mid-sign-out, AuthProvider.signOut() calls notifyListeners() (clearing
    // `user`) before the caller's subsequent Navigator.pushNamedAndRemoveUntil
    // replaces this route -- context.watch rebuilds this widget in that gap
    // with `user == null`. Bail out before building anything that assumes a
    // signed-in user -- navigation to /login is already in flight. Same race
    // as learner_dashboard.dart/parent_dashboard.dart's identical guard.
    if (user == null) {
      return const SizedBox.shrink();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
            'Hi, ${user.name.isNotEmpty ? user.name.split(' ').first : 'Admin'} 👋'),
        actions: [
          IconButton(
            icon: Icon(theme.isDark ? Icons.wb_sunny : Icons.nightlight_round),
            onPressed: theme.toggleTheme,
          ),
        ],
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.admin_panel_settings,
                  size: 64, color: AppColors.primary),
              SizedBox(height: 16),
              Text(
                'Admin features coming soon',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'User management, analytics, and content tools will appear here.',
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 32),
              ProfileSettingsTile(),
            ],
          ),
        ),
      ),
    );
  }
}
