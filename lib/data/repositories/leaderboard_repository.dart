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
