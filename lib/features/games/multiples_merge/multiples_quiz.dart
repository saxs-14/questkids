import 'dart:math';

import '../core/game_config.dart';
import '../core/game_engine.dart';
import '../core/game_session_state.dart';
import 'multiples_merge_config.dart';

/// Timed recall assessment ("8 × 5 = ?") drawn only from the tables the learner
/// practises at their grade. Strict scoring; one question at a time.
class MultiplesQuizEngine extends GameEngine {
  final GameConfig _config;
  final List<int> tables;
  final Random _rng = Random();

  MultiplesQuizEngine({required GameConfig config})
      : _config = config,
        tables = MultiplesMergeConfig.forGrade(config).tables;

  @override
  GameConfig get config => _config;

  @override
  List<Map<String, dynamic>> generateQuestions() {
    return List.generate(_config.questionCount, (_) {
      final a = tables[_rng.nextInt(tables.length)];
      final b = 1 + _rng.nextInt(12);
      final answer = a * b;

      final options = <int>{answer};
      while (options.length < 4) {
        final delta = _rng.nextInt(5) - 2; // near-misses
        final wrongB = (b + (delta == 0 ? 1 : delta)).clamp(1, 14);
        final wrong = a * wrongB;
        if (wrong != answer) options.add(wrong);
      }
      final shuffled = options.toList()..shuffle(_rng);

      return {
        'a': a,
        'b': b,
        'answer': answer,
        'options': shuffled,
        'prompt': '$a × $b = ?',
      };
    });
  }

  @override
  GameAnswerResult checkAnswer(
    Map<String, dynamic> question,
    dynamic answer, {
    int elapsedThresholdSeconds = 5,
  }) {
    final correct = answer == question['answer'];
    return GameAnswerResult(correct: correct, xpDelta: correct ? 10 : 0);
  }

  @override
  GameSessionResult buildResult({
    required int correct,
    required int total,
    required int timeTakenSeconds,
    required int xpFromAnswers,
    bool earlyWin = false,
  }) =>
      defaultResult(
        correct: correct,
        total: total,
        timeTakenSeconds: timeTakenSeconds,
        xpFromAnswers: xpFromAnswers,
        earlyWin: earlyWin,
      );
}

class MultiplesQuizSession extends GameSessionState {
  final String uid;

  MultiplesQuizSession(GameConfig config, this.uid) : super(config) {
    _engine = MultiplesQuizEngine(config: config);
    _questions = _engine.generateQuestions();
  }

  late final MultiplesQuizEngine _engine;
  late final List<Map<String, dynamic>> _questions;

  @override
  GameEngine get engine => _engine;

  @override
  List<Map<String, dynamic>> get questions => _questions;

  int? _selected;
  bool _locked = false;
  bool? _lastCorrect;

  int? get selected => _selected;
  bool get locked => _locked;
  bool? get lastCorrect => _lastCorrect;

  @override
  void submitAnswer(dynamic answer) {
    if (_locked || isFinished) return;
    final q = currentQuestion;
    if (q == null) return;

    _selected = answer as int;
    final res = _engine.checkAnswer(q, answer);
    _lastCorrect = res.correct;
    _locked = true;
    notifyListeners();

    Future.delayed(const Duration(milliseconds: 850), () {
      _selected = null;
      _lastCorrect = null;
      _locked = false;
      final done = recordAnswer(res);
      if (done) {
        finishSession(uid);
      } else {
        notifyListeners();
      }
    });
  }
}
