import 'package:cloud_firestore/cloud_firestore.dart';

class TeacherRepository {
  final _db = FirebaseFirestore.instance;

  Future<Map<String, dynamic>> getClassAnalytics(String teacherUid) async {
    final learnersSnap = await _db
        .collection('users')
        .where('linkedTeacherUids', arrayContains: teacherUid)
        .get();
    if (learnersSnap.docs.isEmpty) {
      return {
        'totalLearners': 0,
        'subjectAvg': <String, double>{},
        'completionRate': 0.0,
        'weakTopics': [],
        'totalAttempted': 0,
        'totalCompleted': 0
      };
    }
    final learnerUids = learnersSnap.docs.map((d) => d.id).toList();
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

    final Map<String, List<double>> subjectScores = {};
    int totalAttempted = 0;
    int totalCompleted = 0;

    for (final uid in learnerUids.take(30)) {
      final sessSnap = await _db
          .collection('game_sessions')
          .where('uid', isEqualTo: uid)
          .where('completedAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(thirtyDaysAgo))
          .get();
      totalAttempted += sessSnap.docs.length;
      for (final doc in sessSnap.docs) {
        final data = doc.data();
        final subj = data['subject'] as String? ?? 'Other';
        final score = (data['score'] as num?)?.toDouble() ?? 0;
        final result = data['result'] as String? ?? '';
        if (result == 'win' || result == 'complete') totalCompleted++;
        subjectScores.putIfAbsent(subj, () => []).add(score);
      }
    }

    final Map<String, double> subjectAvg = {};
    for (final e in subjectScores.entries) {
      subjectAvg[e.key] = e.value.reduce((a, b) => a + b) / e.value.length;
    }

    final weakTopics = subjectAvg.entries
        .where((e) => e.value < 60)
        .map((e) => {'subject': e.key, 'avg': e.value})
        .toList()
      ..sort((a, b) => (a['avg'] as double).compareTo(b['avg'] as double));

    return {
      'totalLearners': learnerUids.length,
      'subjectAvg': subjectAvg,
      'completionRate':
          totalAttempted == 0 ? 0.0 : totalCompleted / totalAttempted,
      'totalAttempted': totalAttempted,
      'totalCompleted': totalCompleted,
      'weakTopics': weakTopics,
    };
  }

  Future<List<Map<String, int>>> getDailyActiveLearners(
      String teacherUid) async {
    final learnersSnap = await _db
        .collection('users')
        .where('linkedTeacherUids', arrayContains: teacherUid)
        .get();
    final learnerUids = learnersSnap.docs.map((d) => d.id).toSet();
    if (learnerUids.isEmpty) return [];

    final result = <Map<String, int>>[];
    for (int i = 13; i >= 0; i--) {
      final dayStart = DateTime.now().subtract(Duration(days: i));
      final dayKey = DateTime(dayStart.year, dayStart.month, dayStart.day);
      final dayEnd = dayKey.add(const Duration(days: 1));
      final Set<String> active = {};
      for (final uid in learnerUids.take(20)) {
        final snap = await _db
            .collection('game_sessions')
            .where('uid', isEqualTo: uid)
            .where('completedAt',
                isGreaterThanOrEqualTo: Timestamp.fromDate(dayKey))
            .where('completedAt', isLessThan: Timestamp.fromDate(dayEnd))
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) active.add(uid);
      }
      result.add({'day': 14 - i, 'count': active.length});
    }
    return result;
  }

  /// Writes a broadcast doc the teacher owns; a Cloud Function
  /// (onClassBroadcast) fans it out to a `notifications` doc per learner
  /// linked to this teacher, since firestore.rules only lets a client
  /// write a notification for its own uid.
  Future<void> sendClassBroadcast({
    required String teacherUid,
    required String title,
    required String body,
  }) async {
    await _db.collection('class_broadcasts').add({
      'teacherUid': teacherUid,
      'title': title,
      'body': body,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<Map<String, dynamic>>> exportClassProgress(
      String teacherUid) async {
    final learnersSnap = await _db
        .collection('users')
        .where('linkedTeacherUids', arrayContains: teacherUid)
        .get();
    final rows = <Map<String, dynamic>>[];
    for (final learner in learnersSnap.docs) {
      final lData = learner.data();
      final sessSnap = await _db
          .collection('game_sessions')
          .where('uid', isEqualTo: learner.id)
          .orderBy('completedAt', descending: true)
          .limit(100)
          .get();
      for (final doc in sessSnap.docs) {
        final d = doc.data();
        rows.add({
          'name': '${lData['name'] ?? ''} ${lData['surname'] ?? ''}'.trim(),
          'grade': lData['grade'] ?? '',
          'subject': d['subject'] ?? '',
          'score': d['score'] ?? 0,
          'xp': d['xpEarned'] ?? 0,
          'date':
              (d['completedAt'] as Timestamp?)?.toDate().toIso8601String() ??
                  '',
          'timeSecs': d['timeTakenSeconds'] ?? 0,
        });
      }
    }
    return rows;
  }
}
