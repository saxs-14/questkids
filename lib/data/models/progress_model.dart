import 'package:cloud_firestore/cloud_firestore.dart';

class ProgressModel {
  final String uid;
  final String activityId;
  final String activityTitle;
  final String subject;
  final int score; // percentage 0-100
  final int pointsEarned;
  final bool completed;
  final bool verified; // parent/teacher verified
  final String? proofUrl; // uploaded image
  final DateTime completedAt;
  final int timeTakenSeconds;

  ProgressModel({
    required this.uid,
    required this.activityId,
    required this.activityTitle,
    required this.subject,
    required this.score,
    required this.pointsEarned,
    this.completed = false,
    this.verified = false,
    this.proofUrl,
    required this.completedAt,
    this.timeTakenSeconds = 0,
  });

  static DateTime _tsToDate(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is Timestamp) return v.toDate();
    if (v is num) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }

  factory ProgressModel.fromMap(Map<String, dynamic> map) {
    return ProgressModel(
      uid: map['uid'] ?? '',
      activityId: map['activityId'] ?? '',
      activityTitle: map['activityTitle'] ?? '',
      subject: map['subject'] ?? '',
      score: (map['score'] as num?)?.toInt() ?? 0,
      pointsEarned: (map['pointsEarned'] as num?)?.toInt() ?? 0,
      completed: map['completed'] ?? false,
      verified: map['verified'] ?? false,
      proofUrl: map['proofUrl'],
      completedAt: _tsToDate(map['completedAt']),
      timeTakenSeconds: (map['timeTakenSeconds'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'activityId': activityId,
      'activityTitle': activityTitle,
      'subject': subject,
      'score': score,
      'pointsEarned': pointsEarned,
      'completed': completed,
      'verified': verified,
      'proofUrl': proofUrl,
      'completedAt': completedAt.millisecondsSinceEpoch,
      'timeTakenSeconds': timeTakenSeconds,
    };
  }

  ProgressModel copyWith({
    bool? completed,
    bool? verified,
    String? proofUrl,
    int? score,
    int? pointsEarned,
  }) {
    return ProgressModel(
      uid: uid,
      activityId: activityId,
      activityTitle: activityTitle,
      subject: subject,
      score: score ?? this.score,
      pointsEarned: pointsEarned ?? this.pointsEarned,
      completed: completed ?? this.completed,
      verified: verified ?? this.verified,
      proofUrl: proofUrl ?? this.proofUrl,
      completedAt: completedAt,
      timeTakenSeconds: timeTakenSeconds,
    );
  }
}
