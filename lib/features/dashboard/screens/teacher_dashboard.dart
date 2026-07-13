import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/profile_avatar_picker.dart';
import '../../../core/widgets/profile_settings_tile.dart';
import '../../../core/widgets/responsive_scaffold.dart';
import '../../teacher/screens/class_analytics_screen.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../providers/auth_provider.dart';
import '../../notifications/screens/notifications_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Colours
// ─────────────────────────────────────────────────────────────────────────────
const _kPrimary = Color(0xFF5C35F5);
const _kMath = Color(0xFFFF6B35);
const _kScience = Color(0xFF00BFA5);
const _kEnglish = Color(0xFFE91E63);
const _kSocial = Color(0xFF43A047);

// ─────────────────────────────────────────────────────────────────────────────
// Root widget
// ─────────────────────────────────────────────────────────────────────────────
class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({super.key});

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  int _selectedIndex = 0;
  final _db = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = context.watch<ThemeProvider>();
    final user = auth.user;
    final uid = user?.uid ?? '';

    return ResponsiveScaffold(
      selectedIndex: _selectedIndex,
      onDestinationSelected: (i) => setState(() => _selectedIndex = i),
      destinations: const [
        ResponsiveDestination(
            icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home'),
        ResponsiveDestination(
            icon: Icons.group_outlined,
            activeIcon: Icons.group,
            label: 'Class'),
        ResponsiveDestination(
            icon: Icons.assignment_outlined,
            activeIcon: Icons.assignment,
            label: 'Activities'),
        ResponsiveDestination(
            icon: Icons.analytics_outlined,
            activeIcon: Icons.analytics,
            label: 'Analytics'),
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
              'Hi, ${user?.displayName ?? user?.name.split(' ').first ?? 'Teacher'}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const Text('Teacher Dashboard',
                style: TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(theme.isDark ? Icons.wb_sunny : Icons.nightlight_round),
            onPressed: theme.toggleTheme,
            tooltip: 'Toggle theme',
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'Notifications',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => setState(() => _selectedIndex = 4),
              child: CircleAvatar(
                backgroundColor: Colors.white24,
                backgroundImage: user?.avatarUrl != null
                    ? CachedNetworkImageProvider(user!.avatarUrl!)
                    : null,
                child: user?.avatarUrl == null
                    ? Text(
                        user?.name.isNotEmpty == true
                            ? user!.name[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700),
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _selectedIndex == 1
          ? FloatingActionButton.extended(
              heroTag: 'fab_class',
              onPressed: () => _showAddLearnerDialog(context, uid),
              backgroundColor: _kPrimary,
              icon: const Icon(Icons.person_add, color: Colors.white),
              label: const Text('Add Learner',
                  style: TextStyle(color: Colors.white)),
            )
          : _selectedIndex == 2
              ? FloatingActionButton.extended(
                  heroTag: 'fab_activity',
                  onPressed: () => _showCreateActivitySheet(context, uid),
                  backgroundColor: _kPrimary,
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text('Create Activity',
                      style: TextStyle(color: Colors.white)),
                )
              : null,
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _HomeTab(teacherUid: uid),
          _ClassTab(teacherUid: uid),
          _ActivitiesTab(teacherUid: uid),
          ClassAnalyticsScreen(teacherUid: uid),
          const _ProfileTab(),
        ],
      ),
    );
  }

  void _showAddLearnerDialog(BuildContext context, String teacherUid) {
    final codeCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        bool loading = false;
        String? error;

        return StatefulBuilder(
          builder: (ctx, setS) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _kPrimary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.link, color: _kPrimary),
                ),
                const SizedBox(width: 12),
                const Text('Add Learner'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ask the learner for their 6-character class link code.',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: codeCtrl,
                  maxLength: 6,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: 'Link Code (e.g. AB12CD)',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    prefixIcon:
                        const Icon(Icons.vpn_key_outlined, color: _kPrimary),
                    errorText: error,
                  ),
                  onChanged: (_) => setS(() => error = null),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: _kPrimary),
                onPressed: loading
                    ? null
                    : () async {
                        final code = codeCtrl.text.trim().toUpperCase();
                        if (code.length != 6) {
                          setS(() => error = 'Enter exactly 6 characters');
                          return;
                        }
                        setS(() => loading = true);
                        try {
                          final q = await _db
                              .collection('users')
                              .where('childLinkCode', isEqualTo: code)
                              .limit(1)
                              .get();
                          if (q.docs.isEmpty) {
                            setS(() {
                              error = 'No learner found with this code';
                              loading = false;
                            });
                            return;
                          }
                          final learnerUid = q.docs.first.id;
                          final batch = _db.batch();
                          batch.update(
                            _db.collection('users').doc(learnerUid),
                            {
                              'linkedTeacherUids':
                                  FieldValue.arrayUnion([teacherUid])
                            },
                          );
                          batch.update(
                            _db.collection('users').doc(teacherUid),
                            {
                              'linkedChildrenUids':
                                  FieldValue.arrayUnion([learnerUid])
                            },
                          );
                          await batch.commit();
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Learner linked successfully!'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          }
                        } catch (e) {
                          setS(() {
                            error = 'Error: ${e.toString()}';
                            loading = false;
                          });
                        }
                      },
                child: loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Link Learner'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCreateActivitySheet(BuildContext context, String teacherUid) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _CreateActivitySheet(teacherUid: teacherUid),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HOME TAB
// ─────────────────────────────────────────────────────────────────────────────
class _HomeTab extends StatelessWidget {
  final String teacherUid;
  const _HomeTab({required this.teacherUid});

  String _timeAgo(dynamic ts) {
    if (ts == null || ts is! Timestamp) return 'unknown';
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Color _subjectColor(String subject) {
    final s = subject.toLowerCase();
    if (s.contains('math')) return _kMath;
    if (s.contains('science')) return _kScience;
    if (s.contains('english') || s.contains('lang')) return _kEnglish;
    return _kSocial;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(teacherUid)
          .snapshots(),
      builder: (context, teacherSnap) {
        final linkedUids = teacherSnap.hasData && teacherSnap.data!.exists
            ? List<String>.from((teacherSnap.data!.data()
                    as Map<String, dynamic>?)?['linkedChildrenUids'] ??
                [])
            : <String>[];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${weekdays[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}',
                        style: AppTextStyles.bodySmall,
                      ),
                      Text('Class Overview', style: AppTextStyles.h3),
                    ],
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _kPrimary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.circle,
                            color: AppColors.success, size: 10),
                        const SizedBox(width: 6),
                        Text(
                          '${linkedUids.length} Learners',
                          style: AppTextStyles.bodySmall.copyWith(
                              color: _kPrimary, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _StatsGrid(teacherUid: teacherUid, linkedUids: linkedUids),
              const SizedBox(height: 28),
              Row(
                children: [
                  const Text('📋', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Text('Recent Class Activity', style: AppTextStyles.h3),
                ],
              ),
              const SizedBox(height: 12),
              if (linkedUids.isEmpty)
                const _EmptyCard(
                  icon: Icons.history_outlined,
                  message:
                      'No learners linked yet. Activity will appear here once learners join.',
                )
              else
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('progress')
                      .where('childUid', whereIn: linkedUids.take(10).toList())
                      .orderBy('completedAt', descending: true)
                      .limit(10)
                      .snapshots(),
                  builder: (context, snap) {
                    if (snap.hasError)
                      return _ErrorCard(message: snap.error.toString());
                    if (!snap.hasData)
                      return const Center(child: CircularProgressIndicator());
                    final docs = snap.data!.docs;
                    if (docs.isEmpty) {
                      return const _EmptyCard(
                          icon: Icons.assignment_outlined,
                          message: 'No activity recorded yet.');
                    }
                    return Column(
                      children: docs.map((doc) {
                        final d = doc.data() as Map<String, dynamic>;
                        final subject = d['subject'] as String? ?? 'General';
                        final score = (d['score'] ?? 0) as int;
                        final childName =
                            d['childName'] as String? ?? 'Learner';
                        return _ActivityCard(
                          learnerName: childName,
                          subject: subject,
                          score: score,
                          timeAgo: _timeAgo(d['completedAt']),
                          subjectColor: _subjectColor(subject),
                        );
                      }).toList(),
                    );
                  },
                ),
              const SizedBox(height: 28),
              Row(
                children: [
                  const Text('⚡', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Text('Quick Actions', style: AppTextStyles.h3),
                ],
              ),
              const SizedBox(height: 12),
              const Row(
                children: [
                  _QuickActionBtn(
                      label: 'Grade\nReport',
                      icon: Icons.bar_chart_rounded,
                      color: _kPrimary),
                  SizedBox(width: 8),
                  _QuickActionBtn(
                      label: 'Send\nNotification',
                      icon: Icons.send_outlined,
                      color: _kMath),
                  SizedBox(width: 8),
                  _QuickActionBtn(
                      label: 'View\nLeaderboard',
                      icon: Icons.emoji_events_outlined,
                      color: AppColors.gold),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stats grid
// ─────────────────────────────────────────────────────────────────────────────
class _StatsGrid extends StatelessWidget {
  final String teacherUid;
  final List<String> linkedUids;

  const _StatsGrid({required this.teacherUid, required this.linkedUids});

  Future<Map<String, dynamic>> _fetchStats(List<String> uids) async {
    if (uids.isEmpty) return {'activeToday': 0, 'avgScore': 0.0, 'pending': 0};
    final db = FirebaseFirestore.instance;
    final today = DateTime.now();
    final todayTs =
        Timestamp.fromDate(DateTime(today.year, today.month, today.day));
    final limitedUids = uids.take(10).toList();

    final results = await Future.wait([
      db
          .collection('progress')
          .where('childUid', whereIn: limitedUids)
          .orderBy('completedAt', descending: true)
          .limit(100)
          .get(),
      db
          .collection('progress')
          .where('childUid', whereIn: limitedUids)
          .where('completed', isEqualTo: true)
          .where('verified', isEqualTo: false)
          .get(),
    ]);

    final progSnap = results[0] as QuerySnapshot;
    final pendingSnap = results[1] as QuerySnapshot;

    double totalScore = 0;
    int scored = 0;
    final Set<String> activeTodayUids = {};

    for (final d in progSnap.docs) {
      final data = d.data() as Map<String, dynamic>;
      final ts = data['completedAt'];
      if (ts is Timestamp && ts.compareTo(todayTs) >= 0) {
        final cUid = data['childUid'] as String?;
        if (cUid != null) activeTodayUids.add(cUid);
      }
      final score = data['score'];
      if (score != null) {
        totalScore += (score as num).toDouble();
        scored++;
      }
    }

    return {
      'activeToday': activeTodayUids.length,
      'avgScore': scored > 0 ? totalScore / scored : 0.0,
      'pending': pendingSnap.docs.length,
    };
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchStats(linkedUids),
      builder: (context, snap) {
        final loaded = snap.hasData;
        final activeToday = snap.data?['activeToday'] as int? ?? 0;
        final avgScore = snap.data?['avgScore'] as double? ?? 0;
        final pending = snap.data?['pending'] as int? ?? 0;

        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.6,
          children: [
            _StatTile(
                label: 'Total Learners',
                value: '${linkedUids.length}',
                icon: Icons.people_alt_rounded,
                color: _kPrimary),
            _StatTile(
                label: 'Active Today',
                value: loaded ? '$activeToday' : '…',
                icon: Icons.online_prediction_rounded,
                color: _kScience),
            _StatTile(
                label: 'Avg Score %',
                value: loaded ? '${avgScore.toStringAsFixed(0)}%' : '…',
                icon: Icons.insights_rounded,
                color: _kMath),
            _StatTile(
                label: 'Pending Reviews',
                value: loaded ? '$pending' : '…',
                icon: Icons.pending_actions_rounded,
                color: AppColors.warning),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CLASS TAB
// ─────────────────────────────────────────────────────────────────────────────
class _ClassTab extends StatelessWidget {
  final String teacherUid;
  const _ClassTab({required this.teacherUid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(teacherUid)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError)
          return Center(child: _ErrorCard(message: snap.error.toString()));
        if (!snap.hasData)
          return const Center(child: CircularProgressIndicator());

        final data = snap.data!.data() as Map<String, dynamic>? ?? {};
        final linkedUids = List<String>.from(data['linkedChildrenUids'] ?? []);

        if (linkedUids.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: _kPrimary.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.group_add_outlined,
                        size: 64, color: _kPrimary),
                  ),
                  const SizedBox(height: 20),
                  Text('No learners yet', style: AppTextStyles.h3),
                  const SizedBox(height: 8),
                  Text(
                    'No learners yet. Share your class code to invite learners.',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return FutureBuilder<List<UserModel>>(
          future: UserRepository().getChildren(linkedUids),
          builder: (context, learnerSnap) {
            if (learnerSnap.hasError) {
              return Center(
                  child: _ErrorCard(message: learnerSnap.error.toString()));
            }
            if (!learnerSnap.hasData)
              return const Center(child: CircularProgressIndicator());
            final learners = learnerSnap.data!;
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              itemCount: learners.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _LearnerCard(
                learner: learners[i],
                onTap: () => _showLearnerDetail(context, learners[i]),
              ),
            );
          },
        );
      },
    );
  }

  void _showLearnerDetail(BuildContext context, UserModel learner) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => _LearnerDetailSheet(learner: learner),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Learner card
// ─────────────────────────────────────────────────────────────────────────────
class _LearnerCard extends StatelessWidget {
  final UserModel learner;
  final VoidCallback onTap;

  const _LearnerCard({required this.learner, required this.onTap});

  String _lastActiveFmt() {
    final d = learner.lastActiveDate;
    if (d == null) return 'Never';
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final progress = (learner.totalPoints / 1000).clamp(0.0, 1.0);
    final initials = learner.name.isNotEmpty
        ? learner.name
            .split(' ')
            .map((w) => w.isNotEmpty ? w[0] : '')
            .take(2)
            .join()
        : '?';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _kPrimary.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: _kPrimary.withValues(alpha: 0.15),
              backgroundImage: learner.avatarUrl != null
                  ? CachedNetworkImageProvider(learner.avatarUrl!)
                  : null,
              child: learner.avatarUrl == null
                  ? Text(initials.toUpperCase(),
                      style: const TextStyle(
                          color: _kPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 16))
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(learner.name, style: AppTextStyles.h4),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _Chip(label: learner.grade, color: _kPrimary),
                      const SizedBox(width: 6),
                      Text('Last active ${_lastActiveFmt()}',
                          style: AppTextStyles.bodySmall),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Stack(
                    children: [
                      Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white.withValues(alpha: 0.12)
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: progress,
                        child: Container(
                          height: 6,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: [_kPrimary, _kScience]),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('${learner.totalPoints} / 1000 XP',
                      style: AppTextStyles.bodySmall),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Learner detail bottom sheet
// ─────────────────────────────────────────────────────────────────────────────
class _LearnerDetailSheet extends StatelessWidget {
  final UserModel learner;
  const _LearnerDetailSheet({required this.learner});

  String _childEmail() {
    final safeName = learner.name.toLowerCase().replaceAll(' ', '.');
    final safeGrade = learner.grade.toLowerCase().replaceAll(' ', '');
    return '$safeName.$safeGrade@questkids.learn';
  }

  @override
  Widget build(BuildContext context) {
    final initials = learner.name.isNotEmpty
        ? learner.name
            .split(' ')
            .map((w) => w.isNotEmpty ? w[0] : '')
            .take(2)
            .join()
        : '?';

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, scrollCtrl) => ListView(
        controller: scrollCtrl,
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white24
                      : Colors.black26,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: _kPrimary.withValues(alpha: 0.12),
                backgroundImage: learner.avatarUrl != null
                    ? CachedNetworkImageProvider(learner.avatarUrl!)
                    : null,
                child: learner.avatarUrl == null
                    ? Text(initials.toUpperCase(),
                        style: const TextStyle(
                            color: _kPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 20))
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(learner.name, style: AppTextStyles.h2),
                    const SizedBox(height: 4),
                    _Chip(label: learner.grade, color: _kPrimary),
                    const SizedBox(height: 4),
                    Text(_childEmail(),
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                    label: 'Total XP',
                    value: '${learner.totalPoints}',
                    icon: Icons.bolt,
                    color: _kPrimary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricTile(
                    label: 'Streak',
                    value: '${learner.streakDays} days',
                    icon: Icons.local_fire_department_rounded,
                    color: _kMath),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Subject Performance', style: AppTextStyles.h4),
          const SizedBox(height: 12),
          _SubjectBreakdownWidget(learnerUid: learner.uid),
          const SizedBox(height: 24),
          Text('Recent Activity', style: AppTextStyles.h4),
          const SizedBox(height: 12),
          _RecentGameHistory(learnerUid: learner.uid),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Subject breakdown
// ─────────────────────────────────────────────────────────────────────────────
class _SubjectBreakdownWidget extends StatelessWidget {
  final String learnerUid;
  const _SubjectBreakdownWidget({required this.learnerUid});

  Color _subjectColor(String subject) {
    final s = subject.toLowerCase();
    if (s.contains('math')) return _kMath;
    if (s.contains('science')) return _kScience;
    if (s.contains('english') || s.contains('lang')) return _kEnglish;
    return _kSocial;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('progress')
          .where('childUid', isEqualTo: learnerUid)
          .limit(100)
          .get(),
      builder: (context, snap) {
        if (snap.hasError) return _ErrorCard(message: snap.error.toString());
        if (!snap.hasData)
          return const Center(child: CircularProgressIndicator());

        final Map<String, List<int>> bySubject = {};
        for (final doc in snap.data!.docs) {
          final d = doc.data() as Map<String, dynamic>;
          final subj = (d['subject'] as String? ?? 'General').trim();
          final score = (d['score'] as num?)?.toInt() ?? 0;
          bySubject.putIfAbsent(subj, () => []).add(score);
        }

        final defaults = <String>[
          'Mathematics',
          'Science',
          'English',
          'Social Sciences'
        ];
        final subjects = bySubject.isEmpty ? defaults : bySubject.keys.toList();

        return Column(
          children: subjects.map((subj) {
            final scores = bySubject[subj] ?? [];
            final avg = scores.isEmpty
                ? 0.0
                : scores.reduce((a, b) => a + b) / scores.length;
            final color = _subjectColor(subj);

            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                                color: color, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                          Text(subj, style: AppTextStyles.bodyMedium),
                        ],
                      ),
                      Text(
                        scores.isEmpty
                            ? 'No data'
                            : '${avg.toStringAsFixed(0)}%',
                        style: AppTextStyles.bodySmall.copyWith(
                            color: color, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: avg / 100,
                      minHeight: 7,
                      backgroundColor: color.withValues(alpha: 0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Recent game history
// ─────────────────────────────────────────────────────────────────────────────
class _RecentGameHistory extends StatelessWidget {
  final String learnerUid;
  const _RecentGameHistory({required this.learnerUid});

  String _timeAgo(dynamic ts) {
    if (ts == null || ts is! Timestamp) return '';
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Color _subjectColor(String subject) {
    final s = subject.toLowerCase();
    if (s.contains('math')) return _kMath;
    if (s.contains('science')) return _kScience;
    if (s.contains('english') || s.contains('lang')) return _kEnglish;
    return _kSocial;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('game_sessions')
          .where('childUid', isEqualTo: learnerUid)
          .orderBy('playedAt', descending: true)
          .limit(5)
          .get(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const SizedBox(
              height: 48, child: Center(child: CircularProgressIndicator()));
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const _EmptyCard(
              icon: Icons.sports_esports_outlined,
              message: 'No games played yet.');
        }
        return Column(
          children: docs.map((doc) {
            final d = doc.data() as Map<String, dynamic>;
            final title = d['activityTitle'] as String? ?? 'Game';
            final subject = d['subject'] as String? ?? '';
            final score = (d['score'] as num?)?.toInt() ?? 0;
            final color = _subjectColor(subject);

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        shape: BoxShape.circle),
                    child: Icon(Icons.sports_esports, color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: AppTextStyles.bodyMedium
                                .copyWith(fontWeight: FontWeight.w600)),
                        if (subject.isNotEmpty)
                          Text(subject, style: AppTextStyles.bodySmall),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('$score%',
                          style: AppTextStyles.bodyMedium.copyWith(
                              color: color, fontWeight: FontWeight.w700)),
                      Text(_timeAgo(d['playedAt']),
                          style: AppTextStyles.bodySmall),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACTIVITIES TAB
// ─────────────────────────────────────────────────────────────────────────────
class _ActivitiesTab extends StatelessWidget {
  final String teacherUid;
  const _ActivitiesTab({required this.teacherUid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('activities')
          .where('teacherUid', isEqualTo: teacherUid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError)
          return Center(child: _ErrorCard(message: snap.error.toString()));
        if (!snap.hasData)
          return const Center(child: CircularProgressIndicator());

        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                        color: _kPrimary.withValues(alpha: 0.08),
                        shape: BoxShape.circle),
                    child: const Icon(Icons.assignment_add,
                        size: 64, color: _kPrimary),
                  ),
                  const SizedBox(height: 20),
                  Text('No activities yet', style: AppTextStyles.h3),
                  const SizedBox(height: 8),
                  Text(
                    'Tap "Create Activity" to build your first lesson.',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            return _ActivityTile(data: d, docId: docs[i].id);
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Activity tile
// ─────────────────────────────────────────────────────────────────────────────
class _ActivityTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;

  const _ActivityTile({required this.data, required this.docId});

  Color _subjectColor(String subject) {
    final s = subject.toLowerCase();
    if (s.contains('math')) return _kMath;
    if (s.contains('science')) return _kScience;
    if (s.contains('english') || s.contains('lang')) return _kEnglish;
    return _kSocial;
  }

  String _fmtDate(dynamic ts) {
    if (ts == null || ts is! Timestamp) return '';
    final dt = ts.toDate();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final title = data['title'] as String? ?? 'Untitled';
    final subject = data['subject'] as String? ?? 'General';
    final grade = data['grade'] as String? ?? '';
    final completionCount = (data['completionCount'] as num?)?.toInt() ?? 0;
    final color = _subjectColor(subject);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 5,
            decoration: BoxDecoration(
              color: color,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(title, style: AppTextStyles.h4)),
                    _Chip(label: grade, color: _kPrimary),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _Chip(label: subject, color: color),
                    const Spacer(),
                    const Icon(Icons.calendar_today_outlined,
                        size: 12, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(_fmtDate(data['createdAt']),
                        style: AppTextStyles.bodySmall),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.check_circle_outline,
                        size: 16, color: AppColors.success),
                    const SizedBox(width: 4),
                    Text(
                      '$completionCount learner${completionCount == 1 ? '' : 's'} completed',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Create Activity bottom sheet
// ─────────────────────────────────────────────────────────────────────────────
class _CreateActivitySheet extends StatefulWidget {
  final String teacherUid;
  const _CreateActivitySheet({required this.teacherUid});

  @override
  State<_CreateActivitySheet> createState() => _CreateActivitySheetState();
}

class _CreateActivitySheetState extends State<_CreateActivitySheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  String _selectedSubject = 'Mathematics';
  String _selectedGrade = 'Grade 1';
  bool _saving = false;

  static const _subjects = [
    'Mathematics',
    'Science',
    'English',
    'Social Sciences',
    'Technology',
    'Arts & Culture',
  ];

  static const _grades = [
    'Grade 1',
    'Grade 2',
    'Grade 3',
    'Grade 4',
    'Grade 5',
    'Grade 6',
    'Grade 7',
  ];

  Color get _subjectColor {
    final s = _selectedSubject.toLowerCase();
    if (s.contains('math')) return _kMath;
    if (s.contains('science')) return _kScience;
    if (s.contains('english') || s.contains('lang')) return _kEnglish;
    return _kSocial;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('activities').add({
        'teacherUid': widget.teacherUid,
        'title': _titleCtrl.text.trim(),
        'subject': _selectedSubject,
        'grade': _selectedGrade,
        'description': _descCtrl.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'completionCount': 0,
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Activity created!'),
              backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white24
                        : Colors.black26,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _kPrimary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.add_circle_outline, color: _kPrimary),
                ),
                const SizedBox(width: 12),
                Text('Create Activity', style: AppTextStyles.h3),
              ],
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText: 'Activity Title',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.title_outlined),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Title required' : null,
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _selectedSubject,
              decoration: InputDecoration(
                labelText: 'Subject',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                        color: _subjectColor, shape: BoxShape.circle),
                  ),
                ),
              ),
              items: _subjects
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _selectedSubject = v ?? _selectedSubject),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _selectedGrade,
              decoration: InputDecoration(
                labelText: 'Grade',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.school_outlined),
              ),
              items: _grades
                  .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _selectedGrade = v ?? _selectedGrade),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Description (optional)',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                alignLabelWithHint: true,
                prefixIcon: const Icon(Icons.description_outlined),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _kPrimary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : Text('Create Activity', style: AppTextStyles.button),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROFILE TAB
// ─────────────────────────────────────────────────────────────────────────────
class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthProvider>().user;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        children: [
          const ProfileAvatarPicker(radius: 55),
          const SizedBox(height: 16),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                currentUser?.displayName ?? currentUser?.name ?? 'Teacher',
                style: AppTextStyles.h2,
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/edit_profile'),
                child: const Icon(Icons.edit, color: AppColors.textSecondary, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: _kPrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Teacher Account',
              style: AppTextStyles.bodySmall
                  .copyWith(color: _kPrimary, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 32),
          _ProfileInfoCard(
            children: [
              _InfoRow(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: currentUser?.email ?? ''),
              const Divider(height: 1),
              _InfoRow(
                  icon: Icons.school_outlined,
                  label: 'Grade / Class',
                  value: currentUser?.grade ?? 'Not set'),
              const Divider(height: 1),
              const _InfoRow(
                  icon: Icons.person_outline, label: 'Role', value: 'Teacher'),
              const Divider(height: 1),
              _InfoRow(
                  icon: Icons.language_outlined,
                  label: 'Language',
                  value: currentUser?.preferredLanguage ?? 'English'),
            ],
          ),
          const SizedBox(height: 20),
          if (currentUser?.childLinkCode != null) ...[
            _ProfileInfoCard(
              children: [
                _InfoRow(
                  icon: Icons.vpn_key_outlined,
                  label: 'Class Code',
                  value: currentUser!.childLinkCode!,
                  valueStyle: AppTextStyles.h4
                      .copyWith(letterSpacing: 4, color: _kPrimary),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
          const ProfileSettingsTile(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared small widgets
// ─────────────────────────────────────────────────────────────────────────────

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatTile(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(value,
              style: AppTextStyles.h2.copyWith(color: color, fontSize: 22)),
          Text(label, style: AppTextStyles.bodySmall, maxLines: 1),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final String learnerName;
  final String subject;
  final int score;
  final String timeAgo;
  final Color subjectColor;

  const _ActivityCard({
    required this.learnerName,
    required this.subject,
    required this.score,
    required this.timeAgo,
    required this.subjectColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: subjectColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: subjectColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: subjectColor.withValues(alpha: 0.2),
            child: Text(
              learnerName.isNotEmpty ? learnerName[0].toUpperCase() : '?',
              style:
                  TextStyle(color: subjectColor, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(learnerName,
                    style: AppTextStyles.bodyMedium
                        .copyWith(fontWeight: FontWeight.w600)),
                Text(subject, style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$score%',
                  style: AppTextStyles.bodyMedium.copyWith(
                      color: subjectColor, fontWeight: FontWeight.w700)),
              Text(timeAgo, style: AppTextStyles.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _QuickActionBtn(
      {required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('${label.replaceAll('\n', ' ')} — coming soon')),
        ),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 6),
              Text(label,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: color, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                  maxLines: 2),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;

  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: AppTextStyles.bodySmall
              .copyWith(color: color, fontWeight: FontWeight.w700)),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricTile(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: AppTextStyles.h4.copyWith(color: color)),
              Text(label, style: AppTextStyles.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileInfoCard extends StatelessWidget {
  final List<Widget> children;
  const _ProfileInfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kPrimary.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final TextStyle? valueStyle;

  const _InfoRow(
      {required this.icon,
      required this.label,
      required this.value,
      this.valueStyle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: _kPrimary, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.bodySmall),
                const SizedBox(height: 2),
                Text(value,
                    style: valueStyle ??
                        AppTextStyles.bodyMedium
                            .copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyCard({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _kPrimary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kPrimary.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Text(message,
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message,
                style:
                    AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
