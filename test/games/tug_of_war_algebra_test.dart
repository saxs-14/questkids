import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/features/games/core/game_config.dart';
import 'package:questkids/features/games/tug_of_war/tug_of_war_config.dart';
import 'package:questkids/features/games/tug_of_war/tug_of_war_engine.dart';

void main() {
  test('algebra/linear_equations topic generates solve-for-x questions, not multiplication', () {
    const config = GameConfig(
      engineType: 'tugOfWar',
      subject: 'Mathematics',
      grade: 'grade7',
      topicId: 'algebra',
      subtopicId: 'linear_equations',
    );
    final tugConfig = TugOfWarConfig.fromGameConfig(config);
    expect(tugConfig.questionType, 'algebra');

    final engine = TugOfWarEngine(tugConfig: tugConfig, config: config);
    final questions = engine.generateQuestions();
    expect(questions, isNotEmpty);
    for (final q in questions) {
      expect(q['type'], 'algebra');
      // ax + b = c form: verify the stored answer actually solves the
      // stored a/b/c, i.e. a*answer + b == c.
      final a = q['coeffA'] as int;
      final b = q['coeffB'] as int;
      final c = q['coeffC'] as int;
      final answer = q['answer'] as int;
      expect(a * answer + b, c);
    }
  });
}
