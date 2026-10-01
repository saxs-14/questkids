import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/data/services/game_level_progress_service.dart';

void main() {
  test('Grade 1 game progress defaults to level 1 of 10', () {
    final progress = GameLevelProgress.fromMap('math_g1_addition', null);

    expect(progress.currentLevel, 1);
    expect(progress.highestCompletedLevel, 0);
    expect(progress.bestScore, 0);
    expect(progress.completed, isFalse);
  });

  test('Grade 1 game progress clamps invalid stored values', () {
    final progress = GameLevelProgress.fromMap('math_g1_addition', {
      'currentLevel': 99,
      'highestCompletedLevel': -5,
      'bestScore': 500,
      'completed': true,
    });

    expect(progress.currentLevel, 10);
    expect(progress.highestCompletedLevel, 0);
    expect(progress.bestScore, 100);
    expect(progress.completed, isTrue);
  });
}
