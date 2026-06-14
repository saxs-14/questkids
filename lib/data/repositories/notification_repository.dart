import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';

class NotificationRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<NotificationModel>> getUserNotifications(String uid) {
    return _firestore
        .collection('notifications')
        // support both 'targetUid' and 'recipientUid' fields
        .where('targetUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => NotificationModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  Future<void> markAsRead(String notificationId) async {
    await _firestore
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true, 'read': true});
  }

  // New API
  Future<void> createNotification(Map<String, dynamic> data) async {
    final ref = _firestore.collection('notifications').doc();
    data['id'] = ref.id;
    data['createdAt'] = FieldValue.serverTimestamp();
    data['read'] = data['read'] ?? false;
    // keep legacy key
    data['isRead'] = data['isRead'] ?? data['read'];
    await ref.set(data);
  }

  Stream<List<NotificationModel>> watchNotifications(String uid) {
    return _firestore
        .collection('notifications')
        .where('recipientUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => NotificationModel.fromMap(d.data(), d.id)).toList());
  }

  Future<void> markAllAsRead(String uid) async {
    final snaps = await _firestore.collection('notifications').where('recipientUid', isEqualTo: uid).where('read', isEqualTo: false).get();
    final batch = _firestore.batch();
    for (final d in snaps.docs) {
      batch.update(d.reference, {'read': true, 'isRead': true});
    }
    await batch.commit();
  }

  Future<int> getUnreadCount(String uid) async {
    final snaps = await _firestore.collection('notifications').where('recipientUid', isEqualTo: uid).where('read', isEqualTo: false).get();
    return snaps.docs.length;
  }
}
