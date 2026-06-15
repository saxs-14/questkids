import '../core/game_config.dart';
import '../core/game_session_state.dart';
import 'explorer_map_config.dart';
import 'explorer_map_engine.dart';

class ExplorerMapSession extends GameSessionState {
  final String uid;

  ExplorerMapSession(GameConfig config, this.uid) : super(config) {
    _mapConfig = ExplorerMapConfig.saProvinces(config);
    _engine = ExplorerMapEngine(mapConfig: _mapConfig, config: config);
    _questions = _engine.generateQuestions();
  }

  late final ExplorerMapConfig _mapConfig;
  late final ExplorerMapEngine _engine;
  late final List<Map<String, dynamic>> _questions;

  @override
  ExplorerMapEngine get engine => _engine;

  @override
  List<Map<String, dynamic>> get questions => _questions;

  // ── State ──────────────────────────────────────────────────────────────────

  String? _selectedId;
  bool? _lastAnswerCorrect;
  String? _feedbackFact;
  bool _awaitingNext = false; // brief lock while showing feedback

  String? get selectedId => _selectedId;
  bool? get lastAnswerCorrect => _lastAnswerCorrect;
  String? get feedbackFact => _feedbackFact;
  bool get awaitingNext => _awaitingNext;

  ExplorerMapConfig get mapConfig => _mapConfig;

  ProvincePin? get currentCorrectProvince {
    final q = currentQuestion;
    if (q == null) return null;
    return _engine.getProvince(q['correctId'] as String);
  }

  List<ProvincePin> get currentOptions {
    final q = currentQuestion;
    if (q == null) return [];
    return (q['optionIds'] as List)
        .map((id) => _engine.getProvince(id as String))
        .whereType<ProvincePin>()
        .toList();
  }

  // ── Answer submission ──────────────────────────────────────────────────────

  @override
  void submitAnswer(dynamic answer) {
    if (_awaitingNext || isFinished) return;
    final provinceId = answer as String;
    _selectedId = provinceId;

    final q = currentQuestion!;
    final result = _engine.checkAnswer(
      q,
      provinceId,
      elapsedThresholdSeconds: elapsedSeconds,
    );

    _lastAnswerCorrect = result.correct;
    _feedbackFact = q['feedbackFact'] as String;
    _awaitingNext = true;
    notifyListeners();

    Future.delayed(const Duration(milliseconds: 1800), () {
      final done = recordAnswer(result.correct);
      _selectedId = null;
      _lastAnswerCorrect = null;
      _feedbackFact = null;
      _awaitingNext = false;
      if (done) {
        finishSession(uid);
      }
    });
  }
}
