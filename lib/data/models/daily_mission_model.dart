import 'package:cloud_firestore/cloud_firestore.dart';

class DailyMission {
  final String id;
  final String gameId;
  final String title;
  final String subject;
  final String emoji;
  final int xpBonus;
  final bool completed;
  final DateTime? completedAt;
  final String source; // 'teacher' | 'adaptive' | 'curated'

  const DailyMission({
    required this.id,
    required this.gameId,
    required this.title,
    required this.subject,
    required this.emoji,
    required this.xpBonus,
    required this.completed,
    this.completedAt,
    required this.source,
  });

  factory DailyMission.fromMap(String id, Map<String, dynamic> map) {
    return DailyMission(
      id: id,
      gameId: map['gameId'] as String? ?? '',
      title: map['title'] as String? ?? 'Daily Mission',
      subject: map['subject'] as String? ?? 'General',
      emoji: map['emoji'] as String? ?? '⭐',
      xpBonus: (map['xpBonus'] as num?)?.toInt() ?? 15,
      completed: map['completed'] as bool? ?? false,
      completedAt: map['completedAt'] is Timestamp
          ? (map['completedAt'] as Timestamp).toDate()
          : null,
      source: map['source'] as String? ?? 'curated',
    );
  }

  String get sourceBadge {
    switch (source) {
      case 'teacher':
        return '📋 Teacher';
      case 'adaptive':
        return '🤖 AI Pick';
      default:
        return '⭐ Daily';
    }
  }
}
