import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/leaderboard_entry_model.dart';

class LeaderboardRepository {
  final _db = FirebaseFirestore.instance;

  Stream<List<LeaderboardEntry>> watchGradeLeaderboard(
    String grade, {
    String period = 'weekly',
  }) {
    return _db
        .collection('leaderboards')
        .doc(grade)
        .collection(period)
        .orderBy('rank')
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs.map(LeaderboardEntry.fromDoc).toList());
  }

  Stream<List<LeaderboardEntry>> watchClassLeaderboard(String teacherUid) {
    return _db
        .collection('users')
        .where('linkedTeacherUid', isEqualTo: teacherUid)
        .snapshots()
        .map((snap) {
      final entries = snap.docs.map((doc) {
        final data = doc.data();
        return LeaderboardEntry(
          uid: doc.id,
          displayName: '${data['name'] ?? ''} ${data['surname'] ?? ''}'.trim(),
          avatarEmoji: data['avatarEmoji'] as String? ?? '🦁',
          grade: data['grade'] as String? ?? 'Grade 1',
          xp: (data['totalPoints'] as num?)?.toInt() ?? 0,
          rank: 0,
        );
      }).toList();

      entries.sort((a, b) => b.xp.compareTo(a.xp));
      return entries
          .asMap()
          .entries
          .map((e) => LeaderboardEntry(
                uid: e.value.uid,
                displayName: e.value.displayName,
                avatarEmoji: e.value.avatarEmoji,
                grade: e.value.grade,
                xp: e.value.xp,
                rank: e.key + 1,
              ))
          .toList();
    });
  }

  Future<int?> getOwnRank(
    String uid,
    String grade, {
    String period = 'weekly',
  }) async {
    final doc = await _db
        .collection('leaderboards')
        .doc(grade)
        .collection(period)
        .where('uid', isEqualTo: uid)
        .limit(1)
        .get();
    if (doc.docs.isEmpty) return null;
    return (doc.docs.first.data()['rank'] as num?)?.toInt();
  }
}
