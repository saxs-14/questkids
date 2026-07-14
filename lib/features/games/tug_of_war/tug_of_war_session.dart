import 'dart:async';
import 'dart:math';

import '../core/game_config.dart';
import '../core/game_session_state.dart';
import 'tug_of_war_config.dart';
import 'tug_of_war_engine.dart';

class TugOfWarSession extends GameSessionState {
  final String uid;

  TugOfWarSession(GameConfig config, this.uid) : super(config) {
    _tugConfig = TugOfWarConfig.fromGameConfig(config);
    _engine = TugOfWarEngine(tugConfig: _tugConfig, config: config);
    _questions = _engine.generateQuestions();
    _opponentQuestions = _engine.generateQuestions();
    _currentOpponentIntervalMs = _tugConfig.opponentIntervalMs;
  }

  // ── Engine + questions ─────────────────────────────────────────────────────

  late final TugOfWarConfig _tugConfig;
  late final TugOfWarEngine _engine;
  late final List<Map<String, dynamic>> _questions;
  late List<Map<String, dynamic>> _opponentQuestions;

  @override
  TugOfWarEngine get engine => _engine;

  @override
  List<Map<String, dynamic>> get questions => _questions;

  // ── TugOfWar-specific state ────────────────────────────────────────────────

  int _opponentScore = 0;
  int _opponentQIndex = 0;
  String _currentInput = '';
  int _questionStartSec = 0;
  int _playerStreak = 0;
  bool? _lastAnswerCorrect; // null = no flash

  // Adaptive difficulty
  int _currentOpponentIntervalMs = 4000;

  Timer? _opponentTimer;
  Timer? _flashTimer;

  // ── Public read-only accessors ─────────────────────────────────────────────

  int get playerScore => correctCount;
  int get opponentScore => _opponentScore;
  String get currentInput => _currentInput;
  bool? get lastAnswerCorrect => _lastAnswerCorrect;

  Map<String, dynamic>? get opponentCurrentQuestion =>
      _opponentQIndex < _opponentQuestions.length
          ? _opponentQuestions[_opponentQIndex]
          : null;

  /// -1.0 = opponent winning fully, 0.0 = tied, 1.0 = player winning fully
  double get flagPosition =>
      ((playerScore - _opponentScore) / _tugConfig.winThreshold)
          .clamp(-1.0, 1.0);

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void startSession() {
    _questionStartSec = 0;
    super.startSession();
    _startOpponent();
  }

  @override
  void dispose() {
    _opponentTimer?.cancel();
    _flashTimer?.cancel();
    super.dispose();
  }

  // ── Player input ───────────────────────────────────────────────────────────

  void appendDigit(String digit) {
    if (isFinished) return;
    if (digit == '±') {
      _currentInput = _currentInput.startsWith('-')
          ? _currentInput.substring(1)
          : '-$_currentInput';
      notifyListeners();
      return;
    }
    if (digit == '.') {
      if (_currentInput.contains('.') || _currentInput.length >= 6) return;
      _currentInput += digit;
      notifyListeners();
      return;
    }
    if (digit == '-') return; // only the ± toggle may add a sign
    if (_currentInput.length >= 6) return;
    _currentInput += digit;
    notifyListeners();
  }

  void clearInput() {
    if (isFinished) return;
    _currentInput = '';
    notifyListeners();
  }

  // ── Answer submission ──────────────────────────────────────────────────────

  @override
  void submitAnswer(dynamic answer) {
    if (isFinished || currentQuestion == null) return;

    final raw = answer is String ? answer : answer.toString();
    if (raw.isEmpty) return;

    final timeSince = elapsedSeconds - _questionStartSec;
    final ar = _engine.checkAnswer(
      currentQuestion!,
      raw,
      elapsedThresholdSeconds: timeSince,
    );

    _currentInput = '';
    _lastAnswerCorrect = ar.correct;
    _scheduleFlashClear();

    if (ar.correct) {
      _playerStreak++;
      if (_playerStreak >= 3 && config.difficulty == 'adaptive') {
        _currentOpponentIntervalMs =
            (_currentOpponentIntervalMs * 0.85).toInt().clamp(1500, 8000);
        _restartOpponent();
      }
    } else {
      _playerStreak = 0;
    }

    final done = recordAnswer(ar);
    _questionStartSec = elapsedSeconds;

    if (done || flagPosition >= 1.0 || flagPosition <= -1.0) {
      _opponentTimer?.cancel();
      finishSession(uid, earlyWin: playerScore > _opponentScore);
    }
  }

  // ── AI Opponent ────────────────────────────────────────────────────────────

  void _startOpponent() {
    _opponentTimer?.cancel();
    _opponentTimer = Timer.periodic(
      Duration(milliseconds: _currentOpponentIntervalMs),
      (_) => _opponentTick(),
    );
  }

  void _restartOpponent() {
    _opponentTimer?.cancel();
    _startOpponent();
  }

  void _opponentTick() {
    if (isFinished) {
      _opponentTimer?.cancel();
      return;
    }

    final correct = Random().nextDouble() < _tugConfig.opponentAccuracy;
    if (correct) _opponentScore++;

    _opponentQIndex++;
    if (_opponentQIndex >= _opponentQuestions.length) {
      _opponentQuestions = _engine.generateQuestions();
      _opponentQIndex = 0;
    }

    notifyListeners();

    if (flagPosition <= -1.0 && !isFinished) {
      _opponentTimer?.cancel();
      finishSession(uid, earlyWin: false);
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _scheduleFlashClear() {
    _flashTimer?.cancel();
    _flashTimer = Timer(const Duration(milliseconds: 650), () {
      _lastAnswerCorrect = null;
      notifyListeners();
    });
  }
}
