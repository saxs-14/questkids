import '../core/game_config.dart';
import '../core/game_engine.dart';
import '../core/game_session_state.dart';
import 'sequence_builder_config.dart';
import 'sequence_builder_engine.dart';

enum SequencePhase { learn, ordering }

/// State for a drag-to-order sequencing game.
///
/// Recognition-before-recall: the session starts in [SequencePhase.learn]
/// (a labelled walkthrough), then moves to [SequencePhase.ordering] where the
/// learner places shuffled stages into the correct order. Each completed
/// ordering counts as one scored round.
class SequenceBuilderSession extends GameSessionState {
  final String uid;

  SequenceBuilderSession(GameConfig config, this.uid) : super(config) {
    _seqConfig = SequenceBuilderConfig.forGame(config);
    _engine = SequenceBuilderEngine(seqConfig: _seqConfig, config: config);
    _questions = _engine.generateQuestions();
    _resetTray();
  }

  late final SequenceBuilderConfig _seqConfig;
  late final SequenceBuilderEngine _engine;
  late final List<Map<String, dynamic>> _questions;

  @override
  GameEngine get engine => _engine;

  @override
  List<Map<String, dynamic>> get questions => _questions;

  @override
  int get totalQuestions => _seqConfig.rounds;

  SequenceBuilderConfig get seqConfig => _seqConfig;

  SequencePhase _phase = SequencePhase.learn;
  SequencePhase get phase => _phase;

  /// Stage indices (into the ordered [stages]) placed so far, in order.
  final List<int> _placed = [];
  // Tray holds the not-yet-placed stage indices, shuffled.
  final List<int> _tray = [];
  bool? _lastPlaceCorrect;
  bool _roundComplete = false;

  List<SequenceStage> get stages => _seqConfig.stages;
  List<int> get placed => List.unmodifiable(_placed);
  List<int> get tray => List.unmodifiable(_tray);
  bool? get lastPlaceCorrect => _lastPlaceCorrect;
  bool get roundComplete => _roundComplete;

  /// How many scene stages should be revealed (drives the animated backdrop).
  int get revealed =>
      _phase == SequencePhase.learn ? stages.length : _placed.length;

  void _resetTray() {
    _placed.clear();
    _tray
      ..clear()
      ..addAll(List.generate(stages.length, (i) => i)..shuffle());
    _lastPlaceCorrect = null;
    _roundComplete = false;
  }

  void startChallenge() {
    _phase = SequencePhase.ordering;
    _resetTray();
    notifyListeners();
  }

  @override
  void submitAnswer(dynamic answer) {
    // Sequencing uses [placeStage]; this satisfies the contract.
  }

  /// Try to place [stageIndex] into the next slot. Correct only if it is the
  /// next stage in order. Wrong attempts are rejected gently (no penalty).
  void placeStage(int stageIndex) {
    if (_phase != SequencePhase.ordering || isFinished || _roundComplete) return;

    if (stageIndex == _placed.length) {
      _placed.add(stageIndex);
      _tray.remove(stageIndex);
      _lastPlaceCorrect = true;
      notifyListeners();

      if (_placed.length == stages.length) {
        _roundComplete = true;
        final done = recordAnswer(true);
        notifyListeners();
        Future.delayed(const Duration(milliseconds: 1100), () {
          if (done) {
            finishSession(uid, earlyWin: true);
          } else {
            _resetTray();
            notifyListeners();
          }
        });
      }
    } else {
      _lastPlaceCorrect = false;
      notifyListeners();
      Future.delayed(const Duration(milliseconds: 500), () {
        _lastPlaceCorrect = null;
        notifyListeners();
      });
    }
  }
}
