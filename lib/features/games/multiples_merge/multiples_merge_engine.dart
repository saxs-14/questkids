import 'dart:math';

import '../core/game_config.dart';
import '../core/game_engine.dart';
import 'multiples_merge_config.dart';

/// One generated round. In 'numeric' mode: the target table, the grid
/// values, and a guaranteed in-order solution path (cell indices) so a
/// valid chain always exists. In 'pairs' mode: a term/definition pair
/// placed on two adjacent cells among distractor tokens, with
/// [pairPartner] recording the mutual cell-index mapping so the session
/// can validate a tap without arithmetic.
class MergeRound {
  final String mode; // 'numeric' | 'pairs'
  final int table; // numeric mode only; 0 for pairs rounds
  final int gridSize;
  final int chainLength;
  final List<Object> values; // int cells (numeric) or String cells (pairs)
  final List<int> solutionPath; // numeric mode: cell indices, in order
  final Map<int, int>? pairPartner; // pairs mode: cell index -> partner cell

  const MergeRound({
    required this.mode,
    required this.table,
    required this.gridSize,
    required this.chainLength,
    required this.values,
    required this.solutionPath,
    this.pairPartner,
  });
}

class MultiplesMergeEngine extends GameEngine {
  final MultiplesMergeConfig mergeConfig;
  final GameConfig _config;
  final Random _rng = Random();

  MultiplesMergeEngine({required this.mergeConfig, required GameConfig config})
      : _config = config;

  @override
  GameConfig get config => _config;

  @override
  List<Map<String, dynamic>> generateQuestions() =>
      List.generate(_config.questionCount, (i) => {'round': i});

  /// Build a fresh, solvable round for the configured mode.
  MergeRound buildRound() =>
      mergeConfig.mode == 'pairs' ? _buildPairsRound() : _buildNumericRound();

  MergeRound _buildNumericRound() {
    final table = mergeConfig.tables[_rng.nextInt(mergeConfig.tables.length)];
    final n = mergeConfig.gridSize;
    final len = mergeConfig.chainLength.clamp(2, n * n);

    final path = _generatePath(n, len);
    final values = List<int>.filled(n * n, 0);
    final chainValues = List.generate(len, (i) => table * (i + 1));
    for (int i = 0; i < len; i++) {
      values[path[i]] = chainValues[i];
    }

    final used = chainValues.toSet();
    for (int c = 0; c < values.length; c++) {
      if (values[c] != 0) continue;
      values[c] = _distractor(table, len, used);
    }

    return MergeRound(
      mode: 'numeric',
      table: table,
      gridSize: n,
      chainLength: len,
      values: values,
      solutionPath: path,
    );
  }

  MergeRound _buildPairsRound() {
    final n = mergeConfig.gridSize;
    final groups = mergeConfig.tokenGroups;
    final targetGroup = groups[_rng.nextInt(groups.length)];

    final path = _generatePath(n, 2); // exactly 2 adjacent cells
    final values = List<Object?>.filled(n * n, null);
    values[path[0]] = targetGroup[0];
    values[path[1]] = targetGroup[1];

    // Fill remaining cells with ONE token per distractor pair (never both
    // halves of the same non-target pair), so no accidental second match
    // exists on the board.
    final distractorPool = <String>[];
    for (final g in groups) {
      if (identical(g, targetGroup)) continue;
      distractorPool.add(_rng.nextBool() ? g[0] : g[1]);
    }
    distractorPool.shuffle(_rng);

    int di = 0;
    for (int c = 0; c < values.length; c++) {
      if (values[c] != null) continue;
      if (di < distractorPool.length) {
        values[c] = distractorPool[di++];
      } else {
        // More filler cells than distractor tokens available (typical: 10
        // tokenGroups on a 4×4 grid needs 14 filler cells but the pool
        // above only has 9 tokens -- one per non-target group). Repeat an
        // ALREADY-PLACED distractor string rather than drawing a fresh
        // token: drawing fresh would risk introducing a non-target group's
        // other half, which would leave both halves of that pair on the
        // board with no pairPartner mapping recognizing them as a match --
        // confusing, since tapping them looks like it should work but
        // silently does nothing. A repeated distractor string is inert by
        // construction (it was already screened as safe above).
        values[c] = distractorPool[_rng.nextInt(distractorPool.length)];
      }
    }

    return MergeRound(
      mode: 'pairs',
      table: 0,
      gridSize: n,
      chainLength: 2,
      values: values.cast<Object>(),
      solutionPath: path,
      pairPartner: {path[0]: path[1], path[1]: path[0]},
    );
  }

  /// A plausible distractor number that is NOT one of the chain multiples
  /// (avoids ambiguous duplicate tiles).
  int _distractor(int table, int len, Set<int> avoid) {
    final maxV = max(table * len + table * 2, 20);
    for (int tries = 0; tries < 40; tries++) {
      final v = 1 + _rng.nextInt(maxV);
      if (!avoid.contains(v)) return v;
    }
    return table * len + 1 + _rng.nextInt(5);
  }

  // ── Self-avoiding 8-connected path search (backtracking) ────────────────
  List<int> _generatePath(int n, int length) {
    final total = n * n;
    for (int attempt = 0; attempt < 80; attempt++) {
      final start = _rng.nextInt(total);
      final path = <int>[start];
      final visited = <int>{start};
      if (_walk(n, path, visited, length)) return path;
    }
    return _snake(n, length); // guaranteed-valid fallback
  }

  bool _walk(int n, List<int> path, Set<int> visited, int length) {
    if (path.length == length) return true;
    final neighbors = _neighbors8(n, path.last)..shuffle(_rng);
    for (final nb in neighbors) {
      if (visited.contains(nb)) continue;
      visited.add(nb);
      path.add(nb);
      if (_walk(n, path, visited, length)) return true;
      visited.remove(nb);
      path.removeLast();
    }
    return false;
  }

  static List<int> _neighbors8(int n, int idx) {
    final r = idx ~/ n, c = idx % n;
    final res = <int>[];
    for (int dr = -1; dr <= 1; dr++) {
      for (int dc = -1; dc <= 1; dc++) {
        if (dr == 0 && dc == 0) continue;
        final nr = r + dr, nc = c + dc;
        if (nr >= 0 && nr < n && nc >= 0 && nc < n) res.add(nr * n + nc);
      }
    }
    return res;
  }

  List<int> _snake(int n, int length) {
    final path = <int>[];
    for (int r = 0; r < n && path.length < length; r++) {
      final cols = r.isEven
          ? List.generate(n, (c) => c)
          : List.generate(n, (c) => n - 1 - c);
      for (final c in cols) {
        if (path.length < length) path.add(r * n + c);
      }
    }
    return path;
  }

  /// True if cells [a] and [b] are 8-connected neighbours on an n×n grid.
  static bool areAdjacent8(int n, int a, int b) {
    final dr = (a ~/ n - b ~/ n).abs();
    final dc = (a % n - b % n).abs();
    return dr <= 1 && dc <= 1 && !(dr == 0 && dc == 0);
  }

  @override
  GameAnswerResult checkAnswer(
    Map<String, dynamic> question,
    dynamic answer, {
    int elapsedThresholdSeconds = 5,
  }) {
    final correct = answer == true;
    return GameAnswerResult(correct: correct, xpDelta: correct ? 20 : 0);
  }

  @override
  GameSessionResult buildResult({
    required int correct,
    required int total,
    required int timeTakenSeconds,
    bool earlyWin = false,
  }) =>
      defaultResult(
        correct: correct,
        total: total,
        timeTakenSeconds: timeTakenSeconds,
        earlyWin: earlyWin,
      );
}
