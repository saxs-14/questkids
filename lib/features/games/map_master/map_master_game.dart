import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/game_session_model.dart';
import '../core/game_config.dart';
import '../core/game_session_persistence.dart';

// ────────────────────────────────────────────────────────────────────────────
// Map Master — Grade 4 Social Sciences: map skills (compass directions,
// map symbols, grid references, using maps)
//
// NOTE: this is a DIFFERENT engine from explorer_map/ (engineType
// 'explorerMap'), which is a shared generic engine still used by 6 other
// catalog entries. This engine (engineType 'mapMaster') is registered ONLY
// against ss_g4_maps.
//
// 4 Zones (5 questions each = 20 total):
//   1. Compass Directions — tap the correct point on an 8-point compass
//      rose; a needle rotates and locks onto your answer
//   2. Map Symbols          — recall MCQ about what map symbols mean
//   3. Grid References      — read an alphanumeric grid reference (e.g.
//      "B2") and tap the matching cell on a lettered/numbered map grid
//   4. Using Maps           — recall MCQ about map types, scale and legends
//
// Structurally distinct from every prior engine: Zone 1's compass rose is
// the first radial dial where tapping rotates a physical needle to lock
// onto a cardinal/intercardinal direction, and Zone 3's grid is read by
// coordinate label (letter+number) rather than built by movement or
// sequencing, unlike Coding Adventure's maze.
// Architecture: fully self-contained StatefulWidget.
// ────────────────────────────────────────────────────────────────────────────

enum _Phase { intro, playing, correct, wrong, streak, zoneDone, victory }

enum _Kind { compass, grid, simple }

const _compassPoints = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
const _compassDegrees = [0, 45, 90, 135, 180, 225, 270, 315];
const _compassFull = {
  'N': 'North',
  'NE': 'North-East',
  'E': 'East',
  'SE': 'South-East',
  'S': 'South',
  'SW': 'South-West',
  'W': 'West',
  'NW': 'North-West',
};

class _CompassQ {
  final String prompt;
  final String correct; // one of _compassPoints
  const _CompassQ({required this.prompt, required this.correct});
}

class _GridQ {
  final String prompt;
  final int correctCol; // 0..3 => A..D
  final int correctRow; // 0..3 => 1..4
  const _GridQ({required this.prompt, required this.correctCol, required this.correctRow});
}

class _SimpleQ {
  final String prompt;
  final List<String> choices; // [0] correct
  const _SimpleQ({required this.prompt, required this.choices});
}

class _Zone {
  final String name;
  final _Kind kind;
  final List<_CompassQ> compass;
  final List<_GridQ> grid;
  final List<_SimpleQ> simple;
  const _Zone.compass(this.name, this.compass)
      : kind = _Kind.compass,
        grid = const [],
        simple = const [];
  const _Zone.grid(this.name, this.grid)
      : kind = _Kind.grid,
        compass = const [],
        simple = const [];
  const _Zone.simple(this.name, this.simple)
      : kind = _Kind.simple,
        compass = const [],
        grid = const [];

  int get length => switch (kind) {
        _Kind.compass => compass.length,
        _Kind.grid => grid.length,
        _Kind.simple => simple.length,
      };
}

class MapMasterGame extends StatefulWidget {
  final GameConfig config;
  final dynamic user;
  const MapMasterGame({super.key, required this.config, this.user});

  @override
  State<MapMasterGame> createState() => _MMState();
}

class _MMState extends State<MapMasterGame> with TickerProviderStateMixin {
  static const _zones = [
    _Zone.compass('Compass Directions', [
      _CompassQ(prompt: 'The sun rises in the...?', correct: 'E'),
      _CompassQ(prompt: 'The sun sets in the...?', correct: 'W'),
      _CompassQ(
          prompt: 'If you are facing North and turn to face the opposite direction, you face...?',
          correct: 'S'),
      _CompassQ(prompt: 'Halfway between North and East is called...?', correct: 'NE'),
      _CompassQ(prompt: 'Halfway between South and West is called...?', correct: 'SW'),
    ]),
    _Zone.simple('Map Symbols', [
      _SimpleQ(
          prompt: 'What does this map symbol usually show: 🏫',
          choices: ['A school', 'A hospital', 'A river']),
      _SimpleQ(
          prompt: 'What does 🏥 usually show on a map?',
          choices: ['A hospital', 'A forest', 'A bridge']),
      _SimpleQ(
          prompt: 'A wavy blue line on a map usually shows a...?',
          choices: ['River', 'Road', 'Railway line']),
      _SimpleQ(
          prompt: 'What is the KEY (or legend) on a map used for?',
          choices: [
            'Explaining what the symbols mean',
            'Locking the map',
            'Showing the weather'
          ]),
      _SimpleQ(
          prompt: 'A green shaded area on a map often shows...?',
          choices: ['Forest or vegetation', 'A city', 'A desert']),
    ]),
    _Zone.grid('Grid References', [
      _GridQ(prompt: 'Find grid reference B2 and tap it.', correctCol: 1, correctRow: 1),
      _GridQ(prompt: 'Find grid reference D4 and tap it.', correctCol: 3, correctRow: 3),
      _GridQ(prompt: 'Find grid reference A3 and tap it.', correctCol: 0, correctRow: 2),
      _GridQ(prompt: 'Find grid reference C1 and tap it.', correctCol: 2, correctRow: 0),
      _GridQ(prompt: 'Find grid reference B4 and tap it.', correctCol: 1, correctRow: 3),
    ]),
    _Zone.simple('Using Maps', [
      _SimpleQ(
          prompt: 'A map that shows mountains, rivers and natural features is called a...?',
          choices: ['Physical map', 'Political map', 'Weather map']),
      _SimpleQ(
          prompt: 'A map that shows countries, provinces and borders is called a...?',
          choices: ['Political map', 'Physical map', 'Road map']),
      _SimpleQ(
          prompt: 'The SCALE on a map helps you work out...?',
          choices: [
            'Real distances between places',
            'The colour of the map',
            'The name of the mapmaker'
          ]),
      _SimpleQ(
          prompt: 'Why do we use maps?',
          choices: [
            'To find our way and understand a place',
            'To tell the time',
            'To predict the weather'
          ]),
      _SimpleQ(
          prompt: 'A compass on a map helps you know...?',
          choices: [
            'Which direction is which',
            'How far away something is',
            'How old the map is'
          ]),
    ]),
  ];

  static const _wrongReactions = [
    "Not quite -- read it again!",
    'Hmm, try tracing it more carefully!',
    'Almost -- take another look!',
  ];

  static const _bg1 = Color(0xFF0B2027);
  static const _bg2 = Color(0xFF163B44);
  static const _card = Color(0xFF1F5A63);
  static const _sand = Color(0xFFE8C170);

  late AnimationController _ambientCtrl;
  late AnimationController _fadeCtrl;
  late AnimationController _flashCtrl;
  late AnimationController _burstCtrl;
  late AnimationController _shakeCtrl;
  late AnimationController _needleCtrl;

  late Animation<double> _ambientAnim;
  late Animation<double> _fadeAnim;
  late Animation<double> _flashAnim;
  late Animation<double> _burstAnim;
  late Animation<double> _shakeAnim;

  int _zoneIdx = 0;
  int _qIdx = 0;
  int _correctCount = 0;
  int _streak = 0;
  int _totalXP = 0;

  _Phase _phase = _Phase.intro;
  int? _selectedIndex;
  String? _selectedCompassPoint;
  double _needleFromDeg = 0;
  double _needleToDeg = 0;
  bool? _lastPickCorrect;
  int? _pickedCol;
  int? _pickedRow;

  String _wrongReaction = '';

  final _rng = math.Random();

  String get _uid => (widget.user?.uid as String?) ?? '';

  int get _totalQuestions => _zones.fold<int>(0, (sum, z) => sum + z.length);

  final List<Timer> _pendingTimers = [];

  void _delayed(int ms, VoidCallback callback) {
    late final Timer timer;
    timer = Timer(Duration(milliseconds: ms), () {
      _pendingTimers.remove(timer);
      if (mounted) callback();
    });
    _pendingTimers.add(timer);
  }

  @override
  void initState() {
    super.initState();
    _initAnims();
    _delayed(700, _startGame);
  }

  void _initAnims() {
    _ambientCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 6))
      ..repeat(reverse: true);
    _ambientAnim = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _ambientCtrl, curve: Curves.easeInOut));

    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);

    _flashCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _flashAnim = CurvedAnimation(parent: _flashCtrl, curve: Curves.easeOut);

    _burstCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600));
    _burstAnim = CurvedAnimation(parent: _burstCtrl, curve: Curves.easeOut);

    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _shakeAnim = CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut);

    _needleCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
  }

  @override
  void dispose() {
    for (final timer in List<Timer>.from(_pendingTimers)) {
      timer.cancel();
    }
    _pendingTimers.clear();
    _ambientCtrl.dispose();
    _fadeCtrl.dispose();
    _flashCtrl.dispose();
    _burstCtrl.dispose();
    _shakeCtrl.dispose();
    _needleCtrl.dispose();
    super.dispose();
  }

  void _startGame() {
    setState(() {
      _zoneIdx = 0;
      _qIdx = 0;
      _correctCount = 0;
      _streak = 0;
      _totalXP = 0;
      _phase = _Phase.playing;
      _selectedIndex = null;
    });
    _setupCurrentQuestion();
    _fadeCtrl.forward(from: 0);
  }

  void _setupCurrentQuestion() {
    _selectedCompassPoint = null;
    _lastPickCorrect = null;
    _pickedCol = null;
    _pickedRow = null;
    _needleFromDeg = 0;
    _needleToDeg = 0;
    _needleCtrl.value = 0;
  }

  void _onSimpleAnswer(int index) {
    if (_phase != _Phase.playing) return;
    final isCorrect = index == 0;
    setState(() => _selectedIndex = index);
    _applyAnswerResult(isCorrect);
  }

  void _onCompassTap(String point) {
    if (_phase != _Phase.playing) return;
    final q = _zones[_zoneIdx].compass[_qIdx];
    final isCorrect = point == q.correct;

    final fromIdx = _compassPoints.indexOf(_selectedCompassPoint ?? 'N');
    final toIdx = _compassPoints.indexOf(point);
    _needleFromDeg = _compassDegrees[fromIdx].toDouble();
    var toDeg = _compassDegrees[toIdx].toDouble();
    // Take the shorter rotation path.
    var delta = toDeg - _needleFromDeg;
    if (delta > 180) delta -= 360;
    if (delta < -180) delta += 360;
    _needleToDeg = _needleFromDeg + delta;

    setState(() => _selectedCompassPoint = point);
    _needleCtrl.forward(from: 0);
    _applyAnswerResult(isCorrect);
  }

  void _onGridTap(int col, int row) {
    if (_phase != _Phase.playing) return;
    final q = _zones[_zoneIdx].grid[_qIdx];
    final isCorrect = col == q.correctCol && row == q.correctRow;
    setState(() {
      _pickedCol = col;
      _pickedRow = row;
    });
    _applyAnswerResult(isCorrect);
  }

  void _applyAnswerResult(bool isCorrect) {
    setState(() {
      _lastPickCorrect = isCorrect;
      if (isCorrect) {
        _correctCount++;
        _streak++;
        _totalXP += 10;
      } else {
        _streak = 0;
        _totalXP += 2;
        _wrongReaction = _wrongReactions[_rng.nextInt(_wrongReactions.length)];
      }
      _phase = isCorrect ? _Phase.correct : _Phase.wrong;
    });

    if (isCorrect) {
      _flashCtrl.forward(from: 0);
      final isStreak = _streak > 0 && _streak % 3 == 0;
      if (isStreak) {
        _delayed(300, () {
          setState(() => _phase = _Phase.streak);
          _burstCtrl.forward(from: 0);
          _delayed(1600, _advance);
        });
      } else {
        _delayed(1200, _advance);
      }
    } else {
      _shakeCtrl.forward(from: 0);
      _delayed(1800, _advance);
    }
  }

  void _advance() {
    if (!mounted) return;
    final zone = _zones[_zoneIdx];
    final next = _qIdx + 1;

    if (next >= zone.length) {
      if (_zoneIdx + 1 >= _zones.length) {
        _persistSession();
        setState(() => _phase = _Phase.victory);
      } else {
        setState(() => _phase = _Phase.zoneDone);
        _delayed(2000, () {
          setState(() {
            _zoneIdx++;
            _qIdx = 0;
            _selectedIndex = null;
            _phase = _Phase.playing;
          });
          _setupCurrentQuestion();
          _fadeCtrl.forward(from: 0);
        });
      }
    } else {
      setState(() {
        _qIdx = next;
        _selectedIndex = null;
        _phase = _Phase.playing;
      });
      _setupCurrentQuestion();
      _fadeCtrl.forward(from: 0);
    }
  }

  void _persistSession() {
    final total = _totalQuestions;
    final accuracy = total > 0 ? _correctCount / total : 0.0;
    final isPerfect = _correctCount == total;
    final isWin = _correctCount > total / 2;
    var xp = _totalXP;
    if (isPerfect) {
      xp += 100;
    } else if (isWin) {
      xp += 50;
    }
    setState(() => _totalXP = xp);

    final uid = _uid;
    if (uid.isEmpty) return;
    final session = GameSessionModel(
      id: const Uuid().v4(),
      uid: uid,
      grade: widget.config.grade,
      subject: widget.config.subject,
      engineType: widget.config.engineType,
      score: (accuracy * 100).round(),
      xpEarned: xp,
      coinsEarned: xp ~/ 10,
      accuracy: accuracy,
      timeTakenSeconds: 0,
      completedAt: DateTime.now(),
      result: isWin ? 'win' : 'complete',
      metadata: {
        'topicId': widget.config.topicId,
        'subtopicId': widget.config.subtopicId,
        'correctCount': _correctCount,
        'totalQuestions': total,
      },
    );
    persistGameSession(session);
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_phase == _Phase.intro) {
      return const _IntroScreen();
    }
    if (_phase == _Phase.victory) {
      return _VictoryScreen(
        correctCount: _correctCount,
        total: _totalQuestions,
        totalXP: _totalXP,
        onReplay: _startGame,
        onExit: () => Navigator.of(context).pop(),
      );
    }

    final zone = _zones[_zoneIdx];
    final total = _totalQuestions;
    final completedSteps =
        _zones.take(_zoneIdx).fold<int>(0, (sum, z) => sum + z.length) + _qIdx;
    final revealed = _phase == _Phase.correct || _phase == _Phase.wrong;

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_bg1, _bg2],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _ambientAnim,
              builder: (context, _) =>
                  CustomPaint(painter: _DottedMapBgPainter(_ambientAnim.value)),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _MapHeader(
                  zoneName: zone.name,
                  zoneIdx: _zoneIdx,
                  totalZones: _zones.length,
                  completedSteps: completedSteps,
                  totalSteps: total,
                ),
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: switch (zone.kind) {
                        _Kind.compass => _buildCompassQuestion(zone.compass[_qIdx]),
                        _Kind.grid => _buildGridQuestion(zone.grid[_qIdx]),
                        _Kind.simple => _buildSimpleQuestion(zone.simple[_qIdx], revealed),
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_phase == _Phase.correct)
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _flashAnim,
                builder: (context, _) => Opacity(
                  opacity: (1 - _flashAnim.value).clamp(0.0, 1.0) * 0.3,
                  child: Container(color: _sand),
                ),
              ),
            ),
          if (_phase == _Phase.streak)
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _burstAnim,
                builder: (context, _) => CustomPaint(
                  painter: _SparkleShowerPainter(_burstAnim.value),
                  size: Size.infinite,
                ),
              ),
            ),
          if (_phase == _Phase.zoneDone)
            _ZoneDoneOverlay(
              completedZoneName: zone.name,
              nextZoneName: _zoneIdx + 1 < _zones.length ? _zones[_zoneIdx + 1].name : null,
            ),
        ],
      ),
    );
  }

  Widget _buildCompassQuestion(_CompassQ q) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Text(
          q.prompt,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: 240,
          height: 240,
          child: AnimatedBuilder(
            animation: _needleCtrl,
            builder: (context, _) {
              final t = Curves.easeOutBack.transform(_needleCtrl.value);
              final currentDeg = _needleFromDeg + (_needleToDeg - _needleFromDeg) * t;
              return Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF0A1A20),
                      border: Border.all(color: Colors.white24, width: 2),
                    ),
                  ),
                  // Needle
                  Transform.rotate(
                    angle: currentDeg * math.pi / 180,
                    child: Container(
                      width: 6,
                      height: 90,
                      decoration: BoxDecoration(
                        color: _selectedCompassPoint == null
                            ? Colors.white54
                            : (_lastPickCorrect == true ? const Color(0xFF4CAF7D) : const Color(0xFFE05656)),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  Container(
                    width: 14,
                    height: 14,
                    decoration: const BoxDecoration(color: _sand, shape: BoxShape.circle),
                  ),
                  // 8 tappable points
                  for (var i = 0; i < _compassPoints.length; i++)
                    _compassPointButton(i, q),
                ],
              );
            },
          ),
        ),
        if (_phase == _Phase.wrong)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              '$_wrongReaction The answer was ${_compassFull[q.correct]}.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _compassPointButton(int i, _CompassQ q) {
    final deg = _compassDegrees[i].toDouble();
    final rad = (deg - 90) * math.pi / 180;
    const radius = 95.0;
    final dx = radius * math.cos(rad);
    final dy = radius * math.sin(rad);
    final point = _compassPoints[i];
    final revealed = _phase == _Phase.correct || _phase == _Phase.wrong;
    final isCorrectPoint = point == q.correct;
    final isPicked = point == _selectedCompassPoint;

    Color fill = _card;
    if (revealed && isCorrectPoint) fill = const Color(0xFF4CAF7D);
    if (revealed && isPicked && !isCorrectPoint) fill = const Color(0xFFE05656);

    return Transform.translate(
      offset: Offset(dx, dy),
      child: GestureDetector(
        onTap: () => _onCompassTap(point),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
            border: Border.all(color: _sand, width: 1.5),
          ),
          alignment: Alignment.center,
          child: Text(point,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }

  Widget _buildGridQuestion(_GridQ q) {
    const cellSize = 62.0;
    const cols = ['A', 'B', 'C', 'D'];
    final revealed = _phase == _Phase.correct || _phase == _Phase.wrong;

    return Column(
      children: [
        const SizedBox(height: 8),
        Text(
          q.prompt,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 22),
            for (final c in cols)
              SizedBox(
                  width: cellSize,
                  child: Text(c,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700))),
          ],
        ),
        for (var row = 0; row < 4; row++)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                  width: 22,
                  child: Text('${row + 1}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700))),
              for (var col = 0; col < 4; col++)
                _buildGridCell(col, row, q, revealed, cellSize),
            ],
          ),
        if (_phase == _Phase.wrong)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              '$_wrongReaction Correct: ${cols[q.correctCol]}${q.correctRow + 1}.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildGridCell(int col, int row, _GridQ q, bool revealed, double cellSize) {
    final isCorrectCell = col == q.correctCol && row == q.correctRow;
    final isPicked = col == _pickedCol && row == _pickedRow;

    Color fill = const Color(0xFF0A1A20);
    if (revealed && isCorrectCell) fill = const Color(0xFF4CAF7D);
    if (revealed && isPicked && !isCorrectCell) fill = const Color(0xFFE05656);

    return GestureDetector(
      onTap: () => _onGridTap(col, row),
      child: Container(
        width: cellSize,
        height: cellSize,
        margin: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          color: fill,
          border: Border.all(color: Colors.white24),
        ),
        alignment: Alignment.center,
        child: revealed && isCorrectCell
            ? const Text('📍', style: TextStyle(fontSize: 20))
            : null,
      ),
    );
  }

  Widget _buildSimpleQuestion(_SimpleQ q, bool revealed) {
    return Column(
      children: [
        const SizedBox(height: 12),
        Text(
          q.prompt,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 22),
        AnimatedBuilder(
          animation: _shakeAnim,
          builder: (context, _) {
            final dx = _phase == _Phase.wrong
                ? math.sin(_shakeAnim.value * math.pi * 6) * 6
                : 0.0;
            return Transform.translate(
              offset: Offset(dx, 0),
              child: Wrap(
                spacing: 14,
                runSpacing: 14,
                alignment: WrapAlignment.center,
                children: [
                  for (var i = 0; i < q.choices.length; i++)
                    _SimpleTile(
                      label: q.choices[i],
                      selected: _selectedIndex == i,
                      isCorrect: i == 0,
                      revealed: revealed,
                      onTap: () => _onSimpleAnswer(i),
                    ),
                ],
              ),
            );
          },
        ),
        if (_phase == _Phase.wrong)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              '$_wrongReaction The answer was ${q.choices[0]}.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        const SizedBox(height: 20),
      ],
    );
  }
}

// ── Simple tile (MCQ) ────────────────────────────────────────────────────────

class _SimpleTile extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isCorrect;
  final bool revealed;
  final VoidCallback onTap;
  const _SimpleTile({
    required this.label,
    required this.selected,
    required this.isCorrect,
    required this.revealed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color fill = _MMState._card;
    if (revealed && isCorrect) fill = const Color(0xFF4CAF7D);
    if (revealed && selected && !isCorrect) fill = const Color(0xFFE05656);

    return GestureDetector(
      onTap: revealed ? null : onTap,
      child: Container(
        constraints: const BoxConstraints(minWidth: 110, maxWidth: 260),
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _MMState._sand.withValues(alpha: 0.7), width: 2),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

// ── Painters ─────────────────────────────────────────────────────────────────

class _DottedMapBgPainter extends CustomPainter {
  final double t;
  const _DottedMapBgPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = _MMState._sand.withValues(alpha: 0.05 + 0.03 * t);
    const spacing = 26.0;
    for (var y = 0.0; y < size.height; y += spacing) {
      for (var x = 0.0; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), 1.4, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DottedMapBgPainter oldDelegate) => oldDelegate.t != t;
}

class _SparkleShowerPainter extends CustomPainter {
  final double t;
  const _SparkleShowerPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(53);
    for (var i = 0; i < 18; i++) {
      final startX = rng.nextDouble() * size.width;
      final speed = 0.5 + rng.nextDouble() * 0.6;
      final y = (t * speed) * (size.height + 40) - 20;
      final x = startX + math.sin((t * 6) + i) * 12;
      final paint = Paint()
        ..color = _MMState._sand.withValues(alpha: (1 - t).clamp(0.0, 1.0));
      canvas.drawCircle(Offset(x, y), 3, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparkleShowerPainter oldDelegate) => oldDelegate.t != t;
}

// ── Header / progress ────────────────────────────────────────────────────────

class _MapHeader extends StatelessWidget {
  final String zoneName;
  final int zoneIdx;
  final int totalZones;
  final int completedSteps;
  final int totalSteps;
  const _MapHeader({
    required this.zoneName,
    required this.zoneIdx,
    required this.totalZones,
    required this.completedSteps,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        children: [
          Row(
            children: [
              const Text('🧭', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  children: [
                    Text('Zone ${zoneIdx + 1}/$totalZones',
                        style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    Text(
                      zoneName,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 30),
            ],
          ),
          const SizedBox(height: 8),
          _MapTrail(completed: completedSteps, total: totalSteps),
        ],
      ),
    );
  }
}

class _MapTrail extends StatelessWidget {
  final int completed;
  final int total;
  const _MapTrail({required this.completed, required this.total});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 22,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          Container(
            height: 3,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            color: Colors.white24,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < total; i++)
                Text(
                  i < completed ? '📍' : '·',
                  style: TextStyle(
                    fontSize: i < completed ? 12 : 10,
                    color: i < completed ? null : Colors.white38,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ZoneDoneOverlay extends StatelessWidget {
  final String completedZoneName;
  final String? nextZoneName;
  const _ZoneDoneOverlay({required this.completedZoneName, required this.nextZoneName});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black45,
        alignment: Alignment.center,
        child: Container(
          padding: const EdgeInsets.all(24),
          margin: const EdgeInsets.symmetric(horizontal: 40),
          decoration: BoxDecoration(
            color: _MMState._card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _MMState._sand, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🧭', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 8),
              Text('$completedZoneName complete!',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
              if (nextZoneName != null) ...[
                const SizedBox(height: 6),
                Text('Next: $nextZoneName', style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _IntroScreen extends StatelessWidget {
  const _IntroScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_MMState._bg1, _MMState._bg2],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🗺️🧭', style: TextStyle(fontSize: 44)),
                  SizedBox(height: 16),
                  Text(
                    'Map Master',
                    style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Spin the compass, read the grid, and master every map skill!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  SizedBox(height: 24),
                  CircularProgressIndicator(color: _MMState._sand),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VictoryScreen extends StatelessWidget {
  final int correctCount;
  final int total;
  final int totalXP;
  final VoidCallback onReplay;
  final VoidCallback onExit;
  const _VictoryScreen({
    required this.correctCount,
    required this.total,
    required this.totalXP,
    required this.onReplay,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (correctCount / total * 100).round() : 0;
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_MMState._bg1, _MMState._bg2],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🏆🧭', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  const Text('Map Master!',
                      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  Text('$correctCount / $total correct ($pct%)',
                      style: const TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('+$totalXP XP',
                      style: const TextStyle(color: _MMState._sand, fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: onReplay,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _MMState._card,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    ),
                    child: const Text('Play Again'),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: onExit,
                    child: const Text('Exit', style: TextStyle(color: Colors.white70)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
