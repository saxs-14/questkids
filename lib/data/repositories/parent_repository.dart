import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import '../models/user_model.dart';
import '../models/progress_model.dart';

class ParentRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  // Link requests are created and resolved only by protected Cloud Functions.
  Future<Map<String, dynamic>> requestParentLink(
      String code, {String method = 'code'}) async {
    final result = await FirebaseFunctions.instanceFor(region: 'us-central1')
        .httpsCallable('requestParentLink')
        .call({'code': code, 'method': method});
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<void> approveLinkRequest(String requestId) async {
    await FirebaseFunctions.instanceFor(region: 'us-central1')
        .httpsCallable('resolveParentLinkRequest')
        .call({'requestId': requestId, 'action': 'approve'});
  }

  Future<void> declineLinkRequest(String requestId) async {
    await FirebaseFunctions.instanceFor(region: 'us-central1')
        .httpsCallable('resolveParentLinkRequest')
        .call({'requestId': requestId, 'action': 'decline'});
  }

  Future<void> cancelLinkRequest(String requestId) async {
    await FirebaseFunctions.instanceFor(region: 'us-central1')
        .httpsCallable('resolveParentLinkRequest')
        .call({'requestId': requestId, 'action': 'cancel'});
  }

  Stream<Map<String, dynamic>?> watchUserDoc(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.data());
  }

  Stream<List<Map<String, dynamic>>> watchPendingRequests(
      String primaryParentUid) {
    return _db
        .collection('parent_link_requests')
        .where('primaryParentUid', isEqualTo: primaryParentUid)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => {...d.data(), 'id': d.id}).toList());
  }

  Stream<List<Map<String, dynamic>>> watchOutgoingRequests(
      String requestingParentUid) {
    return _db
        .collection('parent_link_requests')
        .where('requestingParentUid', isEqualTo: requestingParentUid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => {...d.data(), 'id': d.id}).toList());
  }

  // Child identity is resolved by a protected callable; direct
  // cross-account queries by childLinkCode are not exposed to clients.
  Future<UserModel?> findChildByCode(String code) async {
    try {
      final result = await FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('lookupChildLinkCode')
          .call({'code': code});
      final data = Map<String, dynamic>.from(result.data as Map);
      return UserModel(
        uid: data['childUid'] as String,
        name: data['childName'] as String? ?? 'Child',
        email: '',
        role: 'learner',
        grade: data['grade'] as String? ?? 'Grade 1',
        createdAt: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> unlinkParentFromChild(
    String parentUid,
    String childUid,
    String otpCode,
  ) async {
    await FirebaseFunctions.instanceFor(region: 'us-central1')
        .httpsCallable('unlinkParentChild')
        .call({'childUid': childUid, 'otpCode': otpCode});
  }

  Future<List<UserModel>> getLinkedChildren(List<String> childUids) async {
    if (childUids.isEmpty) return [];
    final snaps = await _db
        .collection('users')
        .where(FieldPath.documentId, whereIn: childUids)
        .get();
    return snaps.docs.map((d) => UserModel.fromMap(d.data(), d.id)).toList();
  }

  // Link code generation
  String generateLinkCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = _uuid.v4().replaceAll('-', '').toUpperCase();
    return List.generate(
      6,
      (i) => chars[(rnd.codeUnitAt(i) + i) % chars.length],
    ).join();
  }

  Future<void> saveLinkCode(String childUid, String code) async {
    await _db.collection('users').doc(childUid).update({
      'childLinkCode': code,
    });
  }

  // Calendar
  Future<void> addCalendarEvent(Map<String, dynamic> event) async {
    final ref = _db.collection('shared_calendar').doc();
    event['id'] = ref.id;
    event['createdAt'] = FieldValue.serverTimestamp();
    await ref.set(event);
  }

  Stream<List<Map<String, dynamic>>> watchCalendarEvents(String childUid) {
    return _db
        .collection('shared_calendar')
        .where('childUid', isEqualTo: childUid)
        .orderBy('date')
        .snapshots()
        .map((s) => s.docs.map((d) => {...d.data(), 'id': d.id}).toList());
  }

  Future<void> deleteCalendarEvent(String eventId) async {
    await _db.collection('shared_calendar').doc(eventId).delete();
  }

  Future<void> updateCalendarEvent(
      String eventId, Map<String, dynamic> payload) async {
    payload['updatedAt'] = FieldValue.serverTimestamp();
    await _db.collection('shared_calendar').doc(eventId).update(payload);
  }

  // Reminders
  Future<void> addReminder(Map<String, dynamic> reminder) async {
    final ref = _db.collection('reminders').doc();
    reminder['id'] = ref.id;
    reminder['createdAt'] = FieldValue.serverTimestamp();
    await ref.set(reminder);
  }

  Stream<List<Map<String, dynamic>>> watchReminders(String childUid) {
    return _db
        .collection('reminders')
        .where('childUid', isEqualTo: childUid)
        .orderBy('remindAt', descending: false)
        .snapshots()
        .map((s) => s.docs.map((d) => {...d.data(), 'id': d.id}).toList());
  }

  Future<void> deleteReminder(String reminderId) async {
    await _db.collection('reminders').doc(reminderId).delete();
  }

  // Document vault
  Future<void> uploadDocument({
    required String childUid,
    required String uploadedByUid,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final docRef = _db.collection('document_vault').doc();
    final storageRef = FirebaseStorage.instance
        .ref('document_vault/$childUid/${docRef.id}_$fileName');
    await storageRef.putData(bytes);
    final url = await storageRef.getDownloadURL();
    await docRef.set({
      'id': docRef.id,
      'childUid': childUid,
      'uploadedByUid': uploadedByUid,
      'fileName': fileName,
      'url': url,
      'sizeBytes': bytes.length,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Map<String, dynamic>>> watchDocuments(String childUid) {
    return _db
        .collection('document_vault')
        .where('childUid', isEqualTo: childUid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => {...d.data(), 'id': d.id}).toList());
  }

  Future<void> deleteDocument(String docId) async {
    await _db.collection('document_vault').doc(docId).delete();
  }

  // Mood check-in
  Future<void> logMood(Map<String, dynamic> moodData) async {
    final ref = _db.collection('mood_checkins').doc();
    moodData['id'] = ref.id;
    moodData['date'] = FieldValue.serverTimestamp();
    await ref.set(moodData);
  }

  Stream<List<Map<String, dynamic>>> watchMoodHistory(String childUid) {
    return _db
        .collection('mood_checkins')
        .where('childUid', isEqualTo: childUid)
        .orderBy('date', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => {...d.data(), 'id': d.id}).toList());
  }

  Future<void> deleteMoodEntry(String checkinId) async {
    await _db.collection('mood_checkins').doc(checkinId).delete();
  }

  // Analytics
  Future<Map<String, dynamic>> getChildAnalytics(
      String childUid, DateTime from, DateTime to) async {
    final fromTs = Timestamp.fromDate(from);
    final toTs = Timestamp.fromDate(to);

    final snaps = await _db
        .collection('progress')
        .where('uid', isEqualTo: childUid)
        .where('completedAt', isGreaterThanOrEqualTo: fromTs)
        .where('completedAt', isLessThanOrEqualTo: toTs)
        .get();

    final totalGames = snaps.docs.length;
    double totalScore = 0;
    int points = 0;
    final Map<String, List<double>> subjectScores = {};

    for (final d in snaps.docs) {
      final data = d.data();
      final score = (data['score'] ?? 0).toDouble();
      totalScore += score;
      points += (data['pointsEarned'] ?? 0) as int;
      final subject = data['subject'] ?? 'General';
      subjectScores.putIfAbsent(subject, () => []).add(score);
    }

    final avgScore = totalGames > 0 ? (totalScore / totalGames) : 0.0;

    // Best subject
    String bestSubject = 'N/A';
    double bestAvg = 0;
    subjectScores.forEach((subject, scores) {
      final avg = scores.reduce((a, b) => a + b) / scores.length;
      if (avg > bestAvg) {
        bestAvg = avg;
        bestSubject = subject;
      }
    });

    return {
      'totalGames': totalGames,
      'avgScore': avgScore,
      'pointsEarned': points,
      'bestSubject': bestSubject,
      'subjectBreakdown': subjectScores,
    };
  }

  Future<Map<String, dynamic>?> getLatestWeeklyReport(String childUid) async {
    final snap = await _db.collection('weekly_reports')
        .where('childUid', isEqualTo: childUid)
        .orderBy('weekKey', descending: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return snap.docs.first.data();
  }

  Future<List<ProgressModel>> getChildProgress(String childUid,
      {int limit = 50}) async {
    final snaps = await _db
        .collection('progress')
        .where('uid', isEqualTo: childUid)
        .orderBy('completedAt', descending: true)
        .limit(limit)
        .get();
    return snaps.docs.map((d) {
      final data = Map<String, dynamic>.from(d.data());
      data['uid'] = d.id;
      return ProgressModel.fromMap(data);
    }).toList();
  }

  Stream<List<Map<String, dynamic>>> watchPendingVerifications(
      List<String> childUids) {
    if (childUids.isEmpty) return Stream.value([]);
    return _db
        .collection('progress')
        .where('uid', whereIn: childUids)
        .where('completed', isEqualTo: true)
        .where('verified', isEqualTo: false)
        .orderBy('completedAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => {...d.data(), 'id': d.id}).toList());
  }

  Future<void> approveProgress(String progressId,
      {int points = 0, String? childUid}) async {
    final ref = _db.collection('progress').doc(progressId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      tx.update(ref, {'verified': true});
      // optionally award points to child
      if (childUid != null && points > 0) {
        final userRef = _db.collection('users').doc(childUid);
        tx.update(userRef, {'totalPoints': FieldValue.increment(points)});
      }
    });
  }

  Future<void> declineProgress(String progressId) async {
    await _db
        .collection('progress')
        .doc(progressId)
        .update({'verified': false});
  }

  Future<Map<String, double>> getWeeklyScoreTrend(String childUid) async {
    final Map<String, double> result = {};
    for (int i = 7; i >= 0; i--) {
      final weekStart = DateTime.now().subtract(Duration(days: i * 7));
      final weekEnd = weekStart.add(const Duration(days: 7));
      final snap = await _db
          .collection('game_sessions')
          .where('uid', isEqualTo: childUid)
          .where('completedAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
          .where('completedAt', isLessThan: Timestamp.fromDate(weekEnd))
          .get();
      final key = 'W${8 - i}';
      if (snap.docs.isEmpty) {
        result[key] = 0;
      } else {
        final avg = snap.docs
                .map((d) => (d.data()['score'] as num?)?.toDouble() ?? 0)
                .reduce((a, b) => a + b) /
            snap.docs.length;
        result[key] = avg;
      }
    }
    return result;
  }

  Future<Map<String, int>> getTimeSpentBySubject(String childUid) async {
    final snap = await _db
        .collection('game_sessions')
        .where('uid', isEqualTo: childUid)
        .where('completedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(
                DateTime.now().subtract(const Duration(days: 30))))
        .get();
    final Map<String, int> totals = {};
    for (final doc in snap.docs) {
      final subj = doc.data()['subject'] as String? ?? 'Other';
      final secs = (doc.data()['timeTakenSeconds'] as num?)?.toInt() ?? 0;
      totals[subj] = (totals[subj] ?? 0) + secs;
    }
    return totals;
  }
}
