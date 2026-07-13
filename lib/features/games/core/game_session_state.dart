import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/offline_service.dart';
import '../../../core/services/rewards_service.dart';
import '../../../data/models/game_session_model.dart';
import '../../../data/repositories/game_repository.dart';
import 'game_config.dart';
import 'game_engine.dart';
import 'game_session_persistence.dart';

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
  // The generated question list is the source of truth for length, not
  // config.questionCount -- an engine session may generate fewer questions
  // than that default (e.g. a demo/fallback content pack), and keying off
  // the independent config value left currentQuestion returning null before
  // totalQuestions was reached, permanently freezing the game screen.
  int get totalQuestions => questions.isNotEmpty ? questions.length : config.questionCount;
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
      final offlineService = OfflineService();
      final online = await offlineService.isOnline();
      var writeSucceeded = false;
      if (online) {
        try {
          await _repo.logGameSession(session);
          writeSucceeded = true;
          try {
            await RewardsService().grantGameSessionRewards(session);
          } catch (_) {
            // Non-fatal: the session itself is already saved; a failure
            // here just means this session's XP won't show on the
            // Rewards screen/dashboard until the next successful grant.
          }
        } catch (_) {
          writeSucceeded = false;
        }
      }
      if (shouldQueueGameSessionOffline(
          isOnline: online, writeSucceeded: writeSucceeded)) {
        await offlineService.saveGameSessionOffline(session);
      }
    }
  }

  bool _disposed = false;

  /// Guards against the many `Future.delayed` callbacks in concrete sessions
  /// (flash clears, round transitions, end-of-game) firing after the player has
  /// quit and the session was disposed — which would otherwise throw
  /// "A ChangeNotifier was used after being disposed".
  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    super.dispose();
  }
}
