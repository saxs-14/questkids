import 'dart:async' show StreamSubscription;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/profile_avatar_picker.dart';
import '../../../core/widgets/responsive_scaffold.dart';
import '../../../data/repositories/parent_repository.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/parent_provider.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../../parent/screens/child_analytics_screen.dart';
import '../widgets/child_card.dart';

class ParentDashboard extends StatefulWidget {
  const ParentDashboard({super.key});

  @override
  State<ParentDashboard> createState() => _ParentDashboardState();
}

class _ParentDashboardState extends State<ParentDashboard> {
  int _selectedIndex = 0;
  final UserRepository _userRepo = UserRepository();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().user;
      if (user != null) context.read<ParentProvider>().loadParentData(user.uid);
    });
  }

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
            icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home'),
        ResponsiveDestination(
            icon: Icons.verified_outlined,
            activeIcon: Icons.verified,
            label: 'Verify'),
        ResponsiveDestination(
            icon: Icons.bar_chart_outlined,
            activeIcon: Icons.bar_chart,
            label: 'Reports'),
        ResponsiveDestination(
            icon: Icons.calendar_today_outlined,
            activeIcon: Icons.calendar_today,
            label: 'Calendar'),
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
              'Hi, ${user?.name.split(' ').first ?? 'Parent'} 👋',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const Text('Parent Dashboard',
                style: TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        elevation: 2,
        actions: [
          IconButton(
            icon: Icon(theme.isDark ? Icons.wb_sunny : Icons.nightlight_round),
            onPressed: theme.toggleTheme,
          ),
          IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const NotificationsScreen()),
                  )),
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
                            color: Colors.white, fontWeight: FontWeight.w700),
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _ParentHomeTab(user: user, userRepo: _userRepo),
          _VerificationTab(),
          const _ParentReportsTab(),
          _ParentCalendarTab(),
          _ParentProfileTab(user: user),
        ],
      ),
    );
  }
}

class _ParentCalendarTab extends StatefulWidget {
  @override
  State<_ParentCalendarTab> createState() => _ParentCalendarTabState();
}

class _ParentCalendarTabState extends State<_ParentCalendarTab> {
  DateTime _focused = DateTime.now();
  DateTime? _selected;
  Map<DateTime, List<Map<String, dynamic>>> _events = {};
  List<Map<String, dynamic>> _reminders = [];
  StreamSubscription? _eventsSub;
  StreamSubscription? _remindersSub;
  String? _loadedChildUid;

  @override
  void dispose() {
    _eventsSub?.cancel();
    _remindersSub?.cancel();
    super.dispose();
  }

  void _loadEvents(String childUid) {
    if (_loadedChildUid == childUid) return;
    _loadedChildUid = childUid;
    _eventsSub?.cancel();
    _remindersSub?.cancel();

    _eventsSub =
        ParentRepository().watchCalendarEvents(childUid).listen((list) {
      final map = <DateTime, List<Map<String, dynamic>>>{};
      for (final e in list) {
        final ts = e['date'];
        DateTime date;
        if (ts is Timestamp) {
          date = ts.toDate();
        } else if (ts is DateTime) {
          date = ts;
        } else {
          date = DateTime.tryParse(e['date'].toString()) ?? DateTime.now();
        }
        final key = DateTime(date.year, date.month, date.day);
        map.putIfAbsent(key, () => []).add(e);
      }
      if (mounted) setState(() => _events = map);
    });
    _remindersSub = ParentRepository().watchReminders(childUid).listen((list) {
      if (mounted) setState(() => _reminders = list);
    });
  }

  Future<void> _showEventDialog(
      {Map<String, dynamic>? event, required String childUid}) async {
    final titleCtrl = TextEditingController(text: event?['title'] ?? '');
    final descCtrl = TextEditingController(text: event?['description'] ?? '');
    DateTime selectedDate = event != null && event['date'] != null
        ? (event['date'] is Timestamp
            ? (event['date'] as Timestamp).toDate()
            : event['date'])
        : DateTime.now();

    await showDialog<void>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text(event == null ? 'Add Event' : 'Edit Event'),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(labelText: 'Title')),
                TextField(
                    controller: descCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Description')),
                const SizedBox(height: 8),
                Row(children: [
                  Text('${selectedDate.toLocal()}'.split(' ')[0]),
                  const SizedBox(width: 8),
                  TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                            context: ctx,
                            initialDate: selectedDate,
                            firstDate: DateTime.now()
                                .subtract(const Duration(days: 365)),
                            lastDate:
                                DateTime.now().add(const Duration(days: 365)));
                        if (picked != null)
                          setDialogState(() => selectedDate = DateTime(
                              picked.year,
                              picked.month,
                              picked.day,
                              selectedDate.hour,
                              selectedDate.minute));
                      },
                      child: const Text('Change')),
                ])
              ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Cancel')),
                ElevatedButton(
                    onPressed: () async {
                      final payload = {
                        'childUid': childUid,
                        'title': titleCtrl.text,
                        'description': descCtrl.text,
                        'date': Timestamp.fromDate(selectedDate),
                      };
                      if (event == null) {
                        await ParentRepository().addCalendarEvent(payload);
                      } else {
                        await ParentRepository()
                            .updateCalendarEvent(event['id'], payload);
                      }
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    },
                    child: const Text('Save'))
              ],
            );
          });
        });
  }

  Future<void> _showReminderDialog(
      {Map<String, dynamic>? reminder, required String childUid}) async {
    final titleCtrl = TextEditingController(text: reminder?['title'] ?? '');
    final descCtrl = TextEditingController(text: reminder?['note'] ?? '');
    DateTime selectedDate = reminder != null && reminder['remindAt'] != null
        ? (reminder['remindAt'] is Timestamp
            ? (reminder['remindAt'] as Timestamp).toDate()
            : reminder['remindAt'])
        : DateTime.now().add(const Duration(hours: 1));

    await showDialog<void>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text(reminder == null ? 'Add Reminder' : 'Edit Reminder'),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(labelText: 'Title')),
                TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(labelText: 'Note')),
                const SizedBox(height: 8),
                Row(children: [
                  Text('${selectedDate.toLocal()}'.split(' ')[0]),
                  const SizedBox(width: 8),
                  TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                            context: ctx,
                            initialDate: selectedDate,
                            firstDate: DateTime.now()
                                .subtract(const Duration(days: 365)),
                            lastDate:
                                DateTime.now().add(const Duration(days: 365)));
                        if (picked != null)
                          setDialogState(() => selectedDate = DateTime(
                              picked.year,
                              picked.month,
                              picked.day,
                              selectedDate.hour,
                              selectedDate.minute));
                      },
                      child: const Text('Change')),
                ])
              ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Cancel')),
                ElevatedButton(
                    onPressed: () async {
                      final payload = {
                        'childUid': childUid,
                        'title': titleCtrl.text,
                        'note': descCtrl.text,
                        'remindAt': Timestamp.fromDate(selectedDate),
                      };
                      if (reminder == null) {
                        await ParentRepository().addReminder(payload);
                      } else {
                        await ParentRepository()
                            .updateCalendarEvent(reminder['id'], payload);
                      }
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    },
                    child: const Text('Save'))
              ],
            );
          });
        });
  }

  @override
  Widget build(BuildContext context) {
    final parentProv = context.watch<ParentProvider>();
    final child = parentProv.selectedChild;
    if (child != null && child.uid != _loadedChildUid) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _loadEvents(child.uid));
    }
    if (child == null)
      return Center(
          child: Text('Select a child to view calendar',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary)));

    List<Map<String, dynamic>> eventsForDay(DateTime day) =>
        _events[DateTime(day.year, day.month, day.day)] ?? [];

    return Column(children: [
      TableCalendar(
        firstDay: DateTime.now().subtract(const Duration(days: 365)),
        lastDay: DateTime.now().add(const Duration(days: 365)),
        focusedDay: _focused,
        selectedDayPredicate: (d) => isSameDay(_selected, d),
        eventLoader: eventsForDay,
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selected = selectedDay;
            _focused = focusedDay;
          });
        },
      ),
      const SizedBox(height: 8),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            // reminders list
            if (_reminders.isNotEmpty) ...[
              Text('Reminders', style: AppTextStyles.h4),
              const SizedBox(height: 8),
              ..._reminders.map((r) => Card(
                      child: ListTile(
                    title: Text(r['title'] ?? 'Reminder'),
                    subtitle: Text(r['note'] ?? ''),
                    trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () async {
                          await ParentRepository().deleteReminder(r['id']);
                        }),
                  ))),
              const SizedBox(height: 12),
            ],

            // events
            ...eventsForDay(_selected ?? _focused).map((e) => Card(
                    child: ListTile(
                  title: Text(e['title'] ?? 'Event'),
                  subtitle: Text(e['description'] ?? ''),
                  trailing: PopupMenuButton<String>(
                      onSelected: (v) async {
                        if (v == 'edit') {
                          await _showEventDialog(event: e, childUid: child.uid);
                        } else if (v == 'delete') {
                          await ParentRepository().deleteCalendarEvent(e['id']);
                        }
                      },
                      itemBuilder: (_) => [
                            const PopupMenuItem(
                                value: 'edit', child: Text('Edit')),
                            const PopupMenuItem(
                                value: 'delete', child: Text('Delete'))
                          ]),
                ))),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          ElevatedButton.icon(
              onPressed: () => _showEventDialog(childUid: child.uid),
              icon: const Icon(Icons.add),
              label: const Text('Add Event')),
          const SizedBox(width: 12),
          OutlinedButton.icon(
              onPressed: () => _showReminderDialog(childUid: child.uid),
              icon: const Icon(Icons.alarm),
              label: const Text('Add Reminder')),
          const SizedBox(width: 12),
          OutlinedButton.icon(
              onPressed: () => _importCsv(child.uid),
              icon: const Icon(Icons.upload_file),
              label: const Text('Import CSV')),
        ]),
      )
    ]);
  }

  Future<void> _importCsv(String childUid) async {
    try {
      const XTypeGroup typeGroup =
          XTypeGroup(label: 'csv', extensions: ['csv']);
      final file = await openFile(acceptedTypeGroups: [typeGroup]);
      if (file == null) return;
      final content = await file.readAsString();
      final rows = const CsvToListConverter().convert(content);
      // Expect header: date,title,description
      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.isEmpty) continue;
        final dateStr = row[0].toString();
        DateTime? date;
        try {
          date = DateTime.parse(dateStr);
        } catch (_) {
          // try common formats
          date = DateTime.tryParse(dateStr);
        }
        if (date == null) continue;
        final title = row.length > 1 ? row[1].toString() : 'Imported Event';
        final desc = row.length > 2 ? row[2].toString() : '';
        await ParentRepository().addCalendarEvent({
          'childUid': childUid,
          'title': title,
          'description': desc,
          'date': Timestamp.fromDate(date)
        });
      }
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('CSV imported')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Import failed: $e')));
    }
  }
}

class _ParentHomeTab extends StatefulWidget {
  final dynamic user;
  final UserRepository userRepo;
  const _ParentHomeTab({required this.user, required this.userRepo});

  @override
  State<_ParentHomeTab> createState() => _ParentHomeTabState();
}

class _ParentHomeTabState extends State<_ParentHomeTab> {
  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final parentProv = context.watch<ParentProvider>();

    final children = parentProv.linkedChildren;
    final selected = parentProv.selectedChild ??
        (children.isNotEmpty ? children.first : null);

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Multi-child switcher
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, index) {
                if (index < children.length) {
                  final c = children[index];
                  final isSelected = selected?.uid == c.uid;
                  return GestureDetector(
                    onTap: () => parentProv.selectChild(c),
                    child: Container(
                      width: 120,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withValues(alpha: 0.12)
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.08)),
                      ),
                      child: Column(children: [
                        CircleAvatar(
                            radius: 24,
                            backgroundColor: AppColors.primary,
                            child: Text(c.name.isNotEmpty ? c.name[0] : '?')),
                        const SizedBox(height: 8),
                        Text(c.name,
                            style: AppTextStyles.bodySmall,
                            overflow: TextOverflow.ellipsis),
                        Text(c.grade,
                            style:
                                AppTextStyles.bodySmall.copyWith(fontSize: 11)),
                      ]),
                    ),
                  );
                }
                // Add child card
                return GestureDetector(
                  onTap: () =>
                      Navigator.pushNamed(context, '/parent_child_setup'),
                  child: Container(
                    width: 120,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.08)),
                    ),
                    child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add),
                          SizedBox(height: 8),
                          Text('Add Child')
                        ]),
                  ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemCount: children.length + 1,
            ),
          ),
          const SizedBox(height: 16),

          // Selected child summary
          if (selected != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  AppColors.primary,
                  AppColors.primary.withValues(alpha: 0.8)
                ]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(selected.name,
                        style: AppTextStyles.h2.copyWith(color: Colors.white)),
                    const SizedBox(height: 8),
                    Text(
                        '${selected.grade} • Level ${selected.totalPoints > 0 ? (selected.totalPoints ~/ 100) : 1}',
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: Colors.white70)),
                    const SizedBox(height: 12),
                    Row(children: [
                      Text('🔥 Streak: ${selected.streakDays}',
                          style: AppTextStyles.bodyMedium
                              .copyWith(color: Colors.white)),
                      const SizedBox(width: 16),
                      Text(
                          'Last played: ${selected.lastActiveDate != null ? '${DateTime.now().difference(selected.lastActiveDate!).inHours}h ago' : 'Never'}',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: Colors.white70)),
                    ])
                  ]),
            ),
            const SizedBox(height: 16),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12)),
              child: Column(children: [
                Text('No child selected', style: AppTextStyles.h4),
                const SizedBox(height: 8),
                Text('Select a child or add a new one.',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.textSecondary))
              ]),
            ),
            const SizedBox(height: 16),
          ],

          // Quick Stats
          Text('Quick Stats', style: AppTextStyles.h3),
          const SizedBox(height: 12),
          _buildQuickStats(isMobile),
        ],
      ),
    );
  }

  Widget _buildQuickStats(bool isMobile) {
    final parentProv = context.watch<ParentProvider>();
    final child = parentProv.selectedChild ??
        (parentProv.linkedChildren.isNotEmpty
            ? parentProv.linkedChildren.first
            : null);
    final points = child?.totalPoints ?? 0;
    final streak = child?.streakDays ?? 0;
    final level = points > 0 ? (points ~/ 100) + 1 : 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          _StatRow(
              label: 'Current Level',
              value: 'Level $level',
              icon: Icons.military_tech),
          const SizedBox(height: 12),
          _StatRow(
              label: 'Points Earned', value: '$points XP', icon: Icons.star),
          const SizedBox(height: 12),
          _StatRow(
              label: 'Day Streak',
              value: '$streak days 🔥',
              icon: Icons.local_fire_department),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(width: 12),
            Text(label, style: AppTextStyles.bodyMedium),
          ],
        ),
        Text(value,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            )),
      ],
    );
  }
}

class _VerificationTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final parentProv = context.watch<ParentProvider>();
    final pending = parentProv.pendingVerifications;

    if (parentProv.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (pending.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('🎉', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 12),
          Text('No pending verifications', style: AppTextStyles.h3),
          const SizedBox(height: 8),
          Text('All recent activities have been verified',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary)),
        ]),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemBuilder: (context, i) {
        final item = pending[i];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
                child: Text(item['activityTitle'] != null &&
                        item['activityTitle'].isNotEmpty
                    ? item['activityTitle'][0]
                    : 'A')),
            title: Text(item['activityTitle'] ?? 'Activity'),
            subtitle: Text(
                '${item['childName'] ?? ''} • Score: ${item['score'] ?? 0}%'),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              ElevatedButton(
                  onPressed: () async {
                    // approve: set verified = true and award points
                    await ParentRepository().approveProgress(item['id'],
                        points: item['pointsEarned'] ?? 0,
                        childUid: item['childUid']);
                  },
                  child: const Text('Approve')),
              const SizedBox(width: 8),
              OutlinedButton(
                  onPressed: () async {
                    await ParentRepository().declineProgress(item['id']);
                  },
                  child: const Text('Decline')),
            ]),
          ),
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemCount: pending.length,
    );
  }
}

class _ParentReportsTab extends StatefulWidget {
  const _ParentReportsTab();

  @override
  State<_ParentReportsTab> createState() => _ParentReportsTabState();
}

class _ParentReportsTabState extends State<_ParentReportsTab> {
  @override
  Widget build(BuildContext context) {
    final parentProv = context.watch<ParentProvider>();
    final selected = parentProv.selectedChild;

    if (selected == null) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.bar_chart, size: 64, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          Text('No child selected', style: AppTextStyles.h3),
          const SizedBox(height: 8),
          Text('Select a child to view analytics',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary)),
        ]),
      );
    }

    return ChildAnalyticsScreen(child: selected);
  }
}

class _ParentProfileTab extends StatelessWidget {
  final dynamic user;
  const _ParentProfileTab({required this.user});

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
          Text(user?.name ?? 'Parent', style: AppTextStyles.h2),
          Text(user?.displayName ?? 'Parent Account',
              style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
            ),
            child: Column(
              children: [
                _ProfileInfoRow(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: user?.email ?? '',
                ),
                const Divider(),
                _ProfileInfoRow(
                  icon: Icons.person_outline,
                  label: 'Full Name',
                  value: '${user?.name ?? ''} ${user?.surname ?? ''}',
                ),
                const Divider(),
                _ProfileInfoRow(
                  icon: Icons.wc_outlined,
                  label: 'Gender',
                  value: user?.gender ?? 'Not specified',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Builder(builder: (context) {
            final children = context.watch<ParentProvider>().linkedChildren;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('My Children', style: AppTextStyles.h4),
                const SizedBox(height: 12),
                if (children.isEmpty)
                  Text(
                    'No children linked yet.',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.textSecondary),
                  )
                else
                  ...children.map((c) => ChildCard(
                        child: c,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChildAnalyticsScreen(child: c),
                          ),
                        ),
                      )),
              ],
            );
          }),
          const SizedBox(height: 24),
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
}

class _ProfileInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileInfoRow({
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
              Text(label,
                  style: AppTextStyles.bodySmall.copyWith(fontSize: 11)),
              const SizedBox(height: 4),
              Text(value, style: AppTextStyles.bodyMedium),
            ],
          ),
        ],
      ),
    );
  }
}
