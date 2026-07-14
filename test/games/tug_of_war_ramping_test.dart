import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/features/games/core/game_config.dart';
import 'package:questkids/features/games/tug_of_war/tug_of_war_config.dart';
import 'package:questkids/features/games/tug_of_war/tug_of_war_engine.dart';

void main() {
  test('later questions in a tugOfWar session use a wider multiplier range', () {
    const config = GameConfig(
      engineType: 'tugOfWar',
      subject: 'Mathematics',
      grade: 'grade4',
      topicId: 'multiplication',
      subtopicId: 'times_tables',
      questionCount: 12,
      extras: {'multiplierMin': 2, 'multiplierMax': 12},
    );
    final tugConfig = TugOfWarConfig.fromGameConfig(config);
    final engine = TugOfWarEngine(tugConfig: tugConfig, config: config);
    final questions = engine.generateQuestions();

    final firstThirdMax = questions
        .take(4)
        .map((q) => [q['a'] as int, q['b'] as int].reduce((a, b) => a > b ? a : b))
        .reduce((a, b) => a > b ? a : b);
    final lastThirdMax = questions
        .skip(8)
        .map((q) => [q['a'] as int, q['b'] as int].reduce((a, b) => a > b ? a : b))
        .reduce((a, b) => a > b ? a : b);

    expect(lastThirdMax, greaterThanOrEqualTo(firstThirdMax));
  });
}
