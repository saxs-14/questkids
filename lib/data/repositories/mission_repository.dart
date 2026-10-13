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

  Future<bool> completeMission(
    String uid,
    String missionId,
    String gameId,
  ) async {
    final docRef = _db
        .collection('daily_missions')
        .doc(uid)
        .collection('today')
        .doc('missions');

    return _db.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) {
        throw StateError('Today\'s missions could not be found.');
      }

      final data = snap.data() ?? {};
      final missions = List<Map<String, dynamic>>.from(
          (data['missions'] as List<dynamic>? ?? [])
              .map((m) => Map<String, dynamic>.from(m as Map)));

      var found = false;
      for (final m in missions) {
        if (m['id'] == missionId) {
          found = true;
          if (m['completed'] as bool? ?? false) return false;
          m['completed'] = true;
          m['completedAt'] = FieldValue.serverTimestamp();
          break;
        }
      }
      if (!found) {
        throw StateError('This mission is no longer available.');
      }

      tx.update(docRef, {'missions': missions});
      return true;
    });
  }
}
