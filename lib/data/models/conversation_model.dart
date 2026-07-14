import 'package:cloud_firestore/cloud_firestore.dart';

class ConversationModel {
  final String id;
  final String teacherUid;
  final String parentUid;
  final String childUid;
  final String childName;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final DateTime createdAt;

  const ConversationModel({
    required this.id,
    required this.teacherUid,
    required this.parentUid,
    required this.childUid,
    required this.childName,
    this.lastMessage = '',
    this.lastMessageAt,
    required this.createdAt,
  });

  List<String> get participants => [teacherUid, parentUid];

  factory ConversationModel.fromMap(Map<String, dynamic> map, String id) {
    return ConversationModel(
      id: id,
      teacherUid: map['teacherUid'] as String,
      parentUid: map['parentUid'] as String,
      childUid: map['childUid'] as String,
      childName: map['childName'] as String? ?? '',
      lastMessage: map['lastMessage'] as String? ?? '',
      lastMessageAt: map['lastMessageAt'] is Timestamp
          ? (map['lastMessageAt'] as Timestamp).toDate()
          : null,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'teacherUid': teacherUid,
        'parentUid': parentUid,
        'childUid': childUid,
        'childName': childName,
        'participants': participants,
        'lastMessage': lastMessage,
        'lastMessageAt':
            lastMessageAt != null ? Timestamp.fromDate(lastMessageAt!) : null,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
