import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/core/constants/app_constants.dart';
import 'package:questkids/core/constants/game_catalog.dart';
import 'package:questkids/features/games/adventure_journey/adventure_journey_config.dart';
import 'package:questkids/features/games/adventure_journey/adventure_journey_engine.dart';
import 'package:questkids/features/games/budget_builder/budget_builder_engine.dart';
import 'package:questkids/features/games/circuit_builder/circuit_builder_engine.dart';
import 'package:questkids/features/games/core/game_config.dart';
import 'package:questkids/features/games/core/game_engine.dart';
import 'package:questkids/features/games/explorer_map/explorer_map_config.dart';
import 'package:questkids/features/games/explorer_map/explorer_map_engine.dart';
import 'package:questkids/features/games/multiples_merge/multiples_merge_config.dart';
import 'package:questkids/features/games/multiples_merge/multiples_merge_engine.dart';
import 'package:questkids/features/games/runner_collector/runner_collector_config.dart';
import 'package:questkids/features/games/runner_collector/runner_collector_engine.dart';
import 'package:questkids/features/games/sequence_builder/sequence_builder_config.dart';
import 'package:questkids/features/games/sequence_builder/sequence_builder_engine.dart';
import 'package:questkids/features/games/tug_of_war/tug_of_war_config.dart';
import 'package:questkids/features/games/tug_of_war/tug_of_war_engine.dart';

/// Exercises EVERY catalog entry end-to-end: loads its content pack,
/// instantiates its engine, generates questions, simulates a correct
/// answer, a wrong answer, and a completed session — asserting no
/// exceptions and sane score/XP output. This is the mandatory
/// per-topic functionality gate (CLAUDE.md gamegen Phase D §1).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final entry in GameCatalog.all) {
    test(
        '${entry.id} (${entry.engineType}) plays a full round without exceptions',
        () async {
      final config = GameConfig.fromCatalogEntry(entry);

      // numberCountingDuel's single catalog entry is a fully self-contained
      // widget with no GameConfig-driven engine layer (see GameRouter) — its
      // pack exists for theming/schema completeness only. Widget coverage
      // for it is in game_router_widget_test.dart instead.
      if (entry.engineType == AppConstants.engineNumberCountingDuel) {
        final path = config.contentPackPath;
        expect(path, isNotNull);
        final raw = await rootBundle.loadString(path!);
        expect(jsonDecode(raw), isA<Map<String, dynamic>>());
        return;
      }

      final path = config.contentPackPath;
      expect(path, isNotNull,
          reason: '${entry.id} has no catalogId-derived content pack path');
      final raw = await rootBundle.loadString(path!);
      final pack = jsonDecode(raw) as Map<String, dynamic>;

      final engine = _buildEngine(entry.engineType, config, pack);
      final questions = engine.generateQuestions();
      expect(questions, isNotEmpty,
          reason: '${entry.id} produced no questions');

      final firstQuestion = questions.first;
      final correctAnswer = _correctAnswerFor(entry.engineType, firstQuestion);
      final correctResult = engine.checkAnswer(firstQuestion, correctAnswer,
          elapsedThresholdSeconds: 1);
      expect(correctResult.correct, isTrue,
          reason:
              '${entry.id}: engine.checkAnswer rejected the answer it says is correct');
      expect(correctResult.xpDelta, greaterThanOrEqualTo(0));

      final wrongAnswer = _wrongAnswerFor(entry.engineType, firstQuestion);
      final wrongResult = engine.checkAnswer(firstQuestion, wrongAnswer,
          elapsedThresholdSeconds: 20);
      expect(wrongResult.correct, isFalse,
          reason:
              '${entry.id}: engine.checkAnswer accepted a deliberately wrong answer');

      final total = questions.length;
      final completeResult = engine.buildResult(
          correct: total,
          total: total,
          timeTakenSeconds: 30,
          xpFromAnswers: correctResult.xpDelta * total);
      expect(completeResult.score, inInclusiveRange(0, 100));
      expect(completeResult.xpEarned, greaterThanOrEqualTo(0));
      expect(completeResult.coinsEarned, greaterThanOrEqualTo(0));
      expect(completeResult.accuracy, inInclusiveRange(0.0, 1.0));

      final lossResult = engine.buildResult(
          correct: 0, total: total, timeTakenSeconds: 30, xpFromAnswers: 0);
      expect(lossResult.score, inInclusiveRange(0, 100));
    });
  }
}

GameEngine _buildEngine(
    String engineType, GameConfig config, Map<String, dynamic> pack) {
  switch (engineType) {
    case AppConstants.engineTugOfWar:
      return TugOfWarEngine(
          tugConfig: TugOfWarConfig.fromGameConfig(config), config: config);
    case AppConstants.engineAdventureJourney:
      return AdventureJourneyEngine(
          journeyConfig: AdventureJourneyConfig.fromPack(pack), config: config);
    case AppConstants.engineRunnerCollector:
      return RunnerCollectorEngine(
          runnerConfig: RunnerCollectorConfig.fromPack(pack), config: config);
    case AppConstants.engineExplorerMap:
      return ExplorerMapEngine(
          mapConfig: ExplorerMapConfig.fromPack(pack), config: config);
    case AppConstants.engineSequenceBuilder:
      return SequenceBuilderEngine(
          seqConfig: SequenceBuilderConfig.fromPack(pack), config: config);
    case AppConstants.engineCircuitBuilder:
      return CircuitBuilderEngine(config,
          circuits: (pack['circuits'] as List).cast<Map<String, dynamic>>());
    case AppConstants.engineBudgetBuilder:
      return BudgetBuilderEngine(config,
          scenarios: (pack['scenarios'] as List).cast<Map<String, dynamic>>());
    case AppConstants.engineMultiplesMerge:
      return MultiplesMergeEngine(
          mergeConfig: MultiplesMergeConfig.fromPack(pack, config),
          config: config);
    default:
      throw StateError(
          'all_topics_smoke_test: no engine builder for "$engineType"');
  }
}

dynamic _correctAnswerFor(String engineType, Map<String, dynamic> question) {
  switch (engineType) {
    case AppConstants.engineTugOfWar:
      return question['answer'];
    case AppConstants.engineAdventureJourney:
      return question['answer'];
    case AppConstants.engineExplorerMap:
      return question['correctId'];
    case AppConstants.engineSequenceBuilder:
    case AppConstants.engineMultiplesMerge:
      return true;
    case AppConstants.engineRunnerCollector:
      return true; // RunnerCollectorEngine.checkAnswer is a passthrough (see class doc)
    case AppConstants.engineCircuitBuilder:
      final blanks = (question['blanks'] as List).cast<Map<String, dynamic>>();
      return blanks.map((b) => b['correctComponent'] as String).toList();
    case AppConstants.engineBudgetBuilder:
      final items = (question['items'] as List).cast<Map<String, dynamic>>();
      return {
        for (final item in items)
          item['name'] as String: item['category'] as String
      };
    default:
      throw StateError(
          'all_topics_smoke_test: no correct-answer builder for "$engineType"');
  }
}

dynamic _wrongAnswerFor(String engineType, Map<String, dynamic> question) {
  switch (engineType) {
    case AppConstants.engineTugOfWar:
      return (question['answer'] as num) + 999999;
    case AppConstants.engineAdventureJourney:
      final options = (question['options'] as List).cast<String>();
      return options.firstWhere((o) => o != question['answer'],
          orElse: () => '__wrong__');
    case AppConstants.engineExplorerMap:
      return '__not_a_real_id__';
    case AppConstants.engineSequenceBuilder:
    case AppConstants.engineMultiplesMerge:
      return false;
    case AppConstants.engineRunnerCollector:
      return false;
    case AppConstants.engineCircuitBuilder:
      final blanks = (question['blanks'] as List).cast<Map<String, dynamic>>();
      return List.generate(blanks.length, (_) => '__wrong_component__');
    case AppConstants.engineBudgetBuilder:
      final items = (question['items'] as List).cast<Map<String, dynamic>>();
      return {
        for (final item in items) item['name'] as String: '__wrong_category__'
      };
    default:
      throw StateError(
          'all_topics_smoke_test: no wrong-answer builder for "$engineType"');
  }
}
