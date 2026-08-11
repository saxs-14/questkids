import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/game_session_model.dart';
import '../core/game_config.dart';
import '../core/game_session_persistence.dart';

// ────────────────────────────────────────────────────────────────────────────
// Number Ninja — Grade 4 Mathematics: number patterns and sequences
//
// 4 Zones (5 questions each = 20 total):
//   1. Add Pattern Dojo    — ascending sequences, constant difference
//   2. Subtract Pattern Dojo — descending sequences, constant difference
//   3. Skip Count Shadows   — skip-counting / multiples patterns
//   4. Rule Master          — input-output "function machine" rules
//
// Structurally distinct from every prior engine: the first REFLEX / timed
// mechanic in the roster. Every question has a shrinking "chi" timer bar;
// if it runs out before a shuriken is tapped, the question resolves as a
// timeout (shown distinctly from a wrong tap) with no permanent penalty --
// same no-punishment philosophy as every other engine, just under real
// time pressure, matching the "ninja reflex" framing.
// Architecture: fully self-contained StatefulWidget.
// ────────────────────────────────────────────────────────────────────────────

enum _Phase { intro, playing, correct, wrong, streak, zoneDone, victory }

class _NinjaQ {
  final String prompt;
  final List<String> choices; // choices[0] is always correct
  const _NinjaQ({required this.prompt, required this.choices});
}

class _Zone {
  final String name;
  final List<_NinjaQ> questions;
  const _Zone(this.name, this.questions);
}

class NumberNinjaGame extends StatefulWidget {
  final GameConfig config;
  final dynamic user;
  const NumberNinjaGame({super.key, required this.config, this.user});

  @override
  State<NumberNinjaGame> createState() => _NNState();
}

class _NNState extends State<NumberNinjaGame> with TickerProviderStateMixin {
  static const _zones = [
    _Zone('Add Pattern Dojo', [
      _NinjaQ(prompt: '3, 6, 9, 12, ?', choices: ['15', '14', '18']),
      _NinjaQ(prompt: '5, 10, 15, 20, ?', choices: ['25', '24', '30']),
      _NinjaQ(prompt: '2, 5, 8, 11, ?', choices: ['14', '13', '15']),
      _NinjaQ(prompt: '10, 20, 30, 40, ?', choices: ['50', '45', '60']),
      _NinjaQ(prompt: '4, 9, 14, 19, ?', choices: ['24', '23', '25']),
    ]),
    _Zone('Subtract Pattern Dojo', [
      _NinjaQ(prompt: '50, 45, 40, 35, ?', choices: ['30', '25', '35']),
      _NinjaQ(prompt: '100, 90, 80, 70, ?', choices: ['60', '50', '65']),
      _NinjaQ(prompt: '33, 28, 23, 18, ?', choices: ['13', '12', '14']),
      _NinjaQ(prompt: '90, 80, 70, 60, ?', choices: ['50', '40', '55']),
      _NinjaQ(prompt: '44, 38, 32, 26, ?', choices: ['20', '19', '24']),
    ]),
    _Zone('Skip Count Shadows', [
      _NinjaQ(prompt: '7, 14, 21, 28, ?', choices: ['35', '36', '42']),
      _NinjaQ(prompt: '6, 12, 18, 24, ?', choices: ['30', '28', '36']),
      _NinjaQ(prompt: '9, 18, 27, 36, ?', choices: ['45', '44', '54']),
      _NinjaQ(prompt: '12, 24, 36, 48, ?', choices: ['60', '54', '72']),
      _NinjaQ(prompt: '11, 22, 33, 44, ?', choices: ['55', '54', '66']),
    ]),
    _Zone('Rule Master', [
      _NinjaQ(
          prompt: 'Rule: ×2\nInput 6 → Output ?',
          choices: ['12', '10', '14']),
      _NinjaQ(
          prompt: 'Rule: +5\nInput 9 → Output ?',
          choices: ['14', '13', '15']),
      _NinjaQ(
          prompt: 'Rule: ×3\nInput 4 → Output ?',
          choices: ['12', '9', '15']),
      _NinjaQ(
          prompt: 'Rule: -6\nInput 20 → Output ?',
          choices: ['14', '13', '16']),
      _NinjaQ(
          prompt: 'Rule: ×2, then +1\nInput 5 → Output ?',
          choices: ['11', '10', '12']),
    ]),
  ];

  static const _wrongReactions = [
    'Not quite -- check the pattern again!',
    'Close -- look at the gap between numbers!',
    'Try again, ninja -- watch the rule!',
  ];

  static const _dojoBg = Color(0xFF1B1B2E);
  static const _dojoBg2 = Color(0xFF3D2B4F);
  static const _lantern = Color(0xFFE23D3D);
  static const _gold = Color(0xFFFFC94A);

  static const _questionSeconds = 6;

  late AnimationController _ambientCtrl;
  late AnimationController _fadeCtrl;
  late AnimationController _flashCtrl;
  late AnimationController _burstCtrl;
  late AnimationController _shakeCtrl;
  late AnimationController _timerCtrl;

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
  bool _timedOut = false;
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
        vsync: this, duration: const Duration(seconds: 5))
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

    _timerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _questionSeconds),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && _phase == _Phase.playing) {
          _onTimeout();
        }
      });
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
    _timerCtrl.dispose();
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
      _timedOut = false;
    });
    _fadeCtrl.forward(from: 0);
    _timerCtrl.forward(from: 0);
  }

  void _onTimeout() {
    if (_phase != _Phase.playing) return;
    setState(() {
      _selectedIndex = null;
      _timedOut = true;
    });
    _applyAnswerResult(false);
  }

  Object? _cachedQ;
  List<String> _cachedChoices = [];

  List<String> _getShuffledChoices(_NinjaQ q) {
    if (!identical(_cachedQ, q)) {
      _cachedQ = q;
      _cachedChoices = List<String>.from(q.choices)..shuffle(_rng);
    }
    return _cachedChoices;
  }

  void _onAnswer(int index) {
    if (_phase != _Phase.playing) return;
    _timerCtrl.stop();
    final q = _zones[_zoneIdx].questions[_qIdx];
    final choices = _getShuffledChoices(q);
    final isCorrect = choices[index] == q.choices[0];
    setState(() {
      _selectedIndex = index;
      _timedOut = false;
    });
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
            _timedOut = false;
            _phase = _Phase.playing;
          });
          _fadeCtrl.forward(from: 0);
          _timerCtrl.forward(from: 0);
        });
      }
    } else {
      setState(() {
        _qIdx = next;
        _selectedIndex = null;
        _timedOut = false;
        _phase = _Phase.playing;
      });
      _fadeCtrl.forward(from: 0);
      _timerCtrl.forward(from: 0);
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
                  colors: [_dojoBg, _dojoBg2],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _ambientAnim,
              builder: (context, _) =>
                  CustomPaint(painter: _LanternBgPainter(_ambientAnim.value)),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _DojoHeader(
                  zoneName: zone.name,
                  zoneIdx: _zoneIdx,
                  totalZones: _zones.length,
                  completedSteps: completedSteps,
                  totalSteps: total,
                ),
                if (!revealed)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _ChiBar(controller: _timerCtrl),
                  ),
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          const SizedBox(height: 16),
                          Text(
                            q.prompt,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 26),
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
                                  spacing: 16,
                                  runSpacing: 16,
                                  alignment: WrapAlignment.center,
                                  children: [
                                    for (var i = 0; i < choices.length; i++)
                                      _ShurikenButton(
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
                                _timedOut
                                    ? 'Too slow, ninja! The answer was ${q.choices[0]}.'
                                    : '$_wrongReaction The answer was ${q.choices[0]}.',
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
                  painter: _ShurikenBurstPainter(_burstAnim.value),
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

// ── Chi timer bar ─────────────────────────────────────────────────────────────

class _ChiBar extends StatelessWidget {
  final AnimationController controller;
  const _ChiBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final remaining = (1 - controller.value).clamp(0.0, 1.0);
        final color = Color.lerp(
          const Color(0xFFE23D3D),
          const Color(0xFF4CAF7D),
          remaining,
        )!;
        return ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: remaining,
            minHeight: 8,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        );
      },
    );
  }
}

// ── Shuriken button ──────────────────────────────────────────────────────────

class _ShurikenButton extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isCorrect;
  final bool revealed;
  final VoidCallback onTap;
  const _ShurikenButton({
    required this.label,
    required this.selected,
    required this.isCorrect,
    required this.revealed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color fill = _NNState._lantern;
    if (revealed && isCorrect) fill = const Color(0xFF4CAF7D);
    if (revealed && selected && !isCorrect) fill = const Color(0xFF5C5C6E);

    return GestureDetector(
      onTap: revealed ? null : onTap,
      child: ClipPath(
        clipper: const _ShurikenClipper(),
        child: Container(
          width: 92,
          height: 92,
          alignment: Alignment.center,
          color: fill,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _ShurikenClipper extends CustomClipper<Path> {
  const _ShurikenClipper();
  @override
  Path getClip(Size size) {
    final c = size.center(Offset.zero);
    final outerR = size.shortestSide / 2;
    final innerR = outerR * 0.42;
    const points = 4;
    final path = Path();
    for (var i = 0; i < points * 2; i++) {
      final r = i.isEven ? outerR : innerR;
      final angle = (math.pi / points) * i - math.pi / 2;
      final p = c + Offset(math.cos(angle), math.sin(angle)) * r;
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

// ── Painters ─────────────────────────────────────────────────────────────────

class _LanternBgPainter extends CustomPainter {
  final double t;
  const _LanternBgPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 4; i++) {
      final x = size.width * (0.15 + i * 0.25);
      final glow = (math.sin(t * math.pi * 2 + i * 1.4) + 1) / 2;
      canvas.drawCircle(
        Offset(x, size.height * 0.12),
        22,
        Paint()
          ..color = _NNState._lantern.withValues(alpha: 0.08 + glow * 0.1),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LanternBgPainter oldDelegate) =>
      oldDelegate.t != t;
}

class _ShurikenBurstPainter extends CustomPainter {
  final double t;
  const _ShurikenBurstPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(23);
    final center = Offset(size.width / 2, size.height * 0.35);
    for (var i = 0; i < 16; i++) {
      final angle = (i / 16) * 2 * math.pi;
      final dist = t * (100 + rng.nextDouble() * 120);
      final pos = center + Offset(math.cos(angle), math.sin(angle)) * dist;
      final paint = Paint()
        ..color = _NNState._gold.withValues(alpha: (1 - t).clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(t * 8 + i);
      canvas.drawRect(const Rect.fromLTWH(-5, -5, 10, 10), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ShurikenBurstPainter oldDelegate) =>
      oldDelegate.t != t;
}

// ── Header / progress ────────────────────────────────────────────────────────

class _DojoHeader extends StatelessWidget {
  final String zoneName;
  final int zoneIdx;
  final int totalZones;
  final int completedSteps;
  final int totalSteps;
  const _DojoHeader({
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
              const Text('🥷', style: TextStyle(fontSize: 22)),
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
          _NinjaTrail(completed: completedSteps, total: totalSteps),
        ],
      ),
    );
  }
}

class _NinjaTrail extends StatelessWidget {
  final int completed;
  final int total;
  const _NinjaTrail({required this.completed, required this.total});

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
                  i < completed ? '⚔️' : '·',
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
            color: _NNState._dojoBg2,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _NNState._gold, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🥷', style: TextStyle(fontSize: 40)),
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
            colors: [_NNState._dojoBg, _NNState._dojoBg2],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🥷🔢', style: TextStyle(fontSize: 44)),
                  SizedBox(height: 16),
                  Text(
                    'Number Ninja',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Spot the pattern before your chi runs out -- '
                    'slice the correct number fast!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  SizedBox(height: 24),
                  CircularProgressIndicator(color: _NNState._gold),
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
            colors: [_NNState._dojoBg, _NNState._dojoBg2],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🏆🥷', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  const Text('Dojo Mastered!',
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
                          color: _NNState._gold,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: onReplay,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _NNState._lantern,
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
