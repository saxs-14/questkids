import '../core/game_config.dart';
import '../core/game_session_state.dart';
import 'adventure_journey_config.dart';
import 'adventure_journey_engine.dart';

/// Possible states the droplet can be in after an answer.
enum DropletState { idle, advancing, bouncing }

class AdventureJourneySession extends GameSessionState {
  final String uid;

  /// [pack] is the pre-loaded content pack JSON (see
  /// lib/features/games/core/content_pack_loader.dart), or null to fall
  /// back to the built-in demo content.
  AdventureJourneySession(GameConfig config, this.uid,
      {Map<String, dynamic>? pack})
      : super(config) {
    _journeyConfig = pack != null
        ? AdventureJourneyConfig.fromPack(pack)
        : AdventureJourneyConfig.waterCycle(config);
    _engine = AdventureJourneyEngine(
      journeyConfig: _journeyConfig,
      config: config,
    );
    _questions = _engine.generateQuestions();
  }

  late final AdventureJourneyConfig _journeyConfig;
  late final AdventureJourneyEngine _engine;
  late final List<Map<String, dynamic>> _questions;

  @override
  AdventureJourneyEngine get engine => _engine;

  @override
  List<Map<String, dynamic>> get questions => _questions;

  // ── Adventure-specific state ───────────────────────────────────────────────

  DropletState _dropletState = DropletState.idle;
  String? _feedbackText;
  bool _feedbackIsCorrect = false;

  DropletState get dropletState => _dropletState;
  String? get feedbackText => _feedbackText;
  bool get feedbackIsCorrect => _feedbackIsCorrect;

  AdventureJourneyConfig get journeyConfig => _journeyConfig;

  JourneyStage get currentStage => _journeyConfig
      .stages[questionIndex.clamp(0, _journeyConfig.stages.length - 1)];

  // ── Answer handling ────────────────────────────────────────────────────────

  @override
  void submitAnswer(dynamic answer) {
    if (isFinished) return;

    final q = currentQuestion;
    if (q == null) return;

    final result = _engine.checkAnswer(q, answer);

    if (result.correct) {
      _feedbackText = q['correctFeedback'] as String;
      _feedbackIsCorrect = true;
      _dropletState = DropletState.advancing;
      notifyListeners();

      // Advance after animation delay
      Future.delayed(const Duration(milliseconds: 1000), () {
        _dropletState = DropletState.idle;
        _feedbackText = null;
        final done = recordAnswer(true);
        if (done) finishSession(uid);
      });
    } else {
      _feedbackText = q['wrongFeedback'] as String;
      _feedbackIsCorrect = false;
      _dropletState = DropletState.bouncing;
      notifyListeners();

      // Reset to idle — same question stays (no permanent fail)
      Future.delayed(const Duration(milliseconds: 900), () {
        _dropletState = DropletState.idle;
        _feedbackText = null;
        recordAnswer(
            false); // records the wrong attempt but does NOT advance stage
        // Restore questionIndex so player retries same stage
        notifyListeners();
      });
    }
  }

  // Override recordAnswer to prevent stage advance on wrong answer
  // We call super.recordAnswer only for the wrong-attempt count,
  // then roll back questionIndex.
  // Instead, track retry count separately.

  int _retryCount = 0;
  int get retryCount => _retryCount;

  @override
  bool recordAnswer(bool correct) {
    if (!correct) {
      _retryCount++;
      notifyListeners();
      return false; // never advance on wrong
    }
    _retryCount = 0;
    return super.recordAnswer(correct);
  }
}
