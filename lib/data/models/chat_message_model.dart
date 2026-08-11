import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessageModel {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isLoading;
  final String? imageUrl;
  final String? intent;

  ChatMessageModel({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isLoading = false,
    this.imageUrl,
    this.intent,
  });

  static DateTime _tsToDate(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is Timestamp) return v.toDate();
    if (v is num) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }

  factory ChatMessageModel.user(String text, {String? intent}) {
    return ChatMessageModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
      intent: intent,
    );
  }

  factory ChatMessageModel.bot(String text, {String? intent}) {
    return ChatMessageModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      isUser: false,
      timestamp: DateTime.now(),
      intent: intent,
    );
  }

  factory ChatMessageModel.loading() {
    return ChatMessageModel(
      id: 'loading',
      text: '',
      isUser: false,
      timestamp: DateTime.now(),
      isLoading: true,
    );
  }

  ChatMessageModel copyWith({
    String? text,
    bool? isLoading,
  }) {
    return ChatMessageModel(
      id: id,
      text: text ?? this.text,
      isUser: isUser,
      timestamp: timestamp,
      isLoading: isLoading ?? this.isLoading,
      imageUrl: imageUrl,
      intent: intent,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'isUser': isUser,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'imageUrl': imageUrl,
      'intent': intent,
    };
  }

  factory ChatMessageModel.fromMap(Map<String, dynamic> map, String id) {
    return ChatMessageModel(
      id: id,
      text: map['text'] ?? '',
      isUser: map['isUser'] ?? true,
      timestamp: _tsToDate(map['timestamp']),
      imageUrl: map['imageUrl'],
      intent: map['intent'] as String?,
    );
  }
}
