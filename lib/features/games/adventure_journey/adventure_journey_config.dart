import 'package:flutter/material.dart';
import '../core/game_config.dart';

/// A single stage in an Adventure Journey game.
class JourneyStage {
  final String id;
  final String name;
  final String emoji;           // background theme emoji
  final Color themeColor;
  final String question;
  final List<String> options;   // exactly 4 options
  final String correctOption;
  final String correctFeedback; // shown on correct answer
  final String wrongFeedback;   // shown on wrong answer

  const JourneyStage({
    required this.id,
    required this.name,
    required this.emoji,
    required this.themeColor,
    required this.question,
    required this.options,
    required this.correctOption,
    this.correctFeedback = 'Correct! Moving forward!',
    this.wrongFeedback = 'Try again!',
  });
}

/// Config wrapper that adds stage definitions on top of [GameConfig.extras].
class AdventureJourneyConfig {
  final List<JourneyStage> stages;
  final String characterEmoji;

  const AdventureJourneyConfig({
    required this.stages,
    this.characterEmoji = '💧',
  });

  static AdventureJourneyConfig waterCycle(GameConfig config) {
    return const AdventureJourneyConfig(
      characterEmoji: '💧',
      stages: [
        JourneyStage(
          id: 'ocean',
          name: 'The Ocean',
          emoji: '🌊',
          themeColor: Color(0xFF0288D1),
          question: 'Where does most of the water cycle begin?',
          options: ['Oceans', 'Rivers', 'Clouds', 'Ice caps'],
          correctOption: 'Oceans',
          correctFeedback: 'Yes! Most water comes from the oceans! 🌊',
          wrongFeedback: 'Oceans cover 71% of Earth and are the start!',
        ),
        JourneyStage(
          id: 'evaporation',
          name: 'Evaporation',
          emoji: '☀️',
          themeColor: Color(0xFFF9A825),
          question: 'What process turns liquid water into water vapour?',
          options: ['Evaporation', 'Condensation', 'Precipitation', 'Runoff'],
          correctOption: 'Evaporation',
          correctFeedback: 'Correct! The sun heats the water and it evaporates! ☀️',
          wrongFeedback: 'Evaporation is when heat turns liquid water into vapour!',
        ),
        JourneyStage(
          id: 'clouds',
          name: 'Cloud Formation',
          emoji: '⛅',
          themeColor: Color(0xFF78909C),
          question: 'What do clouds consist of?',
          options: [
            'Tiny water droplets',
            'Water vapour only',
            'Ice and rock',
            'Carbon dioxide'
          ],
          correctOption: 'Tiny water droplets',
          correctFeedback: 'Yes! Clouds are made of tiny water droplets! ⛅',
          wrongFeedback: 'Clouds form when vapour cools into tiny water droplets!',
        ),
        JourneyStage(
          id: 'condensation',
          name: 'Condensation',
          emoji: '🌁',
          themeColor: Color(0xFF546E7A),
          question:
              'What is it called when water vapour cools and turns back to liquid?',
          options: ['Condensation', 'Evaporation', 'Transpiration', 'Filtration'],
          correctOption: 'Condensation',
          correctFeedback: 'That\'s right! Condensation forms clouds and dew! 💧',
          wrongFeedback: 'Condensation = vapour cooling back into liquid water!',
        ),
        JourneyStage(
          id: 'rainfall',
          name: 'Rainfall',
          emoji: '🌧️',
          themeColor: Color(0xFF1565C0),
          question: 'What is the term for water falling from clouds?',
          options: ['Precipitation', 'Evaporation', 'Condensation', 'Runoff'],
          correctOption: 'Precipitation',
          correctFeedback: 'Brilliant! Rain, hail, and snow are all precipitation! 🌧️',
          wrongFeedback: 'Precipitation includes any water that falls from clouds!',
        ),
        JourneyStage(
          id: 'collection',
          name: 'Collection',
          emoji: '🏞️',
          themeColor: Color(0xFF2E7D32),
          question: 'Where does rainwater collect to start the cycle again?',
          options: [
            'Rivers, lakes and oceans',
            'Only in the sky',
            'Underground only',
            'In clouds'
          ],
          correctOption: 'Rivers, lakes and oceans',
          correctFeedback:
              'Perfect! Water collects and the cycle begins again! 🔄',
          wrongFeedback:
              'Rainwater collects in rivers, lakes and flows to the ocean!',
        ),
      ],
    );
  }
}
