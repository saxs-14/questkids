import 'dart:math';

import '../core/game_config.dart';
import '../core/game_engine.dart';
import '../core/game_session_state.dart';
import 'explorer_map_config.dart';
import 'explorer_map_engine.dart';

/// The three scaffolded difficulty modes for the explorer map.
enum ExplorerMode { learn, easy, hard }

/// SA Provinces Explorer session.
///
/// Three modes build from recognition to recall:
///  • **learn**  – free exploration; tap each province to discover its name,
///    capital and a fun fact (every discovery earns XP).
///  • **easy**   – a province is highlighted on the map → pick its name.
///  • **hard**   – given a name/capital → tap the correct province on the map
///    (a hint can dim the non-answers).
class ExplorerMapSession extends GameSessionState {
  final String uid;
  final ExplorerMode mode;

  /// [pack] is the pre-loaded content pack JSON (see
  /// lib/features/games/core/content_pack_loader.dart), or null to fall
  /// back to the built-in demo content.
  ExplorerMapSession(GameConfig config, this.uid, {Map<String, dynamic>? pack})
      : mode = _modeFrom(config),
        super(config) {
    _mapConfig = pack != null
        ? ExplorerMapConfig.fromPack(pack)
        : ExplorerMapConfig.saProvinces(config);
    _engine = ExplorerMapEngine(mapConfig: _mapConfig, config: config);
    _questions = _buildQuestions();
  }

  static ExplorerMode _modeFrom(GameConfig c) {
    switch (c.extras['mode']) {
      case 'learn':
        return ExplorerMode.learn;
      case 'hard':
        return ExplorerMode.hard;
      default:
        return ExplorerMode.easy;
    }
  }

  late final ExplorerMapConfig _mapConfig;
  late final ExplorerMapEngine _engine;
  late final List<Map<String, dynamic>> _questions;
  final Random _rng = Random();

  @override
  ExplorerMapEngine get engine => _engine;

  @override
  List<Map<String, dynamic>> get questions => _questions;

  ExplorerMapConfig get mapConfig => _mapConfig;

  // ── Shared feedback state ────────────────────────────────────────────────
  String? _selectedId;
  bool? _lastAnswerCorrect;
  String? _feedbackFact;
  bool _awaitingNext = false;

  String? get selectedId => _selectedId;
  bool? get lastAnswerCorrect => _lastAnswerCorrect;
  String? get feedbackFact => _feedbackFact;
  bool get awaitingNext => _awaitingNext;

  // ── Learn-mode state ─────────────────────────────────────────────────────
  final Set<String> _discovered = {};
  ProvincePin? _infoProvince;
  Set<String> get discovered => Set.unmodifiable(_discovered);
  ProvincePin? get infoProvince => _infoProvince;

  // ── Hard-mode hint ───────────────────────────────────────────────────────
  bool _hintActive = false;
  Set<String>? _litCache; // stable hint set, computed once per activation
  bool get hintActive => _hintActive;

  // ── Derived ──────────────────────────────────────────────────────────────
  String get prompt => (currentQuestion?['prompt'] as String?) ?? '';

  ProvincePin? get currentCorrectProvince {
    final q = currentQuestion;
    if (q == null) return null;
    return _engine.getProvince(q['correctId'] as String);
  }

  List<ProvincePin> get currentOptions {
    final q = currentQuestion;
    if (q == null) return [];
    return ((q['optionIds'] as List?) ?? const [])
        .map((id) => _engine.getProvince(id as String))
        .whereType<ProvincePin>()
        .toList();
  }

  /// In hard mode with the hint on, only the correct + 3 other pins stay lit.
  /// Computed once per activation (cached) so the set doesn't flicker on
  /// rebuilds.
  Set<String> get litProvinceIds {
    if (mode != ExplorerMode.hard || !_hintActive) {
      return _mapConfig.provinces.map((p) => p.id).toSet();
    }
    return _litCache ?? _mapConfig.provinces.map((p) => p.id).toSet();
  }

  // ── Question generation per mode ─────────────────────────────────────────
  List<Map<String, dynamic>> _buildQuestions() {
    final provinces = List<ProvincePin>.from(_mapConfig.provinces)
      ..shuffle(_rng);

    switch (mode) {
      case ExplorerMode.learn:
        return provinces.map((p) => {'correctId': p.id}).toList();

      case ExplorerMode.easy:
        return provinces.take(8).map((p) {
          return {
            'correctId': p.id,
            'optionIds': _nameOptions(p),
            'prompt': 'Which province is highlighted on the map?',
            'feedbackFact': p.facts.isNotEmpty ? p.facts.first : p.name,
          };
        }).toList();

      case ExplorerMode.hard:
        return provinces.take(8).map((p) {
          final byCapital = p.capital.isNotEmpty && _rng.nextBool();
          return {
            'correctId': p.id,
            'prompt': byCapital
                ? 'Tap the province whose capital is ${p.capital}.'
                : 'Tap ${p.name} on the map.',
            'feedbackFact': p.facts.isNotEmpty ? p.facts.first : p.name,
          };
        }).toList();
    }
  }

  List<String> _nameOptions(ProvincePin correct) {
    final others = _mapConfig.provinces
        .where((p) => p.id != correct.id)
        .toList()
      ..shuffle(_rng);
    final opts = [correct.id, ...others.take(3).map((p) => p.id)]
      ..shuffle(_rng);
    return opts;
  }

  // ── Input ──────────────────────────────────────────────────────────────
  /// Learn mode: reveal a province's info and count it as discovered.
  void discover(String provinceId) {
    if (mode != ExplorerMode.learn || isFinished) return;
    _infoProvince = _engine.getProvince(provinceId);
    if (_discovered.add(provinceId)) {
      final done =
          recordAnswer(const GameAnswerResult(correct: true, xpDelta: 10));
      if (done) {
        notifyListeners();
        finishSession(uid, earlyWin: true);
        return;
      }
    }
    notifyListeners();
  }

  void useHint() {
    if (mode == ExplorerMode.hard && !_awaitingNext && _litCache == null) {
      final correct = currentQuestion?['correctId'] as String?;
      final ids = _mapConfig.provinces.map((p) => p.id).toList()..shuffle(_rng);
      final keep = <String>{if (correct != null) correct};
      for (final id in ids) {
        if (keep.length >= 4) break;
        keep.add(id);
      }
      _litCache = keep;
      _hintActive = true;
      notifyListeners();
    }
  }

  @override
  void submitAnswer(dynamic answer) {
    if (_awaitingNext || isFinished || mode == ExplorerMode.learn) return;
    final provinceId = answer as String;
    _selectedId = provinceId;

    final q = currentQuestion!;
    final result = _engine.checkAnswer(q, provinceId,
        elapsedThresholdSeconds: elapsedSeconds);

    _lastAnswerCorrect = result.correct;
    _feedbackFact = q['feedbackFact'] as String?;
    _awaitingNext = true;
    notifyListeners();

    Future.delayed(const Duration(milliseconds: 1700), () {
      final done = recordAnswer(result);
      _selectedId = null;
      _lastAnswerCorrect = null;
      _feedbackFact = null;
      _awaitingNext = false;
      _hintActive = false;
      _litCache = null;
      if (done) {
        finishSession(uid);
      } else {
        notifyListeners();
      }
    });
  }
}
