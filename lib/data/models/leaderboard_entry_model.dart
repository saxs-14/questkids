import 'package:cloud_firestore/cloud_firestore.dart';

class LeaderboardEntry {
  final String uid;
  final String displayName;
  final String avatarEmoji;
  final String grade;
  final int xp;
  final int rank;

  const LeaderboardEntry({
    required this.uid,
    required this.displayName,
    required this.avatarEmoji,
    required this.grade,
    required this.xp,
    required this.rank,
  });

  factory LeaderboardEntry.fromMap(Map<String, dynamic> map) {
    return LeaderboardEntry(
      uid: map['uid'] as String? ?? '',
      displayName: map['displayName'] as String? ?? 'Learner',
      avatarEmoji: map['avatarEmoji'] as String? ?? '🦁',
      grade: map['grade'] as String? ?? 'Grade 1',
      xp: (map['xp'] as num?)?.toInt() ?? 0,
      rank: (map['rank'] as num?)?.toInt() ?? 0,
    );
  }

  factory LeaderboardEntry.fromDoc(DocumentSnapshot doc) {
    return LeaderboardEntry.fromMap(doc.data() as Map<String, dynamic>? ?? {});
  }
}
