import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/daily_mission_model.dart';

class MissionRepository {
  final _db = FirebaseFirestore.instance;

  Stream<List<DailyMission>> watchTodayMissions(String uid) {
    return _db
        .collection('daily_missions')
        .doc(uid)
        .collection('today')
        .doc('missions')
        .snapshots()
        .map((doc) {
      if (!doc.exists) return <DailyMission>[];
      final data = doc.data() ?? {};
      final list = (data['missions'] as List<dynamic>?) ?? [];
      return list
          .map((m) => DailyMission.fromMap(
              m['id'] as String? ?? '', m as Map<String, dynamic>))
          .toList();
    });
  }

  Future<void> completeMission(
    String uid,
    String missionId,
    String gameId,
  ) async {
    final docRef = _db
        .collection('daily_missions')
        .doc(uid)
        .collection('today')
        .doc('missions');

    await _db.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) return;

      final data = snap.data() ?? {};
      final missions = List<Map<String, dynamic>>.from(
          (data['missions'] as List<dynamic>? ?? [])
              .map((m) => Map<String, dynamic>.from(m as Map)));

      bool found = false;
      for (final m in missions) {
        if (m['id'] == missionId && !(m['completed'] as bool? ?? false)) {
          m['completed'] = true;
          m['completedAt'] = FieldValue.serverTimestamp();
          found = true;
          break;
        }
      }
      if (!found) return;

      tx.update(docRef, {'missions': missions});
    });
  }
}
