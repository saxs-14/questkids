import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/conversation_model.dart';
import '../models/thread_message_model.dart';

/// Teacher <-> parent messaging, one conversation per (teacher, parent,
/// child) triple. Conversation docs live in `conversations/{id}`, with a
/// `messages` subcollection per conversation.
class MessagingRepository {
  final _db = FirebaseFirestore.instance;

  /// Deterministic id so repeated getOrCreate calls for the same triple
  /// never create duplicate threads, regardless of call-site argument
  /// order (teacherUid/parentUid are sorted before joining).
  static String conversationId({
    required String teacherUid,
    required String parentUid,
    required String childUid,
  }) {
    final sorted = [teacherUid, parentUid]..sort();
    return '${sorted[0]}_${sorted[1]}_$childUid';
  }

  Future<ConversationModel> getOrCreateConversation({
    required String teacherUid,
    required String parentUid,
    required String childUid,
    required String childName,
  }) async {
    final id = conversationId(
        teacherUid: teacherUid, parentUid: parentUid, childUid: childUid);
    final ref = _db.collection('conversations').doc(id);
    final snap = await ref.get();
    if (snap.exists) {
      return ConversationModel.fromMap(snap.data()!, id);
    }
    final model = ConversationModel(
      id: id,
      teacherUid: teacherUid,
      parentUid: parentUid,
      childUid: childUid,
      childName: childName,
      createdAt: DateTime.now(),
    );
    await ref.set(model.toMap());
    return model;
  }

  Future<void> sendMessage({
    required String conversationId,
    required String senderUid,
    required String senderRole,
    required String text,
  }) async {
    final now = DateTime.now();
    final convoRef = _db.collection('conversations').doc(conversationId);
    final msgRef = convoRef.collection('messages').doc();
    final batch = _db.batch();
    batch.set(
      msgRef,
      ThreadMessageModel(
        id: msgRef.id,
        senderUid: senderUid,
        senderRole: senderRole,
        text: text,
        sentAt: now,
      ).toMap(),
    );
    batch.update(convoRef, {
      'lastMessage': text,
      'lastMessageAt': Timestamp.fromDate(now),
    });
    await batch.commit();
  }

  Stream<List<ThreadMessageModel>> watchMessages(String conversationId) {
    return _db
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('sentAt')
        .snapshots()
        .map((s) => s.docs
            .map((d) => ThreadMessageModel.fromMap(d.data(), d.id))
            .toList());
  }

  Stream<List<ConversationModel>> watchConversationsForUser(String uid) {
    return _db
        .collection('conversations')
        .where('participants', arrayContains: uid)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => ConversationModel.fromMap(d.data(), d.id))
            .toList());
  }
}
