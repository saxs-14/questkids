import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/game_session_model.dart';
import '../core/game_config.dart';
import '../core/game_session_persistence.dart';

// ────────────────────────────────────────────────────────────────────────────
// Subtraction Safari — Grade 1 animal rescue mission
//
// 4 Safari Zones (difficulty bands, subtraction within 20 overall):
//   1. Watering Hole  — within 5
//   2. Grasslands     — within 10
//   3. Jungle Trail    — within 15
//   4. Mountain Den    — within 20
// 5 questions per zone = 20 total.
//
// Deliberately distinct from Number Counting Duel (vs-AI arena duel) and
// Addition Adventure (solo sailing voyage, coins merging): this is a
// rescue mission where animals visibly hop OUT of a cage (a "taking
// away" visual for subtraction, not two piles merging), the player taps
// how many are still waiting to be rescued, wrong answers get a silly
// animal reaction instead of any punishment, and a streak triggers a
// safari parade instead of fireworks or a coin shower. Architecture:
// fully self-contained StatefulWidget, no external engine (same pattern
// as NumberCountingDuelGame / AdditionAdventureGame).
// ────────────────────────────────────────────────────────────────────────────

enum _Phase { intro, question, correct, wrong, streak, zoneDone, victory }

// ── Question model ─────────────────────────────────────────────────────────

class _Q {
  final int total; // animals originally trapped
  final int freed; // animals that hopped free
  final List<int> choices;
  final int correct;

  _Q({required this.total, required this.freed, required this.choices})
      : correct = total - freed;
}

// ── Zone definitions ─────────────────────────────────────────────────────────

class _Zone {
  final String name;
  final int maxTotal;
  final String animal;
  final int questionCount = 5;
  const _Zone(this.name, this.maxTotal, this.animal);
}

// ── Main game widget ───────────────────────────────────────────────────────

class SubtractionSafariGame extends StatefulWidget {
  final GameConfig config;
  final dynamic user;
  const SubtractionSafariGame(
      {super.key, required this.config, this.user});

  @override
  State<SubtractionSafariGame> createState() => _SSState();
}

class _SSState extends State<SubtractionSafariGame>
    with TickerProviderStateMixin {
  static const _zones = [
    _Zone('Watering Hole', 5, '🐸'),
    _Zone('Grasslands', 10, '🦓'),
    _Zone('Jungle Trail', 15, '🐒'),
    _Zone('Mountain Den', 20, '🦁'),
  ];

  static const _wrongReactions = [
    'The monkey giggled and hid again! 🙈 Try again!',
    'The zebra did a silly wiggle! 🦓 Try again!',
    'The lion cub tumbled over! 🦁 Try again!',
    'Oopsie! The frog hopped the wrong way! 🐸 Try again!',
  ];

  // ── Animations ──────────────────────────────────────────────────────────
  late AnimationController _swayCtrl; // grass + cage sway
  late AnimationController _hopCtrl; // freed-animal hop-away on correct
  late AnimationController _wiggleCtrl; // silly wrong-answer wiggle
  late AnimationController _paradeCtrl; // streak celebration
  late AnimationController _fadeCtrl; // question fade-in

  late Animation<double> _swayAnim;
  late Animation<double> _hopAnim;
  late Animation<double> _wiggleAnim;
  late Animation<double> _paradeAnim;
  late Animation<double> _fadeAnim;

  // ── Game state ──────────────────────────────────────────────────────────
  int _zoneIdx = 0;
  int _qIdx = 0;
  int _rescuedCount = 0;
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
    _swayCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);
    _swayAnim = Tween<double>(begin: -0.02, end: 0.02)
        .animate(CurvedAnimation(parent: _swayCtrl, curve: Curves.easeInOut));

    _hopCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _hopAnim = CurvedAnimation(parent: _hopCtrl, curve: Curves.easeOutCubic);

    _wiggleCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _wiggleAnim = CurvedAnimation(parent: _wiggleCtrl, curve: Curves.elasticOut);

    _paradeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600));
    _paradeAnim = CurvedAnimation(parent: _paradeCtrl, curve: Curves.easeOut);

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
    _swayCtrl.dispose();
    _hopCtrl.dispose();
    _wiggleCtrl.dispose();
    _paradeCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Game flow ────────────────────────────────────────────────────────────

  void _startGame() {
    setState(() {
      _zoneIdx = 0;
      _qIdx = 0;
      _rescuedCount = 0;
      _streak = 0;
      _totalXP = 0;
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
        _rescuedCount += q.freed;
        _streak++;
        _totalXP += 10;
      });
      _hopCtrl.forward(from: 0);
      final isStreak = _streak > 0 && _streak % 3 == 0;
      if (isStreak) {
        setState(() => _phase = _Phase.streak);
        _paradeCtrl.forward(from: 0);
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
      _wiggleCtrl.forward(from: 0);
      _delayed(1400, _advance);
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
  /// self-contained (no GameEngine/GameSessionState), matching
  /// NumberCountingDuelGame / AdditionAdventureGame's established
  /// pattern. Applies the same completion-bonus tiers as
  /// GameEngine.defaultResult() so the number shown on the victory
  /// screen matches what actually gets awarded.
  void _persistSession() {
    final totalQuestions =
        _zones.fold<int>(0, (sum, z) => sum + z.questionCount); // 20
    // Correctness is tracked via XP earned (10 per correct answer),
    // not _rescuedCount (which is an animal tally, not a question tally).
    final correctCount = _totalXP ~/ 10;
    final accuracy =
        totalQuestions > 0 ? correctCount / totalQuestions : 0.0;
    final isPerfect = correctCount == totalQuestions;
    final isWin = correctCount > totalQuestions / 2;
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
    final total = 2 + _rng.nextInt(zone.maxTotal - 1);
    final freed = 1 + _rng.nextInt(total);
    final correct = total - freed;
    final choices = _threeChoices(correct, total);
    return _Q(total: total, freed: freed, choices: choices);
  }

  List<int> _threeChoices(int correct, int total) {
    final s = <int>{correct};
    int attempts = 0;
    while (s.length < 3 && attempts < 200) {
      final delta = 1 + _rng.nextInt(4);
      final c = _rng.nextBool() ? correct + delta : correct - delta;
      if (c >= 0 && c <= total && c != correct) s.add(c);
      attempts++;
    }
    while (s.length < 3) {
      s.add(s.length); // 0,1,2 fallback, still >= 0
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
        rescuedCount: _rescuedCount,
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
          const Positioned.fill(child: _SavannaBg()),

          if (_phase == _Phase.streak)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _paradeAnim,
                builder: (_, __) => CustomPaint(
                  painter: _ParadePainter(_paradeAnim.value),
                ),
              ),
            ),

          SafeArea(
            child: Column(
              children: [
                _SafariHeader(
                  zoneName: zone.name,
                  zoneIdx: _zoneIdx,
                  totalZones: _zones.length,
                  qIdx: _qIdx,
                  totalQ: zone.questionCount,
                  rescuedCount: _rescuedCount,
                ),
                SizedBox(
                  height: 100,
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_swayAnim, _hopAnim]),
                    builder: (_, __) => _CageScene(
                      swayAngle: _swayAnim.value,
                      hopProgress: _hopAnim.value,
                      animal: zone.animal,
                      phase: _phase,
                    ),
                  ),
                ),
                Expanded(
                  child: q == null
                      ? const SizedBox()
                      : FadeTransition(
                          opacity: _fadeAnim,
                          child: AnimatedBuilder(
                            animation: _wiggleAnim,
                            builder: (_, child) => Transform.rotate(
                              angle: _phase == _Phase.wrong
                                  ? (1 - _wiggleAnim.value) * 0.08
                                  : 0,
                              child: child,
                            ),
                            child: _QuestionArea(
                              q: q,
                              zoneAnimal: zone.animal,
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Savanna background CustomPainter — warm gold grass, blue sky, acacia
// trees. Distinct from Number Counting Duel's purple night arena and
// Addition Adventure's turquoise ocean.
// ─────────────────────────────────────────────────────────────────────────────

class _SavannaBg extends StatelessWidget {
  const _SavannaBg();
  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _SavannaPainter());
  }
}

class _SavannaPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = const LinearGradient(
          colors: [
            Color(0xFF87CEEB),
            Color(0xFFFFD54F),
            Color(0xFFE8A33D),
          ],
          stops: [0.0, 0.55, 1.0],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // Sun
    canvas.drawCircle(
      Offset(w * 0.15, h * 0.10),
      26,
      Paint()..color = const Color(0xFFFFF9C4).withValues(alpha: 0.9),
    );

    // Acacia tree silhouettes
    _drawAcacia(canvas, Offset(w * 0.85, h * 0.30), 34);
    _drawAcacia(canvas, Offset(w * 0.62, h * 0.24), 22);

    // Distant hill line
    final hillPaint = Paint()..color = const Color(0xFFC17A3D).withValues(alpha: 0.5);
    final hillPath = Path()
      ..moveTo(0, h * 0.42)
      ..quadraticBezierTo(w * 0.3, h * 0.36, w * 0.55, h * 0.42)
      ..quadraticBezierTo(w * 0.8, h * 0.47, w, h * 0.40)
      ..lineTo(w, h * 0.55)
      ..lineTo(0, h * 0.55)
      ..close();
    canvas.drawPath(hillPath, hillPaint);
  }

  void _drawAcacia(Canvas canvas, Offset base, double size) {
    final trunkPaint = Paint()
      ..color = const Color(0xFF5D4037).withValues(alpha: 0.75)
      ..strokeWidth = 4;
    canvas.drawLine(base, base + Offset(0, -size), trunkPaint);
    final canopyPaint = Paint()..color = const Color(0xFF33691E).withValues(alpha: 0.65);
    canvas.drawOval(
      Rect.fromCenter(
          center: base + Offset(0, -size * 1.1),
          width: size * 2.2,
          height: size * 0.55),
      canopyPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Safari header: zone name + question progress + animals rescued
// ─────────────────────────────────────────────────────────────────────────────

class _SafariHeader extends StatelessWidget {
  final String zoneName;
  final int zoneIdx, totalZones, qIdx, totalQ, rescuedCount;

  const _SafariHeader({
    required this.zoneName,
    required this.zoneIdx,
    required this.totalZones,
    required this.qIdx,
    required this.totalQ,
    required this.rescuedCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFF8D6E33).withValues(alpha: 0.55),
            width: 1.5),
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
                  color: const Color(0xFF8BC34A).withValues(alpha: 0.90),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('🐾 $rescuedCount',
                    style: const TextStyle(
                        color: Color(0xFF1B3A0E),
                        fontSize: 15,
                        fontWeight: FontWeight.w900)),
              ),
              Column(
                children: [
                  Text(
                    'Zone ${zoneIdx + 1}/$totalZones',
                    style: const TextStyle(
                        color: Color(0xFFFFE082),
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
                      ? const Color(0xFF8BC34A)
                      : active
                          ? const Color(0xFFFFE082)
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
// Cage scene: an animal that hops away on a correct answer
// ─────────────────────────────────────────────────────────────────────────────

class _CageScene extends StatelessWidget {
  final double swayAngle;
  final double hopProgress;
  final String animal;
  final _Phase phase;

  const _CageScene({
    required this.swayAngle,
    required this.hopProgress,
    required this.animal,
    required this.phase,
  });

  @override
  Widget build(BuildContext context) {
    final hopping = phase == _Phase.correct || phase == _Phase.streak;
    final dx = hopping ? hopProgress * 90 : 0.0;
    final dy = hopping ? -math.sin(hopProgress * math.pi) * 30 : 0.0;

    return Stack(
      alignment: Alignment.center,
      children: [
        Transform.rotate(
          angle: swayAngle,
          child: const Text('🌳', style: TextStyle(fontSize: 44)),
        ),
        Transform.translate(
          offset: Offset(dx, dy),
          child: Opacity(
            opacity: hopping ? (1 - hopProgress * 0.6) : 1,
            child: Text(animal, style: const TextStyle(fontSize: 52)),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Question area: cage total, freed count, and signpost answer choices
// ─────────────────────────────────────────────────────────────────────────────

class _QuestionArea extends StatelessWidget {
  final _Q q;
  final String zoneAnimal;
  final _Phase phase;
  final int? picked;
  final void Function(int) onAnswer;

  const _QuestionArea({
    required this.q,
    required this.zoneAnimal,
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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.32),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: const Color(0xFF8BC34A).withValues(alpha: 0.55),
                  width: 1.5),
            ),
            child: Text(
              '${q.total} $zoneAnimal were trapped. ${q.freed} hopped free!\n'
              'How many still need rescuing?',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                height: 1.3,
                shadows: [Shadow(blurRadius: 8, color: Colors.black45)],
              ),
            ),
          ),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            alignment: WrapAlignment.center,
            children: q.choices
                .map((c) => _SignpostBtn(
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

class _SignpostBtn extends StatelessWidget {
  final int value, correct;
  final _Phase phase;
  final int? picked;
  final VoidCallback onTap;

  const _SignpostBtn({
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

    Color plankColor = const Color(0xFF8D6E33);
    Color border = const Color(0xFFD7B98E);

    if (isAnswered) {
      if (isCorrectThis) {
        plankColor = const Color(0xFF558B2F);
        border = const Color(0xFFAEEA00);
      } else if (isPickedThis) {
        plankColor = const Color(0xFFB71C1C);
        border = const Color(0xFFFF8A80);
      } else {
        plankColor = const Color(0xFF6D6D6D);
        border = Colors.white24;
      }
    }

    return GestureDetector(
      onTap: isAnswered ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 78,
        height: 66,
        decoration: BoxDecoration(
          color: plankColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border, width: 3),
          boxShadow: [
            BoxShadow(
              color: isCorrectThis && isAnswered
                  ? const Color(0xFF8BC34A).withValues(alpha: 0.55)
                  : Colors.black.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$value',
              style: const TextStyle(
                color: Color(0xFF3E2723),
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Feedback banner — safari rescue copy, distinct from every other engine
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
      _Phase.correct => ('🐾 Rescue complete! Great counting!', const Color(0xFF558B2F)),
      _Phase.wrong => (wrongReaction, const Color(0xFFBF360C)),
      _Phase.streak => (
          '🌟 ${streak}x RESCUE STREAK! 🎉',
          const Color(0xFFEF6C00)
        ),
      _Phase.zoneDone => ('🏞️  Zone Cleared!', const Color(0xFF33691E)),
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
              const Text('🐾 🏞️ 🐾', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 12),
              Text('Zone $zoneNum Cleared!',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              const Text('Heading to the next safari zone!',
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
      backgroundColor: Color(0xFFE8A33D),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🦁', style: TextStyle(fontSize: 72)),
            SizedBox(height: 16),
            Text('Subtraction Safari',
                style: TextStyle(
                    color: Color(0xFF3E2723),
                    fontSize: 24,
                    fontWeight: FontWeight.w900)),
            SizedBox(height: 8),
            Text('Rescue the animals!',
                style: TextStyle(color: Color(0xFF5D4037), fontSize: 16)),
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
  final int rescuedCount, totalXP;
  final VoidCallback onReplay, onExit;

  const _VictoryScreen({
    required this.rescuedCount,
    required this.totalXP,
    required this.onReplay,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    final stars = rescuedCount >= 40
        ? 3
        : rescuedCount >= 24
            ? 2
            : 1;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF87CEEB), Color(0xFFFFD54F), Color(0xFFE8A33D)],
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
                  const Text('🏆 Safari Complete!',
                      style: TextStyle(
                          color: Color(0xFF3E2723),
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
                      color: Colors.black.withValues(alpha: 0.30),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color:
                              const Color(0xFF8BC34A).withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Column(
                          children: [
                            const Text('🐾 Rescued',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 12)),
                            Text('$rescuedCount',
                                style: const TextStyle(
                                    color: Color(0xFF8BC34A),
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
                          label: '🔄 Rescue Again',
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
                  colors: [Color(0xFF8BC34A), Color(0xFF558B2F)])
              : null,
          color: primary ? null : Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: primary ? const Color(0xFF8BC34A) : Colors.white38,
            width: 1.5,
          ),
        ),
        child: Text(label,
            style: TextStyle(
                color: primary ? const Color(0xFF1B3A0E) : Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Safari parade painter (streak celebration) — a row of animal
// silhouettes marching across the screen, distinct from Number Counting
// Duel's fireworks and Addition Adventure's coin shower.
// ─────────────────────────────────────────────────────────────────────────────

class _ParadePainter extends CustomPainter {
  final double t;
  _ParadePainter(this.t);

  static const _paradeAnimals = ['🦓', '🦁', '🐒', '🐘', '🦒'];

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * 0.5;
    for (int i = 0; i < _paradeAnimals.length; i++) {
      final startX = -60.0 - i * 70;
      final endX = size.width + 60.0;
      final x = startX + (endX - startX) * t;
      final tp = TextPainter(
        text: TextSpan(
            text: _paradeAnimals[i], style: const TextStyle(fontSize: 34)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x, y));
    }
  }

  @override
  bool shouldRepaint(covariant _ParadePainter old) => old.t != t;
}
