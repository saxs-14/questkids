import '../core/game_config.dart';
import '../core/game_engine.dart';
import 'explorer_map_config.dart';

class ExplorerMapEngine extends GameEngine {
  final ExplorerMapConfig mapConfig;
  final GameConfig _config;

  ExplorerMapEngine({required this.mapConfig, required GameConfig config})
      : _config = config;

  @override
  GameConfig get config => _config;

  @override
  List<Map<String, dynamic>> generateQuestions() {
    return mapConfig.questions
        .map((q) => {
              'question': q.question,
              'correctId': q.correctId,
              'optionIds': q.optionIds,
              'feedbackFact': q.feedbackFact,
            })
        .toList();
  }

  @override
  GameAnswerResult checkAnswer(
    Map<String, dynamic> question,
    dynamic answer, {
    int elapsedThresholdSeconds = 0,
  }) {
    final correct = answer == question['correctId'];
    final isBonus = correct && elapsedThresholdSeconds <= 5;
    return GameAnswerResult(
      correct: correct,
      xpDelta: correct ? (isBonus ? 15 : 10) : 0,
      isBonus: isBonus,
    );
  }

  @override
  GameSessionResult buildResult({
    required int correct,
    required int total,
    required int timeTakenSeconds,
    bool earlyWin = false,
  }) {
    final base = defaultResult(
      correct: correct,
      total: total,
      timeTakenSeconds: timeTakenSeconds,
    );
    if (correct == total) {
      return GameSessionResult(
        result: 'complete',
        score: base.score,
        xpEarned: base.xpEarned + 100,
        coinsEarned: base.coinsEarned + 10,
        accuracy: base.accuracy,
      );
    }
    return base;
  }

  ProvincePin? getProvince(String id) {
    try {
      return mapConfig.provinces.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }
}
