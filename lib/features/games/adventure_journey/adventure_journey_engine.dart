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

  @override
  List<Map<String, dynamic>> generateQuestions() {
    return journeyConfig.stages
        .map((s) => {
              'stageId': s.id,
              'stageName': s.name,
              'question': s.question,
              'options': s.options,
              'answer': s.correctOption,
              'correctFeedback': s.correctFeedback,
              'wrongFeedback': s.wrongFeedback,
              'display': s.question,
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
    bool earlyWin = false,
  }) {
    final isPerfect = correct == total;
    final accuracy = total > 0 ? correct / total : 0.0;
    final score = (accuracy * 100).round();
    int xp = correct * 10;
    if (isPerfect) xp += 100; // "Science Star" bonus

    return GameSessionResult(
      result: isPerfect ? 'complete' : (correct > total ~/ 2 ? 'win' : 'loss'),
      score: score,
      xpEarned: xp,
      coinsEarned: xp ~/ 10,
      accuracy: accuracy,
    );
  }
}
