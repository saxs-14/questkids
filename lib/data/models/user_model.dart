import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String? surname;
  final String email;
  final String role; // learner, parent, teacher
  final String? gender;
  final String? title; // Mr, Mrs, Ms, Dr
  final DateTime? birthDate; // For learners
  final String? relationToChild; // For parents (e.g. Father, Mother)
  final String grade;
  final String? parentUid;
  final String? avatarUrl;
  // New fields for multi-parent linking and profile
  final String? childLinkCode; // 6-char code for learners
  final List<String> linkedParentUids; // for learners
  final bool emailVerified;
  final bool twoFactorEnabled;
  final String? profileImageBase64;
  final DateTime? lastActiveDate;
  final int totalPoints;
  final int streakDays;
  final DateTime createdAt;
  final List<String> linkedChildrenUids;
  final String preferredLanguage;
  final String? fcmToken;
  final String? linkedTeacherUid; // for learners linked to a teacher's class

  String get displayName {
    if (role == 'teacher' || role == 'parent') {
      final t = title != null ? '$title ' : '';
      final s = surname != null && surname!.isNotEmpty ? surname! : name;
      return '$t$s'.trim();
    }
    return name;
  }

  /// Simple emoji/avatar fallback used in UI when no image is available.
  String get avatarEmoji {
    // Prefer an explicit avatarUrl or profile image indication
    if (avatarUrl != null && avatarUrl!.isNotEmpty) return '🖼️';
    if (profileImageBase64 != null && profileImageBase64!.isNotEmpty)
      return '🖼️';
    // Use first character of name as a friendly fallback (or a default emoji)
    final trimmed = name.trim();
    if (trimmed.isNotEmpty) {
      final first = String.fromCharCode(trimmed.runes.first);
      // If first character is ASCII letter/number, wrap it; otherwise use it directly
      if (RegExp(r"[A-Za-z0-9]").hasMatch(first)) return first.toUpperCase();
      return first;
    }
    return '🙂';
  }

  UserModel({
    required this.uid,
    required this.name,
    this.surname,
    required this.email,
    required this.role,
    this.gender,
    this.title,
    this.birthDate,
    this.relationToChild,
    required this.grade,
    this.parentUid,
    this.avatarUrl,
    this.childLinkCode,
    this.linkedParentUids = const [],
    this.emailVerified = false,
    this.twoFactorEnabled = false,
    this.profileImageBase64,
    this.lastActiveDate,
    this.totalPoints = 0,
    this.streakDays = 0,
    required this.createdAt,
    this.linkedChildrenUids = const [],
    this.preferredLanguage = 'English',
    this.fcmToken,
    this.linkedTeacherUid,
  });

  static DateTime? _tsToDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return null;
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    return UserModel(
      uid: uid,
      name: map['name'] ?? '',
      surname: map['surname'],
      email: map['email'] ?? '',
      role: map['role'] ?? 'learner',
      gender: map['gender'],
      title: map['title'],
      birthDate: _tsToDate(map['birthDate']),
      relationToChild: map['relationToChild'],
      grade: map['grade'] ?? 'Grade 1',
      parentUid: map['parentUid'],
      avatarUrl: map['avatarUrl'],
      childLinkCode: map['childLinkCode'],
      linkedParentUids: List<String>.from(map['linkedParentUids'] ?? []),
      emailVerified: map['emailVerified'] ?? false,
      twoFactorEnabled: map['twoFactorEnabled'] ?? false,
      profileImageBase64: map['profileImageBase64'],
      lastActiveDate: _tsToDate(map['lastActiveDate']),
      totalPoints: map['totalPoints'] ?? 0,
      streakDays: map['streakDays'] ?? 0,
      createdAt: _tsToDate(map['createdAt']) ?? DateTime.now(),
      linkedChildrenUids: List<String>.from(map['linkedChildrenUids'] ?? []),
      preferredLanguage: map['preferredLanguage'] ?? 'English',
      fcmToken: map['fcmToken'],
      linkedTeacherUid: map['linkedTeacherUid'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'surname': surname,
      'email': email,
      'role': role,
      'gender': gender,
      'title': title,
      'birthDate': birthDate?.millisecondsSinceEpoch,
      'relationToChild': relationToChild,
      'grade': grade,
      'parentUid': parentUid,
      'avatarUrl': avatarUrl,
      'childLinkCode': childLinkCode,
      'linkedParentUids': linkedParentUids,
      'emailVerified': emailVerified,
      'twoFactorEnabled': twoFactorEnabled,
      'profileImageBase64': profileImageBase64,
      'lastActiveDate': lastActiveDate?.millisecondsSinceEpoch,
      'totalPoints': totalPoints,
      'streakDays': streakDays,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'linkedChildrenUids': linkedChildrenUids,
      'preferredLanguage': preferredLanguage,
      'fcmToken': fcmToken,
      'linkedTeacherUid': linkedTeacherUid,
    };
  }

  UserModel copyWith({
    String? name,
    String? surname,
    String? email,
    String? role,
    String? gender,
    String? title,
    DateTime? birthDate,
    String? relationToChild,
    String? grade,
    String? parentUid,
    String? avatarUrl,
    String? childLinkCode,
    List<String>? linkedParentUids,
    bool? emailVerified,
    bool? twoFactorEnabled,
    String? profileImageBase64,
    DateTime? lastActiveDate,
    int? totalPoints,
    int? streakDays,
    List<String>? linkedChildrenUids,
    String? preferredLanguage,
    String? fcmToken,
  }) {
    return UserModel(
      uid: uid,
      name: name ?? this.name,
      surname: surname ?? this.surname,
      email: email ?? this.email,
      role: role ?? this.role,
      gender: gender ?? this.gender,
      title: title ?? this.title,
      birthDate: birthDate ?? this.birthDate,
      relationToChild: relationToChild ?? this.relationToChild,
      grade: grade ?? this.grade,
      parentUid: parentUid ?? this.parentUid,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      childLinkCode: childLinkCode ?? this.childLinkCode,
      linkedParentUids: linkedParentUids ?? this.linkedParentUids,
      emailVerified: emailVerified ?? this.emailVerified,
      twoFactorEnabled: twoFactorEnabled ?? this.twoFactorEnabled,
      profileImageBase64: profileImageBase64 ?? this.profileImageBase64,
      lastActiveDate: lastActiveDate ?? this.lastActiveDate,
      totalPoints: totalPoints ?? this.totalPoints,
      streakDays: streakDays ?? this.streakDays,
      createdAt: createdAt,
      linkedChildrenUids: linkedChildrenUids ?? this.linkedChildrenUids,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      fcmToken: fcmToken ?? this.fcmToken,
    );
  }
}
