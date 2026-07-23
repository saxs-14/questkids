import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../addition_adventure/addition_adventure_game.dart';
import '../adventure_journey/adventure_journey_game.dart';
import '../alphabet_explorer/alphabet_explorer_game.dart';
import '../ancient_civilizations/ancient_civilizations_game.dart';
import '../budget_builder/budget_builder_game.dart';
import '../career_explorer/career_explorer_game.dart';
import '../circuit_builder/circuit_builder_game.dart';
import '../circuit_lab/circuit_lab_game.dart';
import '../climate_quest/climate_quest_game.dart';
import '../coding_adventure/coding_adventure_game.dart';
import '../colonial_era/colonial_era_game.dart';
import '../data_city/data_city_game.dart';
import '../debate_duel/debate_duel_game.dart';
import '../decimal_dunes/decimal_dunes_game.dart';
import '../democracy_game/democracy_game.dart';
import '../division_desert/division_desert_game.dart';
import '../ecosystem_explorer/ecosystem_explorer_game.dart';
import '../ecosystems/ecosystems_game.dart';
import '../energy_quest/energy_quest_game.dart';
import '../environmental_awareness/environmental_awareness_game.dart';
import '../explorer_map/province_explorer.dart';
import '../financial_literacy/financial_literacy_game.dart';
import '../fraction_forest/fraction_forest_game.dart';
import '../geometry_jungle/geometry_jungle_game.dart';
import '../grammar_garden/grammar_garden_game.dart';
import '../healthy_living/healthy_living_game.dart';
import '../idiom_island/idiom_island_game.dart';
import '../liberation_heroes/liberation_heroes_game.dart';
import '../life_cycles/life_cycles_game.dart';
import '../map_master/map_master_game.dart';
import '../maths_mountain/maths_mountain_game.dart';
import '../matter_master/matter_master_game.dart';
import '../measurement_valley/measurement_valley_game.dart';
import '../multiple_chain/multiple_chain_game.dart';
import '../multiples_merge/multiples_merge_game.dart';
import '../multiplication_mountains/multiplication_mountains_game.dart';
import '../noun_navigator/noun_navigator_game.dart';
import '../number_counting_duel/number_counting_duel_game.dart';
import '../number_ninja/number_ninja_game.dart';
import '../phonics_fun/phonics_fun_game.dart';
import '../poetry_explorer/poetry_explorer_game.dart';
import '../problem_solver/problem_solver_game.dart';
import '../punctuation_police/punctuation_police_game.dart';
import '../reading_quest/reading_quest_game.dart';
import '../reading_rainbow/reading_rainbow_game.dart';
import '../robot_maker/robot_maker_game.dart';
import '../runner_collector/grammar_hero_run.dart';
import '../sa_history/sa_history_game.dart';
import '../sa_provinces_explorer/sa_provinces_explorer_game.dart';
import '../sequence_builder/sequence_builder_game.dart';
import '../simple_machines/simple_machines_game.dart';
import '../social_skills/social_skills_game.dart';
import '../solar_system/solar_system_game.dart';
import '../spelling_bee/spelling_bee_game.dart';
import '../story_builder/story_builder_game.dart';
import '../subtraction_safari/subtraction_safari_game.dart';
import '../times_table_tower/times_table_tower_game.dart';
import '../tug_of_war/tug_of_war_game.dart';
import '../verb_volcano/verb_volcano_game.dart';
import '../water_cycle/water_cycle_game.dart';
import '../weather_watcher/weather_watcher_game.dart';
import '../word_builder/word_builder_game.dart';
import '../word_power/word_power_game.dart';
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
        NumberCountingDuelGame(config: config, user: user),
      AppConstants.engineAdditionAdventure =>
        AdditionAdventureGame(config: config, user: user),
      AppConstants.engineSubtractionSafari =>
        SubtractionSafariGame(config: config, user: user),
      AppConstants.engineMathsMountain =>
        MathsMountainGame(config: config, user: user),
      AppConstants.engineMultipleChain =>
        MultipleChainGame(config: config, user: user),
      AppConstants.engineAlphabetExplorer =>
        AlphabetExplorerGame(config: config, user: user),
      AppConstants.engineWordBuilder =>
        WordBuilderGame(config: config, user: user),
      AppConstants.enginePhonicsFun =>
        PhonicsFunGame(config: config, user: user),
      AppConstants.engineReadingRainbow =>
        ReadingRainbowGame(config: config, user: user),
      AppConstants.engineGrammarGarden =>
        GrammarGardenGame(config: config, user: user),
      AppConstants.engineFractionForest =>
        FractionForestGame(config: config, user: user),
      AppConstants.engineGeometryJungle =>
        GeometryJungleGame(config: config, user: user),
      AppConstants.engineMeasurementValley =>
        MeasurementValleyGame(config: config, user: user),
      AppConstants.engineDataCity => DataCityGame(config: config, user: user),
      AppConstants.engineDecimalDunes =>
        DecimalDunesGame(config: config, user: user),
      AppConstants.engineMultiplicationMountains =>
        MultiplicationMountainsGame(config: config, user: user),
      AppConstants.engineDivisionDesert =>
        DivisionDesertGame(config: config, user: user),
      AppConstants.engineEcosystemExplorer =>
        EcosystemExplorerGame(config: config, user: user),
      AppConstants.engineEnergyQuest =>
        EnergyQuestGame(config: config, user: user),
      AppConstants.engineLifeCycles =>
        LifeCyclesGame(config: config, user: user),
      AppConstants.engineSolarSystem =>
        SolarSystemGame(config: config, user: user),
      AppConstants.engineWeatherWatcher =>
        WeatherWatcherGame(config: config, user: user),
      AppConstants.engineSimpleMachines =>
        SimpleMachinesGame(config: config, user: user),
      AppConstants.engineMatterMaster =>
        MatterMasterGame(config: config, user: user),
      AppConstants.engineNumberNinja =>
        NumberNinjaGame(config: config, user: user),
      AppConstants.engineProblemSolver =>
        ProblemSolverGame(config: config, user: user),
      AppConstants.engineTimesTableTower =>
        TimesTableTowerGame(config: config, user: user),
      AppConstants.engineCodingAdventure =>
        CodingAdventureGame(config: config, user: user),
      AppConstants.engineCircuitLab =>
        CircuitLabGame(config: config, user: user),
      AppConstants.engineRobotMaker =>
        RobotMakerGame(config: config, user: user),
      AppConstants.engineMapMaster =>
        MapMasterGame(config: config, user: user),
      AppConstants.engineSaProvincesExplorer =>
        SaProvincesExplorerGame(config: config, user: user),
      AppConstants.engineClimateQuest =>
        ClimateQuestGame(config: config, user: user),
      AppConstants.engineWaterCycle =>
        WaterCycleGame(config: config, user: user),
      AppConstants.engineEcosystems =>
        EcosystemsGame(config: config, user: user),
      AppConstants.engineAncientCivilizations =>
        AncientCivilizationsGame(config: config, user: user),
      AppConstants.engineSaHistory =>
        SaHistoryGame(config: config, user: user),
      AppConstants.engineColonialEra =>
        ColonialEraGame(config: config, user: user),
      AppConstants.engineLiberationHeroes =>
        LiberationHeroesGame(config: config, user: user),
      AppConstants.engineDemocracyGame =>
        DemocracyGame(config: config, user: user),
      AppConstants.engineReadingQuest =>
        ReadingQuestGame(config: config, user: user),
      AppConstants.engineNounNavigator =>
        NounNavigatorGame(config: config, user: user),
      AppConstants.engineVerbVolcano =>
        VerbVolcanoGame(config: config, user: user),
      AppConstants.engineWordPower =>
        WordPowerGame(config: config, user: user),
      AppConstants.engineSpellingBee =>
        SpellingBeeGame(config: config, user: user),
      AppConstants.enginePunctuationPolice =>
        PunctuationPoliceGame(config: config, user: user),
      AppConstants.engineStoryBuilder =>
        StoryBuilderGame(config: config, user: user),
      AppConstants.enginePoetryExplorer =>
        PoetryExplorerGame(config: config, user: user),
      AppConstants.engineIdiomIsland =>
        IdiomIslandGame(config: config, user: user),
      AppConstants.engineDebateDuel =>
        DebateDuelGame(config: config, user: user),
      AppConstants.engineCareerExplorer =>
        CareerExplorerGame(config: config, user: user),
      AppConstants.engineFinancialLiteracy =>
        FinancialLiteracyGame(config: config, user: user),
      AppConstants.engineHealthyLiving =>
        HealthyLivingGame(config: config, user: user),
      AppConstants.engineSocialSkills =>
        SocialSkillsGame(config: config, user: user),
      AppConstants.engineEnvironmentalAwareness =>
        EnvironmentalAwarenessGame(config: config, user: user),
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
