import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/game_catalog.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/daily_mission_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/mission_provider.dart';
import '../../games/core/game_config.dart';
import '../../games/core/game_router.dart';

class DailyMissionsCard extends StatelessWidget {
  const DailyMissionsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MissionProvider>();
    final missions = provider.missions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Daily Missions', style: AppTextStyles.h3),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${provider.completedCount}/${provider.totalCount}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: provider.totalCount > 0
                ? provider.completedCount / provider.totalCount
                : 0,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            valueColor:
                const AlwaysStoppedAnimation<Color>(AppColors.primary),
            minHeight: 4,
          ),
        ),
        const SizedBox(height: 12),
        if (missions.isEmpty)
          _EmptyMissions()
        else
          SizedBox(
            height: 136,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: missions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) => _MissionTile(
                mission: missions[i],
                index: i,
              ),
            ),
          ),
      ],
    );
  }
}

class _MissionTile extends StatelessWidget {
  final DailyMission mission;
  final int index;

  const _MissionTile({required this.mission, required this.index});

  Color _subjectColor() {
    switch (mission.subject) {
      case 'Mathematics':
        return AppColors.math;
      case 'English':
        return AppColors.english;
      case 'Natural Sciences':
        return AppColors.science;
      case 'Social Sciences':
        return AppColors.socialSciences;
      case 'Technology':
        return const Color(0xFF7C4DFF);
      case 'EMS':
        return const Color(0xFF00897B);
      default:
        return AppColors.primary;
    }
  }

  void _launchGame(BuildContext context) {
    final catalogEntry = GameCatalog.all
        .where((g) => g.id == mission.gameId)
        .cast<GameCatalogEntry?>()
        .firstOrNull;
    if (catalogEntry == null) return;

    final user = context.read<AuthProvider>().user;
    final config = GameConfig.fromCatalogEntry(catalogEntry);

    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => GameRouter(config: config, user: user),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final color = _subjectColor();
    final done = mission.completed;

    return GestureDetector(
      onTap: done ? null : () => _launchGame(context),
      child: Container(
        width: 148,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: done
              ? null
              : LinearGradient(
                  colors: [color, color.withValues(alpha: 0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          color: done ? Colors.grey.withValues(alpha: 0.15) : null,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: done ? Colors.grey.withValues(alpha: 0.3) : color,
          ),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mission.emoji,
                  style: TextStyle(
                    fontSize: 30,
                    color: done ? Colors.grey : null,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  mission.title,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: done ? Colors.grey : Colors.white,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                Text(
                  mission.sourceBadge,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: done
                        ? Colors.grey
                        : Colors.white.withValues(alpha: 0.75),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            if (done)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Center(
                    child: Text('✅', style: TextStyle(fontSize: 32)),
                  ),
                ),
              ),
          ],
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: index * 60))
        .slideX(begin: 0.2, end: 0, curve: Curves.easeOut)
        .fadeIn();
  }
}

class _EmptyMissions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          const Text('🌅', style: TextStyle(fontSize: 32)),
          const SizedBox(height: 8),
          Text(
            "Today's missions are loading...",
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
