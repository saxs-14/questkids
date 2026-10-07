import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/services/admin_service.dart';
import '../../../providers/auth_provider.dart';
import '../theme/admin_colors.dart';
import '../widgets/admin_header.dart';
import '../widgets/admin_stat_card.dart';
import '../widgets/admin_user_row.dart';
import '../widgets/admin_report_card.dart';
import '../widgets/admin_operations_card.dart';
import '../widgets/admin_search_field.dart';

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
  String _userSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    try {
      final counts = await _service.getOverviewCounts();
      if (mounted) {
        setState(() {
          _counts = counts;
          _loadingCounts = false;
        });
      }
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
          SnackBar(content: Text('Role update failed: $e')),
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
          SnackBar(content: Text('Account update failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    if (user == null || user.role != 'admin') {
      return const SizedBox.shrink();
    }

    final pages = [_overview(), _users(), _safety(), _aiGameLab(), _operations()];

    return Scaffold(
      backgroundColor: AdminColors.bgPage,
      appBar: AppBar(
        backgroundColor: AdminColors.bgPage,
        elevation: 0,
        foregroundColor: AdminColors.textPrimary,
        title: const Text('QuestKids Admin'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCounts,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Log out',
            onPressed: () async {
              await context.read<AuthProvider>().signOut();
              if (!context.mounted) return;
              Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
            },
          ),
        ],
      ),
      body: pages[_tab],
      bottomNavigationBar: NavigationBar(
        backgroundColor: AdminColors.cardBottom,
        indicatorColor: AdminColors.brandPrimary.withValues(alpha: 0.3),
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined, color: AdminColors.textSecondary),
            selectedIcon: Icon(Icons.dashboard, color: AdminColors.textPrimary),
            label: 'Overview',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline, color: AdminColors.textSecondary),
            selectedIcon: Icon(Icons.people, color: AdminColors.textPrimary),
            label: 'Users',
          ),
          NavigationDestination(
            icon: Icon(Icons.shield_outlined, color: AdminColors.textSecondary),
            selectedIcon: Icon(Icons.shield, color: AdminColors.textPrimary),
            label: 'Safety',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined, color: AdminColors.textSecondary),
            selectedIcon: Icon(Icons.auto_awesome, color: AdminColors.textPrimary),
            label: 'AI Lab',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined, color: AdminColors.textSecondary),
            selectedIcon: Icon(Icons.settings, color: AdminColors.textPrimary),
            label: 'Operations',
          ),
        ],
      ),
    );
  }

  Widget _overview() {
    if (_loadingCounts) {
      return const Center(
        child: CircularProgressIndicator(color: AdminColors.brandPrimary),
      );
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
      color: AdminColors.brandPrimary,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: AdminSectionHeader(
                  eyebrow: 'QUESTKIDS ADMIN',
                  title: 'Platform Overview',
                  subtitle:
                      'Manage QuestKids users, curriculum, child safety and platform operations from one protected console.',
                ),
              ),
              SizedBox(width: 12),
              AdminStatusPill(label: 'All systems operational'),
            ],
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
              return AdminStatCard(
                icon: card[2] as IconData,
                value: (card[1] as int).toString(),
                label: card[0] as String,
              );
            },
          ),
          const SizedBox(height: 20),
          const AdminOperationsCard(
            title: 'Admin responsibilities',
            items: [
              'User and account administration',
              'Parent-child relationship oversight',
              'Approved learning-content management',
              'Questy and AI safety review',
              'Missions, rewards and leaderboard operations',
              'System health and configuration monitoring',
            ],
          ),
        ],
      ),
    );
  }

  Widget _users() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _service.watchUsers(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Unable to load users: ${snapshot.error}',
              style: const TextStyle(color: AdminColors.textSecondary),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: AdminColors.brandPrimary),
          );
        }

        final query = _userSearchQuery.trim().toLowerCase();
        final docs = snapshot.data!.docs.where((doc) {
          if (query.isEmpty) return true;
          final data = doc.data();
          final name = (data['name'] ?? '').toString().toLowerCase();
          final email = (data['email'] ?? '').toString().toLowerCase();
          final role = (data['role'] ?? 'learner').toString().toLowerCase();
          return name.contains(query) || email.contains(query) || role.contains(query);
        }).toList();

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const AdminSectionHeader(
              eyebrow: 'QUESTKIDS ADMIN',
              title: 'User Management',
              subtitle:
                  'Role changes and account disabling are performed through protected server-side operations.',
            ),
            const SizedBox(height: 20),
            AdminSearchField(
              hintText: 'Search by name, email, or role…',
              onChanged: (value) => setState(() => _userSearchQuery = value),
            ),
            const SizedBox(height: 16),
            if (docs.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AdminColors.cardBottom,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  query.isEmpty ? 'No users found.' : 'No users match your search.',
                  style: const TextStyle(color: AdminColors.textSecondary),
                ),
              ),
            ...docs.map((doc) {
              final data = doc.data();
              final role = (data['role'] ?? 'learner').toString();
              final name = (data['name'] ?? data['email'] ?? 'Unknown user').toString();
              final email = (data['email'] ?? '').toString();

              return AdminUserRow(
                name: name,
                email: email,
                role: adminRoleFromString(role),
                trailing: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: AdminColors.textSecondary),
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
          return Center(
            child: Text(
              'Unable to load AI reports: ${snapshot.error}',
              style: const TextStyle(color: AdminColors.textSecondary),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: AdminColors.brandPrimary),
          );
        }

        final docs = snapshot.data!.docs;

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const AdminSectionHeader(
              eyebrow: 'QUESTKIDS ADMIN',
              title: 'Child Safety & AI Review',
              subtitle: 'Review Questy reports submitted by children or parents.',
            ),
            const SizedBox(height: 20),
            if (docs.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AdminColors.cardBottom,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'No AI reports have been submitted.',
                  style: TextStyle(color: AdminColors.textSecondary),
                ),
              ),
            ...docs.map((doc) {
              final data = doc.data();
              final reason = (data['reason'] ?? data['category'] ?? 'AI report').toString();
              final detail = (data['messageText'] ??
                      data['message'] ??
                      data['details'] ??
                      'No details provided')
                  .toString();

              return AdminReportCard(
                title: reason,
                detail: detail,
                severity: severityForReportReason(reason),
                onResolve: () => _service.resolveAiReport(
                  reportId: doc.id,
                  status: 'resolved',
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Future<void> _generateDemoGame(String document) async {
    try {
      final result = await FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('generateGameDraft')
          .call({'document': document});
      if (!mounted) return;
      final data = Map<String, dynamic>.from(result.data as Map);
      final draft = data['draft'];
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('AI Game Draft Preview'),
          content: SingleChildScrollView(
            child: SelectableText(draft is Map ? draft.entries.map((e) => '${e.key}: ${e.value}').join('\n\n') : draft.toString()),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI draft generation failed: $e')),
      );
    }
  }

  Widget _aiGameLab() {
    const docs = [
      (
        title: 'Demo 1 — Rainbow Number Rescue',
        document: '''GAME CREATION DOCUMENT
Grade: 1
Subject: Mathematics
Topic: Number bonds to 10
Goal: Help a learner practise number bonds without relying only on multiple choice.
Content: Use numbers 1–9 with missing partners to make 10.
Interaction: Randomly choose between tap, drag, matching pairs and a short sequence challenge.
Feedback: Celebrate correct answers and give a strategy hint after an error.
Safety: No external links, no personal data, no purchases.''',
      ),
      (
        title: 'Demo 2 — Animal Habitat Adventure',
        document: '''GAME CREATION DOCUMENT
Grade: 4
Subject: Natural Sciences
Topic: Animal habitats
Goal: Match animals with suitable habitats and explain the reason.
Content: Lion, penguin, frog, camel, fish and their habitats.
Interaction: Randomly present a drag target, swipe decision, matching round or timed movement round.
Feedback: Explain why the selected habitat is suitable instead of revealing answers before the learner tries.
Safety: Child-friendly language and no personal data.''',
      ),
    ];

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const AdminSectionHeader(
          eyebrow: 'QUESTKIDS AI LAB',
          title: 'Game Creation Document Preview',
          subtitle: 'Two dummy creation documents demonstrate how an approved brief is sent to Gemini for a draft. Drafts are previews only and do not add games to the catalogue.',
        ),
        const SizedBox(height: 18),
        ...docs.map((item) => Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AdminColors.bgPage,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SelectableText(item.document),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => _generateDemoGame(item.document),
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Send document to AI for draft'),
              ),
            ]),
          ),
        )),
      ],
    );
  }

  Widget _operations() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: const [
        AdminSectionHeader(
          eyebrow: 'QUESTKIDS ADMIN',
          title: 'Platform Operations',
          subtitle:
              'System status readouts — operational controls are not yet wired to live data.',
        ),
        SizedBox(height: 20),
        AdminOperationsCard(
          title: 'Content',
          items: [
            'Manage approved activities and CAPS curriculum reference data.',
            'Keep the game catalogue and learning objectives aligned.',
          ],
        ),
        AdminOperationsCard(
          title: 'Gamification',
          items: [
            'Monitor daily missions, rewards and leaderboard refreshes.',
            'Investigate abnormal progress or reward activity.',
          ],
        ),
        AdminOperationsCard(
          title: 'Security',
          items: [
            'Admin access is claim-based, not controlled by a client role field.',
            'Use the bootstrap script only for the first admin.',
          ],
        ),
        AdminOperationsCard(
          title: 'System health',
          items: [
            'Use Firebase logs, Crashlytics and deployment checks for operational monitoring.',
          ],
        ),
      ],
    );
  }
}
