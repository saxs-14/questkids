import '../core/game_config.dart';

/// A word card scrolling toward the player in a lane.
class LaneWord {
  final String word;
  final String partOfSpeech; // 'noun' | 'verb' | 'adjective' | 'pronoun'
  final int lane;             // 0, 1, or 2
  double xPosition;           // 0.0 = right edge, 1.0 = left edge (off-screen)
  bool collected;

  LaneWord({
    required this.word,
    required this.partOfSpeech,
    required this.lane,
    this.xPosition = 0.0,
    this.collected = false,
  });
}

/// One gameplay level — defines what the player must collect.
class GrammarLevel {
  final int index;
  final String targetPOS;     // 'noun' | 'verb' | 'adjective' | 'pronoun' | 'mixed'
  final String missionLabel;  // e.g. "Collect only Nouns"
  final double scrollSpeed;   // words per second across screen
  final List<String> nouns;
  final List<String> verbs;
  final List<String> adjectives;
  final List<String> pronouns;

  const GrammarLevel({
    required this.index,
    required this.targetPOS,
    required this.missionLabel,
    required this.scrollSpeed,
    required this.nouns,
    required this.verbs,
    required this.adjectives,
    required this.pronouns,
  });
}

class RunnerCollectorConfig {
  final List<GrammarLevel> levels;
  final int heartsStart;

  const RunnerCollectorConfig({
    required this.levels,
    this.heartsStart = 3,
  });

  static RunnerCollectorConfig grammarHero(GameConfig config) {
    return const RunnerCollectorConfig(
      heartsStart: 3,
      levels: [
        GrammarLevel(
          index: 0,
          targetPOS: 'noun',
          missionLabel: 'Collect only Nouns! 📦',
          scrollSpeed: 0.08,
          nouns: ['dog', 'house', 'school', 'river', 'table', 'book', 'city', 'teacher'],
          verbs: ['run', 'eat', 'jump', 'sleep', 'play', 'swim'],
          adjectives: ['happy', 'big', 'cold', 'fast', 'small'],
          pronouns: ['he', 'she', 'they', 'it', 'we'],
        ),
        GrammarLevel(
          index: 1,
          targetPOS: 'verb',
          missionLabel: 'Collect only Verbs! 🏃',
          scrollSpeed: 0.10,
          nouns: ['cat', 'road', 'cloud', 'flower', 'market'],
          verbs: ['sing', 'write', 'fly', 'build', 'cook', 'throw', 'learn', 'drive'],
          adjectives: ['red', 'quiet', 'tall', 'young'],
          pronouns: ['you', 'him', 'her', 'us'],
        ),
        GrammarLevel(
          index: 2,
          targetPOS: 'adjective',
          missionLabel: 'Collect only Adjectives! ✨',
          scrollSpeed: 0.12,
          nouns: ['sun', 'tree', 'train', 'door'],
          verbs: ['talk', 'draw', 'push', 'read'],
          adjectives: ['brave', 'tiny', 'warm', 'dark', 'bright', 'loud', 'soft', 'long'],
          pronouns: ['mine', 'yours', 'theirs'],
        ),
        GrammarLevel(
          index: 3,
          targetPOS: 'pronoun',
          missionLabel: 'Collect only Pronouns! 👤',
          scrollSpeed: 0.13,
          nouns: ['bag', 'lake', 'star', 'hill'],
          verbs: ['open', 'close', 'mix', 'lift'],
          adjectives: ['green', 'wet', 'dry', 'old'],
          pronouns: ['I', 'you', 'he', 'she', 'we', 'they', 'it', 'me', 'him', 'her'],
        ),
        GrammarLevel(
          index: 4,
          targetPOS: 'mixed',
          missionLabel: 'Mixed Challenge! Collect Nouns & Verbs! 🐉',
          scrollSpeed: 0.15,
          nouns: ['village', 'storm', 'bridge', 'island', 'mountain'],
          verbs: ['explore', 'discover', 'escape', 'battle', 'defend'],
          adjectives: ['fierce', 'ancient', 'golden', 'silent'],
          pronouns: ['them', 'its', 'ours', 'his'],
        ),
      ],
    );
  }
}
