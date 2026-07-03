/// Environment configuration for QuestKids Firebase setup
library;

class FirebaseConfig {
  // Firebase Project
  static const String projectId = 'questkids-mobile';
  static const String projectName = 'QuestKids 2.0';

  // Email Configuration
  static const String emailSender = 'questkids.dev@gmail.com';
  static const String smtpHost = 'smtp.gmail.com';
  static const int smtpPort = 587;
  static const String smtpSecurity = 'tls';

  // Support Email
  static const String supportEmail = 'support@questkids.com';

  // App Configuration
  static const int defaultGrade = 4;
  static const int defaultPoints = 0;
  static const int defaultLevel = 1;

  // Firestore Collections
  static const String usersCollection = 'users';
  static const String activitiesCollection = 'activities';
  static const String progressCollection = 'progress';
  static const String rewardsCollection = 'rewards';
  static const String notificationsCollection = 'notifications';
  static const String emailsCollection = 'emails';

  // Authentication Providers
  static const List<String> enabledProviders = [
    'email',
    'phone',
    'google',
    'playGames',
    'gameCenter',
  ];

  // Security
  static const int passwordMinLength = 8;
  static const int otpExpirationMinutes = 10;
  static const int emailVerificationLinkExpiration = 24; // hours
  static const int passwordResetLinkExpiration = 24; // hours

  // Google Sign-In
  static const String googleClientIdWeb =
      'YOUR_GOOGLE_CLIENT_ID.apps.googleusercontent.com';
  static const String googleClientIdAndroid =
      'YOUR_GOOGLE_CLIENT_ID.apps.googleusercontent.com';
  static const String googleClientIdIos =
      'YOUR_GOOGLE_CLIENT_ID.apps.googleusercontent.com';

  // Play Games (Android)
  static const String playGamesAppId = 'YOUR_PLAY_GAMES_APP_ID';

  // Game Center (iOS)
  static const String gameCenterId =
      'com.questkids.questkids'; // Update with your bundle ID

  // API Endpoints (if using custom backend)
  static const String apiBaseUrl = 'https://api.questkids.com';
  static const String authEndpoint = '/auth';
  static const String userEndpoint = '/user';

  // Feature Flags
  static const bool enableEmailVerification = true;
  static const bool enablePhoneVerification = true;
  static const bool enableGoogleSignIn = true;
  static const bool enablePlayGames = true;
  static const bool enableGameCenter = true;
  static const bool enableParentConsent = true; // For grade 4 learners
  static const bool enableNotifications = true;

  // App Version & Build
  static const String appVersion = '2.0.0';
  static const String buildNumber = '1';
}

/// Environment-specific configuration
enum Environment {
  development,
  staging,
  production,
}

class EnvironmentConfig {
  static Environment currentEnvironment = Environment.production;

  static bool get isDevelopment =>
      currentEnvironment == Environment.development;
  static bool get isStaging => currentEnvironment == Environment.staging;
  static bool get isProduction => currentEnvironment == Environment.production;

  /// Firebase Emulator Configuration (for development/testing)
  static const String emulatorsHost = 'localhost';
  static const int firestoreEmulatorPort = 8080;
  static const int authEmulatorPort = 9099;
  static const int functionsEmulatorPort = 5001;

  /// Enable emulators for local development
  static const bool enableFirebaseEmulators =
      false; // Set to true for local testing
}

/// Email Template Configuration
class EmailConfig {
  static const String emailSender = 'support@questkids.com';
  static const String senderName = 'QuestKids Support';

  // Email Templates
  static const Map<String, String> emailTemplates = {
    'welcome': 'Welcome to QuestKids 2.0! 🎮',
    'email_verification': 'Verify Your Email Address',
    'password_reset': 'Reset Your QuestKids Password',
    'achievement': 'You Unlocked an Achievement! 🏆',
    'daily_challenge': 'New Daily Challenge Available! ⭐',
    'level_up': 'Congratulations! You Leveled Up! 🎉',
  };
}

/// Firestore Collections Schema Configuration
class FirestoreSchema {
  // Users collection document structure
  static const List<String> userFields = [
    'uid',
    'email',
    'displayName',
    'phoneNumber',
    'photoUrl',
    'authProvider',
    'grade',
    'points',
    'level',
    'isEmailVerified',
    'createdAt',
    'lastLogin',
    'isActive',
  ];

  // Activities collection document structure
  static const List<String> activityFields = [
    'id',
    'title',
    'subject',
    'gradeLevel',
    'description',
    'difficulty',
    'pointsValue',
    'estimatedTime',
    'imageUrl',
    'createdAt',
    'updatedAt',
  ];

  // Progress collection document structure
  static const List<String> progressFields = [
    'userId',
    'activityId',
    'score',
    'completionTime',
    'attemptsCount',
    'completedAt',
    'updatedAt',
  ];

  // Rewards collection document structure
  static const List<String> rewardFields = [
    'userId',
    'rewardName',
    'rewardType',
    'pointsEarned',
    'earnedAt',
    'description',
  ];

  // Notifications collection document structure
  static const List<String> notificationFields = [
    'userId',
    'title',
    'body',
    'type',
    'relatedEntityId',
    'isRead',
    'createdAt',
    'expiresAt',
  ];
}

/// Error Messages Configuration
class ErrorMessages {
  static const String invalidEmail = 'Please enter a valid email address';
  static const String weakPassword = 'Password must be at least 8 characters';
  static const String passwordsDoNotMatch = 'Passwords do not match';
  static const String emailAlreadyInUse = 'This email is already registered';
  static const String invalidCredentials = 'Invalid email or password';
  static const String networkError =
      'Network error. Please check your connection';
  static const String unknown =
      'An unexpected error occurred. Please try again';
  static const String phoneVerificationFailed =
      'Phone verification failed. Please try again';
  static const String googleSignInFailed =
      'Google Sign-In failed. Please try again';
  static const String firestoreError = 'Database error. Please try again later';
}

/// Success Messages Configuration
class SuccessMessages {
  static const String signUpSuccess =
      'Account created successfully! Welcome to QuestKids!';
  static const String signInSuccess = 'Welcome back!';
  static const String signOutSuccess = 'You have been signed out';
  static const String emailVerificationSent =
      'Verification email sent. Please check your inbox';
  static const String passwordResetSent =
      'Password reset link sent to your email';
  static const String phoneVerified = 'Phone number verified successfully';
}
