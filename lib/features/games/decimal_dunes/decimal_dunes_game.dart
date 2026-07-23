import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/game_session_model.dart';
import '../core/game_config.dart';
import '../core/game_session_persistence.dart';

// ────────────────────────────────────────────────────────────────────────────
// Decimal Dunes — Grade 4 Mathematics: decimals
//
// 4 Zones (5 questions each = 20 total):
//   1. Dune Line     — drag a camel to the correct spot on a number line
//   2. Oasis Order    — tap the smallest/largest of 3 decimals
//   3. Compare Canyon — tap the larger of 2 decimals
//   4. Sandstorm Sums — add/subtract decimals in Rand amounts (MCQ)
//
// Structurally distinct from every prior engine: Dune Line is the first
// continuous drag-to-position mechanic in the whole roster (not drag-to-bin
// like Geometry Jungle, and not a fixed set of tap targets) -- the learner
// drags a camel anywhere along a number line and it snaps to the nearest
// tenth, directly testing decimal place value and magnitude. The other
// three zones are all tap-a-tile, but on genuinely different judgements
// (smallest/largest/bigger/sum) so no two zones feel the same.
// Architecture: fully self-contained StatefulWidget.
// ────────────────────────────────────────────────────────────────────────────

enum _Phase { intro, playing, correct, wrong, streak, zoneDone, victory }

enum _Kind { numberLine, tapTile, arithmetic }

class _DDQ {
  final String prompt;
  final double? target; // numberLine
  final List<String> tiles; // tapTile / arithmetic choices
  final int correctIndex; // tapTile / arithmetic
  const _DDQ({
    required this.prompt,
    this.target,
    this.tiles = const [],
    this.correctIndex = 0,
  });
}

class _Zone {
  final String name;
  final _Kind kind;
  final List<_DDQ> questions;
  const _Zone({required this.name, required this.kind, required this.questions});
}

class DecimalDunesGame extends StatefulWidget {
  final GameConfig config;
  final dynamic user;
  const DecimalDunesGame({super.key, required this.config, this.user});

  @override
  State<DecimalDunesGame> createState() => _DDState();
}

class _DDState extends State<DecimalDunesGame> with TickerProviderStateMixin {
  static const _lineMin = 0.0;
  static const _lineMax = 2.0;
  static const _lineStep = 0.1;

  static const _zones = [
    _Zone(name: 'Dune Line', kind: _Kind.numberLine, questions: [
      _DDQ(prompt: 'Drag the camel to 0.3', target: 0.3),
      _DDQ(prompt: 'Drag the camel to 0.7', target: 0.7),
      _DDQ(prompt: 'Drag the camel to 1.4', target: 1.4),
      _DDQ(prompt: 'Drag the camel to 1.8', target: 1.8),
      _DDQ(prompt: 'Drag the camel to 0.9', target: 0.9),
    ]),
    _Zone(name: 'Oasis Order', kind: _Kind.tapTile, questions: [
      _DDQ(
          prompt: 'Tap the SMALLEST decimal.',
          tiles: ['1.5', '0.8', '1.2'],
          correctIndex: 1),
      _DDQ(
          prompt: 'Tap the LARGEST decimal.',
          tiles: ['2.3', '2.1', '2.35'],
          correctIndex: 2),
      _DDQ(
          prompt: 'Tap the SMALLEST decimal.',
          tiles: ['0.6', '0.06', '0.66'],
          correctIndex: 1),
      _DDQ(
          prompt: 'Tap the LARGEST decimal.',
          tiles: ['3.05', '3.5', '3.15'],
          correctIndex: 1),
      _DDQ(
          prompt: 'Tap the SMALLEST decimal.',
          tiles: ['4.4', '4.04', '4.44'],
          correctIndex: 1),
    ]),
    _Zone(name: 'Compare Canyon', kind: _Kind.tapTile, questions: [
      _DDQ(prompt: 'Tap the BIGGER decimal.', tiles: ['3.4', '3.04'], correctIndex: 0),
      _DDQ(prompt: 'Tap the BIGGER decimal.', tiles: ['0.5', '0.45'], correctIndex: 0),
      _DDQ(prompt: 'Tap the BIGGER decimal.', tiles: ['2.19', '2.2'], correctIndex: 1),
      _DDQ(prompt: 'Tap the BIGGER decimal.', tiles: ['6.06', '6.6'], correctIndex: 1),
      _DDQ(prompt: 'Tap the BIGGER decimal.', tiles: ['1.09', '1.9'], correctIndex: 1),
    ]),
    _Zone(name: 'Sandstorm Sums', kind: _Kind.arithmetic, questions: [
      _DDQ(
          prompt: 'R12.50 + R3.25 = ?',
          tiles: ['R15.75', 'R15.25', 'R16.75'],
          correctIndex: 0),
      _DDQ(
          prompt: 'R8.60 - R2.10 = ?',
          tiles: ['R6.50', 'R6.40', 'R7.50'],
          correctIndex: 0),
      _DDQ(
          prompt: 'R4.35 + R5.40 = ?',
          tiles: ['R9.75', 'R9.65', 'R10.75'],
          correctIndex: 0),
      _DDQ(
          prompt: 'R20.00 - R7.75 = ?',
          tiles: ['R12.25', 'R13.25', 'R12.75'],
          correctIndex: 0),
      _DDQ(
          prompt: 'R6.50 + R3.50 = ?',
          tiles: ['R10.00', 'R9.50', 'R10.50'],
          correctIndex: 0),
    ]),
  ];

  static const _wrongReactions = [
    'Not quite -- check the digits again!',
    'Close -- look at the decimal point!',
    'Try again, careful with the place value!',
  ];

  static const _duneTop = Color(0xFFF4A947);
  static const _duneBottom = Color(0xFFC1652F);
  static const _gold = Color(0xFF8B4513);

  late AnimationController _ambientCtrl;
  late AnimationController _fadeCtrl;
  late AnimationController _flashCtrl;
  late AnimationController _sparkleCtrl;
  late AnimationController _shakeCtrl;

  late Animation<double> _ambientAnim;
  late Animation<double> _fadeAnim;
  late Animation<double> _flashAnim;
  late Animation<double> _sparkleAnim;
  late Animation<double> _shakeAnim;

  int _zoneIdx = 0;
  int _qIdx = 0;
  int _correctCount = 0;
  int _streak = 0;
  int _totalXP = 0;

  _Phase _phase = _Phase.intro;
  int? _selectedIndex;
  double? _dragValue;
  double? _droppedValue;
  String _wrongReaction = '';

  final _rng = math.Random();

  String get _uid => (widget.user?.uid as String?) ?? '';

  int get _totalQuestions =>
      _zones.fold<int>(0, (sum, z) => sum + z.questions.length);

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
        vsync: this, duration: const Duration(seconds: 7))
      ..repeat(reverse: true);
    _ambientAnim = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _ambientCtrl, curve: Curves.easeInOut));

    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);

    _flashCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _flashAnim = CurvedAnimation(parent: _flashCtrl, curve: Curves.easeOut);

    _sparkleCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1700));
    _sparkleAnim =
        CurvedAnimation(parent: _sparkleCtrl, curve: Curves.easeOut);

    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _shakeAnim = CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut);
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
    _sparkleCtrl.dispose();
    _shakeCtrl.dispose();
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
      _dragValue = null;
      _droppedValue = null;
    });
    _fadeCtrl.forward(from: 0);
  }

  void _onTileAnswer(int tappedIndex) {
    if (_phase != _Phase.playing) return;
    final zone = _zones[_zoneIdx];
    final q = zone.questions[_qIdx];
    final isCorrect = tappedIndex == q.correctIndex;
    setState(() => _selectedIndex = tappedIndex);
    _applyAnswerResult(isCorrect);
  }

  void _onNumberLineDrop(double snapped) {
    if (_phase != _Phase.playing) return;
    final zone = _zones[_zoneIdx];
    final q = zone.questions[_qIdx];
    final isCorrect = (snapped - q.target!).abs() < 0.05;
    setState(() => _droppedValue = snapped);
    _applyAnswerResult(isCorrect);
  }

  void _applyAnswerResult(bool isCorrect) {
    setState(() {
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
          _sparkleCtrl.forward(from: 0);
          _delayed(1600, _advance);
        });
      } else {
        _delayed(1000, _advance);
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

    if (next >= zone.questions.length) {
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
            _dragValue = null;
            _droppedValue = null;
            _phase = _Phase.playing;
          });
          _fadeCtrl.forward(from: 0);
        });
      }
    } else {
      setState(() {
        _qIdx = next;
        _selectedIndex = null;
        _dragValue = null;
        _droppedValue = null;
        _phase = _Phase.playing;
      });
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
    final q = zone.questions[_qIdx];
    final total = _totalQuestions;
    final completedSteps = _zones
            .take(_zoneIdx)
            .fold<int>(0, (sum, z) => sum + z.questions.length) +
        _qIdx;
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
                  colors: [_duneTop, _duneBottom],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _ambientAnim,
              builder: (context, _) =>
                  CustomPaint(painter: _DuneBgPainter(_ambientAnim.value)),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _DuneHeader(
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
                      child: Column(
                        children: [
                          const SizedBox(height: 12),
                          Text(
                            q.prompt,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 26),
                          if (zone.kind == _Kind.numberLine)
                            _buildNumberLine(q, revealed)
                          else
                            AnimatedBuilder(
                              animation: _shakeAnim,
                              builder: (context, _) {
                                final dx = _phase == _Phase.wrong
                                    ? math.sin(_shakeAnim.value * math.pi * 6) *
                                        6
                                    : 0.0;
                                return Transform.translate(
                                  offset: Offset(dx, 0),
                                  child: Wrap(
                                    spacing: 14,
                                    runSpacing: 14,
                                    alignment: WrapAlignment.center,
                                    children: [
                                      for (var i = 0; i < q.tiles.length; i++)
                                        _DuneTile(
                                          label: q.tiles[i],
                                          selected: _selectedIndex == i,
                                          isCorrect: i == q.correctIndex,
                                          revealed: revealed,
                                          onTap: () => _onTileAnswer(i),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          if (_phase == _Phase.wrong)
                            Padding(
                              padding: const EdgeInsets.only(top: 18),
                              child: Text(
                                zone.kind == _Kind.numberLine
                                    ? '$_wrongReaction The answer was ${q.target!.toStringAsFixed(1)}.'
                                    : '$_wrongReaction The answer was ${q.tiles[q.correctIndex]}.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          const SizedBox(height: 24),
                        ],
                      ),
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
                  child: Container(color: Colors.white),
                ),
              ),
            ),
          if (_phase == _Phase.streak)
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _sparkleAnim,
                builder: (context, _) => CustomPaint(
                  painter: _SparkleShowerPainter(_sparkleAnim.value),
                  size: Size.infinite,
                ),
              ),
            ),
          if (_phase == _Phase.zoneDone)
            _ZoneDoneOverlay(
              completedZoneName: zone.name,
              nextZoneName: _zoneIdx + 1 < _zones.length
                  ? _zones[_zoneIdx + 1].name
                  : null,
            ),
        ],
      ),
    );
  }

  Widget _buildNumberLine(_DDQ q, bool revealed) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      const markerSize = 32.0;
      const range = _lineMax - _lineMin;

      void updateFromGlobal(Offset globalPos, RenderBox box) {
        final local = box.globalToLocal(globalPos);
        final raw = _lineMin + (local.dx / width) * range;
        setState(() => _dragValue = raw.clamp(_lineMin, _lineMax));
      }

      void submit() {
        final raw = _dragValue ?? _lineMin;
        final snappedRaw = (raw / _lineStep).round() * _lineStep;
        final snapped = double.parse(snappedRaw.toStringAsFixed(1));
        _onNumberLineDrop(snapped);
      }

      final previewValue = revealed ? (_droppedValue ?? _lineMin) : (_dragValue ?? _lineMin);
      final fraction = ((previewValue - _lineMin) / range).clamp(0.0, 1.0);

      return GestureDetector(
        onHorizontalDragUpdate: revealed
            ? null
            : (details) {
                final box = context.findRenderObject() as RenderBox;
                updateFromGlobal(details.globalPosition, box);
              },
        onHorizontalDragEnd: revealed ? null : (_) => submit(),
        onTapDown: revealed
            ? null
            : (details) {
                final box = context.findRenderObject() as RenderBox;
                updateFromGlobal(details.globalPosition, box);
              },
        onTapUp: revealed ? null : (_) => submit(),
        child: SizedBox(
          height: 100,
          width: double.infinity,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              CustomPaint(
                size: Size(width, 70),
                painter: _NumberLinePainter(
                  min: _lineMin,
                  max: _lineMax,
                  step: _lineStep,
                  revealed: revealed,
                  target: q.target!,
                ),
              ),
              Positioned(
                left: (fraction * (width - markerSize)).clamp(0.0, width - markerSize),
                top: 0,
                child: Container(
                  width: markerSize + 8,
                  height: markerSize + 8,
                  alignment: Alignment.center,
                  decoration: revealed
                      ? BoxDecoration(
                          shape: BoxShape.circle,
                          color: ((_droppedValue ?? _lineMin) - q.target!)
                                      .abs() <
                                  0.05
                              ? const Color(0xFF4CAF7D)
                              : const Color(0xFFE05656),
                        )
                      : null,
                  child: const Text('🐫', style: TextStyle(fontSize: markerSize)),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

// ── Number line painter ──────────────────────────────────────────────────────

class _NumberLinePainter extends CustomPainter {
  final double min;
  final double max;
  final double step;
  final bool revealed;
  final double target;
  const _NumberLinePainter({
    required this.min,
    required this.max,
    required this.step,
    required this.revealed,
    required this.target,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * 0.6;
    final linePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);

    final range = max - min;
    final steps = (range / step).round();
    for (var i = 0; i <= steps; i++) {
      final v = min + i * step;
      final x = (v - min) / range * size.width;
      final isMajor = (v * 10).round() % 10 == 0;
      canvas.drawLine(
        Offset(x, y - (isMajor ? 12 : 6)),
        Offset(x, y + (isMajor ? 12 : 6)),
        Paint()
          ..color = Colors.white.withValues(alpha: isMajor ? 0.9 : 0.5)
          ..strokeWidth = isMajor ? 2 : 1,
      );
      if (isMajor) {
        final tp = TextPainter(
          text: TextSpan(
            text: v.toStringAsFixed(0),
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x - tp.width / 2, y + 16));
      }
    }

    if (revealed) {
      final tx = (target - min) / range * size.width;
      final flagPaint = Paint()
        ..color = const Color(0xFF4CAF7D)
        ..strokeWidth = 3;
      canvas.drawLine(Offset(tx, y - 22), Offset(tx, y + 22), flagPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _NumberLinePainter oldDelegate) =>
      oldDelegate.target != target || oldDelegate.revealed != revealed;
}

// ── Tile ─────────────────────────────────────────────────────────────────────

class _DuneTile extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isCorrect;
  final bool revealed;
  final VoidCallback onTap;
  const _DuneTile({
    required this.label,
    required this.selected,
    required this.isCorrect,
    required this.revealed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color fill = Colors.white.withValues(alpha: 0.9);
    Color textColor = _DDState._gold;
    if (revealed && isCorrect) {
      fill = const Color(0xFF4CAF7D);
      textColor = Colors.white;
    }
    if (revealed && selected && !isCorrect) {
      fill = const Color(0xFFE05656);
      textColor = Colors.white;
    }

    return GestureDetector(
      onTap: revealed ? null : onTap,
      child: ClipPath(
        clipper: const _DuneClipper(),
        child: Container(
          width: 100,
          height: 72,
          alignment: Alignment.center,
          color: fill,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textColor,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _DuneClipper extends CustomClipper<Path> {
  const _DuneClipper();
  @override
  Path getClip(Size size) {
    final w = size.width, h = size.height;
    final path = Path()
      ..moveTo(0, h)
      ..quadraticBezierTo(w * 0.1, h * 0.15, w * 0.5, h * 0.1)
      ..quadraticBezierTo(w * 0.9, h * 0.05, w, h * 0.35)
      ..lineTo(w, h)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

// ── Painters ─────────────────────────────────────────────────────────────────

class _DuneBgPainter extends CustomPainter {
  final double t;
  const _DuneBgPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.08);
    for (var i = 0; i < 3; i++) {
      final y = size.height * (0.5 + i * 0.15) + math.sin(t * math.pi * 2 + i) * 5;
      final path = Path()..moveTo(0, y);
      for (double x = 0; x <= size.width; x += 50) {
        path.quadraticBezierTo(x + 25, y - 14, x + 50, y);
      }
      path
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DuneBgPainter oldDelegate) => oldDelegate.t != t;
}

class _SparkleShowerPainter extends CustomPainter {
  final double t;
  const _SparkleShowerPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(13);
    for (var i = 0; i < 20; i++) {
      final startX = rng.nextDouble() * size.width;
      final speed = 0.5 + rng.nextDouble() * 0.6;
      final y = (t * speed) * (size.height + 40) - 20;
      final x = startX + math.sin((t * 6) + i) * 12;
      final paint = Paint()
        ..color = const Color(0xFFFFD98A)
            .withValues(alpha: (1 - t).clamp(0.0, 1.0));
      canvas.drawCircle(Offset(x, y), 3, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparkleShowerPainter oldDelegate) =>
      oldDelegate.t != t;
}

// ── Header / progress ────────────────────────────────────────────────────────

class _DuneHeader extends StatelessWidget {
  final String zoneName;
  final int zoneIdx;
  final int totalZones;
  final int completedSteps;
  final int totalSteps;
  const _DuneHeader({
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
              const Text('🏜️', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  children: [
                    Text('Zone ${zoneIdx + 1}/$totalZones',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11)),
                    Text(
                      zoneName,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 30),
            ],
          ),
          const SizedBox(height: 8),
          _DuneTrail(completed: completedSteps, total: totalSteps),
        ],
      ),
    );
  }
}

class _DuneTrail extends StatelessWidget {
  final int completed;
  final int total;
  const _DuneTrail({required this.completed, required this.total});

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
                  i < completed ? '🌵' : '·',
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
  const _ZoneDoneOverlay(
      {required this.completedZoneName, required this.nextZoneName});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black38,
        alignment: Alignment.center,
        child: Container(
          padding: const EdgeInsets.all(24),
          margin: const EdgeInsets.symmetric(horizontal: 40),
          decoration: BoxDecoration(
            color: _DDState._duneBottom,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🏜️', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 8),
              Text('$completedZoneName complete!',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
              if (nextZoneName != null) ...[
                const SizedBox(height: 6),
                Text('Next: $nextZoneName',
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
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
            colors: [_DDState._duneTop, _DDState._duneBottom],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🏜️🐫', style: TextStyle(fontSize: 44)),
                  SizedBox(height: 16),
                  Text(
                    'Decimal Dunes',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Guide your camel across the dunes -- compare, order '
                    'and place decimals to cross!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  SizedBox(height: 24),
                  CircularProgressIndicator(color: Colors.white),
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
            colors: [_DDState._duneTop, _DDState._duneBottom],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🏆🏜️', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  const Text('Dunes Crossed!',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  Text('$correctCount / $total correct ($pct%)',
                      style: const TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('+$totalXP XP',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: onReplay,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _DDState._gold,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 14),
                    ),
                    child: const Text('Play Again'),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: onExit,
                    child: const Text('Exit',
                        style: TextStyle(color: Colors.white70)),
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
