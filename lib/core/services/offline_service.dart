import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import '../../data/models/activity_model.dart';
import '../../data/models/game_session_model.dart';
import '../../data/models/progress_model.dart';
import '../../data/models/reward_model.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/game_repository.dart';
import '../../data/repositories/progress_repository.dart';
import '../../data/repositories/reward_repository.dart';
import '../../data/repositories/user_repository.dart';
import 'local_storage_service.dart';

class OfflineService {
  final LocalStorageService _store = LocalStorageService.instance;
  final ProgressRepository _progressRepo = ProgressRepository();
  final RewardRepository _rewardRepo = RewardRepository();
  final UserRepository _userRepo = UserRepository();
  final GameRepository _gameRepo = GameRepository();

  // ── Connectivity ────────────────────────────────────

  Future<bool> isOnline() async {
    final results = await Connectivity().checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  Stream<bool> get connectivityStream =>
      Connectivity().onConnectivityChanged.map(
            (results) => results.any((r) => r != ConnectivityResult.none),
          );

  // ── User caching ─────────────────────────────────────

  Future<void> cacheUser(UserModel user) async {
    await _store.insert('users', {
      'uid': user.uid,
      'name': user.name,
      'email': user.email,
      'role': user.role,
      'grade': user.grade,
      'totalPoints': user.totalPoints,
      'streakDays': user.streakDays,
      'avatarUrl': user.avatarUrl,
      'parentUid': user.parentUid,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<UserModel?> getCachedUser(String uid) async {
    final rows = await _store.query(
      'users',
      where: 'uid = ?',
      whereArgs: [uid],
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return UserModel(
      uid: row['uid'] as String,
      name: row['name'] as String,
      email: row['email'] as String,
      role: row['role'] as String,
      grade: row['grade'] as String,
      totalPoints: row['totalPoints'] as int,
      streakDays: row['streakDays'] as int,
      avatarUrl: row['avatarUrl'] as String?,
      parentUid: row['parentUid'] as String?,
      createdAt: DateTime.now(),
    );
  }

  // ── Activity caching ─────────────────────────────────

  Future<void> cacheActivities(List<ActivityModel> activities) async {
    for (final a in activities) {
      await _store.insert('activities', {
        'id': a.id,
        'title': a.title,
        'description': a.description,
        'subject': a.subject,
        'type': a.type,
        'difficulty': a.difficulty,
        'rewardPoints': a.rewardPoints,
        'grade': a.grade,
        'questionsJson': jsonEncode(a.questions.map((q) => q.toMap()).toList()),
        'requiresProof': a.requiresProof ? 1 : 0,
        'createdAt': a.createdAt.millisecondsSinceEpoch,
      });
    }
  }

  Future<List<ActivityModel>> getCachedActivities(String grade) async {
    final rows = await _store.query(
      'activities',
      where: 'grade = ?',
      whereArgs: [grade],
    );
    return rows.map((row) {
      final questionsJson =
          jsonDecode(row['questionsJson'] as String) as List<dynamic>;
      return ActivityModel(
        id: row['id'] as String,
        title: row['title'] as String,
        description: row['description'] as String,
        subject: row['subject'] as String,
        type: row['type'] as String,
        difficulty: row['difficulty'] as String,
        rewardPoints: row['rewardPoints'] as int,
        grade: row['grade'] as String,
        requiresProof: (row['requiresProof'] as int) == 1,
        createdAt: DateTime.fromMillisecondsSinceEpoch(row['createdAt'] as int),
        questions: questionsJson
            .map((q) => QuestionModel.fromMap(q as Map<String, dynamic>))
            .toList(),
      );
    }).toList();
  }

  // ── Progress caching & sync ───────────────────────────

  Future<void> saveProgressOffline(ProgressModel progress) async {
    await _store.insert('progress', {
      'uid': progress.uid,
      'activityId': progress.activityId,
      'activityTitle': progress.activityTitle,
      'subject': progress.subject,
      'score': progress.score,
      'pointsEarned': progress.pointsEarned,
      'completed': progress.completed ? 1 : 0,
      'verified': progress.verified ? 1 : 0,
      'proofUrl': progress.proofUrl,
      'completedAt': progress.completedAt.millisecondsSinceEpoch,
      'timeTakenSeconds': progress.timeTakenSeconds,
      'synced': 0,
    });

    await _addToPendingSync(
      type: 'progress',
      data: progress.toMap(),
    );
  }

  Future<void> saveGameSessionOffline(GameSessionModel session) async {
    final map = session.toMap();
    // Timestamp isn't JSON-serializable; store completedAt as millis and
    // convert back in applyPendingSyncItem's 'game_session' case.
    map['completedAt'] = session.completedAt.millisecondsSinceEpoch;
    await _addToPendingSync(
      type: 'game_session',
      data: {...map, 'id': session.id},
    );
  }

  Future<List<ProgressModel>> getCachedProgress(String uid) async {
    final rows = await _store.query(
      'progress',
      where: 'uid = ?',
      whereArgs: [uid],
      orderBy: 'completedAt DESC',
    );
    return rows
        .map((row) => ProgressModel(
              uid: row['uid'] as String,
              activityId: row['activityId'] as String,
              activityTitle: row['activityTitle'] as String,
              subject: row['subject'] as String,
              score: row['score'] as int,
              pointsEarned: row['pointsEarned'] as int,
              completed: (row['completed'] as int) == 1,
              verified: (row['verified'] as int) == 1,
              proofUrl: row['proofUrl'] as String?,
              completedAt: DateTime.fromMillisecondsSinceEpoch(
                  row['completedAt'] as int),
              timeTakenSeconds: row['timeTakenSeconds'] as int,
            ))
        .toList();
  }

  // ── Rewards caching ───────────────────────────────────

  Future<void> cacheRewards(RewardModel rewards) async {
    await _store.insert('rewards', {
      'uid': rewards.uid,
      'totalPoints': rewards.totalPoints,
      'level': rewards.level,
      'streakDays': rewards.streakDays,
      'badgesJson': jsonEncode(rewards.badges.map((b) => b.toMap()).toList()),
      'achievementsJson':
          jsonEncode(rewards.achievements.map((a) => a.toMap()).toList()),
      'lastActiveDate': rewards.lastActiveDate.millisecondsSinceEpoch,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<RewardModel?> getCachedRewards(String uid) async {
    final rows = await _store.query(
      'rewards',
      where: 'uid = ?',
      whereArgs: [uid],
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    final badgesJson = jsonDecode(row['badgesJson'] as String) as List<dynamic>;
    final achievementsJson =
        jsonDecode(row['achievementsJson'] as String) as List<dynamic>;
    return RewardModel(
      uid: row['uid'] as String,
      totalPoints: row['totalPoints'] as int,
      level: row['level'] as int,
      streakDays: row['streakDays'] as int,
      badges: badgesJson
          .map((b) => BadgeModel.fromMap(b as Map<String, dynamic>))
          .toList(),
      achievements: achievementsJson
          .map((a) => AchievementModel.fromMap(a as Map<String, dynamic>))
          .toList(),
      lastActiveDate:
          DateTime.fromMillisecondsSinceEpoch(row['lastActiveDate'] as int),
    );
  }

  // ── Pending sync queue ────────────────────────────────

  Future<void> _addToPendingSync({
    required String type,
    required Map<String, dynamic> data,
  }) async {
    await _store.insert('pending_sync', {
      'type': type,
      'dataJson': jsonEncode(data),
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      'retryCount': 0,
    });
  }

  Future<List<Map<String, dynamic>>> getPendingSync() async {
    return await _store.query(
      'pending_sync',
      orderBy: 'createdAt ASC',
    );
  }

  Future<void> removePendingSync(int id) async {
    await _store.delete('pending_sync', 'id = ?', [id]);
  }

  Future<void> incrementRetryCount(int id) async {
    final rows = await _store.query(
      'pending_sync',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return;
    final current = rows.first['retryCount'] as int;
    await _store.update(
      'pending_sync',
      {'retryCount': current + 1},
      'id = ?',
      [id],
    );
  }

  // ── Full sync ─────────────────────────────────────────

  /// Applies one pending-sync item to Firestore. Throws if [type] is not
  /// a recognized pending-sync type, so callers must not mark an
  /// unhandled item as synced.
  @visibleForTesting
  Future<void> applyPendingSyncItem(
      String type, Map<String, dynamic> data) async {
    switch (type) {
      case 'progress':
        await _progressRepo.saveProgress(ProgressModel.fromMap(data));
        return;
      case 'game_session':
        final map = Map<String, dynamic>.from(data);
        map['completedAt'] =
            Timestamp.fromMillisecondsSinceEpoch(map['completedAt'] as int);
        await _gameRepo.logGameSession(
          GameSessionModel.fromMap(data['id'] as String, map),
        );
        return;
      default:
        throw StateError('Unknown pending sync type: $type');
    }
  }

  Future<SyncResult> syncToFirestore(String uid) async {
    if (!await isOnline()) {
      return SyncResult(
          success: false, message: 'No internet connection', synced: 0);
    }

    final pending = await getPendingSync();
    if (pending.isEmpty) {
      return SyncResult(
          success: true, message: 'Everything is up to date', synced: 0);
    }

    int syncedCount = 0;
    final errors = <String>[];

    for (final item in pending) {
      try {
        final id = item['id'] as int;
        final type = item['type'] as String;
        final data =
            jsonDecode(item['dataJson'] as String) as Map<String, dynamic>;

        await applyPendingSyncItem(type, data);

        await removePendingSync(id);
        syncedCount++;
      } catch (e) {
        await incrementRetryCount(item['id'] as int);
        errors.add('Failed to sync item: $e');
      }
    }

    await _syncFromFirestore(uid);

    return SyncResult(
      success: errors.isEmpty,
      message: errors.isEmpty
          ? 'Synced $syncedCount items successfully'
          : '${errors.length} items failed to sync',
      synced: syncedCount,
    );
  }

  Future<void> _syncFromFirestore(String uid) async {
    try {
      final user = await _userRepo.getUser(uid);
      if (user != null) await cacheUser(user);

      final rewards = await _rewardRepo.getRewards(uid);
      if (rewards != null) await cacheRewards(rewards);

      final progress = await _progressRepo.getUserProgress(uid);
      for (final p in progress) {
        await _store.insert('progress', {
          'uid': p.uid,
          'activityId': p.activityId,
          'activityTitle': p.activityTitle,
          'subject': p.subject,
          'score': p.score,
          'pointsEarned': p.pointsEarned,
          'completed': p.completed ? 1 : 0,
          'verified': p.verified ? 1 : 0,
          'proofUrl': p.proofUrl,
          'completedAt': p.completedAt.millisecondsSinceEpoch,
          'timeTakenSeconds': p.timeTakenSeconds,
          'synced': 1,
        });
      }
    } catch (_) {}
  }

  // ── App settings ──────────────────────────────────────

  Future<void> saveSetting(String key, String value) async {
    await _store.insert('app_settings', {'key': key, 'value': value});
  }

  Future<String?> getSetting(String key) async {
    final rows = await _store.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: [key],
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  // ── Clear local data ──────────────────────────────────

  Future<void> clearAllLocalData() async {
    await _store.clearTable('users');
    await _store.clearTable('activities');
    await _store.clearTable('progress');
    await _store.clearTable('rewards');
    await _store.clearTable('pending_sync');
    await _store.clearTable('app_settings');
  }
}

class SyncResult {
  final bool success;
  final String message;
  final int synced;
  SyncResult({
    required this.success,
    required this.message,
    required this.synced,
  });
}
