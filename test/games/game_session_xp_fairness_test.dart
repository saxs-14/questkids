import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/features/games/core/game_config.dart';
import 'package:questkids/features/games/tug_of_war/tug_of_war_engine.dart';
import 'package:questkids/features/games/tug_of_war/tug_of_war_config.dart';
import 'package:questkids/features/games/explorer_map/explorer_map_engine.dart';
import 'package:questkids/features/games/explorer_map/explorer_map_config.dart';
import 'package:questkids/features/games/adventure_journey/adventure_journey_engine.dart';
import 'package:questkids/features/games/adventure_journey/adventure_journey_config.dart';

void main() {
  group('Session XP now reflects real per-question xpDelta', () {
    test('tug_of_war: 3 correct with 1 fast-bonus sums real xpDelta, not correct*10', () {
      const config = GameConfig(
        engineType: 'tugOfWar',
        subject: 'Mathematics',
        grade: 'grade4',
        topicId: 'multiplication',
        subtopicId: 'times_tables',
      );
      final tugConfig = TugOfWarConfig.fromGameConfig(config);
      final engine = TugOfWarEngine(tugConfig: tugConfig, config: config);
      // 2 plain-correct (10 each) + 1 fast-bonus correct (15) = 35, not 3*10=30.
      final result = engine.buildResult(
        correct: 3,
        total: 3,
        timeTakenSeconds: 30,
        xpFromAnswers: 35,
      );
      expect(result.xpEarned, 35 + 100); // + perfect-run bonus
    });

    test('explorer_map perfect run no longer double-applies the +100/+10 bonus', () {
      const config = GameConfig(
        engineType: 'explorerMap',
        subject: 'Social Sciences',
        grade: 'grade4',
        topicId: 'geography_sa',
        subtopicId: 'provinces',
      );
      final engine = ExplorerMapEngine(
        mapConfig: ExplorerMapConfig.saProvinces(config),
        config: config,
      );
      final result = engine.buildResult(
        correct: 4,
        total: 4,
        timeTakenSeconds: 20,
        xpFromAnswers: 40,
      );
      // Old buggy behaviour would have been 40 + 100 + 100 = 240.
      expect(result.xpEarned, 40 + 100);
      expect(result.coinsEarned, (40 + 100) ~/ 10);
    });

    test('adventure_journey now grants the win (+50) tier like other engines', () {
      const config = GameConfig(
        engineType: 'adventureJourney',
        subject: 'Natural Sciences',
        grade: 'grade4',
        topicId: 'water_cycle',
        subtopicId: 'evaporation_condensation',
      );
      final engine = AdventureJourneyEngine(
        journeyConfig: AdventureJourneyConfig.waterCycle(config),
        config: config,
      );
      // 3 of 4 correct: a win, not perfect -- old custom formula granted 0 bonus.
      final result = engine.buildResult(
        correct: 3,
        total: 4,
        timeTakenSeconds: 40,
        xpFromAnswers: 30,
      );
      expect(result.xpEarned, 30 + 50);
      expect(result.result, 'win');
    });
  });
}
