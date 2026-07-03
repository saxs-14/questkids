import '../core/game_config.dart';
import '../core/game_session_state.dart';
import 'budget_builder_engine.dart';

class BudgetBuilderSession extends GameSessionState {
  @override
  final BudgetBuilderEngine engine;
  @override
  late final List<Map<String, dynamic>> questions;

  final Map<String, String> _categorised = {};

  final String _uid;

  /// [pack] is the pre-loaded content pack JSON (see
  /// lib/features/games/core/content_pack_loader.dart), or null to fall
  /// back to the built-in demo scenarios.
  BudgetBuilderSession(GameConfig config, String uid,
      {Map<String, dynamic>? pack})
      : engine = BudgetBuilderEngine(
          config,
          scenarios: pack != null
              ? (pack['scenarios'] as List).cast<Map<String, dynamic>>()
              : null,
        ),
        _uid = uid,
        super(config) {
    questions = engine.generateQuestions();
  }

  Map<String, String> get categorised => Map.unmodifiable(_categorised);

  List<Map<String, dynamic>> get currentItems {
    return (currentQuestion?['items'] as List?)?.cast<Map<String, dynamic>>() ??
        [];
  }

  void categorise(String itemName, String category) {
    _categorised[itemName] = category;
    notifyListeners();
  }

  bool get allCategorised =>
      currentItems.every((item) => _categorised.containsKey(item['name']));

  @override
  int get correctCount {
    int count = 0;
    for (final item in currentItems) {
      if (_categorised[item['name']] == item['category']) count++;
    }
    return count;
  }

  @override
  void submitAnswer(dynamic answer) {
    if (isFinished) return;
    final done = recordAnswer(engine
        .checkAnswer(currentQuestion!, Map<String, String>.from(_categorised))
        .correct);
    _categorised.clear();
    if (done) finishSession(_uid);
  }
}
