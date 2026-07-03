import '../core/game_config.dart';

/// A word card scrolling toward the player in a lane.
class LaneWord {
  final String word;
  final String wordClass; // bucket key, e.g. 'noun', 'safe', 'renewable'
  final int lane; // 0, 1, or 2
  double xPosition; // 0.0 = right edge, 1.0 = left edge (off-screen)
  bool collected;

  LaneWord({
    required this.word,
    required this.wordClass,
    required this.lane,
    this.xPosition = 0.0,
    this.collected = false,
  });
}

/// One gameplay level — defines what the player must collect.
///
/// [buckets] is a generic classification map (bucket name -> word list) so
/// the same "sort into the right lane" mechanic serves any classification
/// topic, not just grammar's noun/verb/adjective/pronoun.
class GrammarLevel {
  final int index;
  final String targetClass; // must be a key in [buckets]
  final String missionLabel; // e.g. "Collect only Nouns"
  final double scrollSpeed; // words per second across screen
  final Map<String, List<String>> buckets;

  const GrammarLevel({
    required this.index,
    required this.targetClass,
    required this.missionLabel,
    required this.scrollSpeed,
    required this.buckets,
  });
}

class RunnerCollectorConfig {
  final List<GrammarLevel> levels;
  final int heartsStart;

  const RunnerCollectorConfig({
    required this.levels,
    this.heartsStart = 3,
  });

  /// Builds config from a generated content pack (see
  /// tools/gamegen/content/runner_collector.js for the shape).
  factory RunnerCollectorConfig.fromPack(Map<String, dynamic> pack) {
    final levels = (pack['levels'] as List).cast<Map<String, dynamic>>();
    return RunnerCollectorConfig(
      levels: levels
          .asMap()
          .entries
          .map((entry) => GrammarLevel(
                index: entry.key,
                targetClass: entry.value['targetClass'] as String,
                missionLabel: entry.value['missionLabel'] as String,
                scrollSpeed: (entry.value['scrollSpeed'] as num).toDouble(),
                buckets: (entry.value['buckets'] as Map<String, dynamic>).map(
                  (key, value) => MapEntry(key, (value as List).cast<String>()),
                ),
              ))
          .toList(),
    );
  }

  static RunnerCollectorConfig grammarHero(GameConfig config) {
    return const RunnerCollectorConfig(
      heartsStart: 3,
      levels: [
        GrammarLevel(
          index: 0,
          targetClass: 'noun',
          missionLabel: 'Collect only Nouns! 📦',
          scrollSpeed: 0.08,
          buckets: {
            'noun': [
              'dog',
              'house',
              'school',
              'river',
              'table',
              'book',
              'city',
              'teacher'
            ],
            'verb': ['run', 'eat', 'jump', 'sleep', 'play', 'swim'],
            'adjective': ['happy', 'big', 'cold', 'fast', 'small'],
            'pronoun': ['he', 'she', 'they', 'it', 'we'],
          },
        ),
        GrammarLevel(
          index: 1,
          targetClass: 'verb',
          missionLabel: 'Collect only Verbs! 🏃',
          scrollSpeed: 0.10,
          buckets: {
            'noun': ['cat', 'road', 'cloud', 'flower', 'market'],
            'verb': [
              'sing',
              'write',
              'fly',
              'build',
              'cook',
              'throw',
              'learn',
              'drive'
            ],
            'adjective': ['red', 'quiet', 'tall', 'young'],
            'pronoun': ['you', 'him', 'her', 'us'],
          },
        ),
        GrammarLevel(
          index: 2,
          targetClass: 'adjective',
          missionLabel: 'Collect only Adjectives! ✨',
          scrollSpeed: 0.12,
          buckets: {
            'noun': ['sun', 'tree', 'train', 'door'],
            'verb': ['talk', 'draw', 'push', 'read'],
            'adjective': [
              'brave',
              'tiny',
              'warm',
              'dark',
              'bright',
              'loud',
              'soft',
              'long'
            ],
            'pronoun': ['mine', 'yours', 'theirs'],
          },
        ),
        GrammarLevel(
          index: 3,
          targetClass: 'pronoun',
          missionLabel: 'Collect only Pronouns! 👤',
          scrollSpeed: 0.13,
          buckets: {
            'noun': ['bag', 'lake', 'star', 'hill'],
            'verb': ['open', 'close', 'mix', 'lift'],
            'adjective': ['green', 'wet', 'dry', 'old'],
            'pronoun': [
              'I',
              'you',
              'he',
              'she',
              'we',
              'they',
              'it',
              'me',
              'him',
              'her'
            ],
          },
        ),
      ],
    );
  }
}
