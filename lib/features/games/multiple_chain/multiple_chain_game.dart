import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/game_session_model.dart';
import '../core/game_config.dart';
import '../core/game_session_persistence.dart';

// ────────────────────────────────────────────────────────────────────────────
// Multiple Chain — Grade 1 crystal cavern skip-counting quest
//
// 4 Zones (difficulty bands):
//   1. Twin Crystals   — skip counting by 2s (to 20)
//   2. Fivefold Grotto — skip counting by 5s (to 50)
//   3. Tenfold Vault   — skip counting by 10s (to 100)
//   4. Mixed Cavern    — randomly 2s, 5s or 10s each question
// 5 questions per zone = 20 total.
//
// CAPS Grade 1 covers skip counting forwards in 2s, 5s and 10s -- NOT
// formal multiplication/"multiples of a number" (that starts Grade 3).
// The original catalog description ("link the multiples of a number")
// was corrected to skip counting when this engine was built, keeping the
// chain-building idea from the brief while staying curriculum-accurate.
//
// Structurally distinct from every other Grade 1 engine so far: instead
// of a dot progress bar, the chain of glowing crystals IS the progress
// indicator -- it visibly grows link by link as questions are answered
// correctly, right on screen. Answer choices are hexagonal crystals (a
// fifth distinct button silhouette after rounded squares, circles, wood
// planks and diamonds). A wrong pick makes the pending crystal flicker
// and reset, never breaking crystals already placed in the chain. A
// streak triggers a resonance pulse of light sweeping through the whole
// chain. Architecture: fully self-contained StatefulWidget, no external
// engine (same pattern as the other Grade 1 games).
// ────────────────────────────────────────────────────────────────────────────

enum _Phase { intro, question, correct, wrong, streak, zoneDone, victory }

// ── Question model ─────────────────────────────────────────────────────────

class _Q {
  final int step; // 2, 5, or 10
  final List<int> chainSoFar; // the sequence shown before the blank
  final List<int> choices;
  final int correct;

  _Q({required this.step, required this.chainSoFar, required this.choices})
      : correct = chainSoFar.last + step;
}

// ── Zone definitions ─────────────────────────────────────────────────────────

class _Zone {
  final String name;
  final List<int> steps; // possible skip-count steps in this zone
  final int questionCount = 5;
  const _Zone(this.name, this.steps);
}

// ── Main game widget ───────────────────────────────────────────────────────

class MultipleChainGame extends StatefulWidget {
  final GameConfig config;
  final dynamic user;
  const MultipleChainGame({super.key, required this.config, this.user});

  @override
  State<MultipleChainGame> createState() => _MCState();
}

class _MCState extends State<MultipleChainGame>
    with TickerProviderStateMixin {
  static const _zones = [
    _Zone('Twin Crystals', [2]),
    _Zone('Fivefold Grotto', [5]),
    _Zone('Tenfold Vault', [10]),
    _Zone('Mixed Cavern', [2, 5, 10]),
  ];

  static const _wrongReactions = [
    'The crystal dims and waits... try again!',
    'Not quite — the cave echoes. Try again!',
    'Almost! The crystal flickers. Try again!',
  ];

  static const _crystalColors = [
    Color(0xFF4DD0E1),
    Color(0xFFBA68C8),
    Color(0xFF81C784),
    Color(0xFFFFB74D),
    Color(0xFF7986CB),
  ];

  // ── Animations ──────────────────────────────────────────────────────────
  late AnimationController _glowCtrl; // ambient crystal glow, looping
  late AnimationController _snapCtrl; // new link snaps into chain
  late AnimationController _flickerCtrl; // wrong-answer flicker
  late AnimationController _resonanceCtrl; // streak celebration
  late AnimationController _fadeCtrl; // question fade-in

  late Animation<double> _glowAnim;
  late Animation<double> _snapAnim;
  late Animation<double> _flickerAnim;
  late Animation<double> _resonanceAnim;
  late Animation<double> _fadeAnim;

  // ── Game state ──────────────────────────────────────────────────────────
  int _zoneIdx = 0;
  int _qIdx = 0;
  int _correctCount = 0;
  int _streak = 0;
  int _totalXP = 0;
  final List<int> _placedChain = []; // crystals successfully placed so far

  _Phase _phase = _Phase.intro;
  _Q? _current;
  int? _picked;
  String _wrongReaction = '';

  final _rng = math.Random();

  String get _uid => (widget.user?.uid as String?) ?? '';

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
    _delayed(800, _startGame);
  }

  void _initAnims() {
    _glowCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.5, end: 1.0)
        .animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));

    _snapCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _snapAnim = CurvedAnimation(parent: _snapCtrl, curve: Curves.elasticOut);

    _flickerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 550));
    _flickerAnim = CurvedAnimation(parent: _flickerCtrl, curve: Curves.easeInOut);

    _resonanceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600));
    _resonanceAnim = CurvedAnimation(parent: _resonanceCtrl, curve: Curves.easeOut);

    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
  }

  @override
  void dispose() {
    for (final timer in List<Timer>.from(_pendingTimers)) {
      timer.cancel();
    }
    _pendingTimers.clear();
    _glowCtrl.dispose();
    _snapCtrl.dispose();
    _flickerCtrl.dispose();
    _resonanceCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Game flow ────────────────────────────────────────────────────────────

  void _startGame() {
    setState(() {
      _zoneIdx = 0;
      _qIdx = 0;
      _correctCount = 0;
      _streak = 0;
      _totalXP = 0;
      _placedChain.clear();
    });
    _nextQuestion();
  }

  void _nextQuestion() {
    final zone = _zones[_zoneIdx];
    final q = _makeQuestion(zone);
    _fadeCtrl.reset();
    setState(() {
      _current = q;
      _picked = null;
      _phase = _Phase.question;
    });
    _fadeCtrl.forward();
  }

  void _onAnswer(int choice) {
    if (_picked != null || _phase != _Phase.question) return;
    final q = _current!;
    setState(() => _picked = choice);
    final correct = choice == q.correct;

    if (correct) {
      setState(() {
        _correctCount++;
        _streak++;
        _totalXP += 10;
        _placedChain.add(q.correct);
      });
      _snapCtrl.forward(from: 0);
      final isStreak = _streak > 0 && _streak % 3 == 0;
      if (isStreak) {
        setState(() => _phase = _Phase.streak);
        _resonanceCtrl.forward(from: 0);
        _delayed(1800, _advance);
      } else {
        setState(() => _phase = _Phase.correct);
        _delayed(1200, _advance);
      }
    } else {
      setState(() {
        _streak = 0;
        _phase = _Phase.wrong;
        _wrongReaction =
            _wrongReactions[_rng.nextInt(_wrongReactions.length)];
      });
      _flickerCtrl.forward(from: 0);
      _delayed(1300, _advance);
    }
  }

  void _advance() {
    if (!mounted) return;
    final zone = _zones[_zoneIdx];
    final next = _qIdx + 1;

    if (next >= zone.questionCount) {
      if (_zoneIdx + 1 >= _zones.length) {
        _persistSession();
        setState(() => _phase = _Phase.victory);
      } else {
        setState(() => _phase = _Phase.zoneDone);
        _delayed(2200, () {
          setState(() {
            _zoneIdx++;
            _qIdx = 0;
            _placedChain.clear();
          });
          _nextQuestion();
        });
      }
    } else {
      setState(() => _qIdx = next);
      _delayed(300, _nextQuestion);
    }
  }

  /// Persists this completed session the same way every other engine's
  /// GameSessionState.finishSession does -- this widget is intentionally
  /// self-contained (no GameEngine/GameSessionState), matching the other
  /// Grade 1 games' established pattern. Applies the same
  /// completion-bonus tiers as GameEngine.defaultResult() so the number
  /// shown on the victory screen matches what actually gets awarded.
  void _persistSession() {
    final totalQuestions =
        _zones.fold<int>(0, (sum, z) => sum + z.questionCount); // 20
    final accuracy =
        totalQuestions > 0 ? _correctCount / totalQuestions : 0.0;
    final isPerfect = _correctCount == totalQuestions;
    final isWin = _correctCount > totalQuestions / 2;
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
      result: isPerfect ? 'complete' : (isWin ? 'win' : 'loss'),
    );
    persistGameSession(session);
  }

  // ── Question generation ──────────────────────────────────────────────────

  _Q _makeQuestion(_Zone zone) {
    final step = zone.steps[_rng.nextInt(zone.steps.length)];
    // Start the visible chain at a random multiple of step, 3 links long.
    final startMultiplier = 1 + _rng.nextInt(4);
    final start = step * startMultiplier;
    final chainSoFar = [start, start + step, start + step * 2];
    final correct = chainSoFar.last + step;
    final choices = _threeChoices(correct, step);
    return _Q(step: step, chainSoFar: chainSoFar, choices: choices);
  }

  List<int> _threeChoices(int correct, int step) {
    final s = <int>{correct};
    int attempts = 0;
    while (s.length < 3 && attempts < 200) {
      // Distractors: off by a whole step (skipped/repeated a link), or a
      // small near-miss offset -- both plausible skip-counting slips.
      final offStep = correct + step * (_rng.nextBool() ? 1 : -1);
      final nearMiss = correct + (1 + _rng.nextInt(3)) * (_rng.nextBool() ? 1 : -1);
      final candidate = attempts.isEven ? offStep : nearMiss;
      if (candidate > 0 && candidate != correct) s.add(candidate);
      attempts++;
    }
    while (s.length < 3) s.add(correct + step * (s.length + 1));
    return s.toList()..shuffle(_rng);
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
        totalXP: _totalXP,
        onReplay: _startGame,
        onExit: () => Navigator.of(context).pop(),
      );
    }

    final zone = _zones[_zoneIdx];
    final q = _current;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _glowAnim,
              builder: (_, __) => CustomPaint(
                painter: _CavernBg(glow: _glowAnim.value),
              ),
            ),
          ),

          if (_phase == _Phase.streak)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _resonanceAnim,
                builder: (_, __) => CustomPaint(
                  painter: _ResonancePainter(_resonanceAnim.value),
                ),
              ),
            ),

          SafeArea(
            child: Column(
              children: [
                _CavernHeader(
                  zoneName: zone.name,
                  zoneIdx: _zoneIdx,
                  totalZones: _zones.length,
                  qIdx: _qIdx,
                  totalQ: zone.questionCount,
                  correctCount: _correctCount,
                ),
                SizedBox(
                  height: 96,
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_snapAnim, _glowAnim]),
                    builder: (_, __) => _ChainDisplay(
                      chain: _placedChain,
                      snapProgress: _snapAnim.value,
                      isNewlyPlaced: _phase == _Phase.correct ||
                          _phase == _Phase.streak,
                      glow: _glowAnim.value,
                      colors: _crystalColors,
                    ),
                  ),
                ),
                Expanded(
                  child: q == null
                      ? const SizedBox()
                      : FadeTransition(
                          opacity: _fadeAnim,
                          child: AnimatedBuilder(
                            animation: _flickerAnim,
                            builder: (_, child) => Opacity(
                              opacity: phaseFlickerOpacity(
                                  _phase, _flickerAnim.value),
                              child: child,
                            ),
                            child: _QuestionArea(
                              q: q,
                              phase: _phase,
                              picked: _picked,
                              onAnswer: _onAnswer,
                            ),
                          ),
                        ),
                ),
                _FeedbackBanner(
                    phase: _phase,
                    streak: _streak,
                    wrongReaction: _wrongReaction),
                if (_phase == _Phase.zoneDone)
                  _ZoneDone(zoneNum: _zoneIdx + 1),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static double phaseFlickerOpacity(_Phase phase, double t) {
    if (phase != _Phase.wrong) return 1.0;
    // Flicker between ~0.4 and 1.0 a couple of times.
    return 0.4 + 0.6 * (0.5 + 0.5 * math.sin(t * math.pi * 4));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cavern background CustomPainter — deep emerald/teal cave with glowing
// crystal formations. Distinct from the arena, ocean, savanna and
// mountain palettes.
// ─────────────────────────────────────────────────────────────────────────────

class _CavernBg extends CustomPainter {
  final double glow;
  _CavernBg({required this.glow});

  static final _rng = math.Random(55);
  static final _formations = List.generate(
      8,
      (i) => (
            x: _rng.nextDouble(),
            y: _rng.nextDouble() * 0.5,
            size: 10.0 + _rng.nextDouble() * 18,
            hue: _rng.nextInt(3),
          ));

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = const LinearGradient(
          colors: [
            Color(0xFF0B2E2A),
            Color(0xFF0F3D38),
            Color(0xFF14524A),
            Color(0xFF1B6E62),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    final palette = [
      const Color(0xFF4DD0E1),
      const Color(0xFFBA68C8),
      const Color(0xFF81C784),
    ];
    for (final f in _formations) {
      final c = palette[f.hue];
      canvas.drawCircle(
        Offset(f.x * w, f.y * h),
        f.size * (0.7 + glow * 0.3),
        Paint()
          ..color = c.withValues(alpha: 0.20 * glow)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
      canvas.drawCircle(
        Offset(f.x * w, f.y * h),
        f.size * 0.18,
        Paint()..color = c.withValues(alpha: 0.55),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CavernBg old) => old.glow != glow;
}

// ─────────────────────────────────────────────────────────────────────────────
// Chain display — the growing crystal chain IS the progress indicator
// for this game, replacing the dot-bar every other Grade 1 game uses.
// ─────────────────────────────────────────────────────────────────────────────

class _ChainDisplay extends StatelessWidget {
  final List<int> chain;
  final double snapProgress;
  final bool isNewlyPlaced;
  final double glow;
  final List<Color> colors;

  const _ChainDisplay({
    required this.chain,
    required this.snapProgress,
    required this.isNewlyPlaced,
    required this.glow,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (int i = 0; i < chain.length; i++) ...[
            if (i > 0)
              Icon(Icons.link, color: Colors.white.withValues(alpha: 0.5), size: 18),
            _CrystalLink(
              value: chain[i],
              color: colors[i % colors.length],
              scale: (isNewlyPlaced && i == chain.length - 1)
                  ? 0.7 + snapProgress * 0.3
                  : 1.0,
              glow: glow,
            ),
          ],
        ],
      ),
    );
  }
}

class _CrystalLink extends StatelessWidget {
  final int value;
  final Color color;
  final double scale;
  final double glow;

  const _CrystalLink(
      {required this.value,
      required this.color,
      required this.scale,
      required this.glow});

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: scale,
      child: Container(
        width: 46,
        height: 46,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.85),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.6 * glow), blurRadius: 12),
          ],
          border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.5),
        ),
        child: Center(
          child: Text('$value',
              style: const TextStyle(
                  color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cavern header: zone name + question progress + crystals linked count
// ─────────────────────────────────────────────────────────────────────────────

class _CavernHeader extends StatelessWidget {
  final String zoneName;
  final int zoneIdx, totalZones, qIdx, totalQ, correctCount;

  const _CavernHeader({
    required this.zoneName,
    required this.zoneIdx,
    required this.totalZones,
    required this.qIdx,
    required this.totalQ,
    required this.correctCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.30),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFF4DD0E1).withValues(alpha: 0.5), width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF4DD0E1).withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('💎 $correctCount',
                    style: const TextStyle(
                        color: Color(0xFF0B2E2A),
                        fontSize: 15,
                        fontWeight: FontWeight.w900)),
              ),
              Column(
                children: [
                  Text(
                    'Zone ${zoneIdx + 1}/$totalZones',
                    style: const TextStyle(
                        color: Color(0xFFB2EBF2),
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                  Text(
                    zoneName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(width: 54),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(totalQ, (i) {
              final done = i < qIdx;
              final active = i == qIdx;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 20 : 10,
                height: 10,
                decoration: BoxDecoration(
                  color: done
                      ? const Color(0xFF4DD0E1)
                      : active
                          ? const Color(0xFFB2EBF2)
                          : Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(5),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Question area: the chain-so-far prompt + hexagonal crystal choices
// ─────────────────────────────────────────────────────────────────────────────

class _QuestionArea extends StatelessWidget {
  final _Q q;
  final _Phase phase;
  final int? picked;
  final void Function(int) onAnswer;

  const _QuestionArea({
    required this.q,
    required this.phase,
    required this.picked,
    required this.onAnswer,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.32),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: const Color(0xFF4DD0E1).withValues(alpha: 0.55),
                  width: 1.5),
            ),
            child: Column(
              children: [
                Text(
                  'Count by ${q.step}s! What crystal comes next?',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${q.chainSoFar.join(', ')}, ...?',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    shadows: [Shadow(blurRadius: 8, color: Colors.black45)],
                  ),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: q.choices
                .map((c) => _HexCrystalBtn(
                      value: c,
                      phase: phase,
                      picked: picked,
                      correct: q.correct,
                      onTap: () => onAnswer(c),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _HexCrystalBtn extends StatelessWidget {
  final int value, correct;
  final _Phase phase;
  final int? picked;
  final VoidCallback onTap;

  const _HexCrystalBtn({
    required this.value,
    required this.correct,
    required this.phase,
    required this.picked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isAnswered = phase == _Phase.correct ||
        phase == _Phase.wrong ||
        phase == _Phase.streak ||
        phase == _Phase.zoneDone;
    final isPickedThis = picked == value;
    final isCorrectThis = value == correct;

    Color bg1 = const Color(0xFF4DD0E1);
    Color bg2 = const Color(0xFF00838F);

    if (isAnswered) {
      if (isCorrectThis) {
        bg1 = const Color(0xFF81C784);
        bg2 = const Color(0xFF388E3C);
      } else if (isPickedThis) {
        bg1 = const Color(0xFFE57373);
        bg2 = const Color(0xFFC62828);
      } else {
        bg1 = const Color(0xFF546E7A);
        bg2 = const Color(0xFF37474F);
      }
    }

    return GestureDetector(
      onTap: isAnswered ? null : onTap,
      child: ClipPath(
        clipper: _HexagonClipper(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 74,
          height: 74,
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [bg1, bg2],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter),
          ),
          child: Center(
            child: Text(
              '$value',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                shadows: [Shadow(blurRadius: 6, color: Colors.black45)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Genuine hexagon silhouette -- the fifth distinct answer-button shape
/// across the Grade 1 games (rounded square, circle, wood plank, diamond,
/// hexagon), not just a colour change on a repeated shape.
class _HexagonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path();
    const points = 6;
    for (int i = 0; i < points; i++) {
      final angle = math.pi / 2 + i * (2 * math.pi / points);
      final x = w / 2 + (w / 2) * math.cos(angle);
      final y = h / 2 + (h / 2) * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Feedback banner — crystal cavern copy, distinct from every other engine
// ─────────────────────────────────────────────────────────────────────────────

class _FeedbackBanner extends StatelessWidget {
  final _Phase phase;
  final int streak;
  final String wrongReaction;
  const _FeedbackBanner(
      {required this.phase, required this.streak, required this.wrongReaction});

  @override
  Widget build(BuildContext context) {
    final (text, bg) = switch (phase) {
      _Phase.correct => ('💎 Crystal linked! Chain grows!', const Color(0xFF00838F)),
      _Phase.wrong => (wrongReaction, const Color(0xFF4A148C)),
      _Phase.streak => (
          '✨ ${streak}x RESONANCE STREAK! ✨',
          const Color(0xFF6A1B9A)
        ),
      _Phase.zoneDone => ('🔮  Chain Complete!', const Color(0xFF1B6E62)),
      _ => (null, Colors.transparent),
    };
    if (text == null) return const SizedBox(height: 40);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Center(
        child: Text(text,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15)),
      ),
    );
  }
}

class _ZoneDone extends StatelessWidget {
  final int zoneNum;
  const _ZoneDone({required this.zoneNum});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.60),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🔮 💎 🔮', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 12),
              Text('Chain $zoneNum Complete!',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              const Text('Deeper into the crystal cavern!',
                  style: TextStyle(color: Colors.white70, fontSize: 15)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Intro screen
// ─────────────────────────────────────────────────────────────────────────────

class _IntroScreen extends StatelessWidget {
  const _IntroScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0B2E2A),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🔮', style: TextStyle(fontSize: 72)),
            SizedBox(height: 16),
            Text('Multiple Chain',
                style: TextStyle(
                    color: Color(0xFF4DD0E1),
                    fontSize: 24,
                    fontWeight: FontWeight.w900)),
            SizedBox(height: 8),
            Text('Link the glowing crystals!',
                style: TextStyle(color: Colors.white70, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Victory screen
// ─────────────────────────────────────────────────────────────────────────────

class _VictoryScreen extends StatelessWidget {
  final int correctCount, totalXP;
  final VoidCallback onReplay, onExit;

  const _VictoryScreen({
    required this.correctCount,
    required this.totalXP,
    required this.onReplay,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    final stars = correctCount >= 18
        ? 3
        : correctCount >= 12
            ? 2
            : 1;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0B2E2A), Color(0xFF1B6E62), Color(0xFF4DD0E1)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🏆 Cavern Conquered!',
                      style: TextStyle(
                          color: Color(0xFFE0F7FA),
                          fontSize: 28,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                        3,
                        (i) => Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6),
                              child: Text(i < stars ? '⭐' : '☆',
                                  style: const TextStyle(fontSize: 44)),
                            )),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.30),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color:
                              const Color(0xFF4DD0E1).withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Column(
                          children: [
                            const Text('💎 Linked',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 12)),
                            Text('$correctCount',
                                style: const TextStyle(
                                    color: Color(0xFF4DD0E1),
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900)),
                          ],
                        ),
                        Column(
                          children: [
                            const Text('⭐ XP',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 12)),
                            Text('+$totalXP',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _VBtn(
                          label: '🔄 Chain Again',
                          onTap: onReplay,
                          primary: true),
                      const SizedBox(width: 12),
                      _VBtn(label: '🗺️ Map', onTap: onExit, primary: false),
                    ],
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

class _VBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool primary;
  const _VBtn(
      {required this.label, required this.onTap, required this.primary});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          gradient: primary
              ? const LinearGradient(
                  colors: [Color(0xFF4DD0E1), Color(0xFF00838F)])
              : null,
          color: primary ? null : Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: primary ? const Color(0xFF4DD0E1) : Colors.white38,
            width: 1.5,
          ),
        ),
        child: Text(label,
            style: TextStyle(
                color: primary ? const Color(0xFF0B2E2A) : Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Resonance painter (streak celebration) — a pulse of light rippling
// outward from the crystal chain, distinct from fireworks, a coin
// shower, a parade, or an aurora sweep.
// ─────────────────────────────────────────────────────────────────────────────

class _ResonancePainter extends CustomPainter {
  final double t;
  _ResonancePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.18;
    final colors = [
      const Color(0xFF4DD0E1),
      const Color(0xFFBA68C8),
      const Color(0xFF81C784),
    ];
    for (int ring = 0; ring < 3; ring++) {
      final rt = ((t - ring * 0.18)).clamp(0.0, 1.0);
      if (rt <= 0) continue;
      final alpha = (1 - rt) * 0.5;
      canvas.drawCircle(
        Offset(cx, cy),
        rt * size.width * 0.6,
        Paint()
          ..color = colors[ring].withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ResonancePainter old) => old.t != t;
}
