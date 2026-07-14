import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/features/games/core/game_config.dart';
import 'package:questkids/features/games/tug_of_war/tug_of_war_session.dart';

void main() {
  group('TugOfWar adaptive difficulty eases back down after a miss streak', () {
    test('opponent interval slows back toward the config default after 3 misses', () {
      const config = GameConfig(
        engineType: 'tugOfWar',
        subject: 'Mathematics',
        grade: 'grade4',
        topicId: 'multiplication',
        subtopicId: 'times_tables',
        difficulty: 'adaptive',
      );
      final session = TugOfWarSession(config, 'test-uid');

      // Force 3 wrong answers in a row (submitAnswer takes the raw answer
      // directly -- the keypad's appendDigit is separate UI-only state).
      for (var i = 0; i < 3; i++) {
        session.submitAnswer('999999'); // near-certainly wrong
      }

      expect(session.currentOpponentIntervalMs,
          greaterThanOrEqualTo(session.tugConfig.opponentIntervalMs));
      session.dispose();
    });
  });
}
