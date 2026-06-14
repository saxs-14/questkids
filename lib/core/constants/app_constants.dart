class AppConstants {
  // App Info
  static const String appName     = 'QuestKids';
  static const String appVersion  = '2.0.0';

  // Roles
  static const String roleLearner = 'learner';
  static const String roleParent  = 'parent';
  static const String roleTeacher = 'teacher';

  // Subjects
  static const List<String> subjects = [
    'Math', 'Science', 'English', 'Social Sciences',
  ];

  // Game types
  static const List<String> gameTypes = [
    'quiz', 'practical', 'responsibility', 'tugofwar',
  ];

  // Gamification
  static const int pointsPerQuiz       = 10;
  static const int pointsPerActivity   = 25;
  static const int pointsPerStreak     = 5;
  static const int pointsPerBadge      = 50;

  // Firestore Collections
  static const String colUsers         = 'users';
  static const String colActivities    = 'activities';
  static const String colProgress      = 'progress';
  static const String colRewards       = 'rewards';
  static const String colNotifications = 'notifications';

  // Shared Prefs Keys
  static const String prefTheme        = 'isDarkMode';
  static const String prefOnboarding   = 'onboardingDone';
  static const String prefUserRole     = 'userRole';
}
