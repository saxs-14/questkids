import '../../core/constants/trading_post_catalog.dart';

class RewardModel {
  final String uid;
  final int totalPoints;
  final int level;
  final int streakDays;
  final List<BadgeModel> badges;
  final List<AchievementModel> achievements;
  final DateTime lastActiveDate;

  /// Canonical spendable Gold balance -- the single source of truth for
  /// the Trading Post. Earned atomically alongside XP in
  /// RewardsService.grantGameSessionRewards. (player_stats/{uid}.coins
  /// still exists as a legacy write for analytics history, but nothing
  /// reads it as currency any more.)
  final int goldBalance;

  /// Cosmetic item IDs the learner owns (from [TradingPostCatalog]).
  /// Always contains at least the free starter item.
  final List<String> ownedItemIds;

  /// The cosmetic currently equipped on Quest Boy in the Hideout.
  final String equippedItemId;

  RewardModel({
    required this.uid,
    this.totalPoints = 0,
    this.level = 1,
    this.streakDays = 0,
    this.badges = const [],
    this.achievements = const [],
    required this.lastActiveDate,
    this.goldBalance = 0,
    this.ownedItemIds = const [TradingPostCatalog.starterItemId],
    this.equippedItemId = TradingPostCatalog.starterItemId,
  });

  factory RewardModel.fromMap(Map<String, dynamic> map) {
    return RewardModel(
      uid: map['uid'] ?? '',
      totalPoints: map['totalPoints'] ?? 0,
      level: map['level'] ?? 1,
      streakDays: map['streakDays'] ?? 0,
      badges: (map['badges'] as List<dynamic>? ?? [])
          .map((b) => BadgeModel.fromMap(b))
          .toList(),
      achievements: (map['achievements'] as List<dynamic>? ?? [])
          .map((a) => AchievementModel.fromMap(a))
          .toList(),
      lastActiveDate: map['lastActiveDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['lastActiveDate'])
          : DateTime.now(),
      goldBalance: (map['goldBalance'] as num?)?.toInt() ?? 0,
      ownedItemIds: (map['ownedItemIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [TradingPostCatalog.starterItemId],
      equippedItemId:
          map['equippedItemId'] as String? ?? TradingPostCatalog.starterItemId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'totalPoints': totalPoints,
      'level': level,
      'streakDays': streakDays,
      'badges': badges.map((b) => b.toMap()).toList(),
      'achievements': achievements.map((a) => a.toMap()).toList(),
      'lastActiveDate': lastActiveDate.millisecondsSinceEpoch,
      'goldBalance': goldBalance,
      'ownedItemIds': ownedItemIds,
      'equippedItemId': equippedItemId,
    };
  }
}

class BadgeModel {
  final String id;
  final String name;
  final String description;
  final String icon; // emoji or asset path
  final String category; // subject, streak, level, special
  final DateTime earnedAt;

  BadgeModel({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.category,
    required this.earnedAt,
  });

  factory BadgeModel.fromMap(Map<String, dynamic> map) {
    return BadgeModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      icon: map['icon'] ?? '🏅',
      category: map['category'] ?? 'special',
      earnedAt: map['earnedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['earnedAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon': icon,
      'category': category,
      'earnedAt': earnedAt.millisecondsSinceEpoch,
    };
  }
}

class AchievementModel {
  final String id;
  final String title;
  final String description;
  final int pointsAwarded;
  final DateTime unlockedAt;

  AchievementModel({
    required this.id,
    required this.title,
    required this.description,
    required this.pointsAwarded,
    required this.unlockedAt,
  });

  factory AchievementModel.fromMap(Map<String, dynamic> map) {
    return AchievementModel(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      pointsAwarded: map['pointsAwarded'] ?? 0,
      unlockedAt: map['unlockedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['unlockedAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'pointsAwarded': pointsAwarded,
      'unlockedAt': unlockedAt.millisecondsSinceEpoch,
    };
  }
}
