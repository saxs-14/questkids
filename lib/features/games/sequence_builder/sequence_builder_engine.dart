import '../core/game_config.dart';
import '../core/game_engine.dart';
import 'sequence_builder_config.dart';

class SequenceBuilderEngine extends GameEngine {
  final SequenceBuilderConfig seqConfig;
  final GameConfig _config;

  SequenceBuilderEngine({required this.seqConfig, required GameConfig config})
      : _config = config;

  @override
  GameConfig get config => _config;

  @override
  List<Map<String, dynamic>> generateQuestions() =>
      List.generate(seqConfig.rounds, (i) => {'round': i});

  @override
  GameAnswerResult checkAnswer(
    Map<String, dynamic> question,
    dynamic answer, {
    int elapsedThresholdSeconds = 5,
  }) {
    final correct = answer == true;
    return GameAnswerResult(correct: correct, xpDelta: correct ? 25 : 0);
  }

  @override
  GameSessionResult buildResult({
    required int correct,
    required int total,
    required int timeTakenSeconds,
    bool earlyWin = false,
  }) =>
      defaultResult(
        correct: correct,
        total: total,
        timeTakenSeconds: timeTakenSeconds,
        earlyWin: earlyWin,
      );
}
