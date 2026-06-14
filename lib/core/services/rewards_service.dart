import '../../data/models/reward_model.dart';
import '../../data/repositories/reward_repository.dart';
import '../../data/repositories/user_repository.dart';

class RewardsService {
  final RewardRepository _rewardRepo = RewardRepository();
  final UserRepository _userRepo = UserRepository();

  static const List<Map<String, dynamic>> allBadges = [
    {
      'id': 'first_quest',
      'name': 'Quest Starter',
      'description': 'Complete your first quest',
      'icon': '🎯',
      'category': 'milestone',
      'requirement': 1,
      'type': 'quests_completed',
    },
    {
      'id': 'quest_5',
      'name': 'Quest Explorer',
      'description': 'Complete 5 quests',
      'icon': '🗺️',
      'category': 'milestone',
      'requirement': 5,
      'type': 'quests_completed',
    },
    {
      'id': 'quest_10',
      'name': 'Quest Master',
      'description': 'Complete 10 quests',
      'icon': '⚔️',
      'category': 'milestone',
      'requirement': 10,
      'type': 'quests_completed',
    },
    {
      'id': 'perfect_score',
      'name': 'Perfectionist',
      'description': 'Score 100% on any quiz',
      'icon': '💯',
      'category': 'achievement',
      'requirement': 100,
      'type': 'perfect_score',
    },
    {
      'id': 'streak_3',
      'name': 'On Fire',
      'description': 'Maintain a 3-day streak',
      'icon': '🔥',
      'category': 'streak',
      'requirement': 3,
      'type': 'streak',
    },
    {
      'id': 'streak_7',
      'name': 'Week Warrior',
      'description': 'Maintain a 7-day streak',
      'icon': '🌟',
      'category': 'streak',
      'requirement': 7,
      'type': 'streak',
    },
    {
      'id': 'streak_30',
      'name': 'Monthly Champion',
      'description': 'Maintain a 30-day streak',
      'icon': '👑',
      'category': 'streak',
      'requirement': 30,
      'type': 'streak',
    },
    {
      'id': 'math_master',
      'name': 'Math Wizard',
      'description': 'Complete 3 Math quests',
      'icon': '🔢',
      'category': 'subject',
      'requirement': 3,
      'type': 'math_completed',
    },
    {
      'id': 'science_master',
      'name': 'Science Star',
      'description': 'Complete 3 Science quests',
      'icon': '🔬',
      'category': 'subject',
      'requirement': 3,
      'type': 'science_completed',
    },
    {
      'id': 'english_master',
      'name': 'Word Champion',
      'description': 'Complete 3 English quests',
      'icon': '📖',
      'category': 'subject',
      'requirement': 3,
      'type': 'english_completed',
    },
    {
      'id': 'points_100',
      'name': 'Point Collector',
      'description': 'Earn 100 points',
      'icon': '⭐',
      'category': 'points',
      'requirement': 100,
      'type': 'total_points',
    },
    {
      'id': 'points_500',
      'name': 'Point Hoarder',
      'description': 'Earn 500 points',
      'icon': '💎',
      'category': 'points',
      'requirement': 500,
      'type': 'total_points',
    },
    {
      'id': 'level_5',
      'name': 'Rising Star',
      'description': 'Reach Level 5',
      'icon': '🚀',
      'category': 'level',
      'requirement': 5,
      'type': 'level',
    },
    {
      'id': 'speed_demon',
      'name': 'Speed Demon',
      'description': 'Complete a quiz in under 60 seconds',
      'icon': '⚡',
      'category': 'special',
      'requirement': 60,
      'type': 'speed',
    },
  ];

  Future<List<BadgeModel>> checkAndAwardBadges({
    required String uid,
    required int totalPoints,
    required int level,
    required int streakDays,
    required int questsCompleted,
    required int perfectScores,
    required Map<String, int> subjectCounts,
    required int lastQuizTimeSeconds,
  }) async {
    final rewards = await _rewardRepo.getRewards(uid);
    if (rewards == null) return [];

    final existingBadgeIds =
        rewards.badges.map((b) => b.id).toSet();
    final newBadges = <BadgeModel>[];

    for (final badge in allBadges) {
      if (existingBadgeIds.contains(badge['id'])) continue;

      bool earned = false;
      switch (badge['type']) {
        case 'quests_completed':
          earned = questsCompleted >= (badge['requirement'] as int);
          break;
        case 'perfect_score':
          earned = perfectScores >= 1;
          break;
        case 'streak':
          earned = streakDays >= (badge['requirement'] as int);
          break;
        case 'math_completed':
          earned = (subjectCounts['Math'] ?? 0) >=
              (badge['requirement'] as int);
          break;
        case 'science_completed':
          earned = (subjectCounts['Science'] ?? 0) >=
              (badge['requirement'] as int);
          break;
        case 'english_completed':
          earned = (subjectCounts['English'] ?? 0) >=
              (badge['requirement'] as int);
          break;
        case 'total_points':
          earned = totalPoints >= (badge['requirement'] as int);
          break;
        case 'level':
          earned = level >= (badge['requirement'] as int);
          break;
        case 'speed':
          earned = lastQuizTimeSeconds > 0 &&
              lastQuizTimeSeconds <=
                  (badge['requirement'] as int);
          break;
      }

      if (earned) {
        final newBadge = BadgeModel(
          id: badge['id'] as String,
          name: badge['name'] as String,
          description: badge['description'] as String,
          icon: badge['icon'] as String,
          category: badge['category'] as String,
          earnedAt: DateTime.now(),
        );
        await _rewardRepo.awardBadge(uid, newBadge);
        newBadges.add(newBadge);
      }
    }
    return newBadges;
  }

  Future<void> updateStreak(String uid) async {
    final rewards = await _rewardRepo.getRewards(uid);
    if (rewards == null) return;

    final now = DateTime.now();
    final last = rewards.lastActiveDate;
    final diff = now.difference(last).inDays;

    int newStreak = rewards.streakDays;
    if (diff == 1) {
      newStreak++;
    } else if (diff > 1) {
      newStreak = 1;
    } else if (diff == 0) {
      return;
    }

    await _rewardRepo.updateStreak(uid, newStreak);
    await _userRepo.updateUser(uid, {'streakDays': newStreak});
  }

  static int getLevelFromPoints(int points) =>
      (points ~/ 100) + 1;

  static double getLevelProgress(int points) {
    return (points % 100) / 100;
  }

  static String getLevelTitle(int level) {
    if (level < 3) return 'Beginner';
    if (level < 6) return 'Explorer';
    if (level < 10) return 'Adventurer';
    if (level < 15) return 'Champion';
    if (level < 20) return 'Legend';
    return 'Grand Master';
  }

  static String getLevelEmoji(int level) {
    if (level < 3) return '🌱';
    if (level < 6) return '⭐';
    if (level < 10) return '🔥';
    if (level < 15) return '💎';
    return '👑';
  }
}
