import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/progress_model.dart';
import 'progress_repository.dart';
import 'reward_repository.dart';
import 'notification_repository.dart';
import '../models/reward_model.dart';

class Grade4Repository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final ProgressRepository _progressRepo = ProgressRepository();
  final RewardRepository _rewardRepo = RewardRepository();
  final NotificationRepository _notificationRepo = NotificationRepository();

  CollectionReference get _playerStats => _db.collection('player_stats');
  CollectionReference get _battles => _db.collection('math_battles');
  CollectionReference get _dailyMissions => _db.collection('daily_missions');
  CollectionReference get _achievements => _db.collection('achievements');
  CollectionReference grade4Games(String worldId) => _db.collection('grade4_games');

  Future<Map<String, dynamic>?> getPlayerStats(String uid) async {
    final doc = await _playerStats.doc(uid).get();
    if (!doc.exists) return null;
    return {...doc.data() as Map<String, dynamic>};
  }

  Future<void> updatePlayerStats(String uid, Map<String, dynamic> data) async {
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _playerStats.doc(uid).set(data, SetOptions(merge: true));
  }

  Future<void> incrementXpAndCoins(String uid, int xp, int coins) async {
    final ref = _playerStats.doc(uid);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        tx.set(ref, {
          'uid': uid,
          'xp': xp,
          'coins': coins,
          'level': (xp ~/ 100) + 1,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        // also mirror to rewards
        await _rewardRepo.addPoints(uid, xp);
        return;
      }
      final data = snap.data() as Map<String, dynamic>;
      final curXp = (data['xp'] ?? 0) as int;
      final curCoins = (data['coins'] ?? 0) as int;
      final newXp = curXp + xp;
      final newCoins = curCoins + coins;
      final newLevel = (newXp ~/ 100) + 1;
      tx.update(ref, {'xp': newXp, 'coins': newCoins, 'level': newLevel, 'updatedAt': FieldValue.serverTimestamp()});
      // mirror to rewards collection
      await _rewardRepo.addPoints(uid, xp);
    });
  }

  Future<void> saveMathBattle(Map<String, dynamic> battleData) async {
    // battleData should include uid, opponentId, opponentName, topic, difficulty,
    // questionsTotal, correctAnswers, xpEarned, coinsEarned, result, timeTakenSeconds, proofUrl?
    final ref = _battles.doc();
    battleData['id'] = ref.id;
    battleData['completedAt'] = FieldValue.serverTimestamp();
    battleData['grade'] = battleData['grade'] ?? 'Grade 4';
    battleData['verified'] = true; // system scored
    await ref.set(battleData);

    // Mirror to progress collection
    final uid = battleData['uid'] as String;
    final questionsTotal = battleData['questionsTotal'] as int? ?? 0;
    final correct = battleData['correctAnswers'] as int? ?? 0;
    final score = questionsTotal > 0 ? ((correct / questionsTotal) * 100).round() : 0;
    final xp = battleData['xpEarned'] as int? ?? 0;

    final progress = ProgressModel(
      uid: uid,
      activityId: 'tugofwar_${ref.id}',
      activityTitle: 'Tug of War vs ${battleData['opponentName'] ?? 'Opponent'}',
      subject: 'Math',
      score: score,
      pointsEarned: xp,
      completed: true,
      verified: true,
      proofUrl: battleData['proofUrl'],
      completedAt: DateTime.now(),
      timeTakenSeconds: battleData['timeTakenSeconds'] ?? 0,
    );
    await _progressRepo.saveProgress(progress);

    // Update player stats and rewards
    await incrementXpAndCoins(uid, xp, battleData['coinsEarned'] ?? (xp ~/ 10));

    // Update leaderboard entry (simple)
    final playerStats = await getPlayerStats(uid);
    final name = playerStats?['name'] ?? battleData['playerName'] ?? 'Player';
    final avatar = playerStats?['avatarEmoji'] ?? '🙂';
    final level = playerStats?['level'] ?? ((playerStats?['xp'] ?? 0) ~/ 100) + 1;
    final xpTotal = (playerStats?['xp'] ?? 0) as int;
    await _db.collection('leaderboards').doc('grade4').collection('entries').doc(uid).set({
      'uid': uid,
      'name': name,
      'avatarEmoji': avatar,
      'level': level,
      'xp': xpTotal,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Notify linked parents if win/perfect
    final result = battleData['result'] as String? ?? '';
    if (result == 'win' || result == 'perfect') {
      final notif = {
        'recipientUid': null, // handled per-parent below
        'type': 'grade4_battle',
        'title': '$name ${result == 'perfect' ? 'had a perfect win' : 'won a Tug of War battle'}!',
        'body': '$name ${result == 'perfect' ? 'scored a perfect 10/10' : 'won against ${battleData['opponentName'] ?? 'an opponent'}'} +$xp XP',
        'data': {'battleId': ref.id, 'uid': uid},
      };
      // fetch linked parents from user doc and send individually
      final userDoc = await _db.collection('users').doc(uid).get();
      final linkedParents = List<String>.from(userDoc.data()?['linkedParentUids'] ?? []);
      for (final p in linkedParents) {
        final copy = Map<String, dynamic>.from(notif);
        copy['recipientUid'] = p;
        await _notificationRepo.createNotification(copy);
      }
    }
    // Unlock achievements for special results
    try {
      if (result == 'perfect') {
        await unlockAchievement(uid, 'perfect_battle');
        await unlockAchievement(uid, 'win_battle');
      } else if (result == 'win') {
        await unlockAchievement(uid, 'win_battle');
      }
    } catch (e) {
      // ignore achievement errors for now
    }
  }

  Future<List<Map<String, dynamic>>> getBattleHistory(String uid, {int limit = 20}) async {
    final snaps = await _battles.where('uid', isEqualTo: uid).orderBy('completedAt', descending: true).limit(limit).get();
    return snaps.docs.map((d) => {...d.data() as Map<String, dynamic>, 'id': d.id}).toList();
  }

  Future<Map<String, dynamic>> getOrCreateDailyMissions(String uid, String grade) async {
    final today = DateTime.now();
    final dateStr = '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final docId = '${uid}_$dateStr';
    final ref = _dailyMissions.doc(docId);
    final snap = await ref.get();
    if (snap.exists) return {...snap.data() as Map<String, dynamic>};

    final missions = [
      {'id': 'm1', 'title': 'Complete 1 Math Battle', 'target': 1, 'progress': 0, 'completed': false, 'rewardXp': 50, 'rewardCoins': 5},
      {'id': 'm2', 'title': 'Earn 50 XP', 'target': 50, 'progress': 0, 'completed': false, 'rewardXp': 30, 'rewardCoins': 3},
      {'id': 'm3', 'title': 'Maintain streak', 'target': 1, 'progress': 0, 'completed': false, 'rewardXp': 20, 'rewardCoins': 2},
    ];
    final obj = {'id': docId, 'uid': uid, 'date': dateStr, 'missions': missions, 'allCompleted': false};
    await ref.set({
      ...obj,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return obj;
  }

  Future<void> updateMissionProgress(String uid, String missionId, int progressIncrement) async {
    final today = DateTime.now();
    final dateStr = '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final docId = '${uid}_$dateStr';
    final ref = _dailyMissions.doc(docId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final data = snap.data() as Map<String, dynamic>;
      final missions = List<Map<String, dynamic>>.from(data['missions'] ?? []);
      var allDone = true;
      int totalRewardXp = 0;
      for (var m in missions) {
        if (m['id'] == missionId) {
          m['progress'] = (m['progress'] ?? 0) + progressIncrement;
          if (m['progress'] >= m['target']) m['completed'] = true;
        }
        if (!(m['completed'] ?? false)) allDone = false;
        totalRewardXp += (m['rewardXp'] ?? 0) as int;
      }
      final update = {'missions': missions, 'allCompleted': allDone};
      if (allDone) update['completedAt'] = FieldValue.serverTimestamp();
      tx.update(ref, update);

      if (allDone) {
        // mirror single progress record
        final progress = ProgressModel(
          uid: uid,
          activityId: 'daily_missions_$docId',
          activityTitle: 'Daily Missions Complete',
          subject: 'General',
          score: 100,
          pointsEarned: totalRewardXp,
          completed: true,
          verified: false,
          completedAt: DateTime.now(),
        );
        await _progressRepo.saveProgress(progress);
        // award xp/coins
        await incrementXpAndCoins(uid, totalRewardXp, (totalRewardXp ~/ 10));
      }
    });
  }

  Future<List<Map<String, dynamic>>> getAchievements() async {
    final snaps = await _achievements.get();
    return snaps.docs.map((d) => {...d.data() as Map<String, dynamic>, 'id': d.id}).toList();
  }

  Future<void> unlockAchievement(String uid, String achievementId) async {
    final achDoc = await _achievements.doc(achievementId).get();
    if (!achDoc.exists) return;
    final ach = achDoc.data() as Map<String, dynamic>;
    final playerRef = _playerStats.doc(uid);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(playerRef);
      if (!snap.exists) return;
      final data = snap.data() as Map<String, dynamic>;
      final unlocked = List<String>.from(data['achievements'] ?? []);
      if (!unlocked.contains(achievementId)) {
        unlocked.add(achievementId);
        tx.update(playerRef, {'achievements': unlocked});
        // convert to BadgeModel and add to rewards
        final badge = BadgeModel(
          id: achievementId,
          name: ach['name'] ?? ach['title'] ?? achievementId,
          description: ach['description'] ?? '',
          icon: ach['icon'] ?? '🏆',
          category: ach['category'] ?? 'battle',
          earnedAt: DateTime.now(),
        );
        await _rewardRepo.awardBadge(uid, badge);
        // notify parents
        final userDoc = await _db.collection('users').doc(uid).get();
        final linkedParents = List<String>.from(userDoc.data()?['linkedParentUids'] ?? []);
        for (final p in linkedParents) {
          await _notificationRepo.createNotification({
            'recipientUid': p,
            'type': 'achievement_unlocked',
            'title': '${userDoc.data()?['name'] ?? 'Your child'} unlocked ${badge.name}',
            'body': badge.description,
            'data': {'achievementId': achievementId, 'uid': uid},
          });
        }
      }
    });
  }

  Stream<List<Map<String, dynamic>>> watchLeaderboard(String grade, {int limit = 10}) {
    return _db.collection('leaderboards').doc(grade).collection('entries').orderBy('xp', descending: true).limit(limit).snapshots().map((s) => s.docs.map((d) => {...d.data(), 'id': d.id}).toList());
  }

  Future<void> updateLeaderboardEntry(String uid, Map<String, dynamic> data) async {
    await _db.collection('leaderboards').doc('grade4').collection('entries').doc(uid).set({...data, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
  }

  Future<List<Map<String, dynamic>>> getWorldGames(String worldId, String grade) async {
    final snaps = await _db.collection('grade4_games').where('worldId', isEqualTo: worldId).where('grade', isEqualTo: grade).get();
    return snaps.docs.map((d) => {...d.data(), 'id': d.id}).toList();
  }

  Future<List<String>> getUnlockedWorlds(String uid) async {
    final doc = await _playerStats.doc(uid).get();
    if (!doc.exists) return [];
    return List<String>.from(doc.data()?['unlockedWorlds'] ?? []);
  }

  Future<void> unlockWorld(String uid, String worldId) async {
    final ref = _playerStats.doc(uid);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final data = snap.data() as Map<String, dynamic>;
      final unlocked = List<String>.from(data['unlockedWorlds'] ?? []);
      if (!unlocked.contains(worldId)) {
        unlocked.add(worldId);
        tx.update(ref, {'unlockedWorlds': unlocked, 'updatedAt': FieldValue.serverTimestamp()});
        // add questkids_event to shared_calendar
        await _db.collection('shared_calendar').add({
          'childUid': uid,
          'title': 'Unlocked $worldId',
          'description': 'Unlocked new world: $worldId',
          'type': 'questkids_event',
          'color': 'gold',
          'date': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        });
        // notify parents
        final userDoc = await _db.collection('users').doc(uid).get();
        final linkedParents = List<String>.from(userDoc.data()?['linkedParentUids'] ?? []);
        for (final p in linkedParents) {
          await _notificationRepo.createNotification({
            'recipientUid': p,
            'type': 'world_unlocked',
            'title': '${userDoc.data()?['name'] ?? 'Your child'} unlocked a new world!',
            'body': 'Unlocked $worldId',
            'data': {'worldId': worldId, 'uid': uid},
          });
        }
      }
    });
  }
}
