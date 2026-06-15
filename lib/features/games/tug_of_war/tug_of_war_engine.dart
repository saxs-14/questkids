import 'dart:math';

import '../core/game_config.dart';
import '../core/game_engine.dart';
import 'tug_of_war_config.dart';

class TugOfWarEngine extends GameEngine {
  final TugOfWarConfig tugConfig;
  final GameConfig _config;
  final Random _rng = Random();

  TugOfWarEngine({required this.tugConfig, required GameConfig config})
      : _config = config;

  @override
  GameConfig get config => _config;

  @override
  List<Map<String, dynamic>> generateQuestions() {
    final min = tugConfig.multiplierMin;
    final max = tugConfig.multiplierMax;
    final count = config.questionCount;
    final type = tugConfig.questionType;

    final Set<String> used = {};
    final List<Map<String, dynamic>> out = [];
    int attempts = 0;

    while (out.length < count && attempts < 2000) {
      attempts++;
      final a = min + _rng.nextInt(max - min + 1);
      final b = min + _rng.nextInt(max - min + 1);
      final key = '$a×$b';
      if (used.contains(key)) continue;
      used.add(key);

      switch (type) {
        case 'multiplication':
          out.add({
            'a': a,
            'b': b,
            'answer': a * b,
            'display': '$a × $b = ?',
            'type': type,
          });
        case 'addition':
          out.add({
            'a': a,
            'b': b,
            'answer': a + b,
            'display': '$a + $b = ?',
            'type': type,
          });
        case 'subtraction':
          final bigger = a > b ? a : b;
          final smaller = a > b ? b : a;
          out.add({
            'a': bigger,
            'b': smaller,
            'answer': bigger - smaller,
            'display': '$bigger - $smaller = ?',
            'type': type,
          });
        case 'division':
          final product = a * b;
          out.add({
            'a': product,
            'b': a,
            'answer': b,
            'display': '$product ÷ $a = ?',
            'type': type,
          });
        default:
          out.add({
            'a': a,
            'b': b,
            'answer': a * b,
            'display': '$a × $b = ?',
            'type': 'multiplication',
          });
      }
    }
    return out;
  }

  @override
  GameAnswerResult checkAnswer(
    Map<String, dynamic> question,
    dynamic answer, {
    int elapsedThresholdSeconds = 5,
  }) {
    final expected = question['answer'] as int;
    final submitted = answer is int ? answer : int.tryParse(answer.toString());
    final correct = submitted != null && submitted == expected;
    final isBonus =
        correct && elapsedThresholdSeconds <= tugConfig.fastAnswerThresholdSec;
    return GameAnswerResult(
      correct: correct,
      xpDelta: correct ? (10 + (isBonus ? 5 : 0)) : 0,
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
    return defaultResult(
      correct: correct,
      total: total,
      timeTakenSeconds: timeTakenSeconds,
      earlyWin: earlyWin,
    );
  }
}
