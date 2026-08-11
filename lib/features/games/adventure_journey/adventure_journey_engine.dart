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
    return journeyConfig.stages
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
