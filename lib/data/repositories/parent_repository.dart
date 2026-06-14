import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/user_model.dart';
import '../models/progress_model.dart';

class ParentRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  const _uuid = Uuid();

  // Link requests
  Future<void> sendLinkRequest(Map<String, dynamic> data) async {
    final ref = _db.collection('parent_link_requests').doc();
    data['id'] = ref.id;
    data['createdAt'] = FieldValue.serverTimestamp();
    data['status'] = data['status'] ?? 'pending';
    await ref.set(data);
  }

  Future<void> approveLinkRequest(String requestId, String childUid, String requestingParentUid) async {
    final reqRef = _db.collection('parent_link_requests').doc(requestId);
    await _db.runTransaction((tx) async {
      final reqSnap = await tx.get(reqRef);
      if (!reqSnap.exists) return;
      tx.update(reqRef, {
        'status': 'approved',
        'resolvedAt': FieldValue.serverTimestamp(),
      });

      final childRef = _db.collection('users').doc(childUid);
      final parentRef = _db.collection('users').doc(requestingParentUid);

      final childSnap = await tx.get(childRef);
      final parentSnap = await tx.get(parentRef);

      if (childSnap.exists) {
        final linkedParents = List<String>.from(childSnap.data()?['linkedParentUids'] ?? []);
        if (!linkedParents.contains(requestingParentUid)) {
          linkedParents.add(requestingParentUid);
          tx.update(childRef, {'linkedParentUids': linkedParents});
        }
      }

      if (parentSnap.exists) {
        final linkedChildren = List<String>.from(parentSnap.data()?['linkedChildrenUids'] ?? []);
        if (!linkedChildren.contains(childUid)) {
          linkedChildren.add(childUid);
          tx.update(parentRef, {'linkedChildrenUids': linkedChildren});
        }
      }
    });
  }

  Future<void> declineLinkRequest(String requestId) async {
    await _db.collection('parent_link_requests').doc(requestId).update({
      'status': 'declined',
      'resolvedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Map<String, dynamic>>> watchPendingRequests(String primaryParentUid) {
    return _db
        .collection('parent_link_requests')
        .where('primaryParentUid', isEqualTo: primaryParentUid)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => {...d.data(), 'id': d.id}).toList());
  }

  Stream<List<Map<String, dynamic>>> watchOutgoingRequests(String requestingParentUid) {
    return _db
        .collection('parent_link_requests')
        .where('requestingParentUid', isEqualTo: requestingParentUid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => {...d.data(), 'id': d.id}).toList());
  }

  // Child management
  Future<UserModel?> findChildByCode(String code) async {
    final q = await _db.collection('users').where('childLinkCode', isEqualTo: code).limit(1).get();
    if (q.docs.isEmpty) return null;
    final d = q.docs.first;
    return UserModel.fromMap(d.data(), d.id);
  }

  Future<UserModel?> findChildByNameAndEmail(String childName, String parentEmail) async {
    final q = await _db.collection('users')
      .where('name', isEqualTo: childName)
      .where('email', isEqualTo: parentEmail)
      .limit(1)
      .get();
    if (q.docs.isEmpty) return null;
    final d = q.docs.first;
    return UserModel.fromMap(d.data(), d.id);
  }

  Future<void> linkParentToChild(String parentUid, String childUid) async {
    final childRef = _db.collection('users').doc(childUid);
    final parentRef = _db.collection('users').doc(parentUid);
    await _db.runTransaction((tx) async {
      final childSnap = await tx.get(childRef);
      final parentSnap = await tx.get(parentRef);

      if (childSnap.exists) {
        final linkedParents = List<String>.from(childSnap.data()?['linkedParentUids'] ?? []);
        if (!linkedParents.contains(parentUid)) linkedParents.add(parentUid);
        tx.update(childRef, {'linkedParentUids': linkedParents});
      }

      if (parentSnap.exists) {
        final linkedChildren = List<String>.from(parentSnap.data()?['linkedChildrenUids'] ?? []);
        if (!linkedChildren.contains(childUid)) linkedChildren.add(childUid);
        tx.update(parentRef, {'linkedChildrenUids': linkedChildren});
      }
    });
  }

  Future<void> unlinkParentFromChild(String parentUid, String childUid) async {
    final childRef = _db.collection('users').doc(childUid);
    final parentRef = _db.collection('users').doc(parentUid);
    await _db.runTransaction((tx) async {
      final childSnap = await tx.get(childRef);
      final parentSnap = await tx.get(parentRef);

      if (childSnap.exists) {
        final linkedParents = List<String>.from(childSnap.data()?['linkedParentUids'] ?? []);
        linkedParents.remove(parentUid);
        tx.update(childRef, {'linkedParentUids': linkedParents});
      }

      if (parentSnap.exists) {
        final linkedChildren = List<String>.from(parentSnap.data()?['linkedChildrenUids'] ?? []);
        linkedChildren.remove(childUid);
        tx.update(parentRef, {'linkedChildrenUids': linkedChildren});
      }
    });
  }

  Future<List<UserModel>> getLinkedChildren(List<String> childUids) async {
    if (childUids.isEmpty) return [];
    final snaps = await _db.collection('users').where(FieldPath.documentId, whereIn: childUids).get();
    return snaps.docs.map((d) => UserModel.fromMap(d.data(), d.id)).toList();
  }

  // Link code generation
  String generateLinkCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = _uuid.v4().replaceAll('-', '').toUpperCase();
    final code = List.generate(6, (i) => chars[(rnd.codeUnitAt(i) + i) % chars.length]).join();
    return code;
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

  Future<void> updateCalendarEvent(String eventId, Map<String, dynamic> payload) async {
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
  Future<void> uploadDocument(Map<String, dynamic> doc) async {
    final ref = _db.collection('document_vault').doc();
    doc['id'] = ref.id;
    doc['createdAt'] = FieldValue.serverTimestamp();
    await ref.set(doc);
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

  // Analytics
  Future<Map<String, dynamic>> getChildAnalytics(String childUid, DateTime from, DateTime to) async {
    final fromTs = Timestamp.fromDate(from);
    final toTs = Timestamp.fromDate(to);

    final snaps = await _db
        .collection('progress')
        .where('childUid', isEqualTo: childUid)
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

  Future<List<ProgressModel>> getChildProgress(String childUid, {int limit = 50}) async {
    final snaps = await _db
        .collection('progress')
        .where('childUid', isEqualTo: childUid)
        .orderBy('completedAt', descending: true)
        .limit(limit)
        .get();
    return snaps.docs.map((d) {
      final data = Map<String, dynamic>.from(d.data());
      data['uid'] = d.id;
      return ProgressModel.fromMap(data);
    }).toList();
  }

  Stream<List<Map<String, dynamic>>> watchPendingVerifications(List<String> childUids) {
    if (childUids.isEmpty) return Stream.value([]);
    return _db
        .collection('progress')
        .where('childUid', whereIn: childUids)
        .where('completed', isEqualTo: true)
        .where('verified', isEqualTo: false)
        .orderBy('completedAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => {...d.data(), 'id': d.id}).toList());
  }

  Future<void> approveProgress(String progressId, {int points = 0, String? childUid}) async {
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
    await _db.collection('progress').doc(progressId).update({'verified': false});
  }
}
