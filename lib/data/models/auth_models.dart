/// Authentication models and data classes
library;

/// User authentication providers
enum AuthProvider {
  email,
  phone,
  google,
  playGames,
  gameCenter,
}

/// User profile model
class UserProfile {
  final String uid;
  final String email;
  final String displayName;
  final String authProvider;
  final DateTime createdAt;
  final DateTime lastLogin;
  final int grade;
  final int points;
  final int level;
  final bool isEmailVerified;
  final String? phoneNumber;
  final String? photoUrl;

  UserProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.authProvider,
    required this.createdAt,
    required this.lastLogin,
    this.grade = 4,
    this.points = 0,
    this.level = 1,
    this.isEmailVerified = false,
    this.phoneNumber,
    this.photoUrl,
  });

  /// Convert to JSON for Firestore
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'authProvider': authProvider,
      'createdAt': createdAt,
      'lastLogin': lastLogin,
      'grade': grade,
      'points': points,
      'level': level,
      'isEmailVerified': isEmailVerified,
      'phoneNumber': phoneNumber,
      'photoUrl': photoUrl,
    };
  }

  /// Create from Firestore document
  factory UserProfile.fromMap(Map<String, dynamic> map, String uid) {
    return UserProfile(
      uid: uid,
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? 'User',
      authProvider: map['authProvider'] ?? 'email',
      createdAt: (map['createdAt']).toDate(),
      lastLogin: (map['lastLogin']).toDate(),
      grade: map['grade'] ?? 4,
      points: map['points'] ?? 0,
      level: map['level'] ?? 1,
      isEmailVerified: map['isEmailVerified'] ?? false,
      phoneNumber: map['phoneNumber'],
      photoUrl: map['photoUrl'],
    );
  }

  /// Copy with modifications
  UserProfile copyWith({
    String? displayName,
    int? points,
    int? level,
    bool? isEmailVerified,
    String? photoUrl,
    DateTime? lastLogin,
  }) {
    return UserProfile(
      uid: uid,
      email: email,
      displayName: displayName ?? this.displayName,
      authProvider: authProvider,
      createdAt: createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
      grade: grade,
      points: points ?? this.points,
      level: level ?? this.level,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      phoneNumber: phoneNumber,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }
}

/// Login request model
class LoginRequest {
  final String email;
  final String password;

  LoginRequest({
    required this.email,
    required this.password,
  });
}

/// Sign up request model
class SignUpRequest {
  final String email;
  final String password;
  final String displayName;
  final String? phoneNumber;
  final int grade;

  SignUpRequest({
    required this.email,
    required this.password,
    required this.displayName,
    this.phoneNumber,
    this.grade = 4,
  });

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'password': password,
      'displayName': displayName,
      'phoneNumber': phoneNumber,
      'grade': grade,
    };
  }
}

/// Phone verification request
class PhoneVerificationRequest {
  final String phoneNumber;
  final String? verificationId;
  final String? smsCode;

  PhoneVerificationRequest({
    required this.phoneNumber,
    this.verificationId,
    this.smsCode,
  });
}

/// Authentication response model
class AuthResponse {
  final bool success;
  final UserProfile? user;
  final String? error;
  final String? errorCode;

  AuthResponse({
    required this.success,
    this.user,
    this.error,
    this.errorCode,
  });

  factory AuthResponse.success(UserProfile user) {
    return AuthResponse(
      success: true,
      user: user,
    );
  }

  factory AuthResponse.error(String error, String? errorCode) {
    return AuthResponse(
      success: false,
      error: error,
      errorCode: errorCode,
    );
  }
}

/// Email verification model
class EmailVerification {
  final String email;
  final String verificationLink;
  final DateTime expiresAt;

  EmailVerification({
    required this.email,
    required this.verificationLink,
    required this.expiresAt,
  });
}

/// Password reset model
class PasswordReset {
  final String email;
  final String resetLink;
  final DateTime expiresAt;

  PasswordReset({
    required this.email,
    required this.resetLink,
    required this.expiresAt,
  });
}
