import 'dart:math';

import '../core/game_config.dart';
import '../core/game_engine.dart';
import 'multiples_merge_config.dart';

/// One generated round: the target table, the grid values, and a guaranteed
/// in-order solution path (cell indices) so a valid chain always exists.
class MergeRound {
  final int table;
  final int gridSize;
  final int chainLength;
  final List<int> values; // length gridSize²
  final List<int> solutionPath; // cell indices, in correct order

  const MergeRound({
    required this.table,
    required this.gridSize,
    required this.chainLength,
    required this.values,
    required this.solutionPath,
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

  /// Build a fresh, solvable round.
  MergeRound buildRound() {
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
      table: table,
      gridSize: n,
      chainLength: len,
      values: values,
      solutionPath: path,
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
