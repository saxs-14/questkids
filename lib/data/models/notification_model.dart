class NotificationModel {
  final String id;
  final String title;
  final String body;
  final String
      type; // types: reminder, achievement, verification, parent_update,
  // link_request, link_approved, link_declined, milestone,
  // weekly_report, low_activity, verification
  final String targetUid; // legacy
  final String recipientUid; // new preferred key
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.targetUid,
    this.recipientUid = '',
    this.isRead = false,
    required this.createdAt,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map, String id) {
    return NotificationModel(
      id: id,
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      type: map['type'] ?? 'reminder',
      targetUid: map['targetUid'] ?? '',
      recipientUid: map['recipientUid'] ?? map['targetUid'] ?? '',
      isRead: map['isRead'] ?? map['read'] ?? false,
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'body': body,
      'type': type,
      'targetUid': targetUid,
      'recipientUid': recipientUid,
      'isRead': isRead,
      'read': isRead,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }
}
