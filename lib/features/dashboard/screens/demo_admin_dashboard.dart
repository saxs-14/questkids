import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../providers/auth_provider.dart';

/// Temporary presentation-only admin console.
///
/// This screen deliberately does not impersonate a Firebase administrator
/// and does not perform privileged Firestore writes. Remove it after the
/// Firebase admin claim/provisioning issue is resolved.
class DemoAdminDashboard extends StatefulWidget {
  const DemoAdminDashboard({super.key});

  @override
  State<DemoAdminDashboard> createState() => _DemoAdminDashboardState();
}

class _DemoAdminDashboardState extends State<DemoAdminDashboard> {
  int _tab = 0;

  static const _users = [
    ('Amogelang Mokoena', 'amogelang@example.com', 'learner'),
    ('Lerato Nkosi', 'lerato@example.com', 'learner'),
    ('Parent Demo', 'parent@example.com', 'parent'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final pages = [_overview(), _usersPage(), _safety(), _operations()];

    return Scaffold(
      appBar: AppBar(
        title: const Text('QuestKids Admin • Demo'),
        actions: [
          IconButton(
            tooltip: 'Toggle theme',
            icon: Icon(
              theme.isDark ? Icons.wb_sunny : Icons.nightlight_round,
            ),
            onPressed: theme.toggleTheme,
          ),
          IconButton(
            tooltip: 'Exit demo',
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthProvider>().signOut(),
          ),
        ],
      ),
      body: pages[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Overview',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Users',
          ),
          NavigationDestination(
            icon: Icon(Icons.shield_outlined),
            selectedIcon: Icon(Icons.shield),
            label: 'Safety',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Operations',
          ),
        ],
      ),
    );
  }

  Widget _overview() {
    const cards = [
      ('Users', 3, Icons.people),
      ('Parents', 1, Icons.family_restroom),
      ('Children', 2, Icons.child_care),
      ('Admins', 1, Icons.admin_panel_settings),
      ('Activities', 126, Icons.menu_book),
      ('AI Reports', 2, Icons.flag),
    ];

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _demoBanner(),
        Text(
          'Platform Overview',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Presentation mode for the QuestKids administration experience. '
          'Firebase privileged operations are disabled in this temporary mode.',
        ),
        const SizedBox(height: 20),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cards.length,
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 220,
            mainAxisExtent: 120,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemBuilder: (_, index) {
            final card = cards[index];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(card.$3, color: AppColors.primary),
                    const Spacer(),
                    Text(
                      card.$2.toString(),
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Text(card.$1),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _usersPage() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _demoBanner(),
        Text(
          'User Management',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 16),
        ..._users.map(
          (user) => Card(
            child: ListTile(
              leading: CircleAvatar(child: Text(user.$1[0])),
              title: Text(user.$1),
              subtitle: Text(user.$2 + '\\n' + user.$3),
              isThreeLine: true,
              trailing: const Chip(label: Text('Demo')),
            ),
          ),
        ),
      ],
    );
  }

  Widget _safety() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _demoBanner(),
        Text(
          'Child Safety & AI Review',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 16),
        _reportCard(
          'Content review',
          'Demo report: review Questy response for age-appropriate language.',
        ),
        _reportCard(
          'Safety review',
          'Demo report: investigate a flagged learner interaction.',
        ),
      ],
    );
  }

  Widget _operations() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _demoBanner(),
        Text(
          'Platform Operations',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 16),
        _section('Content', [
          'Manage approved activities and CAPS curriculum reference data.',
          'Keep the game catalogue and learning objectives aligned.',
        ]),
        _section('Gamification', [
          'Monitor missions, rewards and leaderboard refreshes.',
          'Investigate abnormal progress or reward activity.',
        ]),
        _section('Security', [
          'Production admin access remains protected by Firebase claims.',
          'This demo console performs no privileged Firebase operations.',
        ]),
      ],
    );
  }

  Widget _demoBanner() {
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      color: AppColors.primary.withValues(alpha: 0.10),
      child: const ListTile(
        leading: Icon(Icons.info_outline),
        title: Text('Temporary Demo Mode'),
        subtitle: Text(
          'Read-only presentation data. This is not a Firebase administrator session.',
        ),
      ),
    );
  }

  Widget _reportCard(String title, String detail) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.flag_outlined),
        title: Text(title),
        subtitle: Text(detail),
        trailing: const Chip(label: Text('Demo')),
      ),
    );
  }

  Widget _section(String title, List<String> items) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  '),
                    Expanded(child: Text(item)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
