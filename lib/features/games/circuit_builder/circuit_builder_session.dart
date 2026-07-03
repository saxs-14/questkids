import '../core/game_config.dart';
import '../core/game_session_state.dart';
import 'circuit_builder_engine.dart';

class CircuitBuilderSession extends GameSessionState {
  @override
  final CircuitBuilderEngine engine;
  @override
  late final List<Map<String, dynamic>> questions;

  // Tracks which component the learner placed for each blank in the current question.
  // Key: blank index, Value: component string.
  final Map<int, String> _placed = {};

  final String _uid;

  /// [pack] is the pre-loaded content pack JSON (see
  /// lib/features/games/core/content_pack_loader.dart), or null to fall
  /// back to the built-in demo circuits.
  CircuitBuilderSession(GameConfig config, String uid,
      {Map<String, dynamic>? pack})
      : engine = CircuitBuilderEngine(
          config,
          circuits: pack != null
              ? (pack['circuits'] as List).cast<Map<String, dynamic>>()
              : null,
        ),
        _uid = uid,
        super(config) {
    questions = engine.generateQuestions();
  }

  Map<int, String> get placed => Map.unmodifiable(_placed);

  void placeComponent(int blankIndex, String component) {
    _placed[blankIndex] = component;
    notifyListeners();
  }

  void clearPlacement(int blankIndex) {
    _placed.remove(blankIndex);
    notifyListeners();
  }

  bool get allBlanksFilled {
    final blanks = (currentQuestion?['blanks'] as List?)?.length ?? 0;
    return _placed.length >= blanks;
  }

  @override
  void submitAnswer(dynamic answer) {
    if (isFinished) return;
    final blanks =
        (currentQuestion?['blanks'] as List?)?.cast<Map<String, dynamic>>() ??
            [];
    final submitted = List.generate(blanks.length, (i) => _placed[i]);
    final done =
        recordAnswer(engine.checkAnswer(currentQuestion!, submitted).correct);
    _placed.clear();
    if (done) finishSession(_uid);
  }
}
