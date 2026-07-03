import 'dart:math';

import '../core/game_config.dart';
import '../core/game_engine.dart';
import 'runner_collector_config.dart';

class RunnerCollectorEngine extends GameEngine {
  final RunnerCollectorConfig runnerConfig;
  final GameConfig _config;
  final Random _rng = Random();

  RunnerCollectorEngine({
    required this.runnerConfig,
    required GameConfig config,
  }) : _config = config;

  @override
  GameConfig get config => _config;

  /// Returns a stream of word cards for the given level —
  /// called on demand by the session, not pre-generated.
  @override
  List<Map<String, dynamic>> generateQuestions() {
    // Runner uses dynamic word spawning; return the level descriptors.
    return runnerConfig.levels
        .map((l) => {
              'levelIndex': l.index,
              'targetClass': l.targetClass,
              'missionLabel': l.missionLabel,
              'scrollSpeed': l.scrollSpeed,
            })
        .toList();
  }

  /// Spawn a batch of [LaneWord]s for a given level, spread across 3 lanes.
  List<LaneWord> spawnWords(GrammarLevel level, {int count = 6}) {
    final words = <LaneWord>[];
    final allWords = _shuffleWords(level);

    final usedLanes = <int>[];
    for (int i = 0; i < count.clamp(0, allWords.length); i++) {
      final word = allWords[i];
      int lane;
      do {
        lane = _rng.nextInt(3);
      } while (usedLanes.length < 3 && usedLanes.contains(lane));
      usedLanes.add(lane);
      if (usedLanes.length >= 3) usedLanes.clear();

      words.add(LaneWord(
        word: word['word'] as String,
        wordClass: word['wordClass'] as String,
        lane: lane,
        xPosition: -(i * 0.25), // stagger spawning
      ));
    }
    return words;
  }

  /// A single random {word, wordClass} for [level]. With probability
  /// [targetBias] the word is guaranteed to match the level's target class,
  /// so a learner can always find collectables and make progress.
  Map<String, String> randomWord(GrammarLevel level, {double targetBias = 0.5}) {
    final all = _shuffleWords(level);
    if (_rng.nextDouble() < targetBias) {
      final matches = all
          .where((w) => isCorrectCollection(w['wordClass'] as String, level.targetClass))
          .toList();
      if (matches.isNotEmpty) return matches[_rng.nextInt(matches.length)];
    }
    return all[_rng.nextInt(all.length)];
  }

  List<Map<String, String>> _shuffleWords(GrammarLevel level) {
    final all = <Map<String, String>>[
      for (final entry in level.buckets.entries)
        for (final word in entry.value) {'word': word, 'wordClass': entry.key},
    ];
    all.shuffle(_rng);
    return all;
  }

  /// A collection is correct if [wordClass] matches the level's target.
  bool isCorrectCollection(String wordClass, String targetClass) {
    return wordClass == targetClass;
  }

  @override
  GameAnswerResult checkAnswer(
    Map<String, dynamic> question,
    dynamic answer, {
    int elapsedThresholdSeconds = 0,
  }) {
    // Runner uses isCorrectCollection directly; this satisfies the interface.
    final correct = answer == true;
    return GameAnswerResult(
      correct: correct,
      xpDelta: correct ? 10 : 0,
    );
  }

  @override
  GameSessionResult buildResult({
    required int correct,
    required int total,
    required int timeTakenSeconds,
    bool earlyWin = false,
  }) {
    return defaultResult(
      correct: correct,
      total: total,
      timeTakenSeconds: timeTakenSeconds,
      earlyWin: earlyWin,
    );
  }
}
