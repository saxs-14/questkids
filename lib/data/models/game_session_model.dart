import 'package:cloud_firestore/cloud_firestore.dart';

class GameSessionModel {
  final String id;
  final String uid;
  final String grade;
  final String subject;
  final String engineType;
  final int score; // percentage 0–100
  final int xpEarned;
  final int coinsEarned;
  final double accuracy; // 0.0 to 1.0
  final int timeTakenSeconds;
  final DateTime completedAt;
  final String result; // 'win' | 'loss' | 'complete' | 'incomplete'
  final Map<String, dynamic> metadata;

  const GameSessionModel({
    required this.id,
    required this.uid,
    required this.grade,
    required this.subject,
    required this.engineType,
    required this.score,
    required this.xpEarned,
    required this.coinsEarned,
    required this.accuracy,
    required this.timeTakenSeconds,
    required this.completedAt,
    required this.result,
    this.metadata = const {},
  });

  static DateTime _tsToDate(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is Timestamp) return v.toDate();
    if (v is num) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }

  factory GameSessionModel.fromMap(String id, Map<String, dynamic> map) {
    return GameSessionModel(
      id: id,
      uid: map['uid'] as String? ?? '',
      grade: map['grade'] as String? ?? '',
      subject: map['subject'] as String? ?? '',
      engineType: map['engineType'] as String? ?? '',
      score: (map['score'] as num?)?.toInt() ?? 0,
      xpEarned: (map['xpEarned'] as num?)?.toInt() ?? 0,
      coinsEarned: (map['coinsEarned'] as num?)?.toInt() ?? 0,
      accuracy: (map['accuracy'] as num?)?.toDouble() ?? 0.0,
      timeTakenSeconds: (map['timeTakenSeconds'] as num?)?.toInt() ?? 0,
      completedAt: _tsToDate(map['completedAt']),
      result: map['result'] as String? ?? 'complete',
      metadata: Map<String, dynamic>.from(map['metadata'] as Map? ?? {}),
    );
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'grade': grade,
        'subject': subject,
        'engineType': engineType,
        'score': score,
        'xpEarned': xpEarned,
        'coinsEarned': coinsEarned,
        'accuracy': accuracy,
        'timeTakenSeconds': timeTakenSeconds,
        'completedAt': Timestamp.fromDate(completedAt),
        'result': result,
        'metadata': metadata,
      };

  GameSessionModel copyWith({
    String? id,
    String? uid,
    String? grade,
    String? subject,
    String? engineType,
    int? score,
    int? xpEarned,
    int? coinsEarned,
    double? accuracy,
    int? timeTakenSeconds,
    DateTime? completedAt,
    String? result,
    Map<String, dynamic>? metadata,
  }) {
    return GameSessionModel(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      grade: grade ?? this.grade,
      subject: subject ?? this.subject,
      engineType: engineType ?? this.engineType,
      score: score ?? this.score,
      xpEarned: xpEarned ?? this.xpEarned,
      coinsEarned: coinsEarned ?? this.coinsEarned,
      accuracy: accuracy ?? this.accuracy,
      timeTakenSeconds: timeTakenSeconds ?? this.timeTakenSeconds,
      completedAt: completedAt ?? this.completedAt,
      result: result ?? this.result,
      metadata: metadata ?? this.metadata,
    );
  }
}
