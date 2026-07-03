import '../core/game_config.dart';

/// topicId/subtopicId -> questionType, mirroring
/// tools/gamegen/content/math.js's OP_BY_SUBTOPIC. Limited to operations
/// whose correct answer is always a non-negative integer, because
/// [TugOfWarKeypad] only has digits 0-9 (no decimal point or minus sign).
/// Topics not listed here (e.g. decimals, integers, and the non-arithmetic
/// "rapid recall" topics like phonics/spelling/debate) keep the
/// 'multiplication' default until the keypad supports those input shapes —
/// see docs/DEFERRED.md.
const Map<String, String> _questionTypeByTopic = {
  'operations/addition': 'addition',
  'operations/subtraction': 'subtraction',
  'multiplication/times_tables': 'multiplication',
  'division/long_division': 'division',
  'percentages/percentage_applications': 'percentage',
  'measurement/conversions': 'conversion',
  'economics/taxation': 'percentage',
};

/// TugOfWar-specific parameters stored inside [GameConfig.extras].
class TugOfWarConfig {
  final int multiplierMin;           // lowest multiplier in questions
  final int multiplierMax;           // highest multiplier
  final int winThreshold;            // score-lead needed to trigger early win
  final int fastAnswerThresholdSec;  // answer within this many seconds = bonus XP
  final String questionType;         // 'multiplication' | 'addition' | etc.
  final int opponentIntervalMs;      // base ms between opponent simulated answers
  final double opponentAccuracy;     // probability (0–1) that opponent is correct

  const TugOfWarConfig({
    this.multiplierMin = 2,
    this.multiplierMax = 9,
    this.winThreshold = 5,
    this.fastAnswerThresholdSec = 5,
    this.questionType = 'multiplication',
    this.opponentIntervalMs = 4000,
    this.opponentAccuracy = 0.70,
  });

  factory TugOfWarConfig.fromGameConfig(GameConfig config) {
    final d = config.difficulty;
    final defaultInterval = switch (d) {
      'easy'     => 6000,
      'hard'     => 2500,
      'adaptive' => 4000,
      _          => 4000,
    };
    final defaultAccuracy = switch (d) {
      'easy'     => 0.50,
      'hard'     => 0.85,
      'adaptive' => 0.70,
      _          => 0.70,
    };
    final defaultMax = switch (d) {
      'easy'     => 5,
      'hard'     => 12,
      'adaptive' => 9,
      _          => 9,
    };

    final e = config.extras;
    final topicKey = '${config.topicId}/${config.subtopicId}';
    final derivedType = _questionTypeByTopic[topicKey] ?? 'multiplication';
    return TugOfWarConfig(
      multiplierMin: e['multiplierMin'] as int? ?? 2,
      multiplierMax: e['multiplierMax'] as int? ?? defaultMax,
      winThreshold: e['winThreshold'] as int? ?? 5,
      fastAnswerThresholdSec: e['fastAnswerThresholdSec'] as int? ?? 5,
      questionType: e['questionType'] as String? ?? derivedType,
      opponentIntervalMs: e['opponentIntervalMs'] as int? ?? defaultInterval,
      opponentAccuracy:
          (e['opponentAccuracy'] as num?)?.toDouble() ?? defaultAccuracy,
    );
  }
}
