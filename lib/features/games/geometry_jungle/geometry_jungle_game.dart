import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/game_session_model.dart';
import '../core/game_config.dart';
import '../core/game_session_persistence.dart';

// ────────────────────────────────────────────────────────────────────────────
// Geometry Jungle — Grade 4 Mathematics: shapes, angles, 3D objects, symmetry
//
// 4 Zones (5 questions each = 20 total):
//   1. Shape Clearing — name the 2D shape (triangle, square, rectangle,
//      pentagon, hexagon)
//   2. Corner Cave     — classify the angle as acute, right or obtuse
//   3. 3D Den          — name the 3D object (cube, sphere, cylinder, cone,
//      rectangular prism), drawn in pseudo-3D
//   4. Symmetry Swamp  — decide whether the dashed line is a true line of
//      symmetry for the shape
//
// Structurally distinct from every prior engine: this is the first to use
// real drag-and-drop (Draggable/DragTarget) instead of taps. Each question
// shows one diagram card that the learner physically drags onto one of
// several signpost bins. No-punishment design: a wrong drop just returns
// the card and reveals the right bin in gold, no progress lost.
// Architecture: fully self-contained StatefulWidget.
// ────────────────────────────────────────────────────────────────────────────

enum _Phase { intro, playing, correct, wrong, streak, zoneDone, victory }

enum _DiagramKind { shape2d, angle, shape3d, symmetry }

class _GeoQ {
  final _DiagramKind kind;
  final String shapeId;
  final double angleDegrees;
  final bool symmetric;
  final List<String> choices; // choices[0] is always correct
  const _GeoQ({
    required this.kind,
    this.shapeId = '',
    this.angleDegrees = 0,
    this.symmetric = false,
    required this.choices,
  });
}

class _Zone {
  final String name;
  final List<_GeoQ> questions;
  const _Zone(this.name, this.questions);
}

class GeometryJungleGame extends StatefulWidget {
  final GameConfig config;
  final dynamic user;
  const GeometryJungleGame({super.key, required this.config, this.user});

  @override
  State<GeometryJungleGame> createState() => _GJState();
}

class _GJState extends State<GeometryJungleGame>
    with TickerProviderStateMixin {
  static const _zones = [
    _Zone('Shape Clearing', [
      _GeoQ(
          kind: _DiagramKind.shape2d,
          shapeId: 'triangle',
          choices: ['Triangle', 'Square', 'Pentagon']),
      _GeoQ(
          kind: _DiagramKind.shape2d,
          shapeId: 'square',
          choices: ['Square', 'Rectangle', 'Hexagon']),
      _GeoQ(
          kind: _DiagramKind.shape2d,
          shapeId: 'rectangle',
          choices: ['Rectangle', 'Triangle', 'Pentagon']),
      _GeoQ(
          kind: _DiagramKind.shape2d,
          shapeId: 'pentagon',
          choices: ['Pentagon', 'Hexagon', 'Square']),
      _GeoQ(
          kind: _DiagramKind.shape2d,
          shapeId: 'hexagon',
          choices: ['Hexagon', 'Pentagon', 'Rectangle']),
    ]),
    _Zone('Corner Cave', [
      _GeoQ(
          kind: _DiagramKind.angle,
          angleDegrees: 90,
          choices: ['Right', 'Acute', 'Obtuse']),
      _GeoQ(
          kind: _DiagramKind.angle,
          angleDegrees: 35,
          choices: ['Acute', 'Right', 'Obtuse']),
      _GeoQ(
          kind: _DiagramKind.angle,
          angleDegrees: 140,
          choices: ['Obtuse', 'Right', 'Acute']),
      _GeoQ(
          kind: _DiagramKind.angle,
          angleDegrees: 60,
          choices: ['Acute', 'Obtuse', 'Right']),
      _GeoQ(
          kind: _DiagramKind.angle,
          angleDegrees: 110,
          choices: ['Obtuse', 'Acute', 'Right']),
    ]),
    _Zone('3D Den', [
      _GeoQ(
          kind: _DiagramKind.shape3d,
          shapeId: 'cube',
          choices: ['Cube', 'Sphere', 'Cone']),
      _GeoQ(
          kind: _DiagramKind.shape3d,
          shapeId: 'sphere',
          choices: ['Sphere', 'Cube', 'Cylinder']),
      _GeoQ(
          kind: _DiagramKind.shape3d,
          shapeId: 'cylinder',
          choices: ['Cylinder', 'Cone', 'Prism']),
      _GeoQ(
          kind: _DiagramKind.shape3d,
          shapeId: 'cone',
          choices: ['Cone', 'Cylinder', 'Cube']),
      _GeoQ(
          kind: _DiagramKind.shape3d,
          shapeId: 'prism',
          choices: ['Rectangular Prism', 'Cube', 'Sphere']),
    ]),
    _Zone('Symmetry Swamp', [
      _GeoQ(
          kind: _DiagramKind.symmetry,
          shapeId: 'square',
          symmetric: true,
          choices: ['Symmetrical', 'Not Symmetrical']),
      _GeoQ(
          kind: _DiagramKind.symmetry,
          shapeId: 'blob',
          symmetric: false,
          choices: ['Not Symmetrical', 'Symmetrical']),
      _GeoQ(
          kind: _DiagramKind.symmetry,
          shapeId: 'circle',
          symmetric: true,
          choices: ['Symmetrical', 'Not Symmetrical']),
      _GeoQ(
          kind: _DiagramKind.symmetry,
          shapeId: 'rectangle',
          symmetric: false,
          choices: ['Not Symmetrical', 'Symmetrical']),
      _GeoQ(
          kind: _DiagramKind.symmetry,
          shapeId: 'triangle',
          symmetric: true,
          choices: ['Symmetrical', 'Not Symmetrical']),
    ]),
  ];

  static const _wrongReactions = [
    'Not that den! Look again.',
    'Close -- check the shape again!',
    'Try dropping it on another sign!',
  ];

  static const _jungleGreen = Color(0xFF0D4D3C);
  static const _leafGreen = Color(0xFF3FB582);
  static const _vineBrown = Color(0xFF6B4423);
  static const _gold = Color(0xFFFFC94A);

  late AnimationController _ambientCtrl;
  late AnimationController _fadeCtrl;
  late AnimationController _flashCtrl;
  late AnimationController _fireflyCtrl;
  late AnimationController _shakeCtrl;

  late Animation<double> _ambientAnim;
  late Animation<double> _fadeAnim;
  late Animation<double> _flashAnim;
  late Animation<double> _fireflyAnim;
  late Animation<double> _shakeAnim;

  int _zoneIdx = 0;
  int _qIdx = 0;
  int _correctCount = 0;
  int _streak = 0;
  int _totalXP = 0;

  _Phase _phase = _Phase.intro;
  int? _selectedIndex;
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
        vsync: this, duration: const Duration(seconds: 4))
      ..repeat(reverse: true);
    _ambientAnim = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _ambientCtrl, curve: Curves.easeInOut));

    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);

    _flashCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _flashAnim = CurvedAnimation(parent: _flashCtrl, curve: Curves.easeOut);

    _fireflyCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1700));
    _fireflyAnim =
        CurvedAnimation(parent: _fireflyCtrl, curve: Curves.easeOut);

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
    _fireflyCtrl.dispose();
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
    });
    _fadeCtrl.forward(from: 0);
  }

  Object? _cachedQ;
  List<String> _cachedChoices = [];

  List<String> _getShuffledChoices(_GeoQ q) {
    if (!identical(_cachedQ, q)) {
      _cachedQ = q;
      _cachedChoices = List<String>.from(q.choices)..shuffle(_rng);
    }
    return _cachedChoices;
  }

  void _onAnswer(int index) {
    if (_phase != _Phase.playing) return;
    final q = _zones[_zoneIdx].questions[_qIdx];
    final choices = _getShuffledChoices(q);
    final isCorrect = choices[index] == q.choices[0];

    setState(() {
      _selectedIndex = index;
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
          _fireflyCtrl.forward(from: 0);
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
            _phase = _Phase.playing;
          });
          _fadeCtrl.forward(from: 0);
        });
      }
    } else {
      setState(() {
        _qIdx = next;
        _selectedIndex = null;
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
                  colors: [_jungleGreen, Color(0xFF072A20)],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _ambientAnim,
              builder: (context, _) =>
                  CustomPaint(painter: _JungleBgPainter(_ambientAnim.value)),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _JungleHeader(
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
                          const SizedBox(height: 8),
                          Text(
                            _promptFor(q),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 20),
                          AnimatedBuilder(
                            animation: _shakeAnim,
                            builder: (context, _) {
                              final dx = _phase == _Phase.wrong
                                  ? math.sin(_shakeAnim.value * math.pi * 6) *
                                      6
                                  : 0.0;
                              return Transform.translate(
                                offset: Offset(dx, 0),
                                child: _DiagramCard(
                                  q: q,
                                  disabled: revealed,
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 28),
                          Builder(builder: (context) {
                            final choices = _getShuffledChoices(q);
                            return Wrap(
                              spacing: 14,
                              runSpacing: 14,
                              alignment: WrapAlignment.center,
                              children: [
                                for (var i = 0; i < choices.length; i++)
                                  _SignBin(
                                    label: choices[i],
                                    index: i,
                                    selected: _selectedIndex == i,
                                    isCorrect: choices[i] == q.choices[0],
                                    revealed: revealed,
                                    onAccept: () => _onAnswer(i),
                                  ),
                              ],
                            );
                          }),
                          if (_phase == _Phase.wrong)
                            Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: Text(
                                '$_wrongReaction The answer was ${q.choices[0]}.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: _gold,
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
                  opacity: (1 - _flashAnim.value).clamp(0.0, 1.0) * 0.35,
                  child: Container(color: _leafGreen),
                ),
              ),
            ),
          if (_phase == _Phase.streak)
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _fireflyAnim,
                builder: (context, _) => CustomPaint(
                  painter: _FireflyShowerPainter(_fireflyAnim.value),
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

  String _promptFor(_GeoQ q) => switch (q.kind) {
        _DiagramKind.shape2d => 'Drag the shape to its name!',
        _DiagramKind.angle => 'Drag the angle to its type!',
        _DiagramKind.shape3d => 'Drag the 3D object to its name!',
        _DiagramKind.symmetry =>
          'Is the dashed line a true line of symmetry?',
      };
}

// ── Draggable diagram card + drop bins ──────────────────────────────────────

class _DiagramCard extends StatelessWidget {
  final _GeoQ q;
  final bool disabled;
  const _DiagramCard({required this.q, required this.disabled});

  Widget _diagram() => SizedBox(
        width: 120,
        height: 120,
        child: CustomPaint(painter: _diagramPainter(q)),
      );

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white24, width: 2),
      ),
      alignment: Alignment.center,
      child: _diagram(),
    );

    if (disabled) return Opacity(opacity: 0.5, child: card);

    return Draggable<int>(
      data: 0,
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(opacity: 0.85, child: card),
      ),
      childWhenDragging: Opacity(opacity: 0.25, child: card),
      child: card,
    );
  }
}

CustomPainter _diagramPainter(_GeoQ q) => switch (q.kind) {
      _DiagramKind.shape2d => _Shape2DPainter(q.shapeId),
      _DiagramKind.angle => _AnglePainter(q.angleDegrees),
      _DiagramKind.shape3d => _Shape3DPainter(q.shapeId),
      _DiagramKind.symmetry => _SymmetryPainter(q.shapeId, q.symmetric),
    };

class _SignBin extends StatelessWidget {
  final String label;
  final int index;
  final bool selected;
  final bool isCorrect;
  final bool revealed;
  final VoidCallback onAccept;
  const _SignBin({
    required this.label,
    required this.index,
    required this.selected,
    required this.isCorrect,
    required this.revealed,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    return DragTarget<int>(
      onAcceptWithDetails: (_) => onAccept(),
      builder: (context, candidateData, rejectedData) {
        Color fill = const Color(0xFF2E7D4F);
        if (revealed && isCorrect) fill = _GJState._leafGreen;
        if (revealed && selected && !isCorrect) fill = const Color(0xFFE05656);
        final hovering = candidateData.isNotEmpty;

        return ClipPath(
          clipper: const _SignClipper(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: hovering ? 128 : 118,
            height: 76,
            alignment: Alignment.center,
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 16),
            decoration: BoxDecoration(
              color: fill,
              border: hovering
                  ? Border.all(color: _GJState._gold, width: 3)
                  : null,
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SignClipper extends CustomClipper<Path> {
  const _SignClipper();
  @override
  Path getClip(Size size) {
    final w = size.width, h = size.height;
    const postW = 10.0;
    final signH = h - 14;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, w, signH),
        const Radius.circular(10),
      ))
      ..addRect(Rect.fromLTWH(w / 2 - postW / 2, signH - 2, postW, h - signH + 2));
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

// ── Diagram painters ─────────────────────────────────────────────────────────

class _Shape2DPainter extends CustomPainter {
  final String shapeId;
  const _Shape2DPainter(this.shapeId);

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = _GJState._leafGreen;
    final stroke = Paint()
      ..color = _GJState._vineBrown
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 8;
    final path = Path();

    switch (shapeId) {
      case 'triangle':
        path.moveTo(c.dx, c.dy - r);
        path.lineTo(c.dx + r * 0.95, c.dy + r * 0.8);
        path.lineTo(c.dx - r * 0.95, c.dy + r * 0.8);
        path.close();
      case 'square':
        path.addRect(Rect.fromCenter(center: c, width: r * 1.6, height: r * 1.6));
      case 'rectangle':
        path.addRect(Rect.fromCenter(center: c, width: r * 1.9, height: r * 1.2));
      case 'pentagon':
        _regularPolygon(path, c, r, 5);
      case 'hexagon':
        _regularPolygon(path, c, r, 6);
    }
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
  }

  void _regularPolygon(Path path, Offset c, double r, int sides) {
    for (var i = 0; i < sides; i++) {
      final angle = -math.pi / 2 + i * (2 * math.pi / sides);
      final p = c + Offset(math.cos(angle), math.sin(angle)) * r;
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
  }

  @override
  bool shouldRepaint(covariant _Shape2DPainter oldDelegate) =>
      oldDelegate.shapeId != shapeId;
}

class _AnglePainter extends CustomPainter {
  final double degrees;
  const _AnglePainter(this.degrees);

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width * 0.2, size.height * 0.8);
    final rayLen = size.shortestSide * 0.75;
    final basePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final arcPaint = Paint()
      ..color = _GJState._gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final rad = degrees * math.pi / 180;
    final p1 = origin + Offset(rayLen, 0);
    final p2 = origin + Offset(rayLen * math.cos(rad), -rayLen * math.sin(rad));

    canvas.drawLine(origin, p1, basePaint);
    canvas.drawLine(origin, p2, basePaint);
    canvas.drawArc(
      Rect.fromCircle(center: origin, radius: 26),
      -rad,
      rad,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _AnglePainter oldDelegate) =>
      oldDelegate.degrees != degrees;
}

class _Shape3DPainter extends CustomPainter {
  final String shapeId;
  const _Shape3DPainter(this.shapeId);

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = _GJState._leafGreen;
    final dark = Paint()..color = _GJState._leafGreen.withValues(alpha: 0.6);
    final stroke = Paint()
      ..color = _GJState._vineBrown
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    final c = size.center(Offset.zero);

    switch (shapeId) {
      case 'cube':
        _drawBox(canvas, c, 70, 70, fill, dark, stroke);
      case 'prism':
        _drawBox(canvas, c, 90, 55, fill, dark, stroke);
      case 'sphere':
        canvas.drawCircle(c, 42, fill);
        canvas.drawCircle(c, 42, stroke);
        canvas.drawOval(
          Rect.fromCenter(center: c, width: 78, height: 22),
          Paint()
            ..color = _GJState._vineBrown.withValues(alpha: 0.5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      case 'cylinder':
        final top = Offset(c.dx, c.dy - 34);
        final bottom = Offset(c.dx, c.dy + 34);
        canvas.drawRect(
          Rect.fromLTRB(c.dx - 34, top.dy, c.dx + 34, bottom.dy),
          fill,
        );
        canvas.drawOval(
            Rect.fromCenter(center: bottom, width: 68, height: 22), dark);
        canvas.drawOval(
            Rect.fromCenter(center: top, width: 68, height: 22), fill);
        canvas.drawOval(
            Rect.fromCenter(center: top, width: 68, height: 22), stroke);
        canvas.drawLine(Offset(c.dx - 34, top.dy), Offset(c.dx - 34, bottom.dy),
            stroke);
        canvas.drawLine(Offset(c.dx + 34, top.dy), Offset(c.dx + 34, bottom.dy),
            stroke);
      case 'cone':
        final apex = Offset(c.dx, c.dy - 40);
        final baseCenter = Offset(c.dx, c.dy + 30);
        final path = Path()
          ..moveTo(apex.dx, apex.dy)
          ..lineTo(baseCenter.dx - 34, baseCenter.dy)
          ..lineTo(baseCenter.dx + 34, baseCenter.dy)
          ..close();
        canvas.drawPath(path, fill);
        canvas.drawPath(path, stroke);
        canvas.drawOval(
            Rect.fromCenter(center: baseCenter, width: 68, height: 18), dark);
        canvas.drawOval(
            Rect.fromCenter(center: baseCenter, width: 68, height: 18),
            stroke);
    }
  }

  void _drawBox(Canvas canvas, Offset c, double w, double h, Paint fill,
      Paint dark, Paint stroke) {
    const depth = 18.0;
    final front = Rect.fromCenter(center: c, width: w, height: h);
    canvas.drawRect(front, fill);
    canvas.drawRect(front, stroke);

    final topPath = Path()
      ..moveTo(front.left, front.top)
      ..lineTo(front.left + depth, front.top - depth)
      ..lineTo(front.right + depth, front.top - depth)
      ..lineTo(front.right, front.top)
      ..close();
    canvas.drawPath(topPath, dark);
    canvas.drawPath(topPath, stroke);

    final sidePath = Path()
      ..moveTo(front.right, front.top)
      ..lineTo(front.right + depth, front.top - depth)
      ..lineTo(front.right + depth, front.bottom - depth)
      ..lineTo(front.right, front.bottom)
      ..close();
    canvas.drawPath(sidePath, dark);
    canvas.drawPath(sidePath, stroke);
  }

  @override
  bool shouldRepaint(covariant _Shape3DPainter oldDelegate) =>
      oldDelegate.shapeId != shapeId;
}

class _SymmetryPainter extends CustomPainter {
  final String shapeId;
  final bool symmetric;
  const _SymmetryPainter(this.shapeId, this.symmetric);

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = _GJState._leafGreen;
    final stroke = Paint()
      ..color = _GJState._vineBrown
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 10;
    final path = Path();

    switch (shapeId) {
      case 'square':
        path.addRect(Rect.fromCenter(center: c, width: r * 1.6, height: r * 1.6));
      case 'rectangle':
        path.addRect(Rect.fromCenter(center: c, width: r * 1.9, height: r * 1.1));
      case 'circle':
        path.addOval(Rect.fromCircle(center: c, radius: r));
      case 'triangle':
        path.moveTo(c.dx, c.dy - r);
        path.lineTo(c.dx + r * 0.95, c.dy + r * 0.8);
        path.lineTo(c.dx - r * 0.95, c.dy + r * 0.8);
        path.close();
      case 'blob':
        path.moveTo(c.dx - r * 0.8, c.dy - r * 0.3);
        path.quadraticBezierTo(c.dx - r, c.dy - r, c.dx, c.dy - r * 0.7);
        path.quadraticBezierTo(c.dx + r * 0.9, c.dy - r * 0.9, c.dx + r * 0.8, c.dy);
        path.quadraticBezierTo(c.dx + r, c.dy + r * 0.7, c.dx + r * 0.2, c.dy + r * 0.8);
        path.quadraticBezierTo(c.dx - r * 0.5, c.dy + r, c.dx - r * 0.8, c.dy + r * 0.3);
        path.close();
    }
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);

    final linePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.5;
    Offset a, b;
    if (symmetric) {
      a = Offset(c.dx, c.dy - r * 1.15);
      b = Offset(c.dx, c.dy + r * 1.15);
    } else {
      a = Offset(c.dx - r * 1.1, c.dy - r * 0.9);
      b = Offset(c.dx + r * 0.7, c.dy + r * 1.1);
    }
    _drawDashedLine(canvas, a, b, linePaint);
  }

  void _drawDashedLine(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dashLen = 7.0, gapLen = 5.0;
    final total = (b - a).distance;
    final dir = (b - a) / total;
    var covered = 0.0;
    while (covered < total) {
      final start = a + dir * covered;
      final end = a + dir * math.min(covered + dashLen, total);
      canvas.drawLine(start, end, paint);
      covered += dashLen + gapLen;
    }
  }

  @override
  bool shouldRepaint(covariant _SymmetryPainter oldDelegate) =>
      oldDelegate.shapeId != shapeId || oldDelegate.symmetric != symmetric;
}

class _FireflyShowerPainter extends CustomPainter {
  final double t;
  const _FireflyShowerPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(11);
    for (var i = 0; i < 20; i++) {
      final startX = rng.nextDouble() * size.width;
      final startY = rng.nextDouble() * size.height;
      final drift = math.sin(t * 6 + i) * 20;
      final glow = (math.sin(t * 10 + i) + 1) / 2;
      final paint = Paint()
        ..color = _GJState._gold
            .withValues(alpha: (1 - t).clamp(0.0, 1.0) * (0.3 + glow * 0.7));
      canvas.drawCircle(Offset(startX + drift, startY), 3, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FireflyShowerPainter oldDelegate) =>
      oldDelegate.t != t;
}

class _JungleBgPainter extends CustomPainter {
  final double t;
  const _JungleBgPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04 + 0.02 * t);
    for (var i = 0; i < 4; i++) {
      final x = size.width * (0.15 + i * 0.25);
      final sway = math.sin(t * math.pi * 2 + i) * 8;
      canvas.drawCircle(
          Offset(x + sway, size.height * 0.12 + i * 12), 26, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _JungleBgPainter oldDelegate) =>
      oldDelegate.t != t;
}

// ── Header / progress ────────────────────────────────────────────────────────

class _JungleHeader extends StatelessWidget {
  final String zoneName;
  final int zoneIdx;
  final int totalZones;
  final int completedSteps;
  final int totalSteps;
  const _JungleHeader({
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
              const Text('🌴', style: TextStyle(fontSize: 22)),
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
          _VineTrail(completed: completedSteps, total: totalSteps),
        ],
      ),
    );
  }
}

class _VineTrail extends StatelessWidget {
  final int completed;
  final int total;
  const _VineTrail({required this.completed, required this.total});

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
                  i < completed ? '🐵' : '·',
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
        color: Colors.black45,
        alignment: Alignment.center,
        child: Container(
          padding: const EdgeInsets.all(24),
          margin: const EdgeInsets.symmetric(horizontal: 40),
          decoration: BoxDecoration(
            color: _GJState._jungleGreen,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _GJState._gold, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🌳', style: TextStyle(fontSize: 40)),
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
            colors: [_GJState._jungleGreen, Color(0xFF072A20)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🌴🐒🌴', style: TextStyle(fontSize: 44)),
                  SizedBox(height: 16),
                  Text(
                    'Geometry Jungle',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Drag every shape, angle and 3D object to its '
                    'matching jungle sign!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  SizedBox(height: 24),
                  CircularProgressIndicator(color: _GJState._gold),
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
            colors: [_GJState._jungleGreen, Color(0xFF072A20)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🏆🌴', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  const Text('Jungle Explored!',
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
                          color: _GJState._gold,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: onReplay,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _GJState._leafGreen,
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
