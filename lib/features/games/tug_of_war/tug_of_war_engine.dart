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
        case 'percentage':
          // Answers must stay non-negative integers — the keypad has no
          // decimal point — so pick a percentage/base pair that divides
          // evenly.
          const pcts = [10, 20, 25, 50, 75];
          final pct = pcts[a % pcts.length];
          final base = (b + 1) * 20;
          final answer = (pct * base) ~/ 100;
          out.add({
            'a': pct,
            'b': base,
            'answer': answer,
            'display': 'What is $pct% of R$base?',
            'type': type,
          });
        case 'conversion':
          const factors = [100, 1000, 60];
          const units = [
            ['m', 'cm'],
            ['km', 'm'],
            ['h', 'min']
          ];
          final idx = a % factors.length;
          final value = (b % 20) + 1;
          final answer = value * factors[idx];
          out.add({
            'a': value,
            'b': factors[idx],
            'answer': answer,
            'display': '$value ${units[idx][0]} = ? ${units[idx][1]}',
            'type': type,
          });
        case 'decimal':
          // Reuse the dedup-checked a/b pair (declared above the switch)
          // rather than drawing fresh random numbers here -- keeps the
          // `used` set's a×b key meaningful for this case too, matching
          // every other case's pattern. Format `a` as a one-decimal-place
          // value using b's last digit as the tenths; keep the second
          // operand a small plain integer so results fit the keypad's
          // 6-character cap (Task 1), e.g. "83.4".
          final decimal = a + (b % 10) / 10;
          final addend = 1 + (b % 20);
          final isAddDecimal = _rng.nextBool();
          final decimalAnswer =
              isAddDecimal ? decimal + addend : decimal - addend;
          out.add({
            'a': decimal,
            'b': addend,
            'answer': double.parse(decimalAnswer.toStringAsFixed(1)),
            'display': '$decimal ${isAddDecimal ? '+' : '-'} $addend = ?',
            'type': type,
          });
        case 'integer':
          // Reuse the dedup-checked a/b pair for magnitude; only the sign
          // and operation are freshly randomized, so results can land
          // negative -- exercising the ± keypad toggle from Task 1, not
          // just addition of positives.
          final signedA = _rng.nextBool() ? a : -a;
          final signedB = _rng.nextBool() ? b : -b;
          final isAddInt = _rng.nextBool();
          out.add({
            'a': signedA,
            'b': signedB,
            'answer': isAddInt ? signedA + signedB : signedA - signedB,
            'display': isAddInt
                ? '($signedA) + ($signedB) = ?'
                : '($signedA) - ($signedB) = ?',
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
    final expected = question['answer'] as num;
    final submitted = answer is num ? answer : num.tryParse(answer.toString());
    final correct = submitted != null && (expected - submitted).abs() < 0.001;
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
    required int xpFromAnswers,
    bool earlyWin = false,
  }) {
    return defaultResult(
      correct: correct,
      total: total,
      timeTakenSeconds: timeTakenSeconds,
      xpFromAnswers: xpFromAnswers,
      earlyWin: earlyWin,
    );
  }
}
