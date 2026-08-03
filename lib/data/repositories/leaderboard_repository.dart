import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/leaderboard_entry_model.dart';

class LeaderboardRepository {
  final _db = FirebaseFirestore.instance;

  /// Firestore doc id for a leaderboard board. Must match
  /// functions/src/leaderboard/refresh.ts's `subjectKey()` scheme: the
  /// overall grade board lives at doc id `{grade}`, a per-subject board at
  /// `{grade}_{subject with whitespace stripped}`.
  String _boardDocId(String grade, String? subject) {
    if (subject == null) return grade;
    return '${grade}_${subject.replaceAll(RegExp(r'\s+'), '')}';
  }

  /// [subject] is one of AppConstants.subjects, or null for the overall
  /// (all-subjects) grade board.
  Stream<List<LeaderboardEntry>> watchGradeLeaderboard(
    String grade, {
    String period = 'weekly',
    String? subject,
  }) {
    return _db
        .collection('leaderboards')
        .doc(_boardDocId(grade, subject))
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
          // Leaderboards are visible to every classmate -- never expose a
          // surname here, matching functions/src/leaderboard/refresh.ts's
          // first-name-only rule (see CLAUDE.md §6.5).
          displayName: (data['name'] as String? ?? 'Learner').trim(),
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
    String? subject,
  }) async {
    final doc = await _db
        .collection('leaderboards')
        .doc(_boardDocId(grade, subject))
        .collection(period)
        .where('uid', isEqualTo: uid)
        .limit(1)
        .get();
    if (doc.docs.isEmpty) return null;
    return (doc.docs.first.data()['rank'] as num?)?.toInt();
  }
}
