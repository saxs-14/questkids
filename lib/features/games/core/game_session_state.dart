import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/game_session_model.dart';
import 'game_config.dart';
import 'game_engine.dart';
import 'game_feedback_service.dart';
import 'game_session_persistence.dart';
import '../../../core/services/game_celebration_service.dart';

/// Abstract state controller for a game session.
///
/// Extends [ChangeNotifier] so a [ChangeNotifierProvider] can expose it
/// to the widget tree. Game UI widgets must NOT contain business logic —
/// they read from this class and call [submitAnswer].
///
/// Concrete subclasses provide [engine] and [questions], and override
/// [submitAnswer] to handle engine-specific input.
abstract class GameSessionState extends ChangeNotifier {
  final GameConfig config;

  GameSessionState(this.config);

  /// The engine that owns question generation and scoring rules.
  GameEngine get engine;

  /// All questions for this session. Generated once at init.
  List<Map<String, dynamic>> get questions;

  /// Process a player answer. Call [recordAnswer] inside to advance state.
  void submitAnswer(dynamic answer);

  final _uuid = const Uuid();

  Timer? _ticker;
  int _elapsed = 0;
  int _correctCount = 0;
  int _xpFromAnswers = 0;
  int _streak = 0;
  int _questionIndex = 0;
  bool _finished = false;
  GameSessionResult? _result;

  int get elapsedSeconds => _elapsed;
  int get correctCount => _correctCount;
  int get xpFromAnswers => _xpFromAnswers;
  int get questionIndex => _questionIndex;
  int get totalQuestions =>
      questions.isNotEmpty ? questions.length : config.questionCount;
  bool get isFinished => _finished;
  GameSessionResult? get result => _result;

  Map<String, dynamic>? get currentQuestion =>
      _questionIndex < questions.length ? questions[_questionIndex] : null;

  double get progressFraction =>
      totalQuestions > 0 ? _questionIndex / totalQuestions : 0;

  /// Start the session timer once the game UI is ready.
  void startSession() {
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsed++;
      if (config.timeLimitSeconds > 0 && _elapsed >= config.timeLimitSeconds) {
        _ticker?.cancel();
        finishSession('');
      }
      notifyListeners();
    });
  }

  /// Record answer feedback centrally so every game using this session
  /// controller gets the same optional spoken response.
  @protected
  bool recordAnswer(GameAnswerResult result) {
    if (result.correct) {
      _correctCount++;
      _streak++;
      GameCelebrationService.correct(_streak);
      unawaited(GameFeedbackService.correct());
    } else {
      _streak = 0;
      unawaited(GameFeedbackService.incorrect());
    }
    _xpFromAnswers += result.xpDelta;
    _questionIndex++;
    notifyListeners();
    return _questionIndex >= totalQuestions;
  }

  /// End the session, compute the result, and persist it when a UID is present.
  @protected
  Future<void> finishSession(String uid, {bool earlyWin = false}) async {
    if (_finished) return;
    _ticker?.cancel();
    _finished = true;

    _result = engine.buildResult(
      correct: _correctCount,
      total: totalQuestions,
      timeTakenSeconds: _elapsed,
      xpFromAnswers: _xpFromAnswers,
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
        metadata: {
          if (config.catalogId != null) 'catalogId': config.catalogId,
          if (config.extras['level'] != null) 'level': config.extras['level'],
        },
      );
      await persistGameSession(session);
    }
  }

  bool _disposed = false;

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
