import 'game_config.dart';

/// Result of checking a single submitted answer.
class GameAnswerResult {
  final bool correct;
  final int xpDelta;
  final bool isBonus; // true when fast-answer bonus applied

  const GameAnswerResult({
    required this.correct,
    required this.xpDelta,
    this.isBonus = false,
  });
}

/// Final result produced when a game session ends.
class GameSessionResult {
  final String result;    // 'win' | 'loss' | 'complete' | 'incomplete'
  final int score;        // percentage 0–100
  final int xpEarned;
  final int coinsEarned;
  final double accuracy;  // 0.0–1.0

  const GameSessionResult({
    required this.result,
    required this.score,
    required this.xpEarned,
    required this.coinsEarned,
    required this.accuracy,
  });
}

/// Abstract engine — pure rules with no Flutter/widget imports.
///
/// Engines are stateless:  they receive questions and answers,
/// and return typed results.  All mutable state lives in
/// [GameSessionState].
abstract class GameEngine {
  GameConfig get config;

  /// Generate the full question set for this session.
  /// Called once per session at init.
  List<Map<String, dynamic>> generateQuestions();

  /// Check a single submitted [answer] against [question].
  /// [elapsedThresholdSeconds] is used for fast-answer bonus.
  GameAnswerResult checkAnswer(
    Map<String, dynamic> question,
    dynamic answer, {
    int elapsedThresholdSeconds = 5,
  });

  /// Build the final [GameSessionResult] once all questions are done
  /// (or the session ends early).
  GameSessionResult buildResult({
    required int correct,
    required int total,
    required int timeTakenSeconds,
    bool earlyWin = false,
  });

  // ── Default scoring helper — call from concrete buildResult ───────────────

  /// Standard XP formula (spec §2E).  Override in engines that
  /// have different reward tables.
  GameSessionResult defaultResult({
    required int correct,
    required int total,
    required int timeTakenSeconds,
    bool earlyWin = false,
  }) {
    final accuracy = total > 0 ? correct / total : 0.0;
    final score = (accuracy * 100).round();
    final isWin = earlyWin || correct > total / 2;
    final isPerfect = correct == total;

    int xp = correct * 10;
    if (isPerfect) {
      xp += 100;
    } else if (isWin) {
      xp += 50;
    }

    return GameSessionResult(
      result: isPerfect ? 'complete' : (isWin ? 'win' : 'loss'),
      score: score,
      xpEarned: xp,
      coinsEarned: xp ~/ 10,
      accuracy: accuracy,
    );
  }
}
