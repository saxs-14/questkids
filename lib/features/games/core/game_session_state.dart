import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/game_session_model.dart';
import '../../../data/repositories/game_repository.dart';
import 'game_config.dart';
import 'game_engine.dart';

/// Abstract state controller for a game session.
///
/// Extends [ChangeNotifier] so a [ChangeNotifierProvider] can expose it
/// to the widget tree.  Game UI widgets must NOT contain business logic —
/// they read from this class and call [submitAnswer].
///
/// Concrete subclasses (e.g. TugOfWarSession) provide [engine] and
/// [questions], and override [submitAnswer] to handle engine-specific
/// input (multiple-choice tap, numeric keypad, lane swipe, map tap…).
abstract class GameSessionState extends ChangeNotifier {
  final GameConfig config;

  GameSessionState(this.config);

  // ── Abstract contract ──────────────────────────────────────────────────────

  /// The engine that owns question generation and scoring rules.
  GameEngine get engine;

  /// All questions for this session.  Generated once at init.
  List<Map<String, dynamic>> get questions;

  /// Process a player answer.  Call [recordAnswer] inside to advance state.
  /// For tug-of-war this is an [int]; for runner-collector it's a [String];
  /// for explorer-map it's a [String] province id.
  void submitAnswer(dynamic answer);

  // ── Internal state ─────────────────────────────────────────────────────────

  final _repo = GameRepository();
  final _uuid = const Uuid();

  Timer? _ticker;
  int _elapsed = 0;
  int _correctCount = 0;
  int _questionIndex = 0;
  bool _finished = false;
  GameSessionResult? _result;

  // ── Read-only accessors ────────────────────────────────────────────────────

  int get elapsedSeconds => _elapsed;
  int get correctCount => _correctCount;
  int get questionIndex => _questionIndex;
  int get totalQuestions => config.questionCount;
  bool get isFinished => _finished;
  GameSessionResult? get result => _result;

  Map<String, dynamic>? get currentQuestion =>
      _questionIndex < questions.length ? questions[_questionIndex] : null;

  double get progressFraction =>
      totalQuestions > 0 ? _questionIndex / totalQuestions : 0;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  /// Start the session timer.  Call from [State.initState] after the first
  /// frame or once the game UI is ready.
  void startSession() {
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsed++;
      // Check time limit
      if (config.timeLimitSeconds > 0 && _elapsed >= config.timeLimitSeconds) {
        _ticker?.cancel();
        finishSession(''); // uid will be passed by caller
      }
      notifyListeners();
    });
  }

  // ── Helpers for subclasses ─────────────────────────────────────────────────

  /// Call inside [submitAnswer] to record the outcome of one answer and
  /// advance to the next question.  Returns true when the session ends.
  @protected
  bool recordAnswer(bool correct) {
    if (correct) _correctCount++;
    _questionIndex++;
    notifyListeners();
    return _questionIndex >= totalQuestions;
  }

  /// End the session, compute [result], save to Firestore.
  /// [uid] may be empty during local tests; repository handles gracefully.
  @protected
  Future<void> finishSession(String uid, {bool earlyWin = false}) async {
    if (_finished) return;
    _ticker?.cancel();
    _finished = true;

    _result = engine.buildResult(
      correct: _correctCount,
      total: totalQuestions,
      timeTakenSeconds: _elapsed,
      earlyWin: earlyWin,
    );
    notifyListeners();

    if (uid.isNotEmpty) {
      final session = GameSessionModel(
        id: _uuid.v4(),
        uid: uid,
        grade: config.grade,
        subject: config.subject,
        engineType: config.engineType,
        score: _result!.score,
        xpEarned: _result!.xpEarned,
        coinsEarned: _result!.coinsEarned,
        accuracy: _result!.accuracy,
        timeTakenSeconds: _elapsed,
        completedAt: DateTime.now(),
        result: _result!.result,
      );
      try {
        await _repo.logGameSession(session);
      } catch (_) {
        // Non-fatal: local state already updated
      }
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
