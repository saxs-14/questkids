import 'package:cloud_firestore/cloud_firestore.dart';

class GameLevelProgress {
  final String catalogId;
  final int currentLevel;
  final int highestCompletedLevel;
  final int bestScore;
  final bool completed;

  const GameLevelProgress({
    required this.catalogId,
    required this.currentLevel,
    required this.highestCompletedLevel,
    required this.bestScore,
    required this.completed,
  });

  factory GameLevelProgress.fromMap(String catalogId, Map<String, dynamic>? data) {
    final map = data ?? const <String, dynamic>{};
    return GameLevelProgress(
      catalogId: catalogId,
      currentLevel: ((map['currentLevel'] as num?)?.toInt() ?? 1).clamp(1, 10),
      highestCompletedLevel:
          ((map['highestCompletedLevel'] as num?)?.toInt() ?? 0).clamp(0, 10),
      bestScore: ((map['bestScore'] as num?)?.toInt() ?? 0).clamp(0, 100),
      completed: map['completed'] == true,
    );
  }
}

class GameLevelProgressService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<GameLevelProgress> watch(String uid, String catalogId) {
    return _db
        .collection('game_level_progress')
        .doc(uid)
        .collection('games')
        .doc(catalogId)
        .snapshots()
        .map((snap) => GameLevelProgress.fromMap(catalogId, snap.data()));
  }

  Future<GameLevelProgress> get(String uid, String catalogId) async {
    final snap = await _db
        .collection('game_level_progress')
        .doc(uid)
        .collection('games')
        .doc(catalogId)
        .get();
    return GameLevelProgress.fromMap(catalogId, snap.data());
  }
}
