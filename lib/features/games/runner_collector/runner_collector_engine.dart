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
              'targetPOS': l.targetPOS,
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
        partOfSpeech: word['pos'] as String,
        lane: lane,
        xPosition: -(i * 0.25), // stagger spawning
      ));
    }
    return words;
  }

  List<Map<String, String>> _shuffleWords(GrammarLevel level) {
    final all = [
      ...level.nouns.map((w) => {'word': w, 'pos': 'noun'}),
      ...level.verbs.map((w) => {'word': w, 'pos': 'verb'}),
      ...level.adjectives.map((w) => {'word': w, 'pos': 'adjective'}),
      ...level.pronouns.map((w) => {'word': w, 'pos': 'pronoun'}),
    ];
    all.shuffle(_rng);
    return all;
  }

  /// A collection is correct if [wordPOS] matches the level's target(s).
  bool isCorrectCollection(String wordPOS, String targetPOS) {
    if (targetPOS == 'mixed') return wordPOS == 'noun' || wordPOS == 'verb';
    return wordPOS == targetPOS;
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
