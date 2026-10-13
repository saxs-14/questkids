import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/repositories/parent_repository.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/parent_provider.dart';

const _moods = [
  {'label': 'Great', 'emoji': '😊'},
  {'label': 'Good', 'emoji': '🙂'},
  {'label': 'Okay', 'emoji': '😐'},
  {'label': 'Sad', 'emoji': '😟'},
  {'label': 'Upset', 'emoji': '😢'},
];

class MoodCheckinScreen extends StatefulWidget {
  const MoodCheckinScreen({super.key});

  @override
  State<MoodCheckinScreen> createState() => _MoodCheckinScreenState();
}

class _MoodCheckinScreenState extends State<MoodCheckinScreen> {
  final _repo = ParentRepository();
  final _noteCtrl = TextEditingController();
  String? _selectedMood;
  bool _logging = false;
  Stream<List<Map<String, dynamic>>>? _historyStream;
  String? _historyChildUid;
  final Set<String> _deletingEntries = {};

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _logMood(String childUid, String parentUid) async {
    final selectedMood = _selectedMood;
    if (selectedMood == null || _logging) return;
    final mood = _moods.firstWhere((m) => m['label'] == selectedMood);
    setState(() => _logging = true);
    try {
      await context.read<ParentProvider>().logMoodCheckin(
            childUid,
            parentUid,
            mood['label']!,
            mood['emoji']!,
            _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
          );
      _noteCtrl.clear();
      if (!mounted) return;
      setState(() => _selectedMood = null);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Mood logged')));
    } catch (error, stackTrace) {
      debugPrint('Unable to save mood check-in: $error\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Mood check-in could not be saved. Please try again.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _logging = false);
    }
  }

  Future<void> _deleteMoodEntry(String entryId) async {
    if (!_deletingEntries.add(entryId)) return;
    setState(() {});
    try {
      await _repo.deleteMoodEntry(entryId);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Mood entry deleted.')));
      }
    } catch (error, stackTrace) {
      debugPrint('Unable to delete mood check-in: $error\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Mood entry could not be deleted. Please try again.'),
        ));
      }
    } finally {
      _deletingEntries.remove(entryId);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final parent = context.watch<ParentProvider>();
    final child = parent.selectedChild;
    final parentUid = context.read<AuthProvider>().user?.uid ?? '';

    if (child == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mood Check-in')),
        body: const Center(child: Text('Select a child first.')),
      );
    }
    if (_historyChildUid != child.uid) {
      _historyChildUid = child.uid;
      _historyStream = _repo.watchMoodHistory(child.uid);
    }

    return Scaffold(
      appBar: AppBar(title: Text("${child.name}'s Mood Check-in")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('How is ${child.name} feeling today?',
                    style: AppTextStyles.h4),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: _moods.map((m) {
                    final selected = _selectedMood == m['label'];
                    return ChoiceChip(
                      label: Text('${m['emoji']} ${m['label']}'),
                      selected: selected,
                      onSelected: (_) =>
                          setState(() => _selectedMood = m['label']),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _noteCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (_selectedMood == null || _logging)
                        ? null
                        : () => _logMood(child.uid, parentUid),
                    child: _logging
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Log Mood'),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _historyStream,
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                            'Mood history could not be loaded. Check your connection and try again.'),
                        TextButton(
                          onPressed: () => setState(() {
                            _historyStream = _repo.watchMoodHistory(child.uid);
                          }),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final entries = snap.data!;
                if (entries.isEmpty) {
                  return const Center(child: Text('No check-ins yet.'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final e = entries[i];
                    final date = e['date'];
                    final dateStr = date is Timestamp
                        ? DateFormat.yMMMd().add_jm().format(date.toDate())
                        : '';
                    return Card(
                      child: ListTile(
                        leading: Text(e['moodEmoji'] as String? ?? '🙂',
                            style: const TextStyle(fontSize: 24)),
                        title: Text(e['mood'] as String? ?? '',
                            style: AppTextStyles.bodyMedium),
                        subtitle: Text(
                          [
                            dateStr,
                            if ((e['note'] as String?)?.isNotEmpty ?? false)
                              e['note'] as String,
                          ].join(' — '),
                        ),
                        trailing: IconButton(
                          icon: _deletingEntries.contains(e['id'])
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : const Icon(Icons.delete_outline,
                                  color: AppColors.textSecondary),
                          onPressed: _deletingEntries.contains(e['id'])
                              ? null
                              : () => _deleteMoodEntry(e['id'] as String),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
