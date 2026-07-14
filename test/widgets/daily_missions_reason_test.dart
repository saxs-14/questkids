import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/data/models/daily_mission_model.dart';

void main() {
  test('an adaptive mission with a reason prefers the reason over the generic badge', () {
    const mission = DailyMission(
      id: 'adaptive_math_g4_timestable_1',
      gameId: 'math_g4_timestable',
      title: 'Times Table Tower',
      subject: 'Mathematics',
      emoji: '🏗️',
      xpBonus: 15,
      completed: false,
      source: 'adaptive',
      reason: "Because you're working on Mathematics",
    );
    final displayText =
        mission.source == 'adaptive' && mission.reason != null
            ? mission.reason!
            : mission.sourceBadge;
    expect(displayText, "Because you're working on Mathematics");
  });

  test('a curated mission with no reason falls back to the generic badge', () {
    const mission = DailyMission(
      id: 'curated_math_g4_timestable_1',
      gameId: 'math_g4_timestable',
      title: 'Times Table Tower',
      subject: 'Mathematics',
      emoji: '🏗️',
      xpBonus: 10,
      completed: false,
      source: 'curated',
    );
    final displayText =
        mission.source == 'adaptive' && mission.reason != null
            ? mission.reason!
            : mission.sourceBadge;
    expect(displayText, '⭐ Daily');
  });
}
