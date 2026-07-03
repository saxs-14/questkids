import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/connectivity_provider.dart';
import '../../../core/services/offline_service.dart';
import '../../../data/models/activity_model.dart';

class OfflineScreen extends StatefulWidget {
  final bool embedded;
  const OfflineScreen({super.key, this.embedded = false});

  @override
  State<OfflineScreen> createState() => _OfflineScreenState();
}

class _OfflineScreenState extends State<OfflineScreen> {
  final OfflineService _offlineService = OfflineService();
  List<ActivityModel> _cachedActivities = [];
  bool _isLoading = true;
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _loadCachedData();
  }

  Future<void> _loadCachedData() async {
    setState(() => _isLoading = true);
    final user = context.read<AuthProvider>().user;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }
    final activities = await _offlineService.getCachedActivities(user.grade);
    final pending = await _offlineService.getPendingSync();
    setState(() {
      _cachedActivities = activities;
      _pendingCount = pending.length;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final conn = context.watch<ConnectivityProvider>();
    final uid = context.read<AuthProvider>().user?.uid ?? '';

    final body = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: conn.isOnline
                          ? [
                              AppColors.green,
                              AppColors.green.withValues(alpha: 0.7)
                            ]
                          : [
                              AppColors.error,
                              AppColors.error.withValues(alpha: 0.7)
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      Text(
                        conn.isOnline ? '🌐 Online' : '📵 Offline',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        conn.isOnline
                            ? 'All your progress is syncing to the cloud'
                            : 'Your progress is being saved locally',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                      if (_pendingCount > 0) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$_pendingCount items waiting to sync',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Sync Button
                if (conn.isOnline && _pendingCount > 0)
                  ElevatedButton.icon(
                    onPressed: conn.isSyncing
                        ? null
                        : () async {
                            await conn.syncNow(uid);
                            await _loadCachedData();
                          },
                    icon: conn.isSyncing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.sync),
                    label: Text(conn.isSyncing ? 'Syncing...' : 'Sync Now ☁️'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      backgroundColor: AppColors.green,
                    ),
                  ),
                if (conn.isOnline && _pendingCount > 0)
                  const SizedBox(height: 20),

                // Cached Quests
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Available Offline', style: AppTextStyles.h3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_cachedActivities.length} quests',
                        style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _cachedActivities.isEmpty
                    ? Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.1)),
                        ),
                        child: Column(
                          children: [
                            const Text('📦', style: TextStyle(fontSize: 48)),
                            const SizedBox(height: 12),
                            Text('No quests cached yet',
                                style: AppTextStyles.h4),
                            Text(
                              'Go online and open the Quests tab\nto cache quests for offline use.',
                              style: AppTextStyles.bodyMedium
                                  .copyWith(color: AppColors.textSecondary),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _cachedActivities.length,
                        itemBuilder: (_, i) {
                          final a = _cachedActivities[i];
                          return _CachedQuestTile(activity: a);
                        },
                      ),
                const SizedBox(height: 24),

                // Data info
                Text('Local Storage Info', style: AppTextStyles.h3),
                const SizedBox(height: 12),
                _InfoTile(
                  icon: '📚',
                  label: 'Cached Quests',
                  value: '${_cachedActivities.length}',
                  color: AppColors.primary,
                ),
                const SizedBox(height: 8),
                _InfoTile(
                  icon: '⏳',
                  label: 'Pending Sync',
                  value: '$_pendingCount items',
                  color: _pendingCount > 0 ? AppColors.orange : AppColors.green,
                ),
                const SizedBox(height: 8),
                const _InfoTile(
                  icon: '💾',
                  label: 'Local Database',
                  value: 'SQLite (questkids.db)',
                  color: AppColors.blue,
                ),
              ],
            ),
          );

    if (widget.embedded) return body;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Mode'),
        automaticallyImplyLeading: false,
      ),
      body: body,
    );
  }
}

class _CachedQuestTile extends StatelessWidget {
  final ActivityModel activity;
  const _CachedQuestTile({required this.activity});

  String get _emoji {
    switch (activity.subject) {
      case 'Math':
        return '🔢';
      case 'Science':
        return '🔬';
      case 'English':
        return '📖';
      case 'Social Sciences':
        return '🌍';
      default:
        return '📚';
    }
  }

  Color get _color {
    switch (activity.subject) {
      case 'Math':
        return AppColors.math;
      case 'Science':
        return AppColors.science;
      case 'English':
        return AppColors.english;
      default:
        return AppColors.socialSciences;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Text(_emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(activity.title,
                    style: AppTextStyles.bodyMedium
                        .copyWith(fontWeight: FontWeight.w700)),
                Text(
                    '${activity.subject} • '
                    '${activity.questions.length} questions',
                    style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.green.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.offline_pin, color: AppColors.green, size: 14),
                SizedBox(width: 4),
                Text('Cached',
                    style: TextStyle(
                      color: AppColors.green,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  final Color color;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: AppTextStyles.bodyMedium),
          ),
          Text(
            value,
            style: AppTextStyles.bodyMedium.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
