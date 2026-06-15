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

  // Game types (legacy list)
  static const List<String> gameTypes = [
    'quiz', 'practical', 'responsibility', 'tugofwar',
  ];

  // Game Engine Types
  static const String engineTugOfWar         = 'tugOfWar';
  static const String engineAdventureJourney = 'adventureJourney';
  static const String engineRunnerCollector  = 'runnerCollector';
  static const String engineExplorerMap      = 'explorerMap';

  // Gamification
  static const int pointsPerQuiz       = 10;
  static const int pointsPerActivity   = 25;
  static const int pointsPerStreak     = 5;
  static const int pointsPerBadge      = 50;

  // Firestore Collections
  static const String colUsers          = 'users';
  static const String colActivities     = 'activities';
  static const String colProgress       = 'progress';
  static const String colRewards        = 'rewards';
  static const String colNotifications  = 'notifications';
  static const String colGameSessions   = 'game_sessions';
  static const String colPlayerStats    = 'player_stats';
  static const String colGameProgress   = 'game_progress';
  static const String colLeaderboards   = 'leaderboards';
  static const String colDailyMissions  = 'daily_missions';
  static const String colCapsCurriculum = 'caps_curriculum';

  // Shared Prefs Keys
  static const String prefTheme        = 'isDarkMode';
  static const String prefOnboarding   = 'onboardingDone';
  static const String prefUserRole     = 'userRole';
}
