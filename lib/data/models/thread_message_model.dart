import 'package:cloud_firestore/cloud_firestore.dart';

class ThreadMessageModel {
  final String id;
  final String senderUid;
  final String senderRole; // 'teacher' | 'parent'
  final String text;
  final DateTime sentAt;

  const ThreadMessageModel({
    required this.id,
    required this.senderUid,
    required this.senderRole,
    required this.text,
    required this.sentAt,
  });

  factory ThreadMessageModel.fromMap(Map<String, dynamic> map, String id) {
    return ThreadMessageModel(
      id: id,
      senderUid: map['senderUid'] as String,
      senderRole: map['senderRole'] as String,
      text: map['text'] as String,
      sentAt: (map['sentAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'senderUid': senderUid,
        'senderRole': senderRole,
        'text': text,
        'sentAt': Timestamp.fromDate(sentAt),
      };
}
