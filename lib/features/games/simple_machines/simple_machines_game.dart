import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/game_session_model.dart';
import '../core/game_config.dart';
import '../core/game_session_persistence.dart';

// ────────────────────────────────────────────────────────────────────────────
// Simple Machines — Grade 4 Technology: levers, pulleys, gears and other
// engineering challenges
//
// 4 Zones (5 questions each = 20 total):
//   1. Balance the Lever — a seesaw diagram with weights on each side;
//      predict whether it balances or which side goes down
//   2. Pulley Power       — recall MCQ about how pulleys work
//   3. Which Machine?     — classify a real tool as a type of simple machine
//   4. Machines at Work   — word problems about simple machines
//
// Structurally distinct from every prior engine: Balance the Lever draws a
// live seesaw diagram that stays perfectly level while the learner is
// deciding, then physically TILTS to the true outcome the moment the
// answer is revealed -- the diagram itself is the payoff, not just a
// static picture, and no prior engine visualises a physics outcome this way.
// Architecture: fully self-contained StatefulWidget.
// ────────────────────────────────────────────────────────────────────────────

enum _Phase { intro, playing, correct, wrong, streak, zoneDone, victory }

enum _Kind { lever, simple }

class _LeverQ {
  final int leftWeight;
  final int rightWeight;
  final double tiltAngle; // negative = left down, positive = right down, 0 = balance
  final List<String> choices; // [0] correct
  const _LeverQ({
    required this.leftWeight,
    required this.rightWeight,
    required this.tiltAngle,
    required this.choices,
  });
}

class _SimpleQ {
  final String prompt;
  final List<String> choices; // [0] correct
  const _SimpleQ({required this.prompt, required this.choices});
}

class _Zone {
  final String name;
  final _Kind kind;
  final List<_LeverQ> levers;
  final List<_SimpleQ> simple;
  const _Zone.lever(this.name, this.levers)
      : kind = _Kind.lever,
        simple = const [];
  const _Zone.simple(this.name, this.simple)
      : kind = _Kind.simple,
        levers = const [];

  int get length => kind == _Kind.lever ? levers.length : simple.length;
}

class SimpleMachinesGame extends StatefulWidget {
  final GameConfig config;
  final dynamic user;
  const SimpleMachinesGame({super.key, required this.config, this.user});

  @override
  State<SimpleMachinesGame> createState() => _SMState();
}

class _SMState extends State<SimpleMachinesGame> with TickerProviderStateMixin {
  static const _zones = [
    _Zone.lever('Balance the Lever', [
      _LeverQ(
          leftWeight: 2,
          rightWeight: 2,
          tiltAngle: 0,
          choices: ['It will balance', 'The left side goes down', 'The right side goes down']),
      _LeverQ(
          leftWeight: 3,
          rightWeight: 1,
          tiltAngle: -0.18,
          choices: ['The left side goes down', 'The right side goes down', 'It will balance']),
      _LeverQ(
          leftWeight: 1,
          rightWeight: 4,
          tiltAngle: 0.18,
          choices: ['The right side goes down', 'The left side goes down', 'It will balance']),
      _LeverQ(
          leftWeight: 2,
          rightWeight: 3,
          tiltAngle: 0.14,
          choices: ['The right side goes down', 'It will balance', 'The left side goes down']),
      _LeverQ(
          leftWeight: 4,
          rightWeight: 4,
          tiltAngle: 0,
          choices: ['It will balance', 'The right side goes down', 'The left side goes down']),
    ]),
    _Zone.simple('Pulley Power', [
      _SimpleQ(
          prompt: 'A pulley changes the...?',
          choices: ['Direction of the force', 'Amount of the load', 'Colour of the rope']),
      _SimpleQ(
          prompt: 'Which of these uses a pulley?',
          choices: ['A flagpole', 'A door hinge', 'A ramp']),
      _SimpleQ(
          prompt: 'Pulling DOWN on a pulley rope lifts the load...?',
          choices: ['Up', 'Sideways', 'Down']),
      _SimpleQ(
          prompt: 'A pulley makes lifting heavy loads...?',
          choices: ['Easier', 'Harder', 'Impossible']),
      _SimpleQ(
          prompt: 'Which of these uses a pulley system?',
          choices: ['A crane', 'A see-saw', 'A door']),
    ]),
    _Zone.simple('Which Machine?', [
      _SimpleQ(
          prompt: 'A see-saw is an example of a...?',
          choices: ['Lever', 'Pulley', 'Screw']),
      _SimpleQ(
          prompt: 'A ramp for a wheelchair is an example of a...?',
          choices: ['Inclined plane', 'Lever', 'Wheel and axle']),
      _SimpleQ(
          prompt: 'A doorknob is an example of a...?',
          choices: ['Wheel and axle', 'Pulley', 'Wedge']),
      _SimpleQ(
          prompt: 'An axe blade is an example of a...?',
          choices: ['Wedge', 'Screw', 'Lever']),
      _SimpleQ(
          prompt: 'A screwdriver turning a screw uses a...?',
          choices: ['Screw', 'Wedge', 'Pulley']),
    ]),
    _Zone.simple('Machines at Work', [
      _SimpleQ(
          prompt: 'A ramp used to load a wheelbarrow into a truck is an example of a...?',
          choices: ['Inclined plane', 'Wedge', 'Pulley']),
      _SimpleQ(
          prompt: 'Using a crowbar to lift a heavy rock is an example of a...?',
          choices: ['Lever', 'Screw', 'Wheel and axle']),
      _SimpleQ(
          prompt: 'A bicycle uses a...?',
          choices: ['Wheel and axle', 'Pulley', 'Wedge']),
      _SimpleQ(
          prompt: 'Simple machines make work easier by changing the...?',
          choices: ['Amount or direction of force needed', 'Colour of the object', 'Weight of the object']),
      _SimpleQ(
          prompt: 'Scissors use two of which simple machine?',
          choices: ['Levers', 'Pulleys', 'Screws']),
    ]),
  ];

  static const _wrongReactions = [
    'Not quite -- check the weights again!',
    'Close -- think about which side is heavier!',
    'Try again, engineer!',
  ];

  static const _workshopTop = Color(0xFFE8D9B5);
  static const _workshopBottom = Color(0xFF8C6D46);
  static const _card = Color(0xFF5C4326);
  static const _steel = Color(0xFF6E7C89);

  late AnimationController _ambientCtrl;
  late AnimationController _fadeCtrl;
  late AnimationController _flashCtrl;
  late AnimationController _burstCtrl;
  late AnimationController _shakeCtrl;
  late AnimationController _tiltCtrl;

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

    _tiltCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
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
    _tiltCtrl.dispose();
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
    _tiltCtrl.value = 0;
  }

  Object? _cachedQ;
  List<String> _cachedChoices = [];

  List<String> _getShuffledChoices(dynamic q) {
    if (!identical(_cachedQ, q)) {
      _cachedQ = q;
      _cachedChoices = List<String>.from(q.choices as List<String>)..shuffle(_rng);
    }
    return _cachedChoices;
  }

  void _onAnswer(int index) {
    if (_phase != _Phase.playing) return;
    final zone = _zones[_zoneIdx];
    final dynamic q = zone.kind == _Kind.lever ? zone.levers[_qIdx] : zone.simple[_qIdx];
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
    _tiltCtrl.forward(from: 0);

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
      _delayed(2000, _advance);
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
          _fadeCtrl.forward(from: 0);
          _tiltCtrl.value = 0;
        });
      }
    } else {
      setState(() {
        _qIdx = next;
        _selectedIndex = null;
        _phase = _Phase.playing;
      });
      _fadeCtrl.forward(from: 0);
      _tiltCtrl.value = 0;
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

    final dynamic currentQ = zone.kind == _Kind.lever ? zone.levers[_qIdx] : zone.simple[_qIdx];
    final choices = _getShuffledChoices(currentQ);
    final prompt = zone.kind == _Kind.lever
        ? 'Study the lever -- what will happen?'
        : zone.simple[_qIdx].prompt;

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_workshopTop, _workshopBottom],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _ambientAnim,
              builder: (context, _) =>
                  CustomPaint(painter: _GearBgPainter(_ambientAnim.value)),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _WorkshopHeader(
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
                            prompt,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: _card, fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 18),
                          if (zone.kind == _Kind.lever)
                            AnimatedBuilder(
                              animation: _tiltCtrl,
                              builder: (context, _) => SizedBox(
                                width: 260,
                                height: 140,
                                child: CustomPaint(
                                  painter: _LeverPainter(
                                    leftWeight: zone.levers[_qIdx].leftWeight,
                                    rightWeight: zone.levers[_qIdx].rightWeight,
                                    tilt: revealed
                                        ? zone.levers[_qIdx].tiltAngle * _tiltCtrl.value
                                        : 0,
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: 24),
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
                                    for (var i = 0; i < choices.length; i++)
                                      _GearTile(
                                        label: choices[i],
                                        selected: _selectedIndex == i,
                                        isCorrect: choices[i] == currentQ.choices[0],
                                        revealed: revealed,
                                        onTap: () => _onAnswer(i),
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
                                '$_wrongReaction The answer was ${currentQ.choices[0]}.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: _card, fontSize: 14, fontWeight: FontWeight.w600),
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
                  child: Container(color: const Color(0xFF4CAF7D)),
                ),
              ),
            ),
          if (_phase == _Phase.streak)
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _burstAnim,
                builder: (context, _) => CustomPaint(
                  painter: _BoltShowerPainter(_burstAnim.value),
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
}

// ── Lever diagram ────────────────────────────────────────────────────────────

class _LeverPainter extends CustomPainter {
  final int leftWeight;
  final int rightWeight;
  final double tilt;
  const _LeverPainter({required this.leftWeight, required this.rightWeight, required this.tilt});

  @override
  void paint(Canvas canvas, Size size) {
    final pivot = Offset(size.width / 2, size.height * 0.55);
    // Fulcrum triangle
    final fulcrumPaint = Paint()..color = _SMState._steel;
    final fulcrum = Path()
      ..moveTo(pivot.dx, pivot.dy)
      ..lineTo(pivot.dx - 22, pivot.dy + 40)
      ..lineTo(pivot.dx + 22, pivot.dy + 40)
      ..close();
    canvas.drawPath(fulcrum, fulcrumPaint);

    // Beam (rotated around pivot)
    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(tilt);
    final beamPaint = Paint()..color = _SMState._card;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: 200, height: 10),
        const Radius.circular(4),
      ),
      beamPaint,
    );

    // Weights
    void drawWeights(double x, int count, Color color) {
      for (var i = 0; i < count; i++) {
        const w = 20.0;
        final rect = Rect.fromCenter(
          center: Offset(x, -10 - i * (w + 2)),
          width: w,
          height: w,
        );
        canvas.drawRect(rect, Paint()..color = color);
        canvas.drawRect(rect, Paint()..color = Colors.black26..style = PaintingStyle.stroke);
      }
    }

    drawWeights(-85, leftWeight, const Color(0xFF3B6FA0));
    drawWeights(85, rightWeight, const Color(0xFFC1502E));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LeverPainter oldDelegate) =>
      oldDelegate.tilt != tilt ||
      oldDelegate.leftWeight != leftWeight ||
      oldDelegate.rightWeight != rightWeight;
}

// ── Gear tile (MCQ) ──────────────────────────────────────────────────────────

class _GearTile extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isCorrect;
  final bool revealed;
  final VoidCallback onTap;
  const _GearTile({
    required this.label,
    required this.selected,
    required this.isCorrect,
    required this.revealed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color fill = _SMState._steel;
    if (revealed && isCorrect) fill = const Color(0xFF4CAF7D);
    if (revealed && selected && !isCorrect) fill = const Color(0xFFE05656);

    return GestureDetector(
      onTap: revealed ? null : onTap,
      child: Container(
        constraints: const BoxConstraints(minWidth: 110, maxWidth: 220),
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
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

class _GearBgPainter extends CustomPainter {
  final double t;
  const _GearBgPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (var i = 0; i < 3; i++) {
      final cx = size.width * (0.2 + i * 0.3);
      final cy = size.height * 0.1;
      const r = 16.0;
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(t * math.pi * (i.isEven ? 1 : -1));
      for (var j = 0; j < 8; j++) {
        final angle = j * math.pi / 4;
        canvas.drawLine(
          Offset(math.cos(angle) * r, math.sin(angle) * r),
          Offset(math.cos(angle) * (r + 6), math.sin(angle) * (r + 6)),
          paint,
        );
      }
      canvas.drawCircle(Offset.zero, r, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _GearBgPainter oldDelegate) => oldDelegate.t != t;
}

class _BoltShowerPainter extends CustomPainter {
  final double t;
  const _BoltShowerPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(71);
    for (var i = 0; i < 18; i++) {
      final startX = rng.nextDouble() * size.width;
      final speed = 0.5 + rng.nextDouble() * 0.6;
      final y = (t * speed) * (size.height + 40) - 20;
      final x = startX + math.sin((t * 6) + i) * 12;
      final paint = Paint()
        ..color = _SMState._steel.withValues(alpha: (1 - t).clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(t * 8 + i);
      canvas.drawRect(const Rect.fromLTWH(-4, -4, 8, 8), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _BoltShowerPainter oldDelegate) => oldDelegate.t != t;
}

// ── Header / progress ────────────────────────────────────────────────────────

class _WorkshopHeader extends StatelessWidget {
  final String zoneName;
  final int zoneIdx;
  final int totalZones;
  final int completedSteps;
  final int totalSteps;
  const _WorkshopHeader({
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
              const Text('⚙️', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  children: [
                    Text('Zone ${zoneIdx + 1}/$totalZones',
                        style: const TextStyle(color: _SMState._card, fontSize: 11)),
                    Text(
                      zoneName,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _SMState._card, fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 30),
            ],
          ),
          const SizedBox(height: 8),
          _WorkshopTrail(completed: completedSteps, total: totalSteps),
        ],
      ),
    );
  }
}

class _WorkshopTrail extends StatelessWidget {
  final int completed;
  final int total;
  const _WorkshopTrail({required this.completed, required this.total});

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
            color: _SMState._card.withValues(alpha: 0.2),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < total; i++)
                Text(
                  i < completed ? '⚙️' : '·',
                  style: TextStyle(
                    fontSize: i < completed ? 12 : 10,
                    color: i < completed ? null : _SMState._card.withValues(alpha: 0.35),
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
        color: Colors.black38,
        alignment: Alignment.center,
        child: Container(
          padding: const EdgeInsets.all(24),
          margin: const EdgeInsets.symmetric(horizontal: 40),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _SMState._card, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('⚙️', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 8),
              Text('$completedZoneName complete!',
                  style: const TextStyle(color: _SMState._card, fontSize: 18, fontWeight: FontWeight.w700)),
              if (nextZoneName != null) ...[
                const SizedBox(height: 6),
                Text('Next: $nextZoneName', style: const TextStyle(color: _SMState._card, fontSize: 13)),
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
            colors: [_SMState._workshopTop, _SMState._workshopBottom],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('⚙️🔧', style: TextStyle(fontSize: 44)),
                  SizedBox(height: 16),
                  Text(
                    'Simple Machines',
                    style: TextStyle(color: _SMState._card, fontSize: 28, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Balance levers, power pulleys and discover the '
                    'machines that make work easier!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF4A3A22), fontSize: 14),
                  ),
                  SizedBox(height: 24),
                  CircularProgressIndicator(color: _SMState._card),
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
            colors: [_SMState._workshopTop, _SMState._workshopBottom],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🏆⚙️', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  const Text('Machines Mastered!',
                      style: TextStyle(color: _SMState._card, fontSize: 24, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  Text('$correctCount / $total correct ($pct%)',
                      style: const TextStyle(color: Color(0xFF4A3A22), fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('+$totalXP XP',
                      style: const TextStyle(color: _SMState._card, fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: onReplay,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _SMState._card,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    ),
                    child: const Text('Play Again'),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: onExit,
                    child: const Text('Exit', style: TextStyle(color: Color(0xFF4A3A22))),
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
