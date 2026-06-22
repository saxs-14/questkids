import '../../data/models/reward_model.dart';
import '../../data/repositories/reward_repository.dart';
import '../../data/repositories/user_repository.dart';

class RewardsService {
  final RewardRepository _rewardRepo = RewardRepository();
  final UserRepository _userRepo = UserRepository();

  static const List<Map<String, dynamic>> allBadges = [
    {
      'id': 'first_quest',
      'name': 'First Quest',
      'description': 'Complete your first quest',
      'icon': '🌟',
      'category': 'milestone',
      'requirement': 1,
      'type': 'quests_completed',
    },
    {
      'id': 'math_wizard',
      'name': 'Math Wizard',
      'description': 'Complete 10 Maths games',
      'icon': '🔢',
      'category': 'subject',
      'requirement': 10,
      'type': 'math_completed',
    },
    {
      'id': 'bookworm',
      'name': 'Bookworm',
      'description': 'Complete 10 English games',
      'icon': '📚',
      'category': 'subject',
      'requirement': 10,
      'type': 'english_completed',
    },
    {
      'id': 'science_star',
      'name': 'Science Star',
      'description': 'Complete 10 Natural Sciences games',
      'icon': '🔬',
      'category': 'subject',
      'requirement': 10,
      'type': 'science_completed',
    },
    {
      'id': 'history_hunter',
      'name': 'History Hunter',
      'description': 'Complete 10 Social Sciences games',
      'icon': '🏛️',
      'category': 'subject',
      'requirement': 10,
      'type': 'social_completed',
    },
    {
      'id': 'life_champion',
      'name': 'Life Champion',
      'description': 'Complete 10 Life Skills games',
      'icon': '🌈',
      'category': 'subject',
      'requirement': 10,
      'type': 'lifeskills_completed',
    },
    {
      'id': 'speed_demon',
      'name': 'Speed Demon',
      'description': 'Complete a game in under 2 minutes',
      'icon': '⚡',
      'category': 'special',
      'requirement': 120,
      'type': 'speed',
    },
    {
      'id': 'perfect_score',
      'name': 'Perfect Score',
      'description': 'Get 100% in any game',
      'icon': '🎯',
      'category': 'achievement',
      'requirement': 100,
      'type': 'perfect_score',
    },
    {
      'id': 'streak_7',
      'name': '7-Day Streak',
      'description': 'Log in for 7 days in a row',
      'icon': '🔥',
      'category': 'streak',
      'requirement': 7,
      'type': 'streak',
    },
    {
      'id': 'quest_master',
      'name': 'Quest Master',
      'description': 'Complete 50 games',
      'icon': '👑',
      'category': 'milestone',
      'requirement': 50,
      'type': 'quests_completed',
    },
    {
      'id': 'knowledge_seeker',
      'name': 'Knowledge Seeker',
      'description': 'Play all subjects in one day',
      'icon': '🌍',
      'category': 'special',
      'requirement': 1,
      'type': 'all_subjects_today',
    },
    {
      'id': 'legend',
      'name': 'Legend',
      'description': 'Reach Level 10',
      'icon': '🦁',
      'category': 'level',
      'requirement': 10,
      'type': 'level',
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
    bool allSubjectsPlayedToday = false,
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
          earned = (subjectCounts['Mathematics'] ?? 0) >=
              (badge['requirement'] as int);
          break;
        case 'science_completed':
          earned = (subjectCounts['Natural Sciences'] ?? 0) >=
              (badge['requirement'] as int);
          break;
        case 'english_completed':
          earned = (subjectCounts['English'] ?? 0) >=
              (badge['requirement'] as int);
          break;
        case 'social_completed':
          earned = (subjectCounts['Social Sciences'] ?? 0) >=
              (badge['requirement'] as int);
          break;
        case 'lifeskills_completed':
          earned = (subjectCounts['Life Skills'] ?? 0) >=
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
              lastQuizTimeSeconds <= (badge['requirement'] as int);
          break;
        case 'all_subjects_today':
          earned = allSubjectsPlayedToday;
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
