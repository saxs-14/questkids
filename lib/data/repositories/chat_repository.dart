import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_message_model.dart';

class ChatRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> saveMessage(String uid, ChatMessageModel message) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('chats')
        .doc(message.id)
        .set(message.toMap());
  }

  Stream<List<ChatMessageModel>> getChatHistory(String uid, {int limit = 50}) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('chats')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      final messages = snapshot.docs
          .map((doc) => ChatMessageModel.fromMap(doc.data(), doc.id))
          .toList();
      // Reverse to chronological order for Gemini UI
      return messages.reversed.toList();
    });
  }

  Future<List<ChatMessageModel>> fetchChatHistory(String uid, {int limit = 50}) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('chats')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();
        
    final messages = snapshot.docs
        .map((doc) => ChatMessageModel.fromMap(doc.data(), doc.id))
        .toList();
        
    return messages.reversed.toList();
  }
}
