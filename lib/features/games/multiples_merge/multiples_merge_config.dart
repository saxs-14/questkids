import '../core/game_config.dart';
import '../core/game_theme.dart';

/// Per-grade tuning for Multiples Merge.
///
/// Difficulty mapping (from the brief):
///   Gr 1–2 → tables 2, 5, 10, short chains, strong hints.
///   Gr 3–4 → tables 3, 4, 6, 8, medium chains, normal hints.
///   Gr 5–6 → tables 7, 8, 9, 11, 12, long chains, hints off (build fluency).
class MultiplesMergeConfig {
  final List<int> tables; // tables a round may draw from
  final int gridSize;     // grid is gridSize × gridSize
  final int chainLength;  // multiples to connect per round
  final int hintLevel;    // 2 strong · 1 normal · 0 fluency (start hint only)

  const MultiplesMergeConfig({
    required this.tables,
    required this.gridSize,
    required this.chainLength,
    required this.hintLevel,
  });

  /// Builds config from a generated content pack in 'numeric' mode (see
  /// tools/gamegen/content/multiples_merge.js). Packs in 'pairs' mode
  /// (word/token matching — idioms, synonyms, SA leaders, population
  /// terms) aren't wired up yet: MergeRound's grid is `List<int>`, so
  /// rendering string tokens needs a widget-level change beyond this
  /// config swap — see docs/DEFERRED.md. Those topics fall back to the
  /// grade-tuned numeric demo below.
  factory MultiplesMergeConfig.fromPack(Map<String, dynamic> pack, GameConfig config) {
    if (pack['mode'] != 'numeric') return MultiplesMergeConfig.forGrade(config);
    return MultiplesMergeConfig(
      tables: (pack['tables'] as List).cast<int>(),
      gridSize: pack['gridSize'] as int,
      chainLength: pack['chainLength'] as int,
      hintLevel: MultiplesMergeConfig.forGrade(config).hintLevel,
    );
  }

  factory MultiplesMergeConfig.forGrade(GameConfig config) {
    final g = GameTheme.gradeNumber(config.grade);
    if (g <= 2) {
      return const MultiplesMergeConfig(
        tables: [2, 5, 10], gridSize: 4, chainLength: 6, hintLevel: 2);
    } else if (g <= 4) {
      return const MultiplesMergeConfig(
        tables: [3, 4, 6, 8], gridSize: 5, chainLength: 9, hintLevel: 1);
    }
    return const MultiplesMergeConfig(
      tables: [7, 8, 9, 11, 12], gridSize: 5, chainLength: 12, hintLevel: 0);
  }
}
