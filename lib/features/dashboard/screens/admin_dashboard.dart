import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/services/admin_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../providers/auth_provider.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final _service = AdminService();
  int _tab = 0;
  Map<String, int> _counts = {};
  bool _loadingCounts = true;

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    try {
      final counts = await _service.getOverviewCounts();
      if (mounted) setState(() {
        _counts = counts;
        _loadingCounts = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingCounts = false);
    }
  }

  Future<void> _changeRole(String uid, String role) async {
    try {
      await _service.setUserRole(uid: uid, role: role);
      await _loadCounts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User role updated.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Role update failed: ' + e.toString())),
        );
      }
    }
  }

  Future<void> _toggleDisabled(String uid, bool disabled) async {
    try {
      await _service.setUserDisabled(uid: uid, disabled: disabled);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(disabled ? 'Account disabled.' : 'Account enabled.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Account update failed: ' + e.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final theme = context.watch<ThemeProvider>();

    if (user == null || user.role != 'admin') {
      return const SizedBox.shrink();
    }

    final pages = [_overview(), _users(), _safety(), _operations()];

    return Scaffold(
      appBar: AppBar(
        title: const Text('QuestKids Admin'),
        actions: [
          IconButton(
            icon: Icon(theme.isDark ? Icons.wb_sunny : Icons.nightlight_round),
            onPressed: theme.toggleTheme,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCounts,
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
    if (_loadingCounts) {
      return const Center(child: CircularProgressIndicator());
    }

    final cards = [
      ['Users', _counts['users'] ?? 0, Icons.people],
      ['Parents', _counts['parents'] ?? 0, Icons.family_restroom],
      ['Children', _counts['children'] ?? 0, Icons.child_care],
      ['Admins', _counts['admins'] ?? 0, Icons.admin_panel_settings],
      ['Activities', _counts['activities'] ?? 0, Icons.menu_book],
      ['AI Reports', _counts['reports'] ?? 0, Icons.flag],
    ];

    return RefreshIndicator(
      onRefresh: _loadCounts,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Platform Overview',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Manage QuestKids users, curriculum, child safety and platform operations from one protected console.',
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
                      Icon(card[2] as IconData, color: AppColors.primary),
                      const Spacer(),
                      Text(
                        (card[1] as int).toString(),
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(card[0] as String),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          _section('Admin responsibilities', const [
            'User and account administration',
            'Parent-child relationship oversight',
            'Approved learning-content management',
            'Questy and AI safety review',
            'Missions, rewards and leaderboard operations',
            'System health and configuration monitoring',
          ]),
        ],
      ),
    );
  }

  Widget _users() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _service.watchUsers(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Unable to load users: ' + snapshot.error.toString()));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'User Management',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Role changes and account disabling are performed through protected server-side operations.',
            ),
            const SizedBox(height: 16),
            ...docs.map((doc) {
              final data = doc.data();
              final role = (data['role'] ?? 'learner').toString();
              final name = (data['name'] ?? data['email'] ?? 'Unknown user').toString();
              final email = (data['email'] ?? '').toString();

              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(name.isEmpty ? '?' : name[0].toUpperCase()),
                  ),
                  title: Text(name),
                  subtitle: Text(email + '\n' + role),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'disable') {
                        await _toggleDisabled(doc.id, true);
                      } else if (value == 'enable') {
                        await _toggleDisabled(doc.id, false);
                      } else {
                        await _changeRole(doc.id, value);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'learner', child: Text('Make Child')),
                      PopupMenuItem(value: 'parent', child: Text('Make Parent')),
                      PopupMenuItem(value: 'admin', child: Text('Make Admin')),
                      PopupMenuDivider(),
                      PopupMenuItem(value: 'disable', child: Text('Disable Account')),
                      PopupMenuItem(value: 'enable', child: Text('Enable Account')),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _safety() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _service.watchAiReports(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Unable to load AI reports: ' + snapshot.error.toString()));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Child Safety & AI Review',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            const Text('Review Questy reports submitted by children or parents.'),
            const SizedBox(height: 16),
            if (docs.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No AI reports have been submitted.'),
                ),
              ),
            ...docs.map((doc) {
              final data = doc.data();
              final title = (data['reason'] ?? data['category'] ?? 'AI report').toString();
              final detail = (data['message'] ?? data['details'] ?? 'No details provided').toString();

              return Card(
                child: ListTile(
                  leading: const Icon(Icons.flag_outlined, color: AppColors.primary),
                  title: Text(title),
                  subtitle: Text(detail, maxLines: 3, overflow: TextOverflow.ellipsis),
                  trailing: TextButton(
                    onPressed: () => _service.resolveAiReport(
                      reportId: doc.id,
                      status: 'resolved',
                    ),
                    child: const Text('Resolve'),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _operations() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Platform Operations',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 16),
        _section('Content', const [
          'Manage approved activities and CAPS curriculum reference data.',
          'Keep the game catalogue and learning objectives aligned.',
        ]),
        _section('Gamification', const [
          'Monitor daily missions, rewards and leaderboard refreshes.',
          'Investigate abnormal progress or reward activity.',
        ]),
        _section('Security', const [
          'Admin access is claim-based, not controlled by a client role field.',
          'Use the bootstrap script only for the first admin.',
        ]),
        _section('System health', const [
          'Use Firebase logs, Crashlytics and deployment checks for operational monitoring.',
        ]),
      ],
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
