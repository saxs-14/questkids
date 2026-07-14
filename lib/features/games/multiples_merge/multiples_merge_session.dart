import '../core/game_config.dart';
import '../core/game_engine.dart';
import '../core/game_session_state.dart';
import 'multiples_merge_config.dart';
import 'multiples_merge_engine.dart';

/// State for Multiples Merge: tracks the active round, the player's connected
/// chain, scaffolding hints, and round progression. Each completed chain counts
/// as one "question" so XP/coins flow through the shared [finishSession].
class MultiplesMergeSession extends GameSessionState {
  final String uid;

  /// [pack] is the pre-loaded content pack JSON (see
  /// lib/features/games/core/content_pack_loader.dart), or null to fall
  /// back to the built-in grade-tuned demo content.
  MultiplesMergeSession(GameConfig config, this.uid,
      {Map<String, dynamic>? pack})
      : super(config) {
    _mergeConfig = pack != null
        ? MultiplesMergeConfig.fromPack(pack, config)
        : MultiplesMergeConfig.forGrade(config);
    _engine = MultiplesMergeEngine(mergeConfig: _mergeConfig, config: config);
    _questions = _engine.generateQuestions();
    _startRound();
  }

  late final MultiplesMergeConfig _mergeConfig;
  late final MultiplesMergeEngine _engine;
  late final List<Map<String, dynamic>> _questions;

  @override
  GameEngine get engine => _engine;

  @override
  List<Map<String, dynamic>> get questions => _questions;

  MultiplesMergeConfig get mergeConfig => _mergeConfig;

  // ── Round state ──────────────────────────────────────────────────────────
  MergeRound? _round;
  final List<int> _chain = [];
  final List<int> _merged = [];
  bool _merging = false;

  MergeRound? get round => _round;
  List<int> get chain => List.unmodifiable(_chain);
  List<int> get mergedCells => List.unmodifiable(_merged);
  bool get isMerging => _merging;

  int get table => _round?.mode == 'numeric' ? (_round?.table ?? 0) : 0;
  int get gridSize => _round?.gridSize ?? _mergeConfig.gridSize;
  int get chainLength => _round?.chainLength ?? _mergeConfig.chainLength;
  int get hintLevel => _mergeConfig.hintLevel;
  List<Object> get values => _round?.values ?? const [];

  /// The next multiple the learner needs to connect (numeric mode only).
  int get nextExpected => table * (_chain.length + 1);

  void _startRound() {
    _round = _engine.buildRound(
      roundIndex: questionIndex,
      totalRounds: config.questionCount,
    );
    _chain.clear();
    _merged.clear();
    _merging = false;
    notifyListeners();
  }

  /// Cells that currently form a valid next step (used for hints + validation).
  Set<int> get validNextCells {
    final r = _round;
    if (r == null || _merging) return {};
    if (r.mode == 'pairs') {
      if (_chain.length >= r.chainLength) return {};
      if (_chain.isEmpty) {
        return {for (int c = 0; c < r.values.length; c++) c};
      }
      final partner = r.pairPartner?[_chain.first];
      return partner == null ? {} : {partner};
    }
    final result = <int>{};
    if (_chain.isEmpty) {
      for (int c = 0; c < r.values.length; c++) {
        if (r.values[c] == table) result.add(c); // table × 1
      }
      return result;
    }
    if (_chain.length >= r.chainLength) return {};
    final last = _chain.last;
    for (int c = 0; c < r.values.length; c++) {
      if (_chain.contains(c)) continue;
      if (MultiplesMergeEngine.areAdjacent8(r.gridSize, last, c) &&
          r.values[c] == nextExpected) {
        result.add(c);
      }
    }
    return result;
  }

  /// Whether [cell] should glow as a learning hint, respecting hint level.
  /// The starting tile is always hinted; subsequent hints fade out at higher
  /// grades to build fluency.
  bool shouldGlow(int cell) {
    if (_merging) return false;
    if (_chain.isEmpty) return validNextCells.contains(cell);
    if (hintLevel < 1) return false;
    return validNextCells.contains(cell);
  }

  // ── Input ──────────────────────────────────────────────────────────────
  @override
  void submitAnswer(dynamic answer) {
    // Merge uses [onTileTouched]/[endDrag] for gesture input; this satisfies
    // the GameSessionState contract.
  }

  void onTileTouched(int cell) {
    final r = _round;
    if (r == null || isFinished || _merging) return;

    if (_chain.contains(cell)) {
      // Drag back over the previous tile to undo the last step.
      if (_chain.length >= 2 && cell == _chain[_chain.length - 2]) {
        _chain.removeLast();
        notifyListeners();
        return;
      }
      // Tapping the only selected tile again deselects it. In pairs mode
      // any tile is a valid first tap (unlike numeric mode, where only a
      // correct starting value is ever selectable), so a wrong first guess
      // must be reversible -- without this, picking a distractor as the
      // first tap permanently soft-locks the round (no cell is ever a
      // valid second tap for a distractor's pairPartner, which is null).
      if (_chain.length == 1 && cell == _chain.last) {
        _chain.removeLast();
        notifyListeners();
      }
      return;
    }

    if (validNextCells.contains(cell)) {
      _chain.add(cell);
      notifyListeners();
      if (_chain.length >= r.chainLength) _completeRound();
    }
  }

  /// Called when a drag ends. Incomplete chains reset gently (no penalty —
  /// this is a learning loop, not a test).
  void endDrag() {
    if (_round == null || isFinished || _merging) return;
    if (_chain.length < (chainLength) && _chain.isNotEmpty) {
      _chain.clear();
      notifyListeners();
    }
  }

  void _completeRound() {
    _merging = true;
    _merged
      ..clear()
      ..addAll(_chain);
    final done =
        recordAnswer(engine.checkAnswer(currentQuestion ?? const {}, true));
    notifyListeners();

    Future.delayed(const Duration(milliseconds: 750), () {
      if (done) {
        finishSession(uid, earlyWin: true);
      } else {
        _startRound();
      }
    });
  }
}
