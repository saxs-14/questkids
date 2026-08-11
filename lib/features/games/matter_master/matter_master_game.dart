import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/game_session_model.dart';
import '../core/game_config.dart';
import '../core/game_session_persistence.dart';

// ────────────────────────────────────────────────────────────────────────────
// Matter Master — Grade 4 Natural Sciences: solids, liquids, gases
//
// 4 Zones (5 questions each = 20 total):
//   1. Particle Watch  — a LIVE particle-motion animation (not a static
//      diagram) shows how tightly-packed/vibrating, loosely-flowing, or
//      freely-bouncing the particles are; identify the state from the
//      motion itself
//   2. Sort the Stuff  — classify everyday materials by state
//   3. Properties Panel — recall the defining property of each state
//   4. Change It Up    — melting, freezing, evaporation, condensation
//
// Structurally distinct from every prior engine: Particle Watch is the
// first engine anywhere in the app where the "diagram" itself is a live,
// continuously-animated physics-style simulation (particles jittering in
// a lattice for solids, drifting loosely for liquids, bouncing freely for
// gases) that the learner must read and interpret, rather than a static
// picture or chart.
// Architecture: fully self-contained StatefulWidget.
// ────────────────────────────────────────────────────────────────────────────

enum _Phase { intro, playing, correct, wrong, streak, zoneDone, victory }

enum _MatterState { solid, liquid, gas }

class _MatterQ {
  final String prompt;
  final _MatterState? particleState; // for Particle Watch diagram
  final List<String> choices; // [0] correct
  const _MatterQ({
    required this.prompt,
    this.particleState,
    required this.choices,
  });
}

class _Zone {
  final String name;
  final List<_MatterQ> questions;
  const _Zone(this.name, this.questions);
}

class MatterMasterGame extends StatefulWidget {
  final GameConfig config;
  final dynamic user;
  const MatterMasterGame({super.key, required this.config, this.user});

  @override
  State<MatterMasterGame> createState() => _MMasterState();
}

class _MMasterState extends State<MatterMasterGame>
    with TickerProviderStateMixin {
  static const _zones = [
    _Zone('Particle Watch', [
      _MatterQ(
          prompt: 'Watch the particles. What state of matter is this?',
          particleState: _MatterState.solid,
          choices: ['Solid', 'Liquid', 'Gas']),
      _MatterQ(
          prompt: 'Watch the particles. What state of matter is this?',
          particleState: _MatterState.liquid,
          choices: ['Liquid', 'Solid', 'Gas']),
      _MatterQ(
          prompt: 'Watch the particles. What state of matter is this?',
          particleState: _MatterState.gas,
          choices: ['Gas', 'Liquid', 'Solid']),
      _MatterQ(
          prompt: 'Watch the particles. What state of matter is this?',
          particleState: _MatterState.solid,
          choices: ['Solid', 'Gas', 'Liquid']),
      _MatterQ(
          prompt: 'Watch the particles. What state of matter is this?',
          particleState: _MatterState.gas,
          choices: ['Gas', 'Solid', 'Liquid']),
    ]),
    _Zone('Sort the Stuff', [
      _MatterQ(prompt: 'Ice is a...?', choices: ['Solid', 'Liquid', 'Gas']),
      _MatterQ(prompt: 'Juice is a...?', choices: ['Liquid', 'Solid', 'Gas']),
      _MatterQ(prompt: 'Steam is a...?', choices: ['Gas', 'Liquid', 'Solid']),
      _MatterQ(prompt: 'A rock is a...?', choices: ['Solid', 'Gas', 'Liquid']),
      _MatterQ(
          prompt: 'The air we breathe is a...?',
          choices: ['Gas', 'Solid', 'Liquid']),
    ]),
    _Zone('Properties Panel', [
      _MatterQ(
          prompt: 'Which state has a fixed shape AND a fixed volume?',
          choices: ['Solid', 'Liquid', 'Gas']),
      _MatterQ(
          prompt: 'Which state takes the shape of its container but keeps '
              'the same volume?',
          choices: ['Liquid', 'Solid', 'Gas']),
      _MatterQ(
          prompt: 'Which state spreads out to fill all the space available?',
          choices: ['Gas', 'Liquid', 'Solid']),
      _MatterQ(prompt: 'Which state can be poured?',
          choices: ['Liquid', 'Gas', 'Solid']),
      _MatterQ(
          prompt: 'Which state holds its own shape without a container?',
          choices: ['Solid', 'Gas', 'Liquid']),
    ]),
    _Zone('Change It Up', [
      _MatterQ(
          prompt: 'Ice melting into water is called...?',
          choices: ['Melting', 'Freezing', 'Evaporation']),
      _MatterQ(
          prompt: 'Water freezing into ice is called...?',
          choices: ['Freezing', 'Melting', 'Condensation']),
      _MatterQ(
          prompt: 'Water turning into steam is called...?',
          choices: ['Evaporation', 'Condensation', 'Melting']),
      _MatterQ(
          prompt: 'Steam turning back into water droplets is called...?',
          choices: ['Condensation', 'Evaporation', 'Freezing']),
      _MatterQ(
          prompt: 'Butter melting in the sun is an example of...?',
          choices: ['Melting', 'Freezing', 'Evaporation']),
    ]),
  ];

  static const _wrongReactions = [
    'Not quite -- look at the particles again!',
    'Close -- think about the properties again!',
    'Try again -- check your states of matter!',
  ];

  static const _labTop = Color(0xFFEAF4FB);
  static const _labBottom = Color(0xFF7FA8C9);
  static const _flask = Color(0xFF3B6FA0);
  static const _ink = Color(0xFF213B52);

  late AnimationController _ambientCtrl;
  late AnimationController _fadeCtrl;
  late AnimationController _flashCtrl;
  late AnimationController _burstCtrl;
  late AnimationController _shakeCtrl;
  late AnimationController _particleCtrl;

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

    _particleCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 4))
      ..repeat();
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
    _particleCtrl.dispose();
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

  List<String> _getShuffledChoices(_MatterQ q) {
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
          _burstCtrl.forward(from: 0);
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
                  colors: [_labTop, _labBottom],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _ambientAnim,
              builder: (context, _) =>
                  CustomPaint(painter: _LabBgPainter(_ambientAnim.value)),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _LabHeader(
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
                            q.prompt,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 18),
                          if (q.particleState != null)
                            AnimatedBuilder(
                              animation: _particleCtrl,
                              builder: (context, _) => SizedBox(
                                width: 170,
                                height: 170,
                                child: CustomPaint(
                                  painter: _ParticlePainter(
                                    state: q.particleState!,
                                    t: _particleCtrl.value,
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: 24),
                          AnimatedBuilder(
                            animation: _shakeAnim,
                            builder: (context, _) {
                              final dx = _phase == _Phase.wrong
                                  ? math.sin(_shakeAnim.value * math.pi * 6) *
                                      6
                                  : 0.0;
                              final choices = _getShuffledChoices(q);
                              return Transform.translate(
                                offset: Offset(dx, 0),
                                child: Wrap(
                                  spacing: 14,
                                  runSpacing: 14,
                                  alignment: WrapAlignment.center,
                                  children: [
                                    for (var i = 0; i < choices.length; i++)
                                      _FlaskTile(
                                        label: choices[i],
                                        selected: _selectedIndex == i,
                                        isCorrect: choices[i] == q.choices[0],
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
                                '$_wrongReaction The answer was ${q.choices[0]}.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: _ink,
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
                  child: Container(color: const Color(0xFF4CAF7D)),
                ),
              ),
            ),
          if (_phase == _Phase.streak)
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _burstAnim,
                builder: (context, _) => CustomPaint(
                  painter: _BubbleShowerPainter(_burstAnim.value),
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
}

// ── Live particle-motion diagram ─────────────────────────────────────────────

class _ParticlePainter extends CustomPainter {
  final _MatterState state;
  final double t; // 0..1 looping
  const _ParticlePainter({required this.state, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final flaskPaint = Paint()
      ..color = _MMasterState._flask.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = _MMasterState._flask
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(16));
    canvas.drawRRect(rrect, flaskPaint);
    canvas.drawRRect(rrect, borderPaint);

    final particlePaint = Paint()..color = _MMasterState._flask;
    final angle = t * 2 * math.pi;

    switch (state) {
      case _MatterState.solid:
        const cols = 4, rows = 4;
        for (var r = 0; r < rows; r++) {
          for (var c = 0; c < cols; c++) {
            final baseX = size.width * (c + 1) / (cols + 1);
            final baseY = size.height * (r + 1) / (rows + 1);
            final freq = 3 + ((r * cols + c) % 3);
            final jx = math.sin(angle * freq + r + c) * 2.5;
            final jy = math.cos(angle * freq + r - c) * 2.5;
            canvas.drawCircle(Offset(baseX + jx, baseY + jy), 5, particlePaint);
          }
        }
      case _MatterState.liquid:
        const count = 14;
        for (var i = 0; i < count; i++) {
          final freqX = 2 + (i % 3);
          final freqY = 2 + ((i + 1) % 3);
          final cx = size.width * (0.2 + 0.6 * ((i * 37) % 100) / 100);
          final cy = size.height * (0.5 + 0.4 * ((i * 53) % 100) / 100);
          final dx = math.sin(angle * freqX + i) * 14;
          final dy = math.cos(angle * freqY + i * 1.3) * 10;
          canvas.drawCircle(Offset(cx + dx, cy + dy), 5, particlePaint);
        }
      case _MatterState.gas:
        const count = 10;
        for (var i = 0; i < count; i++) {
          final freqX = 1 + (i % 4);
          final freqY = 1 + ((i + 2) % 4);
          final baseX = size.width * (0.15 + 0.7 * ((i * 29) % 100) / 100);
          final baseY = size.height * (0.15 + 0.7 * ((i * 71) % 100) / 100);
          final dx = math.sin(angle * freqX + i * 2) * 40;
          final dy = math.cos(angle * freqY + i * 1.7) * 40;
          final x = (baseX + dx).clamp(10.0, size.width - 10);
          final y = (baseY + dy).clamp(10.0, size.height - 10);
          canvas.drawCircle(Offset(x, y), 5, particlePaint);
        }
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.state != state;
}

// ── Flask answer tile ────────────────────────────────────────────────────────

class _FlaskTile extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isCorrect;
  final bool revealed;
  final VoidCallback onTap;
  const _FlaskTile({
    required this.label,
    required this.selected,
    required this.isCorrect,
    required this.revealed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color fill = _MMasterState._flask;
    if (revealed && isCorrect) fill = const Color(0xFF4CAF7D);
    if (revealed && selected && !isCorrect) fill = const Color(0xFFE05656);

    return GestureDetector(
      onTap: revealed ? null : onTap,
      child: ClipPath(
        clipper: const _FlaskClipper(),
        child: Container(
          width: 108,
          height: 78,
          alignment: Alignment.center,
          padding: const EdgeInsets.only(top: 14),
          color: fill,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _FlaskClipper extends CustomClipper<Path> {
  const _FlaskClipper();
  @override
  Path getClip(Size size) {
    final w = size.width, h = size.height;
    final neckW = w * 0.28;
    final path = Path()
      ..moveTo(w / 2 - neckW / 2, 0)
      ..lineTo(w / 2 + neckW / 2, 0)
      ..lineTo(w / 2 + neckW / 2, h * 0.35)
      ..lineTo(w * 0.92, h)
      ..lineTo(w * 0.08, h)
      ..lineTo(w / 2 - neckW / 2, h * 0.35)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

// ── Painters ─────────────────────────────────────────────────────────────────

class _LabBgPainter extends CustomPainter {
  final double t;
  const _LabBgPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.3);
    for (var i = 0; i < 3; i++) {
      final x = size.width * (0.2 + i * 0.3) + math.sin(t * math.pi * 2 + i) * 8;
      canvas.drawCircle(Offset(x, size.height * 0.1), 18, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LabBgPainter oldDelegate) => oldDelegate.t != t;
}

class _BubbleShowerPainter extends CustomPainter {
  final double t;
  const _BubbleShowerPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(41);
    for (var i = 0; i < 20; i++) {
      final startX = rng.nextDouble() * size.width;
      final speed = 0.5 + rng.nextDouble() * 0.6;
      final y = size.height - (t * speed) * (size.height + 40) + 20;
      final x = startX + math.sin((t * 6) + i) * 12;
      final paint = Paint()
        ..color = _MMasterState._flask
            .withValues(alpha: (1 - t).clamp(0.0, 1.0) * 0.6);
      canvas.drawCircle(Offset(x, y), 5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BubbleShowerPainter oldDelegate) =>
      oldDelegate.t != t;
}

// ── Header / progress ────────────────────────────────────────────────────────

class _LabHeader extends StatelessWidget {
  final String zoneName;
  final int zoneIdx;
  final int totalZones;
  final int completedSteps;
  final int totalSteps;
  const _LabHeader({
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
              const Text('🧪', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  children: [
                    Text('Zone ${zoneIdx + 1}/$totalZones',
                        style: const TextStyle(
                            color: _MMasterState._ink, fontSize: 11)),
                    Text(
                      zoneName,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: _MMasterState._ink,
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
          _LabTrail(completed: completedSteps, total: totalSteps),
        ],
      ),
    );
  }
}

class _LabTrail extends StatelessWidget {
  final int completed;
  final int total;
  const _LabTrail({required this.completed, required this.total});

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
            color: _MMasterState._ink.withValues(alpha: 0.15),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < total; i++)
                Text(
                  i < completed ? '⚗️' : '·',
                  style: TextStyle(
                    fontSize: i < completed ? 12 : 10,
                    color: i < completed
                        ? null
                        : _MMasterState._ink.withValues(alpha: 0.35),
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
        color: Colors.black26,
        alignment: Alignment.center,
        child: Container(
          padding: const EdgeInsets.all(24),
          margin: const EdgeInsets.symmetric(horizontal: 40),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _MMasterState._flask, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🧪', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 8),
              Text('$completedZoneName complete!',
                  style: const TextStyle(
                      color: _MMasterState._ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
              if (nextZoneName != null) ...[
                const SizedBox(height: 6),
                Text('Next: $nextZoneName',
                    style: const TextStyle(
                        color: _MMasterState._ink, fontSize: 13)),
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
            colors: [_MMasterState._labTop, _MMasterState._labBottom],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🧪⚗️', style: TextStyle(fontSize: 44)),
                  SizedBox(height: 16),
                  Text(
                    'Matter Master',
                    style: TextStyle(
                      color: _MMasterState._ink,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Watch how the particles move -- solids, liquids and '
                    'gases each behave in their own way!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF3E5A72), fontSize: 14),
                  ),
                  SizedBox(height: 24),
                  CircularProgressIndicator(color: _MMasterState._flask),
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
            colors: [_MMasterState._labTop, _MMasterState._labBottom],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🏆🧪', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  const Text('Matter Mastered!',
                      style: TextStyle(
                          color: _MMasterState._ink,
                          fontSize: 24,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  Text('$correctCount / $total correct ($pct%)',
                      style: const TextStyle(
                          color: Color(0xFF3E5A72), fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('+$totalXP XP',
                      style: const TextStyle(
                          color: _MMasterState._ink,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: onReplay,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _MMasterState._flask,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 14),
                    ),
                    child: const Text('Play Again'),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: onExit,
                    child: const Text('Exit',
                        style: TextStyle(color: Color(0xFF3E5A72))),
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
