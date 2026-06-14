import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/parent_provider.dart';
import '../../../data/repositories/parent_repository.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/widgets/responsive_scaffold.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../data/models/user_model.dart';

class ParentDashboard extends StatefulWidget {
  const ParentDashboard({super.key});

  @override
  State<ParentDashboard> createState() => _ParentDashboardState();
}

class _ParentDashboardState extends State<ParentDashboard> {
  int _selectedIndex = 0;
  final UserRepository _userRepo = UserRepository();
  final StorageService _storage = StorageService();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final parentProv = context.watch<ParentProvider>();
    final theme = context.watch<ThemeProvider>();
    final user = auth.user;

    // ensure parent provider is listening
    if (user != null && parentProv.linkedChildren.isEmpty && !parentProv.isLoading) {
      parentProv.loadParentData(user.uid);
    }

    return ResponsiveScaffold(
      selectedIndex: _selectedIndex,
      onDestinationSelected: (i) => setState(() => _selectedIndex = i),
      destinations: const [
        ResponsiveDestination(
            icon: Icons.home_outlined,
            activeIcon: Icons.home,
            label: 'Home'),
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
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const Text('Parent Dashboard',
                style: TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        elevation: 2,
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
            child: GestureDetector(
              onTap: () => setState(() => _selectedIndex = 3),
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
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _ParentHomeTab(user: user, userRepo: _userRepo),
          _VerificationTab(),
          const _ParentReportsTab(),
          _ParentCalendarTab(),
          _ParentProfileTab(user: user, storage: _storage, userRepo: _userRepo),
        ],
      ),
    );
  }
}

import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:file_selector/file_selector.dart';
import 'dart:convert';

class _ParentCalendarTab extends StatefulWidget {
  @override
  State<_ParentCalendarTab> createState() => _ParentCalendarTabState();
}

class _ParentCalendarTabState extends State<_ParentCalendarTab> {
  DateTime _focused = DateTime.now();
  DateTime? _selected;
  Map<DateTime, List<Map<String, dynamic>>> _events = {};
  List<Map<String, dynamic>> _reminders = [];

  void _loadEvents(String childUid) {
    ParentRepository().watchCalendarEvents(childUid).listen((list) {
      final map = <DateTime, List<Map<String, dynamic>>>{};
      for (final e in list) {
        final ts = e['date'];
        DateTime date;
        if (ts is Timestamp) {
          date = ts.toDate();
        } else if (ts is DateTime) date = ts;
        else date = DateTime.tryParse(e['date'].toString()) ?? DateTime.now();
        final key = DateTime(date.year, date.month, date.day);
        map.putIfAbsent(key, () => []).add(e);
      }
      setState(() => _events = map);
    });
    // reminders
    ParentRepository().watchReminders(childUid).listen((list) {
      setState(() => _reminders = list);
    });
  }

  Future<void> _showEventDialog({Map<String, dynamic>? event, required String childUid}) async {
    final titleCtrl = TextEditingController(text: event?['title'] ?? '');
    final descCtrl = TextEditingController(text: event?['description'] ?? '');
    DateTime selectedDate = event != null && event['date'] != null
        ? (event['date'] is Timestamp ? (event['date'] as Timestamp).toDate() : event['date'])
        : DateTime.now();

    await showDialog<void>(context: context, builder: (ctx) {
      return AlertDialog(
        title: Text(event == null ? 'Add Event' : 'Edit Event'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title')),
          TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description')),
          const SizedBox(height: 8),
          Row(children: [
            Text('${selectedDate.toLocal()}'.split(' ')[0]),
            const SizedBox(width: 8),
            TextButton(onPressed: () async {
              final picked = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime.now().subtract(const Duration(days: 365)), lastDate: DateTime.now().add(const Duration(days: 365)));
              if (picked != null) setState(() => selectedDate = DateTime(picked.year, picked.month, picked.day, selectedDate.hour, selectedDate.minute));
            }, child: const Text('Change')),
          ])
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(onPressed: () async {
            final payload = {
              'childUid': childUid,
              'title': titleCtrl.text,
              'description': descCtrl.text,
              'date': Timestamp.fromDate(selectedDate),
            };
            if (event == null) {
              await ParentRepository().addCalendarEvent(payload);
            } else {
              await ParentRepository().updateCalendarEvent(event['id'], payload);
            }
            Navigator.of(ctx).pop();
          }, child: const Text('Save'))
        ],
      );
    });
  }

  Future<void> _showReminderDialog({Map<String, dynamic>? reminder, required String childUid}) async {
    final titleCtrl = TextEditingController(text: reminder?['title'] ?? '');
    final descCtrl = TextEditingController(text: reminder?['note'] ?? '');
    DateTime selectedDate = reminder != null && reminder['remindAt'] != null
        ? (reminder['remindAt'] is Timestamp ? (reminder['remindAt'] as Timestamp).toDate() : reminder['remindAt'])
        : DateTime.now().add(const Duration(hours: 1));

    await showDialog<void>(context: context, builder: (ctx) {
      return AlertDialog(
        title: Text(reminder == null ? 'Add Reminder' : 'Edit Reminder'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title')),
          TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Note')),
          const SizedBox(height: 8),
          Row(children: [
            Text('${selectedDate.toLocal()}'.split(' ')[0]),
            const SizedBox(width: 8),
            TextButton(onPressed: () async {
              final picked = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime.now().subtract(const Duration(days: 365)), lastDate: DateTime.now().add(const Duration(days: 365)));
              if (picked != null) setState(() => selectedDate = DateTime(picked.year, picked.month, picked.day, selectedDate.hour, selectedDate.minute));
            }, child: const Text('Change')),
          ])
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(onPressed: () async {
            final payload = {
              'childUid': childUid,
              'title': titleCtrl.text,
              'note': descCtrl.text,
              'remindAt': Timestamp.fromDate(selectedDate),
            };
            if (reminder == null) {
              await ParentRepository().addReminder(payload);
            } else {
              await ParentRepository().updateCalendarEvent(reminder['id'], payload);
            }
            Navigator.of(ctx).pop();
          }, child: const Text('Save'))
        ],
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final parentProv = context.read<ParentProvider>();
    final child = parentProv.selectedChild;
    if (child != null) {
      _loadEvents(child.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final parentProv = context.watch<ParentProvider>();
    final child = parentProv.selectedChild;
    if (child == null) return Center(child: Text('Select a child to view calendar', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)));

    List<Map<String, dynamic>> eventsForDay(DateTime day) => _events[DateTime(day.year, day.month, day.day)] ?? [];

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
              const Text('Reminders', style: AppTextStyles.h4),
              const SizedBox(height: 8),
              ..._reminders.map((r) => Card(child: ListTile(
                title: Text(r['title'] ?? 'Reminder'),
                subtitle: Text(r['note'] ?? ''),
                trailing: IconButton(icon: const Icon(Icons.delete), onPressed: () async { await ParentRepository().deleteReminder(r['id']); }),
              ))),
              const SizedBox(height: 12),
            ],

            // events
            ...eventsForDay(_selected ?? _focused).map((e) => Card(child: ListTile(
              title: Text(e['title'] ?? 'Event'),
              subtitle: Text(e['description'] ?? ''),
              trailing: PopupMenuButton<String>(onSelected: (v) async {
                if (v == 'edit') {
                  await _showEventDialog(event: e, childUid: child.uid);
                } else if (v == 'delete') {
                  await ParentRepository().deleteCalendarEvent(e['id']);
                }
              }, itemBuilder: (_) => [const PopupMenuItem(value: 'edit', child: Text('Edit')), const PopupMenuItem(value: 'delete', child: Text('Delete'))]),
            ))),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          ElevatedButton.icon(onPressed: () => _showEventDialog(childUid: child.uid), icon: const Icon(Icons.add), label: const Text('Add Event')),
          const SizedBox(width: 12),
          OutlinedButton.icon(onPressed: () => _showReminderDialog(childUid: child.uid), icon: const Icon(Icons.alarm), label: const Text('Add Reminder')),
          const SizedBox(width: 12),
          OutlinedButton.icon(onPressed: () => _importCsv(child.uid), icon: const Icon(Icons.upload_file), label: const Text('Import CSV')),
        ]),
      )
    ]);
  }

  Future<void> _importCsv(String childUid) async {
    try {
      final XTypeGroup typeGroup = XTypeGroup(label: 'csv', extensions: ['csv']);
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
        await ParentRepository().addCalendarEvent({'childUid': childUid, 'title': title, 'description': desc, 'date': Timestamp.fromDate(date)});
      }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CSV imported')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: $e')));
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
  late Future<List<UserModel>> _childrenFuture;

  @override
  void initState() {
    super.initState();
    _loadChildren();
  }

  void _loadChildren() {
    _childrenFuture = widget.userRepo.getChildren(
      widget.user?.linkedChildrenUids ?? []
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final parentProv = context.watch<ParentProvider>();

    final children = parentProv.linkedChildren;
    final selected = parentProv.selectedChild ?? (children.isNotEmpty ? children.first : null);

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
                        color: isSelected ? AppColors.primary.withValues(alpha: 0.12) : AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.08)),
                      ),
                      child: Column(children: [
                        CircleAvatar(radius: 24, backgroundColor: AppColors.primary, child: Text(c.name.isNotEmpty ? c.name[0] : '?')),
                        const SizedBox(height: 8),
                        Text(c.name, style: AppTextStyles.bodySmall, overflow: TextOverflow.ellipsis),
                        Text(c.grade, style: AppTextStyles.bodySmall.copyWith(fontSize: 11)),
                      ]),
                    ),
                  );
                }
                // Add child card
                return GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/parent_child_setup'),
                  child: Container(
                    width: 120,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.08)),
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: const [Icon(Icons.add), SizedBox(height: 8), Text('Add Child')]),
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
                gradient: LinearGradient(colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(selected.name, style: AppTextStyles.h2.copyWith(color: Colors.white)),
                const SizedBox(height: 8),
                Text('${selected.grade} • Level ${selected.totalPoints > 0 ? (selected.totalPoints ~/ 100) : 1}', style: AppTextStyles.bodyMedium.copyWith(color: Colors.white70)),
                const SizedBox(height: 12),
                Row(children: [
                  Text('🔥 Streak: ${selected.streakDays}', style: AppTextStyles.bodyMedium.copyWith(color: Colors.white)),
                  const SizedBox(width: 16),
                  Text('Last played: ${selected.lastActiveDate != null ? '${DateTime.now().difference(selected.lastActiveDate!).inHours}h ago' : 'Never'}', style: AppTextStyles.bodySmall.copyWith(color: Colors.white70)),
                ])
              ]),
            ),
            const SizedBox(height: 16),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
              child: Column(children: [Text('No child selected', style: AppTextStyles.h4), const SizedBox(height: 8), Text('Select a child or add a new one.', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary))]),
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

  Widget _buildStatsRow(bool isMobile) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _StatCard(
            label: 'Children',
            value: (widget.user?.linkedChildrenUids?.length ?? 0).toString(),
            emoji: '👧',
            color: AppColors.primary,
          ),
          const SizedBox(width: 12),
          const _StatCard(
            label: 'Active',
            value: '0',
            emoji: '🎮',
            color: AppColors.green,
          ),
          const SizedBox(width: 12),
          const _StatCard(
            label: 'Progress',
            value: '0%',
            emoji: '📈',
            color: AppColors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.1)),
      ),
      child: const Column(
        children: [
          _StatRow(label: 'Total Learning Time', value: '0h 0m', icon: Icons.timer),
          SizedBox(height: 12),
          _StatRow(label: 'Tasks Completed', value: '0', icon: Icons.check_circle),
          SizedBox(height: 12),
          _StatRow(label: 'Points Earned', value: '0', icon: Icons.star),
        ],
      ),
    );
  }
}

class _ChildCard extends StatelessWidget {
  final UserModel child;
  
  const _ChildCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final birthYear = child.birthDate?.year ?? DateTime.now().year;
    final age = DateTime.now().year - birthYear;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primary,
                child: Text(
                  child.name[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      child.name,
                      style: AppTextStyles.h4,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${child.grade} • Age $age',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: AppColors.primary.withValues(alpha: 0.1)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  const Text('⭐', style: TextStyle(fontSize: 20)),
                  const SizedBox(height: 4),
                  Text('0', style: AppTextStyles.bodySmall),
                  Text('Points', style: AppTextStyles.bodySmall.copyWith(fontSize: 10)),
                ],
              ),
              Column(
                children: [
                  const Text('🏆', style: TextStyle(fontSize: 20)),
                  const SizedBox(height: 4),
                  Text('0', style: AppTextStyles.bodySmall),
                  Text('Badges', style: AppTextStyles.bodySmall.copyWith(fontSize: 10)),
                ],
              ),
              Column(
                children: [
                  const Text('🔥', style: TextStyle(fontSize: 20)),
                  const SizedBox(height: 4),
                  Text('0', style: AppTextStyles.bodySmall),
                  Text('Streak', style: AppTextStyles.bodySmall.copyWith(fontSize: 10)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String emoji;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.emoji,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(height: 8),
          Text(value,
              style: AppTextStyles.score.copyWith(color: color),
              textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(label,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
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
          Text('All recent activities have been verified', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
        ]),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemBuilder: (context, i) {
        final item = pending[i];
        return Card(
          child: ListTile(
            leading: CircleAvatar(child: Text(item['activityTitle'] != null && item['activityTitle'].isNotEmpty ? item['activityTitle'][0] : 'A')),
            title: Text(item['activityTitle'] ?? 'Activity'),
            subtitle: Text('${item['childName'] ?? ''} • Score: ${item['score'] ?? 0}%'),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              ElevatedButton(onPressed: () async {
                // approve: set verified = true and award points
                await ParentRepository().approveProgress(item['id'], points: item['pointsEarned'] ?? 0, childUid: item['childUid']);
              }, child: const Text('Approve')),
              const SizedBox(width: 8),
              OutlinedButton(onPressed: () async {
                await ParentRepository().declineProgress(item['id']);
              }, child: const Text('Decline')),
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
          const Icon(Icons.group, size: 64, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          Text('No child selected', style: AppTextStyles.h3),
          const SizedBox(height: 8),
          Text('Select a child to view reports', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
        ]),
      );
    }

    final now = DateTime.now();
    final from = now.subtract(const Duration(days: 7));

    return FutureBuilder<Map<String, dynamic>>(
      future: ParentRepository().getChildAnalytics(selected.uid, from, now),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }

        final data = snap.data ?? {};

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Last 7 days', style: AppTextStyles.h3),
            const SizedBox(height: 12),
            Row(children: [
              ElevatedButton.icon(onPressed: () => _exportCsv(selected), icon: const Icon(Icons.file_present), label: const Text('Export CSV')),
              const SizedBox(width: 8),
              OutlinedButton.icon(onPressed: () => _exportPdf(selected), icon: const Icon(Icons.picture_as_pdf), label: const Text('Export PDF')),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _ReportCard(label: 'Games', value: (data['totalGames'] ?? 0).toString(), icon: Icons.videogame_asset)),
              const SizedBox(width: 12),
              Expanded(child: _ReportCard(label: 'Avg Score', value: '${(data['avgScore'] ?? 0).toStringAsFixed(1)}%', icon: Icons.show_chart)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _ReportCard(label: 'Points', value: (data['pointsEarned'] ?? 0).toString(), icon: Icons.star)),
              const SizedBox(width: 12),
              Expanded(child: _ReportCard(label: 'Best Subject', value: (data['bestSubject'] ?? 'N/A').toString(), icon: Icons.book)),
            ]),
            const SizedBox(height: 20),
            Text('Subject Breakdown', style: AppTextStyles.h4),
            const SizedBox(height: 8),
            _SubjectBreakdown(breakdown: Map<String, List>.from(data['subjectBreakdown'] ?? {})),
          ]),
        );
      },
    );
  }

  Future<void> _exportCsv(dynamic selected) async {
    try {
      final rows = <List<dynamic>>[];
      rows.add(['Date', 'Activity', 'Score', 'Points']);
      final progresses = await ParentRepository().getChildProgress(selected.uid, limit: 1000);
      for (final p in progresses) {
        rows.add([p.completedAt.toIso8601String() ?? '', p.activityTitle ?? '', p.score ?? 0, p.pointsEarned ?? 0]);
      }
      final csv = const ListToCsvConverter().convert(rows);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${selected.uid}_report.csv');
      await file.writeAsString(csv);
      await Share.shareXFiles([XFile(file.path)], text: 'Child report CSV');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  Future<void> _exportPdf(dynamic selected) async {
    try {
      final pdf = pw.Document();
      final progresses = await ParentRepository().getChildProgress(selected.uid, limit: 1000);
      pdf.addPage(pw.MultiPage(build: (ctx) {
        return [
          pw.Header(level: 0, child: pw.Text('Child Report')),
          pw.Paragraph(text: 'Generated on ${DateTime.now().toLocal()}'),
          pw.Table.fromTextArray(context: ctx, data: <List<String>>[
            ['Date', 'Activity', 'Score', 'Points'],
            ...progresses.map((p) => [p.completedAt.toIso8601String() ?? '', p.activityTitle ?? '', (p.score ?? 0).toString(), (p.pointsEarned ?? 0).toString()])
          ])
        ];
      }));

      final bytes = await pdf.save();
      await Printing.sharePdf(bytes: bytes, filename: '${selected.uid}_report.pdf');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF export failed: $e')));
    }
  }
}

class _ReportCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _ReportCard({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.06)),
      ),
      child: Row(children: [
        CircleAvatar(backgroundColor: AppColors.primary.withValues(alpha: 0.12), child: Icon(icon, color: AppColors.primary)),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(value, style: AppTextStyles.h4),
        ])
      ]),
    );
  }
}

class _SubjectBreakdown extends StatelessWidget {
  final Map<String, List> breakdown;

  const _SubjectBreakdown({required this.breakdown});

  @override
  Widget build(BuildContext context) {
    if (breakdown.isEmpty) return Text('No subject data', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary));
    return Column(children: breakdown.entries.map((e) {
      final avg = (e.value).isNotEmpty ? ((e.value).reduce((a, b) => a + b) / (e.value).length) : 0;
      return ListTile(
        title: Text(e.key),
        trailing: Text('${avg.toStringAsFixed(1)}%'),
      );
    }).toList());
  }
}

class _ParentProfileTab extends StatefulWidget {
  final dynamic user;
  final StorageService storage;
  final UserRepository userRepo;
  
  const _ParentProfileTab({
    required this.user,
    required this.storage,
    required this.userRepo,
  });

  @override
  State<_ParentProfileTab> createState() => _ParentProfileTabState();
}

class _ParentProfileTabState extends State<_ParentProfileTab> {
  bool _isUploading = false;

  Future<void> _pickAndUploadImage() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      setState(() => _isUploading = true);

      final bytes = await image.readAsBytes();
      final extension = image.name.split('.').last;
      
      final url = await widget.storage.uploadAvatar(
        uid: widget.user.uid,
        imageFile: bytes,
        extension: extension,
      );

      if (url != null && mounted) {
        await widget.userRepo.updateUser(widget.user.uid, {
          'avatarUrl': url,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile picture updated!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final isMobile = MediaQuery.of(context).size.width < 600;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 60,
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                backgroundImage: widget.user?.avatarUrl != null
                    ? NetworkImage(widget.user!.avatarUrl!)
                    : null,
                child: widget.user?.avatarUrl == null
                    ? Text(
                        widget.user?.name.isNotEmpty == true
                            ? widget.user!.name[0].toUpperCase()
                            : '?',
                        style: AppTextStyles.score
                            .copyWith(color: AppColors.primary),
                      )
                    : null,
              ),
              GestureDetector(
                onTap: _isUploading ? null : _pickAndUploadImage,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: _isUploading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.camera_alt,
                          color: Colors.white, size: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(widget.user?.name ?? 'Parent', style: AppTextStyles.h2),
          Text(widget.user?.displayName ?? 'Parent Account',
              style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.1)),
            ),
            child: Column(
              children: [
                _ProfileInfoRow(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: widget.user?.email ?? '',
                ),
                const Divider(),
                _ProfileInfoRow(
                  icon: Icons.person_outline,
                  label: 'Full Name',
                  value: '${widget.user?.name ?? ''} ${widget.user?.surname ?? ''}',
                ),
                const Divider(),
                _ProfileInfoRow(
                  icon: Icons.wc_outlined,
                  label: 'Gender',
                  value: widget.user?.gender ?? 'Not specified',
                ),
                const Divider(),
                _ProfileInfoRow(
                  icon: Icons.groups_outlined,
                  label: 'Children',
                  value: '${widget.user?.linkedChildrenUids?.length ?? 0}',
                ),
              ],
            ),
          ),
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
              Text(label, style: AppTextStyles.bodySmall.copyWith(fontSize: 11)),
              const SizedBox(height: 4),
              Text(value, style: AppTextStyles.bodyMedium),
            ],
          ),
        ],
      ),
    );
  }
}
