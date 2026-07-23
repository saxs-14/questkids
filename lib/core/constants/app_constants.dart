class AppConstants {
  // App Info
  static const String appName = 'QuestKids';
  static const String appVersion = '2.0.0';

  // Roles
  static const String roleLearner = 'learner';
  static const String roleParent = 'parent';
  static const String roleTeacher = 'teacher';

  // Subjects
  static const List<String> subjects = [
    'Mathematics',
    'Natural Sciences',
    'English',
    'Social Sciences',
    'Technology',
    'Life Skills',
    'EMS',
  ];

  // Game types (legacy list)
  static const List<String> gameTypes = [
    'quiz',
    'practical',
    'responsibility',
    'tugofwar',
  ];

  // Game Engine Types
  static const String engineTugOfWar = 'tugOfWar';
  static const String engineAdventureJourney = 'adventureJourney';
  static const String engineRunnerCollector = 'runnerCollector';
  static const String engineExplorerMap = 'explorerMap';
  static const String engineMultiplesMerge = 'multiplesMerge';
  static const String engineSequenceBuilder = 'sequenceBuilder';
  static const String engineCircuitBuilder = 'circuitBuilder';
  static const String engineBudgetBuilder = 'budgetBuilder';
  static const String engineNumberCountingDuel = 'numberCountingDuel';
  static const String engineAdditionAdventure = 'additionAdventure';
  static const String engineSubtractionSafari = 'subtractionSafari';
  static const String engineMathsMountain = 'mathsMountain';
  static const String engineMultipleChain = 'multipleChain';
  static const String engineAlphabetExplorer = 'alphabetExplorer';
  static const String engineWordBuilder = 'wordBuilder';
  static const String enginePhonicsFun = 'phonicsFun';
  static const String engineReadingRainbow = 'readingRainbow';
  static const String engineGrammarGarden = 'grammarGarden';
  static const String engineFractionForest = 'fractionForest';
  static const String engineGeometryJungle = 'geometryJungle';
  static const String engineMeasurementValley = 'measurementValley';
  static const String engineDataCity = 'dataCity';
  static const String engineDecimalDunes = 'decimalDunes';
  static const String engineMultiplicationMountains = 'multiplicationMountains';
  static const String engineDivisionDesert = 'divisionDesert';
  static const String engineNumberNinja = 'numberNinja';
  static const String engineProblemSolver = 'problemSolver';
  static const String engineTimesTableTower = 'timesTableTower';
  static const String engineEcosystemExplorer = 'ecosystemExplorer';
  static const String engineMatterMaster = 'matterMaster';
  static const String engineEnergyQuest = 'energyQuest';
  static const String engineLifeCycles = 'lifeCycles';
  static const String engineSolarSystem = 'solarSystem';
  static const String engineWeatherWatcher = 'weatherWatcher';
  static const String engineSimpleMachines = 'simpleMachines';
  static const String engineCodingAdventure = 'codingAdventure';
  static const String engineCircuitLab = 'circuitLab';
  static const String engineRobotMaker = 'robotMaker';
  static const String engineMapMaster = 'mapMaster';
  static const String engineSaProvincesExplorer = 'saProvincesExplorer';
  static const String engineClimateQuest = 'climateQuest';
  static const String engineWaterCycle = 'waterCycle';
  static const String engineEcosystems = 'ecosystems';
  static const String engineAncientCivilizations = 'ancientCivilizations';
  static const String engineSaHistory = 'saHistory';
  static const String engineColonialEra = 'colonialEra';
  static const String engineLiberationHeroes = 'liberationHeroes';
  static const String engineDemocracyGame = 'democracyGame';
  static const String engineReadingQuest = 'readingQuest';
  static const String engineNounNavigator = 'nounNavigator';
  static const String engineVerbVolcano = 'verbVolcano';
  static const String engineWordPower = 'wordPower';
  static const String engineSpellingBee = 'spellingBee';
  static const String enginePunctuationPolice = 'punctuationPolice';
  static const String engineStoryBuilder = 'storyBuilder';
  static const String enginePoetryExplorer = 'poetryExplorer';
  static const String engineIdiomIsland = 'idiomIsland';
  static const String engineDebateDuel = 'debateDuel';
  static const String engineCareerExplorer = 'careerExplorer';
  static const String engineFinancialLiteracy = 'financialLiteracy';
  static const String engineHealthyLiving = 'healthyLiving';
  static const String engineSocialSkills = 'socialSkills';
  static const String engineEnvironmentalAwareness = 'environmentalAwareness';

  // Gamification
  static const int pointsPerQuiz = 10;
  static const int pointsPerActivity = 25;
  static const int pointsPerStreak = 5;
  static const int pointsPerBadge = 50;

  // Firestore Collections
  static const String colUsers = 'users';
  static const String colActivities = 'activities';
  static const String colProgress = 'progress';
  static const String colRewards = 'rewards';
  static const String colNotifications = 'notifications';
  static const String colGameSessions = 'game_sessions';
  static const String colPlayerStats = 'player_stats';
  static const String colGameProgress = 'game_progress';
  static const String colLeaderboards = 'leaderboards';
  static const String colDailyMissions = 'daily_missions';
  static const String colCapsCurriculum = 'caps_curriculum';

  // Shared Prefs Keys
  static const String prefTheme = 'isDarkMode';
  static const String prefOnboarding = 'onboardingDone';
  static const String prefUserRole = 'userRole';

  // POPIA parent/guardian consent — bump when the consent copy materially
  // changes so older acceptances can be told apart from current ones.
  static const String consentPolicyVersion = '1.0';
}
