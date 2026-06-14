class ProgressModel {
  final String uid;
  final String activityId;
  final String activityTitle;
  final String subject;
  final int score;           // percentage 0-100
  final int pointsEarned;
  final bool completed;
  final bool verified;       // parent/teacher verified
  final String? proofUrl;    // uploaded image
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

  factory ProgressModel.fromMap(Map<String, dynamic> map) {
    return ProgressModel(
      uid: map['uid'] ?? '',
      activityId: map['activityId'] ?? '',
      activityTitle: map['activityTitle'] ?? '',
      subject: map['subject'] ?? '',
      score: map['score'] ?? 0,
      pointsEarned: map['pointsEarned'] ?? 0,
      completed: map['completed'] ?? false,
      verified: map['verified'] ?? false,
      proofUrl: map['proofUrl'],
      completedAt: map['completedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['completedAt'])
          : DateTime.now(),
      timeTakenSeconds: map['timeTakenSeconds'] ?? 0,
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
