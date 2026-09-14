import 'dart:math';
import '../core/game_config.dart';
import '../core/game_engine.dart';
import 'adventure_journey_config.dart';

class AdventureJourneyEngine extends GameEngine {
  final AdventureJourneyConfig journeyConfig;
  final GameConfig _config;

  AdventureJourneyEngine({
    required this.journeyConfig,
    required GameConfig config,
  }) : _config = config;

  @override
  GameConfig get config => _config;

  final Random _rng = Random();

  @override
  List<Map<String, dynamic>> generateQuestions() {
    // Content packs are authored with more stages than one session shows
    // (10-15 per topic, see tools/gamegen/tiers.js) specifically so
    // replays can vary -- but mapping every stage in its authored order
    // meant every playthrough showed the identical question set in the
    // identical order, with only each question's own option order ever
    // randomized. Shuffle first, then cap at questionCount: packs with a
    // surplus get genuine question-selection variety, packs sized exactly
    // to questionCount still get order variety.
    final shuffledStages = List.of(journeyConfig.stages)..shuffle(_rng);
    final selected = shuffledStages.take(_config.questionCount);
    return selected
        .map((s) {
          final shuffledOptions = List<String>.from(s.options)..shuffle(_rng);
          return {
            'stageId': s.id,
            'stageName': s.name,
            'question': s.question,
            'options': shuffledOptions,
            'answer': s.correctOption,
            'correctFeedback': s.correctFeedback,
            'wrongFeedback': s.wrongFeedback,
            'display': s.question,
          };
        })
        .toList();
  }

  @override
  GameAnswerResult checkAnswer(
    Map<String, dynamic> question,
    dynamic answer, {
    int elapsedThresholdSeconds = 10,
  }) {
    final correct = answer.toString() == question['answer'].toString();
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
    required int xpFromAnswers,
    bool earlyWin = false,
  }) =>
      defaultResult(
        correct: correct,
        total: total,
        timeTakenSeconds: timeTakenSeconds,
        xpFromAnswers: xpFromAnswers,
        earlyWin: earlyWin,
      );
}
