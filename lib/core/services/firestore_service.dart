import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Users
  Future<void> createUser(String uid, Map<String, dynamic> data) =>
      _db.collection('users').doc(uid).set(data);

  Future<Map<String, dynamic>?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.data();
  }

  // Activities
  Stream<QuerySnapshot> getActivities(String subject) => _db
      .collection('activities')
      .where('subject', isEqualTo: subject)
      .snapshots();

  // Progress
  Future<void> saveProgress(String uid, Map<String, dynamic> data) =>
      _db.collection('progress').doc(uid).set(data, SetOptions(merge: true));

  // Rewards
  Future<void> updateRewards(String uid, Map<String, dynamic> data) =>
      _db.collection('rewards').doc(uid).set(data, SetOptions(merge: true));

  // AI reports — flags on a Questy message, reviewed by admins only.
  // See firestore.rules: create by the reporting user, read by admin claim.
  Future<void> reportAiMessage({
    required String uid,
    required String messageText,
    required String reason,
  }) =>
      _db.collection('ai_reports').add({
        'uid': uid,
        'messageText': messageText.length > 500
            ? messageText.substring(0, 500)
            : messageText,
        'reason': reason,
        'createdAt': FieldValue.serverTimestamp(),
      });
}
