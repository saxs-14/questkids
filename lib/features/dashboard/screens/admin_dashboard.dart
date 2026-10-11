import 'dart:convert' show utf8;

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:file_selector/file_selector.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../../core/config/emulator_config.dart';
import '../../../core/constants/game_catalog.dart';
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
  bool _showDisabledOnly = false;
  late Future<Map<String, dynamic>> _platformReportFuture;

  final _draftDocumentController = TextEditingController();
  bool _generatingDraft = false;
  Map<String, dynamic>? _lastDraft;
  String? _lastDraftError;

  bool _refreshingLeaderboards = false;
  bool _generatingMissions = false;

  @override
  void initState() {
    super.initState();
    _loadCounts();
    _platformReportFuture = _service.getPlatformReport();
  }

  @override
  void dispose() {
    _draftDocumentController.dispose();
    super.dispose();
  }

  Future<void> _exportCsv(String suggestedName, List<List<dynamic>> rows) async {
    try {
      final csvContent = const ListToCsvConverter().convert(rows);
      final location = await getSaveLocation(suggestedName: suggestedName);
      if (location == null) return; // user cancelled
      final file = XFile.fromData(
        utf8.encode(csvContent),
        mimeType: 'text/csv',
        name: suggestedName,
      );
      await file.saveTo(location.path);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exported $suggestedName.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
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

    final pages = [_overview(), _users(), _safety(), _aiGameLab(), _reports(), _operations()];

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
            icon: Icon(Icons.assessment_outlined, color: AdminColors.textSecondary),
            selectedIcon: Icon(Icons.assessment, color: AdminColors.textPrimary),
            label: 'Reports',
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
        final allDocs = snapshot.data!.docs;
        final disabledCount = allDocs.where((d) => d.data()['disabled'] == true).length;
        final docs = allDocs.where((doc) {
          final data = doc.data();
          if (_showDisabledOnly && data['disabled'] != true) return false;
          if (query.isEmpty) return true;
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
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilterChip(
                  label: Text('Disabled accounts ($disabledCount)'),
                  selected: _showDisabledOnly,
                  onSelected: (value) => setState(() => _showDisabledOnly = value),
                  selectedColor: AdminColors.severityRed.withValues(alpha: 0.25),
                  labelStyle: TextStyle(
                    color: _showDisabledOnly ? AdminColors.severityRed : AdminColors.textSecondary,
                  ),
                  backgroundColor: AdminColors.cardBottom,
                ),
                OutlinedButton.icon(
                  onPressed: docs.isEmpty
                      ? null
                      : () => _exportCsv('questkids_users.csv', [
                            ['name', 'email', 'role', 'disabled'],
                            ...docs.map((d) {
                              final data = d.data();
                              return [
                                data['name'] ?? '',
                                data['email'] ?? '',
                                data['role'] ?? 'learner',
                                data['disabled'] == true,
                              ];
                            }),
                          ]),
                  icon: const Icon(Icons.download_outlined, size: 18),
                  label: const Text('Export CSV'),
                ),
              ],
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
                  _showDisabledOnly
                      ? 'No disabled accounts.'
                      : (query.isEmpty ? 'No users found.' : 'No users match your search.'),
                  style: const TextStyle(color: AdminColors.textSecondary),
                ),
              ),
            ...docs.map((doc) {
              final data = doc.data();
              final role = (data['role'] ?? 'learner').toString();
              final name = (data['name'] ?? data['email'] ?? 'Unknown user').toString();
              final email = (data['email'] ?? '').toString();
              final disabled = data['disabled'] == true;

              return AdminUserRow(
                name: name,
                email: email,
                role: adminRoleFromString(role),
                disabled: disabled,
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

  static const _quickStartDocs = [
    (
      title: 'Quick start: Rainbow Number Rescue',
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
      title: 'Quick start: Animal Habitat Adventure',
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

  Future<void> _generateDraft() async {
    final document = _draftDocumentController.text.trim();
    if (document.isEmpty) {
      setState(() => _lastDraftError = 'Write or load a game creation document first.');
      return;
    }
    setState(() {
      _generatingDraft = true;
      _lastDraftError = null;
      _lastDraft = null;
    });
    try {
      final result = await _service.generateGameDraft(document);
      if (!mounted) return;
      setState(() => _lastDraft = result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _lastDraftError = 'AI draft generation failed: $e');
    } finally {
      if (mounted) setState(() => _generatingDraft = false);
    }
  }

  Future<void> _saveDraftToReviewLog() async {
    final draft = _lastDraft;
    final uid = context.read<AuthProvider>().user?.uid;
    if (draft == null || uid == null) return;
    try {
      await _service.saveGameDraft(
        createdBy: uid,
        document: _draftDocumentController.text.trim(),
        draft: draft['draft'],
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Draft saved to the review log.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save draft: $e')),
      );
    }
  }

  String _formatDraft(dynamic draft) {
    if (draft is Map) {
      return draft.entries.map((e) => '${e.key}: ${e.value}').join('\n\n');
    }
    return draft.toString();
  }

  Widget _aiGameLab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const AdminSectionHeader(
          eyebrow: 'QUESTKIDS AI LAB',
          title: 'Game Creation Document Drafting',
          subtitle:
              'Write (or load a quick-start example), send it to Gemini for a draft, and optionally save it to the review log below. Drafts are previews only and never add games to the catalogue — a new engine still needs real code (see CLAUDE.md §4).',
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _quickStartDocs
              .map((item) => ActionChip(
                    label: Text(item.title),
                    onPressed: () => setState(() {
                      _draftDocumentController.text = item.document;
                      _lastDraft = null;
                      _lastDraftError = null;
                    }),
                  ))
              .toList(),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _draftDocumentController,
          maxLines: 10,
          style: const TextStyle(color: AdminColors.textPrimary),
          cursorColor: AdminColors.textPrimary,
          decoration: InputDecoration(
            labelText: 'Game creation document',
            hintText: 'GAME CREATION DOCUMENT\nGrade: ...\nSubject: ...\nTopic: ...\nGoal: ...',
            labelStyle: const TextStyle(color: AdminColors.textSecondary),
            hintStyle: const TextStyle(color: AdminColors.textSecondary),
            alignLabelWithHint: true,
            filled: true,
            fillColor: AdminColors.cardBottom,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AdminColors.borderGlow.withValues(alpha: 0.4)),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide(color: AdminColors.borderGlow),
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _generatingDraft ? null : _generateDraft,
          icon: _generatingDraft
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.auto_awesome),
          label: const Text('Send document to AI for draft'),
        ),
        if (_lastDraftError != null) ...[
          const SizedBox(height: 12),
          Text(_lastDraftError!, style: const TextStyle(color: Colors.red)),
        ],
        if (_lastDraft != null) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('AI draft preview', style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AdminColors.bgPage,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SelectableText(
                      _formatDraft(_lastDraft!['draft']),
                      style: const TextStyle(color: AdminColors.textPrimary),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _saveDraftToReviewLog,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Save to review log'),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        const Text(
          'Review log',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 16,
            color: AdminColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _service.watchGameDrafts(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator(color: AdminColors.brandPrimary)),
              );
            }
            final docs = snapshot.data!.docs;
            if (docs.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('No drafts saved yet.', style: TextStyle(color: AdminColors.textSecondary)),
              );
            }
            return Column(
              children: docs.map((doc) {
                final data = doc.data();
                final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
                final document = (data['document'] ?? '').toString();
                final title = document.split('\n').firstWhere(
                      (l) => l.trim().isNotEmpty && !l.contains('GAME CREATION DOCUMENT'),
                      orElse: () => document,
                    );
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(createdAt == null ? 'Saved' : 'Saved ${createdAt.toLocal()}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _service.deleteGameDraft(doc.id),
                    ),
                    onTap: () => showDialog<void>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Saved draft'),
                        content: SingleChildScrollView(
                          child: SelectableText(_formatDraft(data['draft'])),
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _reports() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _platformReportFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AdminColors.brandPrimary),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 42),
                  const SizedBox(height: 12),
                  const Text(
                    'Platform report could not be loaded.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => setState(
                      () => _platformReportFuture = _service.getPlatformReport(),
                    ),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try again'),
                  ),
                ],
              ),
            ),
          );
        }

        final report = snapshot.data ?? <String, dynamic>{};
        int value(String key) => (report[key] as num?)?.toInt() ?? 0;
        final cards = [
          ['All users', value('users'), Icons.people_alt_outlined],
          ['Learners', value('learners'), Icons.child_care_outlined],
          ['Parents', value('parents'), Icons.family_restroom_outlined],
          ['Admins', value('admins'), Icons.admin_panel_settings_outlined],
          ['Game sessions', value('gameSessions'), Icons.sports_esports_outlined],
          ['Sessions (7 days)', value('gameSessionsLast7Days'), Icons.date_range],
          ['Activities', value('activities'), Icons.menu_book_outlined],
          ['Weekly reports', value('weeklyReports'), Icons.summarize_outlined],
          ['AI reports', value('aiReports'), Icons.flag_outlined],
          ['Pending AI reports', value('pendingAiReports'), Icons.pending_actions],
          ['Resolved AI reports', value('resolvedAiReports'), Icons.task_alt],
        ];
        final generatedAt = DateTime.tryParse(
          (report['generatedAt'] ?? '').toString(),
        );

        return RefreshIndicator(
          onRefresh: () async {
            final future = _service.getPlatformReport();
            setState(() => _platformReportFuture = future);
            await future;
          },
          color: AdminColors.brandPrimary,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const AdminSectionHeader(
                eyebrow: 'QUESTKIDS ADMIN',
                title: 'Platform Reports',
                subtitle:
                    'Live aggregate usage and safety-review counts. This view does not expose individual learner scores or contact details.',
              ),
              const SizedBox(height: 8),
              Text(
                generatedAt == null
                    ? 'Report timestamp unavailable'
                    : 'Generated ${generatedAt.toLocal()}',
                style: const TextStyle(color: AdminColors.textSecondary),
              ),
              const SizedBox(height: 18),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: cards.length,
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  mainAxisExtent: 112,
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
              const SizedBox(height: 18),
              const AdminOperationsCard(
                title: 'How to read these figures',
                items: [
                  'Sessions (7 days) counts recorded game sessions with a completedAt timestamp in the last seven days.',
                  'Pending AI reports means total AI reports minus those marked resolved.',
                  'Weekly reports counts generated weekly report documents; it does not prove that notifications were delivered.',
                  'These are aggregate operational metrics, not a formal assessment of any learner.',
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => setState(
                      () => _platformReportFuture = _service.getPlatformReport(),
                    ),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh report'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _exportCsv('questkids_platform_report.csv', [
                      ['metric', 'value'],
                      ...cards.map((c) => [c[0], c[1]]),
                      ['generatedAt', generatedAt?.toLocal().toString() ?? ''],
                    ]),
                    icon: const Icon(Icons.download_outlined, size: 18),
                    label: const Text('Export CSV'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _runLeaderboardRefresh() async {
    setState(() => _refreshingLeaderboards = true);
    try {
      await _service.refreshLeaderboards();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Leaderboards refreshed.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Leaderboard refresh failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _refreshingLeaderboards = false);
    }
  }

  Future<void> _runMissionsGeneration() async {
    setState(() => _generatingMissions = true);
    try {
      final result = await _service.generateDailyMissions();
      if (!mounted) return;
      final total = result['total'] ?? 0;
      final failed = result['failed'] ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Missions generated for ${total - (failed as int)}/$total learners.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mission generation failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _generatingMissions = false);
    }
  }

  Widget _operations() {
    final bySubject = <String, int>{};
    final engineTypes = <String>{};
    for (final entry in GameCatalog.all) {
      bySubject[entry.subject] = (bySubject[entry.subject] ?? 0) + 1;
      engineTypes.add(entry.engineType);
    }
    final subjectSummary = bySubject.entries.map((e) => '${e.key}: ${e.value}').join(' · ');

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const AdminSectionHeader(
          eyebrow: 'QUESTKIDS ADMIN',
          title: 'Platform Operations',
          subtitle: 'Live catalogue stats and on-demand gamification maintenance jobs.',
        ),
        const SizedBox(height: 20),
        AdminOperationsCard(
          title: 'Content',
          items: [
            '${GameCatalog.all.length} games across ${bySubject.length} subjects and ${engineTypes.length} engine types.',
            subjectSummary,
          ],
        ),
        AdminOperationsCard(
          title: 'Gamification',
          items: const [
            'Leaderboards normally refresh nightly at 01:00 SAST; daily missions at 00:00 SAST.',
            'Run either job now to verify a fix or recover from a bad run, without waiting for the schedule.',
          ],
          trailing: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _refreshingLeaderboards ? null : _runLeaderboardRefresh,
                icon: _refreshingLeaderboards
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.leaderboard_outlined, size: 18),
                label: const Text('Refresh leaderboards now'),
              ),
              OutlinedButton.icon(
                onPressed: _generatingMissions ? null : _runMissionsGeneration,
                icon: _generatingMissions
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.flag_circle_outlined, size: 18),
                label: const Text('Generate daily missions now'),
              ),
            ],
          ),
        ),
        const AdminOperationsCard(
          title: 'Security',
          items: [
            'Admin access is claim-based, not controlled by a client role field.',
            'Use the bootstrap script only for the first admin.',
          ],
        ),
        AdminOperationsCard(
          title: 'System health',
          items: [
            'Firebase project: ${Firebase.app().options.projectId}',
            'Build mode: ${kReleaseMode ? 'Release' : 'Debug'}${emulatorsEnabled ? ' (connected to local emulators)' : ''}',
            'Use Firebase logs, Crashlytics and deployment checks for deeper operational monitoring.',
          ],
        ),
      ],
    );
  }
}
