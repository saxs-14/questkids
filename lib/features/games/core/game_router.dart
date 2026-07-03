import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../adventure_journey/adventure_journey_game.dart';
import '../budget_builder/budget_builder_game.dart';
import '../circuit_builder/circuit_builder_game.dart';
import '../explorer_map/province_explorer.dart';
import '../multiples_merge/multiples_merge_game.dart';
import '../number_counting_duel/number_counting_duel_game.dart';
import '../runner_collector/grammar_hero_run.dart';
import '../sequence_builder/sequence_builder_game.dart';
import '../tug_of_war/tug_of_war_game.dart';
import 'game_config.dart';

/// Routes a [GameConfig] to the correct engine widget.
///
/// Navigation entry point for all games:
///   Navigator.of(context).push(MaterialPageRoute(
///     builder: (_) => GameRouter(config: config, user: user),
///   ));
///
/// UI widgets inside each engine must NOT reference this router — the
/// layering is one-way: GameRouter → EngineGame → EngineSession → GameEngine.
class GameRouter extends StatelessWidget {
  final GameConfig config;
  final dynamic user;

  const GameRouter({super.key, required this.config, required this.user});

  @override
  Widget build(BuildContext context) {
    return switch (config.engineType) {
      AppConstants.engineTugOfWar => TugOfWarGame(config: config, user: user),
      AppConstants.engineAdventureJourney =>
        AdventureJourneyGame(config: config, user: user),
      AppConstants.engineRunnerCollector =>
        GrammarHeroRun(config: config, user: user),
      AppConstants.engineExplorerMap =>
        ProvinceExplorer(config: config, user: user),
      AppConstants.engineMultiplesMerge =>
        MultiplesMergeGame(config: config, user: user),
      AppConstants.engineSequenceBuilder =>
        SequenceBuilderGame(config: config, user: user),
      AppConstants.engineCircuitBuilder =>
        CircuitBuilderGame(config: config, user: user),
      AppConstants.engineBudgetBuilder =>
        BudgetBuilderGame(config: config, user: user),
      AppConstants.engineNumberCountingDuel =>
        NumberCountingDuelGame(user: user),
      _ => _UnknownEngine(config: config),
    };
  }
}

class _UnknownEngine extends StatelessWidget {
  final GameConfig config;
  const _UnknownEngine({required this.config});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Unknown Engine')),
      body: Center(
        child: Text(
          'No engine registered for: ${config.engineType}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}
