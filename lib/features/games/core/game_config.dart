import '../../../core/constants/app_constants.dart';

/// Immutable configuration passed to every game engine.
/// Engines must NOT contain hardcoded question lists; all tunable
/// parameters live here so a single engine class serves many curricula.
class GameConfig {
  final String engineType;       // AppConstants.engine*
  final String subject;          // e.g. 'Mathematics'
  final String grade;            // e.g. 'grade4'
  final String topicId;          // caps_curriculum topic id
  final String subtopicId;       // caps_curriculum subtopic id
  final String difficulty;       // 'easy' | 'medium' | 'hard' | 'adaptive'
  final int questionCount;       // total questions per session
  final int timeLimitSeconds;    // 0 = no limit (timer still counts up)
  final String opponentName;     // AI opponent display name
  final String opponentEmoji;    // AI opponent emoji / avatar
  final Map<String, dynamic> extras; // engine-specific config (range, lanes, …)

  const GameConfig({
    required this.engineType,
    required this.subject,
    required this.grade,
    this.topicId = '',
    this.subtopicId = '',
    this.difficulty = 'medium',
    this.questionCount = 10,
    this.timeLimitSeconds = 0,
    this.opponentName = 'CPU',
    this.opponentEmoji = '🤖',
    this.extras = const {},
  });

  factory GameConfig.fromMap(Map<String, dynamic> map) {
    return GameConfig(
      engineType: map['engineType'] as String,
      subject: map['subject'] as String,
      grade: map['grade'] as String,
      topicId: map['topicId'] as String? ?? '',
      subtopicId: map['subtopicId'] as String? ?? '',
      difficulty: map['difficulty'] as String? ?? 'medium',
      questionCount: (map['questionCount'] as num?)?.toInt() ?? 10,
      timeLimitSeconds: (map['timeLimitSeconds'] as num?)?.toInt() ?? 0,
      opponentName: map['opponentName'] as String? ?? 'CPU',
      opponentEmoji: map['opponentEmoji'] as String? ?? '🤖',
      extras: Map<String, dynamic>.from(map['extras'] as Map? ?? {}),
    );
  }

  Map<String, dynamic> toMap() => {
        'engineType': engineType,
        'subject': subject,
        'grade': grade,
        'topicId': topicId,
        'subtopicId': subtopicId,
        'difficulty': difficulty,
        'questionCount': questionCount,
        'timeLimitSeconds': timeLimitSeconds,
        'opponentName': opponentName,
        'opponentEmoji': opponentEmoji,
        'extras': extras,
      };

  GameConfig copyWith({
    String? engineType,
    String? subject,
    String? grade,
    String? topicId,
    String? subtopicId,
    String? difficulty,
    int? questionCount,
    int? timeLimitSeconds,
    String? opponentName,
    String? opponentEmoji,
    Map<String, dynamic>? extras,
  }) {
    return GameConfig(
      engineType: engineType ?? this.engineType,
      subject: subject ?? this.subject,
      grade: grade ?? this.grade,
      topicId: topicId ?? this.topicId,
      subtopicId: subtopicId ?? this.subtopicId,
      difficulty: difficulty ?? this.difficulty,
      questionCount: questionCount ?? this.questionCount,
      timeLimitSeconds: timeLimitSeconds ?? this.timeLimitSeconds,
      opponentName: opponentName ?? this.opponentName,
      opponentEmoji: opponentEmoji ?? this.opponentEmoji,
      extras: extras ?? this.extras,
    );
  }

  // ── Preset factories ───────────────────────────────────────────────────────

  static GameConfig multiplicationTables({
    required String grade,
    String difficulty = 'medium',
  }) {
    final range = switch (difficulty) {
      'easy' => {'min': 2, 'max': 5},
      'hard' => {'min': 2, 'max': 12},
      _ => {'min': 2, 'max': 9},
    };
    return GameConfig(
      engineType: AppConstants.engineTugOfWar,
      subject: 'Mathematics',
      grade: grade,
      topicId: 'multiplication',
      subtopicId: 'times_tables',
      difficulty: difficulty,
      opponentName: 'Multiplication Monster',
      opponentEmoji: '👾',
      extras: {'multiplierMin': range['min'], 'multiplierMax': range['max']},
    );
  }

  static const GameConfig waterCycle = GameConfig(
    engineType: AppConstants.engineAdventureJourney,
    subject: 'Natural Sciences',
    grade: 'grade4',
    topicId: 'water_cycle',
    subtopicId: 'evaporation_condensation',
    opponentName: '',
    opponentEmoji: '💧',
  );

  static const GameConfig partsOfSpeech = GameConfig(
    engineType: AppConstants.engineRunnerCollector,
    subject: 'English',
    grade: 'grade4',
    topicId: 'grammar',
    subtopicId: 'nouns_verbs_adjectives',
    opponentName: '',
    opponentEmoji: '🏃',
  );

  static const GameConfig saProvinces = GameConfig(
    engineType: AppConstants.engineExplorerMap,
    subject: 'Social Sciences',
    grade: 'grade4',
    topicId: 'geography_sa',
    subtopicId: 'provinces',
    opponentName: '',
    opponentEmoji: '🗺️',
  );
}
