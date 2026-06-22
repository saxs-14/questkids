import '../core/game_config.dart';

/// One step in a sequence (e.g. a stage of the water cycle).
class SequenceStage {
  final String id;
  final String label;
  final String emoji;
  final String description;

  const SequenceStage({
    required this.id,
    required this.label,
    required this.emoji,
    required this.description,
  });
}

/// Configures a drag-to-order sequencing game. [stages] are listed in the
/// correct order; the UI shuffles them into a tray. [sceneType] selects the
/// animated backdrop (currently 'waterCycle').
class SequenceBuilderConfig {
  final String title;
  final String sceneType;
  final List<SequenceStage> stages;
  final int rounds;

  const SequenceBuilderConfig({
    required this.title,
    required this.sceneType,
    required this.stages,
    this.rounds = 3,
  });

  factory SequenceBuilderConfig.forGame(GameConfig config) {
    // Water Cycle — the only sequence content for now; add more by branching
    // on config.subtopicId / topicId.
    return const SequenceBuilderConfig(
      title: 'Water Cycle Adventure',
      sceneType: 'waterCycle',
      rounds: 3,
      stages: [
        SequenceStage(
          id: 'evaporation',
          label: 'Evaporation',
          emoji: '💨',
          description: 'The sun heats the water and it rises as invisible vapour.',
        ),
        SequenceStage(
          id: 'condensation',
          label: 'Condensation',
          emoji: '☁️',
          description: 'High up it cools and gathers into tiny droplets — clouds!',
        ),
        SequenceStage(
          id: 'precipitation',
          label: 'Precipitation',
          emoji: '🌧️',
          description: 'The droplets join, grow heavy, and fall as rain.',
        ),
        SequenceStage(
          id: 'collection',
          label: 'Collection',
          emoji: '🌊',
          description: 'Water flows into rivers, lakes and the sea — and it starts again!',
        ),
      ],
    );
  }
}
