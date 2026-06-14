import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/repositories/grade4_repository.dart';
import '../games/tug_of_war/tug_of_war_screen.dart';
// imports trimmed

class Grade4Hub extends StatefulWidget {
  final dynamic user;
  const Grade4Hub({super.key, required this.user});

  @override
  State<Grade4Hub> createState() => _Grade4HubState();
}

class _Grade4HubState extends State<Grade4Hub> {
  final Grade4Repository _repo = Grade4Repository();
  Map<String, dynamic>? _stats;
  Map<String, dynamic>? _daily;
  List<Map<String, dynamic>> _leaderboard = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = widget.user?.uid;
    if (uid == null) return;
    final stats = await _repo.getPlayerStats(uid) ?? {};
    final daily = await _repo.getOrCreateDailyMissions(uid, widget.user?.grade ?? 'Grade 4');
    _repo.watchLeaderboard('grade4').listen((list) {
      setState(() => _leaderboard = list);
    });
    setState(() {
      _stats = stats;
      _daily = daily;
    });
  }

  String _rankFromLevel(int level) {
    if (level >= 20) return 'Grand Master';
    if (level >= 15) return 'Legend';
    if (level >= 10) return 'Champion';
    if (level >= 6) return 'Adventurer';
    if (level >= 3) return 'Explorer';
    return 'Beginner';
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final stats = _stats ?? {};
    final xp = stats['xp'] ?? widget.user?.totalPoints ?? 0;
    final level = stats['level'] ?? (xp ~/ 100) + 1;
    final coins = stats['coins'] ?? 0;
    final rank = _rankFromLevel(level as int);

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Hero
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)]),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(children: [
            CircleAvatar(radius: 36, backgroundColor: Colors.white24, child: Text(widget.user?.avatarEmoji ?? '🙂', style: const TextStyle(fontSize: 28))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.user?.name ?? 'Learner', style: AppTextStyles.h2.copyWith(color: Colors.white)),
              const SizedBox(height: 6),
              Text('Grade 4 • Level $level $rank', style: AppTextStyles.bodyMedium.copyWith(color: Colors.white70)),
              const SizedBox(height: 12),
              // XP bar
              LinearProgressIndicator(value: ((xp % 100) / 100), color: Colors.white, backgroundColor: Colors.white24, minHeight: 12),
              const SizedBox(height: 6),
              Row(children: [Text('XP: $xp / ${level * 100}', style: AppTextStyles.bodySmall.copyWith(color: Colors.white)), const Spacer(), Text('🪙 $coins', style: AppTextStyles.bodyMedium.copyWith(color: Colors.white))])
            ]))
          ]),
        ),
        const SizedBox(height: 16),

        // Daily missions
        Text('Daily Missions', style: AppTextStyles.h3),
        const SizedBox(height: 8),
        _daily == null
            ? const SizedBox.shrink()
            : Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    ...(((_daily?['missions'] ?? []) as List).map((m) => _MissionRow(mission: m, onTap: () async {
                      final uid = widget.user?.uid;
                      if (uid == null) return;
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        await _repo.updateMissionProgress(uid, m['id'], 1);
                        final refreshed = await _repo.getOrCreateDailyMissions(uid, widget.user?.grade ?? 'Grade 4');
                        if (mounted) setState(() => _daily = refreshed);
                        final newProgress = (m['progress'] ?? 0) + 1;
                        if (newProgress >= (m['target'] ?? 1)) {
                          messenger.showSnackBar(const SnackBar(content: Text('Mission completed!')));
                        } else {
                          messenger.showSnackBar(const SnackBar(content: Text('Mission progress updated')));
                        }
                      } catch (e) {
                        messenger.showSnackBar(SnackBar(content: Text('Error updating mission: $e')));
                      }
                    }))),
                    const SizedBox(height: 8),
                    Text('+ rewards shown on completion', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                  ]),
                ),
              ),
        const SizedBox(height: 16),

        // World map (simplified horizontal)
        Text('World Map', style: AppTextStyles.h3),
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 6,
            itemBuilder: (context, i) {
              final worldId = 'world_${i+1}';
              final name = ['Number Kingdom','Multiplication Mountains','Fraction Forest','Geometry Jungle','Measurement Valley','Data City'][i];
              final unlocked = (stats['unlockedWorlds'] ?? []).contains(worldId);
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () {
                    if (unlocked) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => TugOfWarScreen(worldId: worldId, user: widget.user)),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('World locked')));
                    }
                  },
                  child: Container(
                  width: 200,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: unlocked ? Colors.white : AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.primary.withValues(alpha: 0.06))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [Text(unlocked ? '🔓' : '🔒'), const SizedBox(width: 8), Expanded(child: Text(name, style: AppTextStyles.bodyMedium))]),
                    const Spacer(),
                    Text(unlocked ? 'Play' : 'Locked', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary))
                  ]),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),

        // Leaderboard
        Text('Grade 4 Leaderboard', style: AppTextStyles.h3),
        const SizedBox(height: 8),
        Card(child: Column(children: _leaderboard.map((e) => ListTile(leading: Text(e['avatarEmoji'] ?? '🙂'), title: Text(e['name'] ?? ''), trailing: Text('Lv ${e['level'] ?? 1} • ${e['xp'] ?? 0} XP'))).toList())),
      ]),
    );
  }
}

class _MissionRow extends StatelessWidget {
  final Map mission;
  final VoidCallback onTap;
  const _MissionRow({required this.mission, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final completed = mission['completed'] ?? false;
    final progress = (mission['progress'] ?? 0) / (mission['target'] ?? 1);
    return ListTile(
      leading: CircleAvatar(backgroundColor: completed ? AppColors.green : AppColors.primary.withValues(alpha: 0.12), child: Text(completed ? '✅' : '⬜')),
      title: Text(mission['title'] ?? ''),
      subtitle: LinearProgressIndicator(value: progress.clamp(0.0,1.0)),
      onTap: onTap,
    );
  }
}
