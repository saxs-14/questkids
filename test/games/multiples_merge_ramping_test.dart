import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/features/games/core/game_config.dart';
import 'package:questkids/features/games/multiples_merge/multiples_merge_config.dart';
import 'package:questkids/features/games/multiples_merge/multiples_merge_engine.dart';

void main() {
  test('chain length ramps up across rounds within a session', () {
    const config = GameConfig(
      engineType: 'multiplesMerge',
      subject: 'Mathematics',
      grade: 'grade4',
      topicId: 'multiplication',
      subtopicId: 'times_tables',
      questionCount: 6,
    );
    final mergeConfig = MultiplesMergeConfig.forGrade(config);
    final engine = MultiplesMergeEngine(mergeConfig: mergeConfig, config: config);

    final firstRound =
        engine.buildRound(roundIndex: 0, totalRounds: config.questionCount);
    final lastRound = engine.buildRound(
        roundIndex: config.questionCount - 1,
        totalRounds: config.questionCount);

    expect(lastRound.chainLength, greaterThanOrEqualTo(firstRound.chainLength));
  });
}
