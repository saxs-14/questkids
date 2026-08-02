import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/game_session_model.dart';
import '../core/game_config.dart';
import '../core/game_session_persistence.dart';

// ────────────────────────────────────────────────────────────────────────────
// Maths Mountain — Grade 1 vertical climbing adventure
//
// 4 Camps (difficulty bands, mixed addition/subtraction within 20 overall):
//   1. Base Camp     — within 5
//   2. Snowline      — within 10
//   3. Ridge Camp    — within 15
//   4. Summit Push   — within 20
// 5 questions per camp = 20 total. Each question is randomly addition or
// subtraction, mixing both operations (NOT multiplication -- CAPS Grade 1
// covers addition/subtraction within 20; formal multiplication only
// starts in Grade 3, so the original catalog description's "multiplication
// basics" framing was corrected when this engine was built).
//
// Structurally distinct from every other Grade 1 engine so far (all of
// which are flat scenes): this is a VERTICAL climb. A climber visibly
// ascends ledges on a snowy mountain as questions are answered correctly.
// Wrong answers cause a gentle snow-puff slip -- the climber never falls
// or loses progress. A checkpoint-flag ceremony marks each camp cleared,
// and a streak triggers an aurora sweep instead of fireworks, a coin
// shower, or a parade. Architecture: fully self-contained StatefulWidget,
// no external engine (same pattern as the other Grade 1 games).
// ────────────────────────────────────────────────────────────────────────────

enum _Phase { intro, question, correct, wrong, streak, campDone, victory }

enum _Op { add, subtract }

// ── Question model ─────────────────────────────────────────────────────────

class _Q {
  final int a;
  final int b;
  final _Op op;
  final List<int> choices;
  final int correct;

  _Q({required this.a, required this.b, required this.op, required this.choices})
      : correct = op == _Op.add ? a + b : a - b;

  String get symbol => op == _Op.add ? '+' : '−';
}

// ── Camp definitions ─────────────────────────────────────────────────────────

class _Camp {
  final String name;
  final int maxRange;
  final int questionCount = 5;
  const _Camp(this.name, this.maxRange);
}

// ── Main game widget ───────────────────────────────────────────────────────

class MathsMountainGame extends StatefulWidget {
  final GameConfig config;
  final dynamic user;
  const MathsMountainGame({super.key, required this.config, this.user});

  @override
  State<MathsMountainGame> createState() => _MMState();
}

class _MMState extends State<MathsMountainGame>
    with TickerProviderStateMixin {
  static const _camps = [
    _Camp('Base Camp', 5),
    _Camp('Snowline', 10),
    _Camp('Ridge Camp', 15),
    _Camp('Summit Push', 20),
  ];

  static const _wrongReactions = [
    'Brr! A gust of snow — try again!',
    'Whoops, an icy patch! Try again!',
    'Slippery! Steady yourself and try again!',
  ];

  // ── Animations ──────────────────────────────────────────────────────────
  late AnimationController _snowCtrl; // falling snow, looping
  late AnimationController _climbCtrl; // climber steps up on correct
  late AnimationController _slipCtrl; // gentle wobble on wrong
  late AnimationController _auroraCtrl; // streak celebration
  late AnimationController _fadeCtrl; // question fade-in

  late Animation<double> _snowAnim;
  late Animation<double> _climbAnim;
  late Animation<double> _slipAnim;
  late Animation<double> _auroraAnim;
  late Animation<double> _fadeAnim;

  // ── Game state ──────────────────────────────────────────────────────────
  int _campIdx = 0;
  int _qIdx = 0;
  int _correctCount = 0;
  int _streak = 0;
  int _totalXP = 0;

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
    _snowCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 6))
      ..repeat();
    _snowAnim = CurvedAnimation(parent: _snowCtrl, curve: Curves.linear);

    _climbCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 550));
    _climbAnim = CurvedAnimation(parent: _climbCtrl, curve: Curves.easeOutBack);

    _slipCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _slipAnim = CurvedAnimation(parent: _slipCtrl, curve: Curves.elasticIn);

    _auroraCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600));
    _auroraAnim = CurvedAnimation(parent: _auroraCtrl, curve: Curves.easeOut);

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
    _snowCtrl.dispose();
    _climbCtrl.dispose();
    _slipCtrl.dispose();
    _auroraCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Game flow ────────────────────────────────────────────────────────────

  void _startGame() {
    setState(() {
      _campIdx = 0;
      _qIdx = 0;
      _correctCount = 0;
      _streak = 0;
      _totalXP = 0;
    });
    _nextQuestion();
  }

  void _nextQuestion() {
    final camp = _camps[_campIdx];
    final q = _makeQuestion(camp);
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
      });
      _climbCtrl.forward(from: 0);
      final isStreak = _streak > 0 && _streak % 3 == 0;
      if (isStreak) {
        setState(() => _phase = _Phase.streak);
        _auroraCtrl.forward(from: 0);
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
      _slipCtrl.forward(from: 0);
      _delayed(1300, _advance);
    }
  }

  void _advance() {
    if (!mounted) return;
    final camp = _camps[_campIdx];
    final next = _qIdx + 1;

    if (next >= camp.questionCount) {
      if (_campIdx + 1 >= _camps.length) {
        _persistSession();
        setState(() => _phase = _Phase.victory);
      } else {
        setState(() => _phase = _Phase.campDone);
        _delayed(2200, () {
          setState(() {
            _campIdx++;
            _qIdx = 0;
          });
          _climbCtrl.reset();
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
        _camps.fold<int>(0, (sum, c) => sum + c.questionCount); // 20
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

  _Q _makeQuestion(_Camp camp) {
    final op = _rng.nextBool() ? _Op.add : _Op.subtract;
    int a, b;
    if (op == _Op.add) {
      a = 1 + _rng.nextInt(camp.maxRange - 1);
      final maxB = camp.maxRange - a;
      b = 1 + _rng.nextInt(math.max(1, maxB));
    } else {
      a = 2 + _rng.nextInt(camp.maxRange - 1);
      b = 1 + _rng.nextInt(a);
    }
    final correct = op == _Op.add ? a + b : a - b;
    final choices = _threeChoices(correct);
    return _Q(a: a, b: b, op: op, choices: choices);
  }

  List<int> _threeChoices(int correct) {
    final s = <int>{correct};
    int attempts = 0;
    while (s.length < 3 && attempts < 200) {
      final delta = 1 + _rng.nextInt(4);
      final c = _rng.nextBool() ? correct + delta : correct - delta;
      if (c >= 0 && c != correct) s.add(c);
      attempts++;
    }
    while (s.length < 3) {
      s.add(s.length);
    }
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

    final camp = _camps[_campIdx];
    final q = _current;
    final overallProgress =
        (_campIdx * 5 + _qIdx) / (_camps.length * 5); // altitude 0..1

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _snowAnim,
              builder: (_, __) => CustomPaint(
                painter: _MountainBg(snowT: _snowAnim.value),
              ),
            ),
          ),

          if (_phase == _Phase.streak)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _auroraAnim,
                builder: (_, __) => CustomPaint(
                  painter: _AuroraPainter(_auroraAnim.value),
                ),
              ),
            ),

          SafeArea(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Vertical altitude rope, left edge
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 90),
                  child: _AltitudeRope(progress: overallProgress),
                ),
                Expanded(
                  child: Column(
                    children: [
                      _CampHeader(
                        campName: camp.name,
                        campIdx: _campIdx,
                        totalCamps: _camps.length,
                        qIdx: _qIdx,
                        totalQ: camp.questionCount,
                        correctCount: _correctCount,
                      ),
                      SizedBox(
                        height: 90,
                        child: AnimatedBuilder(
                          animation: Listenable.merge([_climbAnim, _slipAnim]),
                          builder: (_, __) => _ClimberScene(
                            climbProgress: _climbAnim.value,
                            slipProgress: _slipAnim.value,
                            phase: _phase,
                          ),
                        ),
                      ),
                      Expanded(
                        child: q == null
                            ? const SizedBox()
                            : FadeTransition(
                                opacity: _fadeAnim,
                                child: _QuestionArea(
                                  q: q,
                                  phase: _phase,
                                  picked: _picked,
                                  onAnswer: _onAnswer,
                                ),
                              ),
                      ),
                      _FeedbackBanner(
                          phase: _phase,
                          streak: _streak,
                          wrongReaction: _wrongReaction),
                      if (_phase == _Phase.campDone)
                        _CampDone(campNum: _campIdx + 1),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mountain background CustomPainter — cool blue-grey/white snowy peak,
// falling snow. Distinct from the arena, ocean, and savanna palettes.
// ─────────────────────────────────────────────────────────────────────────────

class _MountainBg extends CustomPainter {
  final double snowT;
  _MountainBg({required this.snowT});

  static final _rng = math.Random(21);
  static final _flakes = List.generate(
      30,
      (i) => (
            x: _rng.nextDouble(),
            y0: _rng.nextDouble(),
            speed: 0.3 + _rng.nextDouble() * 0.5,
            size: 1.5 + _rng.nextDouble() * 2.5,
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
            Color(0xFF37474F),
            Color(0xFF546E7A),
            Color(0xFF90A4AE),
            Color(0xFFCFD8DC),
          ],
          stops: [0.0, 0.35, 0.70, 1.0],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // Distant peak silhouette
    final peakPaint = Paint()..color = Colors.white.withValues(alpha: 0.20);
    final peakPath = Path()
      ..moveTo(0, h * 0.5)
      ..lineTo(w * 0.30, h * 0.18)
      ..lineTo(w * 0.55, h * 0.34)
      ..lineTo(w * 0.80, h * 0.10)
      ..lineTo(w, h * 0.30)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(peakPath, peakPaint);

    // Falling snow
    final snowPaint = Paint()..color = Colors.white.withValues(alpha: 0.85);
    for (final f in _flakes) {
      final y = (f.y0 + snowT * f.speed) % 1.0;
      canvas.drawCircle(
          Offset(f.x * w, y * h), f.size, snowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MountainBg old) => old.snowT != snowT;
}

// ─────────────────────────────────────────────────────────────────────────────
// Vertical altitude rope — a distinct progress visualisation from every
// other Grade 1 game (which all use horizontal dots only).
// ─────────────────────────────────────────────────────────────────────────────

class _AltitudeRope extends StatelessWidget {
  final double progress; // 0..1
  const _AltitudeRope({required this.progress});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 420,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Container(
            width: 4,
            height: 420,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 4,
            height: 420 * progress.clamp(0.0, 1.0),
            decoration: BoxDecoration(
              color: const Color(0xFF4FC3F7),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            bottom: 420 * progress.clamp(0.0, 1.0) - 8,
            child: const Text('🚩', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Camp header: camp name + question progress + summit count
// ─────────────────────────────────────────────────────────────────────────────

class _CampHeader extends StatelessWidget {
  final String campName;
  final int campIdx, totalCamps, qIdx, totalQ, correctCount;

  const _CampHeader({
    required this.campName,
    required this.campIdx,
    required this.totalCamps,
    required this.qIdx,
    required this.totalQ,
    required this.correctCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFF4FC3F7).withValues(alpha: 0.5), width: 1.5),
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
                  color: const Color(0xFF4FC3F7).withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('❄️ $correctCount',
                    style: const TextStyle(
                        color: Color(0xFF0D2B3A),
                        fontSize: 15,
                        fontWeight: FontWeight.w900)),
              ),
              Column(
                children: [
                  Text(
                    'Camp ${campIdx + 1}/$totalCamps',
                    style: const TextStyle(
                        color: Color(0xFFB3E5FC),
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                  Text(
                    campName,
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
                      ? const Color(0xFF4FC3F7)
                      : active
                          ? const Color(0xFFB3E5FC)
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
// Climber scene: a climber that hops up a ledge on correct, wobbles on wrong
// ─────────────────────────────────────────────────────────────────────────────

class _ClimberScene extends StatelessWidget {
  final double climbProgress;
  final double slipProgress;
  final _Phase phase;

  const _ClimberScene({
    required this.climbProgress,
    required this.slipProgress,
    required this.phase,
  });

  @override
  Widget build(BuildContext context) {
    final climbing = phase == _Phase.correct || phase == _Phase.streak;
    final dy = climbing ? -climbProgress * 26 : 0.0;
    final wobble = phase == _Phase.wrong
        ? math.sin(slipProgress * math.pi * 3) * 6
        : 0.0;

    return Stack(
      alignment: Alignment.center,
      children: [
        // Ledge
        Positioned(
          bottom: 10,
          child: Container(
            width: 90,
            height: 10,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(5),
            ),
          ),
        ),
        Transform.translate(
          offset: Offset(wobble, dy),
          child: const Text('🧗', style: TextStyle(fontSize: 48)),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Question area: the equation + ice-crystal answer choices
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
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.30),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: const Color(0xFF4FC3F7).withValues(alpha: 0.55),
                  width: 1.5),
            ),
            child: Text(
              '${q.a} ${q.symbol} ${q.b} = ?',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w900,
                shadows: [Shadow(blurRadius: 8, color: Colors.black45)],
              ),
            ),
          ),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            alignment: WrapAlignment.center,
            children: q.choices
                .map((c) => _IceCrystalBtn(
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

class _IceCrystalBtn extends StatelessWidget {
  final int value, correct;
  final _Phase phase;
  final int? picked;
  final VoidCallback onTap;

  const _IceCrystalBtn({
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
        phase == _Phase.campDone;
    final isPickedThis = picked == value;
    final isCorrectThis = value == correct;

    Color bg1 = const Color(0xFF4FC3F7);
    Color bg2 = const Color(0xFF0288D1);
    Color border = Colors.white.withValues(alpha: 0.5);
    Color textC = Colors.white;

    if (isAnswered) {
      if (isCorrectThis) {
        bg1 = const Color(0xFF66BB6A);
        bg2 = const Color(0xFF388E3C);
        border = const Color(0xFFC8FFC8);
      } else if (isPickedThis) {
        bg1 = const Color(0xFFEF5350);
        bg2 = const Color(0xFFC62828);
        border = const Color(0xFFFFCDD2);
      } else {
        bg1 = Colors.blueGrey.shade400;
        bg2 = Colors.blueGrey.shade600;
        textC = Colors.white54;
      }
    }

    return GestureDetector(
      onTap: isAnswered ? null : onTap,
      // Rotate the whole tile 45° so the square reads as a diamond/ice
      // crystal, then counter-rotate just the number back to upright --
      // a genuinely different silhouette from every other Grade 1 game's
      // answer buttons (rounded-square crystals, circular shells, wood
      // signposts), not just a different colour on the same shape.
      child: Transform.rotate(
        angle: math.pi / 4,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [bg1, bg2],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: isCorrectThis && isAnswered
                    ? const Color(0xFF66BB6A).withValues(alpha: 0.55)
                    : bg1.withValues(alpha: 0.45),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Transform.rotate(
              angle: -math.pi / 4,
              child: Text(
                '$value',
                style: TextStyle(
                  color: textC,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  shadows: const [
                    Shadow(blurRadius: 6, color: Colors.black38)
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Feedback banner — Arctic climbing copy, distinct from every other engine
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
      _Phase.correct => ('🧗 Great climb! Higher you go!', const Color(0xFF0288D1)),
      _Phase.wrong => (wrongReaction, const Color(0xFF37474F)),
      _Phase.streak => (
          '✨ ${streak}x SUMMIT STREAK! ✨',
          const Color(0xFF00838F)
        ),
      _Phase.campDone => ('🚩  Checkpoint Reached!', const Color(0xFF01579B)),
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

class _CampDone extends StatelessWidget {
  final int campNum;
  const _CampDone({required this.campNum});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.60),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🚩 🏔️ 🚩', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 12),
              Text('Checkpoint $campNum Reached!',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              const Text('Onward to the next camp!',
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
      backgroundColor: Color(0xFF37474F),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🏔️', style: TextStyle(fontSize: 72)),
            SizedBox(height: 16),
            Text('Maths Mountain',
                style: TextStyle(
                    color: Color(0xFF4FC3F7),
                    fontSize: 24,
                    fontWeight: FontWeight.w900)),
            SizedBox(height: 8),
            Text('Climb to the summit!',
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
            colors: [Color(0xFF01579B), Color(0xFF4FC3F7), Color(0xFFE1F5FE)],
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
                  const Text('🏆 Summit Reached!',
                      style: TextStyle(
                          color: Color(0xFF0D2B3A),
                          fontSize: 30,
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
                      color: Colors.black.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color:
                              const Color(0xFF4FC3F7).withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Column(
                          children: [
                            const Text('❄️ Solved',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 12)),
                            Text('$correctCount',
                                style: const TextStyle(
                                    color: Color(0xFF01579B),
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
                                    color: Color(0xFF0D2B3A),
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
                          label: '🔄 Climb Again',
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
                  colors: [Color(0xFF4FC3F7), Color(0xFF0288D1)])
              : null,
          color: primary ? null : Colors.black.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: primary ? const Color(0xFF4FC3F7) : Colors.black26,
            width: 1.5,
          ),
        ),
        child: Text(label,
            style: TextStyle(
                color: primary ? const Color(0xFF0D2B3A) : Colors.black87,
                fontWeight: FontWeight.w800,
                fontSize: 15)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Aurora painter (streak celebration) — sweeping ribbons of colour across
// the sky, distinct from fireworks, a coin shower, or a parade.
// ─────────────────────────────────────────────────────────────────────────────

class _AuroraPainter extends CustomPainter {
  final double t;
  _AuroraPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final colors = [
      const Color(0xFF80DEEA),
      const Color(0xFFB39DDB),
      const Color(0xFF80CBC4),
    ];
    for (int i = 0; i < colors.length; i++) {
      final alpha = (math.sin((t * math.pi) - i * 0.4).clamp(0.0, 1.0)) * 0.35;
      if (alpha <= 0) continue;
      final path = Path();
      final baseY = size.height * (0.10 + i * 0.05);
      path.moveTo(0, baseY);
      for (double x = 0; x <= size.width; x += 20) {
        final wobble = math.sin((x / size.width * 3 * math.pi) + t * 6 + i) * 14;
        path.lineTo(x, baseY + wobble);
      }
      path.lineTo(size.width, baseY + 40);
      for (double x = size.width; x >= 0; x -= 20) {
        final wobble = math.sin((x / size.width * 3 * math.pi) + t * 6 + i) * 14;
        path.lineTo(x, baseY + 40 + wobble);
      }
      path.close();
      canvas.drawPath(path, Paint()..color = colors[i].withValues(alpha: alpha));
    }
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter old) => old.t != t;
}
