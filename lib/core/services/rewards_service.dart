import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/models/game_session_model.dart';
import '../../data/models/reward_model.dart';
import '../../data/repositories/progress_repository.dart';
import '../../data/repositories/reward_repository.dart';
import '../constants/app_constants.dart';

class RewardsService {
  final RewardRepository _rewardRepo = RewardRepository();
  final ProgressRepository _progressRepo = ProgressRepository();

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

  /// Grants XP to rewards/{uid} and users/{uid} for a completed
  /// game-engine session, mirroring the writes QuizService.submitQuiz
  /// already performs for the legacy quiz path -- without this, XP
  /// earned playing catalog games only ever landed in player_stats/{uid},
  /// which the Rewards screen, dashboard XP header, and leaderboard never
  /// read. Also checks for newly-earned badges using the same stats
  /// RewardsProvider.checkForNewBadges assembles for the quiz path.
  Future<List<BadgeModel>> grantGameSessionRewards(
      GameSessionModel session) async {
    await _rewardRepo.initRewards(session.uid);

    // Atomic across both stores -- previously two independent sequential
    // awaits (RewardRepository.addPoints then UserRepository.addPoints),
    // which could leave rewards/{uid} and users/{uid} holding different
    // totals for the same XP if interrupted or raced between the two
    // calls. Duplicates the small level-calc inline rather than reusing
    // RewardRepository.addPoints, since that method isn't transaction-
    // aware; keep this formula in sync with RewardRepository.addPoints /
    // RewardsService.getLevelFromPoints if either ever changes.
    final rewardsRef = FirebaseFirestore.instance
        .collection(AppConstants.colRewards)
        .doc(session.uid);
    final userRef =
        FirebaseFirestore.instance.collection(AppConstants.colUsers).doc(session.uid);
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final rewardsSnap = await tx.get(rewardsRef);
      final currentPoints =
          (rewardsSnap.data()?['totalPoints'] as num?)?.toInt() ?? 0;
      final newTotal = currentPoints + session.xpEarned;
      tx.update(rewardsRef, {
        'totalPoints': newTotal,
        'level': (newTotal ~/ 100) + 1,
        'lastActiveDate': DateTime.now().millisecondsSinceEpoch,
      });
      tx.update(userRef, {'totalPoints': FieldValue.increment(session.xpEarned)});
    });

    final rewards = await _rewardRepo.getRewards(session.uid);
    if (rewards == null) return [];

    final progressHistory = await _progressRepo.getUserProgress(session.uid);
    final questsCompleted = progressHistory.where((p) => p.completed).length;
    final perfectScores = progressHistory.where((p) => p.score == 100).length;
    final subjectCounts = <String, int>{};
    for (final p in progressHistory.where((p) => p.completed)) {
      subjectCounts[p.subject] = (subjectCounts[p.subject] ?? 0) + 1;
    }

    return checkAndAwardBadges(
      uid: session.uid,
      totalPoints: rewards.totalPoints,
      level: rewards.level,
      streakDays: rewards.streakDays,
      questsCompleted: questsCompleted,
      perfectScores: perfectScores,
      subjectCounts: subjectCounts,
      lastQuizTimeSeconds: session.timeTakenSeconds,
    );
  }

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

    final existingBadgeIds = rewards.badges.map((b) => b.id).toSet();
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
          earned =
              (subjectCounts['English'] ?? 0) >= (badge['requirement'] as int);
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
    // Compare calendar dates, not raw elapsed duration -- Duration.inDays
    // on the raw DateTimes would miss a new day when the two visits are
    // <24h apart but cross midnight, or fail to count 23h-apart visits
    // that *are* on different calendar days.
    final nowDate = DateTime(now.year, now.month, now.day);
    final lastDate = DateTime(last.year, last.month, last.day);
    final diff = nowDate.difference(lastDate).inDays;

    int newStreak = rewards.streakDays;
    if (diff == 1) {
      newStreak++;
    } else if (diff > 1) {
      newStreak = 1;
    } else if (diff == 0) {
      return;
    } else {
      return; // diff < 0: clock skew -- do not touch the streak.
    }

    final batch = FirebaseFirestore.instance.batch();
    batch.update(
      FirebaseFirestore.instance.collection(AppConstants.colRewards).doc(uid),
      {'streakDays': newStreak, 'lastActiveDate': now.millisecondsSinceEpoch},
    );
    batch.update(
      FirebaseFirestore.instance.collection(AppConstants.colUsers).doc(uid),
      {'streakDays': newStreak},
    );
    await batch.commit();
  }

  static int getLevelFromPoints(int points) => (points ~/ 100) + 1;

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
