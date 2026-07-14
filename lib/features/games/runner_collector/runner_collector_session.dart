import 'dart:async';

import '../core/game_config.dart';
import '../core/game_session_state.dart';
import 'runner_collector_config.dart';
import 'runner_collector_engine.dart';

class RunnerCollectorSession extends GameSessionState {
  final String uid;

  RunnerCollectorSession(GameConfig config, this.uid,
      {Map<String, dynamic>? pack})
      : super(config) {
    _runnerConfig = pack != null
        ? RunnerCollectorConfig.fromPack(pack)
        : RunnerCollectorConfig.grammarHero(config);
    _engine = RunnerCollectorEngine(
      runnerConfig: _runnerConfig,
      config: config,
    );
    _questions = _engine.generateQuestions();
    _hearts = _runnerConfig.heartsStart;
  }

  late final RunnerCollectorConfig _runnerConfig;
  late final RunnerCollectorEngine _engine;
  late final List<Map<String, dynamic>> _questions;

  @override
  RunnerCollectorEngine get engine => _engine;

  @override
  List<Map<String, dynamic>> get questions => _questions;

  // ── Runner state ───────────────────────────────────────────────────────────

  int _hearts = 3;
  int _levelIndex = 0;
  int _wordsCollected = 0;
  int _playerLane = 1; // 0=left, 1=center, 2=right
  bool? _lastCollectionCorrect;
  final List<LaneWord> _activeWords = [];
  Timer? _spawnTimer;

  /// Minimum horizontal gap (in xPosition fraction) between two words in the
  /// same lane. A new word only spawns into a lane once the previous one has
  /// travelled at least this far — guarantees words never stack or overlap.
  static const double _laneGap = 0.34;
  static const int _laneCount = 3;

  int get hearts => _hearts;
  int get levelIndex => _levelIndex;
  int get playerLane => _playerLane;
  int get wordsCollected => _wordsCollected;
  bool? get lastCollectionCorrect => _lastCollectionCorrect;
  List<LaneWord> get activeWords => List.unmodifiable(_activeWords);

  GrammarLevel get currentLevel => _runnerConfig
      .levels[_levelIndex.clamp(0, _runnerConfig.levels.length - 1)];

  String get missionLabel => currentLevel.missionLabel;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void startSession() {
    super.startSession();
    _spawnOne();
    // Steady cadence; each call only fills a lane that has room, so spacing is
    // always preserved regardless of how fast the timer fires.
    _spawnTimer = Timer.periodic(const Duration(milliseconds: 850), (_) {
      if (!isFinished) _spawnOne();
    });
  }

  @override
  void dispose() {
    _spawnTimer?.cancel();
    super.dispose();
  }

  // ── Player input ───────────────────────────────────────────────────────────

  void moveLeft() {
    if (_playerLane > 0) {
      _playerLane--;
      _tryCollect();
      notifyListeners();
    }
  }

  void moveRight() {
    if (_playerLane < 2) {
      _playerLane++;
      _tryCollect();
      notifyListeners();
    }
  }

  void tapLane(int lane) {
    _playerLane = lane.clamp(0, 2);
    _tryCollect();
    notifyListeners();
  }

  // ── Answer submission — called by the game tick or player tap ──────────────

  @override
  void submitAnswer(dynamic answer) {
    // Runner does not use submitAnswer directly;
    // collection is triggered by moveLeft/moveRight/tapLane.
  }

  // ── Word tick (called by the game's AnimationController every frame) ───────

  /// Advance word positions. [delta] is fraction of screen width per frame.
  void tickWords(double delta) {
    if (isFinished) return;
    bool changed = false;

    for (final w in _activeWords) {
      if (w.collected) continue;
      w.xPosition += delta * currentLevel.scrollSpeed;
      changed = true;

      // Word passed player without collection — miss penalty
      if (w.xPosition > 0.85 && !w.collected) {
        final target = currentLevel.targetClass;
        if (_engine.isCorrectCollection(w.wordClass, target)) {
          // Player missed a target word → lose heart
          w.collected = true;
          _loseHeart();
          changed = true;
        } else {
          w.collected = true; // harmless miss
          changed = true;
        }
      }
    }

    _activeWords.removeWhere((w) => w.collected && w.xPosition > 0.9);

    if (changed) notifyListeners();
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  void _tryCollect() {
    if (isFinished) return;
    final target = currentLevel.targetClass;

    // Find a word in the player's lane that is "reachable"
    for (final w in _activeWords) {
      if (w.collected || w.lane != _playerLane) continue;
      if (w.xPosition < 0.3 || w.xPosition > 0.75) continue;

      w.collected = true;
      final correct = _engine.isCorrectCollection(w.wordClass, target);
      _lastCollectionCorrect = correct;

      if (correct) {
        _wordsCollected++;
        recordAnswer(engine.checkAnswer(currentQuestion ?? const {}, true));

        // Advance level every 8 correct collections
        if (_wordsCollected > 0 && _wordsCollected % 8 == 0) {
          _advanceLevel();
        }
      } else {
        _loseHeart();
        recordAnswer(engine.checkAnswer(currentQuestion ?? const {}, false));
      }

      // Clear flash after 500ms
      Future.delayed(const Duration(milliseconds: 500), () {
        _lastCollectionCorrect = null;
        notifyListeners();
      });
      break;
    }
  }

  void _loseHeart() {
    _hearts = (_hearts - 1).clamp(0, _runnerConfig.heartsStart);
    notifyListeners();
    if (_hearts <= 0) {
      _spawnTimer?.cancel();
      finishSession(uid, earlyWin: false);
    }
  }

  void _advanceLevel() {
    if (_levelIndex >= _runnerConfig.levels.length - 1) {
      // Completed all levels
      _spawnTimer?.cancel();
      // Use recordAnswer to complete the session
      while (questionIndex < totalQuestions) {
        recordAnswer(engine.checkAnswer(currentQuestion ?? const {}, true));
      }
      finishSession(uid, earlyWin: true);
      return;
    }
    _levelIndex++;
    notifyListeners();
  }

  /// Spawn exactly one word into a lane that currently has room near the right
  /// edge. If every lane is still occupied close to the spawn point, nothing
  /// spawns this cycle — preventing overlapping/stacked words.
  void _spawnOne() {
    if (isFinished) return;

    // Eligible = lane whose nearest (smallest xPosition) live word has already
    // travelled past _laneGap, or which is empty.
    final eligible = <int>[];
    for (int lane = 0; lane < _laneCount; lane++) {
      final laneWords =
          _activeWords.where((w) => w.lane == lane && !w.collected);
      if (laneWords.isEmpty) {
        eligible.add(lane);
      } else {
        final nearest =
            laneWords.map((w) => w.xPosition).reduce((a, b) => a < b ? a : b);
        if (nearest >= _laneGap) eligible.add(lane);
      }
    }
    if (eligible.isEmpty) return;

    eligible.shuffle();
    final lane = eligible.first;
    final picked = _engine.randomWord(currentLevel, targetBias: 0.5);

    _activeWords.add(LaneWord(
      word: picked['word'] as String,
      wordClass: picked['wordClass'] as String,
      lane: lane,
      xPosition: 0.0,
    ));
    notifyListeners();
  }
}
