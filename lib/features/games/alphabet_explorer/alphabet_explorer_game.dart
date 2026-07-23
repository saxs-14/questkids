import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/game_session_model.dart';
import '../core/game_config.dart';
import '../core/game_session_persistence.dart';

// ────────────────────────────────────────────────────────────────────────────
// Alphabet Explorer — Grade 1 jungle-ruins letter-knowledge quest
//
// 4 Zones (journeying deeper into the temple):
//   1. Jungle Gate    (A-F) — match an UPPERCASE letter to its lowercase form
//   2. Vine Bridge    (G-M) — match a lowercase letter to its UPPERCASE form
//   3. Ruins Courtyard(N-S) — what letter comes next in the alphabet?
//   4. Temple Peak    (T-Z) — mixed: any of the three question types
// 5 questions per zone = 20 total.
//
// CAPS Grade 1 English Home Language covers letter recognition, naming,
// and upper/lowercase correspondence -- letter SOUNDS (phonics/blending)
// are deliberately left to the separate Phonics Fun engine so the two
// games don't overlap.
//
// Structurally distinct from every other Grade 1 engine so far: progress
// is a "fog of war" treasure map that gets uncovered left-to-right as
// questions are answered correctly, with an explorer's compass marker
// sliding along it -- a percentage-reveal indicator, unlike the dot bars,
// the vertical rope, or the growing crystal chain used elsewhere. Answer
// choices are leaf-shaped tiles (a sixth distinct button silhouette). An
// owl guide nods on correct answers and tilts its head on wrong ones. A
// wrong pick never loses map progress, just a gentle stumble animation.
// Architecture: fully self-contained StatefulWidget, no external engine
// (same pattern as the other Grade 1 games).
// ────────────────────────────────────────────────────────────────────────────

enum _Phase { intro, question, correct, wrong, streak, zoneDone, victory }

enum _QType { matchUpper, matchLower, nextLetter }

// ── Question model ─────────────────────────────────────────────────────────

class _Q {
  final _QType type;
  final String prompt; // the letter shown to the learner
  final String correct;
  final List<String> choices;

  _Q({
    required this.type,
    required this.prompt,
    required this.correct,
    required this.choices,
  });
}

// ── Zone definitions ─────────────────────────────────────────────────────────

class _Zone {
  final String name;
  final List<String> letters; // uppercase letters available in this zone
  final List<_QType> types;
  final int questionCount = 5;
  const _Zone(this.name, this.letters, this.types);
}

// ── Main game widget ───────────────────────────────────────────────────────

class AlphabetExplorerGame extends StatefulWidget {
  final GameConfig config;
  final dynamic user;
  const AlphabetExplorerGame({super.key, required this.config, this.user});

  @override
  State<AlphabetExplorerGame> createState() => _AEState();
}

class _AEState extends State<AlphabetExplorerGame>
    with TickerProviderStateMixin {
  static const _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';

  static const _zones = [
    _Zone('Jungle Gate', ['A', 'B', 'C', 'D', 'E', 'F'], [_QType.matchUpper]),
    _Zone('Vine Bridge', ['G', 'H', 'I', 'J', 'K', 'L', 'M'],
        [_QType.matchLower]),
    _Zone('Ruins Courtyard', ['N', 'O', 'P', 'Q', 'R', 'S'],
        [_QType.nextLetter]),
    _Zone('Temple Peak', ['T', 'U', 'V', 'W', 'X', 'Y', 'Z'],
        [_QType.matchUpper, _QType.matchLower, _QType.nextLetter]),
  ];

  static const _wrongReactions = [
    'Oops, wrong path! Try again, explorer!',
    'Not that one — the owl blinks. Try again!',
    'Almost! Take another look. Try again!',
  ];

  // ── Animations ──────────────────────────────────────────────────────────
  late AnimationController _glowCtrl; // ambient firefly glow, looping
  late AnimationController _bounceCtrl; // owl nod on correct
  late AnimationController _stumbleCtrl; // owl tilt / shake on wrong
  late AnimationController _swirlCtrl; // firefly swirl streak celebration
  late AnimationController _fadeCtrl; // question fade-in

  late Animation<double> _glowAnim;
  late Animation<double> _bounceAnim;
  late Animation<double> _stumbleAnim;
  late Animation<double> _swirlAnim;
  late Animation<double> _fadeAnim;

  // ── Game state ──────────────────────────────────────────────────────────
  int _zoneIdx = 0;
  int _qIdx = 0;
  int _correctCount = 0;
  int _streak = 0;
  int _totalXP = 0;

  _Phase _phase = _Phase.intro;
  _Q? _current;
  String? _picked;
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
    _glowAnim = Tween<double>(begin: 0.4, end: 1.0)
        .animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));

    _bounceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _bounceAnim = CurvedAnimation(parent: _bounceCtrl, curve: Curves.elasticOut);

    _stumbleCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 550));
    _stumbleAnim = CurvedAnimation(parent: _stumbleCtrl, curve: Curves.easeInOut);

    _swirlCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600));
    _swirlAnim = CurvedAnimation(parent: _swirlCtrl, curve: Curves.easeOut);

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
    _bounceCtrl.dispose();
    _stumbleCtrl.dispose();
    _swirlCtrl.dispose();
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

  void _onAnswer(String choice) {
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
      _bounceCtrl.forward(from: 0);
      final isStreak = _streak > 0 && _streak % 3 == 0;
      if (isStreak) {
        setState(() => _phase = _Phase.streak);
        _swirlCtrl.forward(from: 0);
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
      _stumbleCtrl.forward(from: 0);
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
          });
          _nextQuestion();
        });
      }
    } else {
      setState(() => _qIdx = next);
      _delayed(300, _nextQuestion);
    }
  }

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
    final type = zone.types[_rng.nextInt(zone.types.length)];
    switch (type) {
      case _QType.matchUpper:
        final letter = zone.letters[_rng.nextInt(zone.letters.length)];
        final correct = letter.toLowerCase();
        return _Q(
          type: type,
          prompt: letter,
          correct: correct,
          choices: _threeChoices(correct, lowercase: true),
        );
      case _QType.matchLower:
        final letter =
            zone.letters[_rng.nextInt(zone.letters.length)].toLowerCase();
        final correct = letter.toUpperCase();
        return _Q(
          type: type,
          prompt: letter,
          correct: correct,
          choices: _threeChoices(correct, lowercase: false),
        );
      case _QType.nextLetter:
        final eligible = zone.letters.where((l) => l != 'Z').toList();
        final letter = eligible[_rng.nextInt(eligible.length)];
        final correct = String.fromCharCode(letter.codeUnitAt(0) + 1);
        return _Q(
          type: type,
          prompt: letter,
          correct: correct,
          choices: _threeChoices(correct, lowercase: false),
        );
    }
  }

  List<String> _threeChoices(String correct, {required bool lowercase}) {
    final letters = (lowercase ? _alphabet.toLowerCase() : _alphabet)
        .split('')
        .where((l) => l != correct)
        .toList()
      ..shuffle(_rng);
    final choices = <String>{correct, ...letters.take(2)}.toList()
      ..shuffle(_rng);
    return choices;
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
    final totalQuestions =
        _zones.fold<int>(0, (sum, z) => sum + z.questionCount);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _glowAnim,
              builder: (_, __) => CustomPaint(painter: _RuinsBg(glow: _glowAnim.value)),
            ),
          ),

          if (_phase == _Phase.streak)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _swirlAnim,
                builder: (_, __) =>
                    CustomPaint(painter: _FireflySwirlPainter(_swirlAnim.value)),
              ),
            ),

          SafeArea(
            child: Column(
              children: [
                _RuinsHeader(
                  zoneName: zone.name,
                  zoneIdx: _zoneIdx,
                  totalZones: _zones.length,
                  qIdx: _qIdx,
                  totalQ: zone.questionCount,
                  correctCount: _correctCount,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  child: _ExplorerMapReveal(
                    correctCount: _correctCount,
                    totalQuestions: totalQuestions,
                  ),
                ),
                Expanded(
                  child: q == null
                      ? const SizedBox()
                      : FadeTransition(
                          opacity: _fadeAnim,
                          child: AnimatedBuilder(
                            animation:
                                Listenable.merge([_bounceAnim, _stumbleAnim]),
                            builder: (_, __) => _QuestionArea(
                              q: q,
                              phase: _phase,
                              picked: _picked,
                              onAnswer: _onAnswer,
                              bounce: _bounceAnim.value,
                              stumble: _stumbleAnim.value,
                            ),
                          ),
                        ),
                ),
                _FeedbackBanner(
                    phase: _phase,
                    streak: _streak,
                    wrongReaction: _wrongReaction),
                if (_phase == _Phase.zoneDone) _ZoneDone(zoneNum: _zoneIdx + 1),
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
// Ruins background CustomPainter — dusky jungle-temple palette (deep forest
// green with warm firefly-gold glow), distinct from the arena, ocean,
// savanna, mountain, and cavern palettes used elsewhere.
// ─────────────────────────────────────────────────────────────────────────────

class _RuinsBg extends CustomPainter {
  final double glow;
  _RuinsBg({required this.glow});

  static final _rng = math.Random(77);
  static final _fireflies = List.generate(
      10,
      (i) => (
            x: _rng.nextDouble(),
            y: _rng.nextDouble() * 0.55,
            size: 2.0 + _rng.nextDouble() * 3,
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
            Color(0xFF0D2818),
            Color(0xFF163A22),
            Color(0xFF1F4A2C),
            Color(0xFF2E5931),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // Stone pillar silhouettes hugging the very base of the screen, kept
    // subtle and low so they read as ambient framing rather than cutting
    // across the question card that sits above them.
    final pillarPaint = Paint()..color = const Color(0xFF14200F).withValues(alpha: 0.35);
    for (final fx in [0.04, 0.90]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(fx * w, h * 0.90, w * 0.06, h * 0.10),
          const Radius.circular(3),
        ),
        pillarPaint,
      );
    }

    for (final f in _fireflies) {
      canvas.drawCircle(
        Offset(f.x * w, f.y * h),
        f.size * (0.8 + glow * 0.4),
        Paint()..color = const Color(0xFFFFD54F).withValues(alpha: 0.75 * glow),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RuinsBg old) => old.glow != glow;
}

// ─────────────────────────────────────────────────────────────────────────────
// Explorer's treasure map — fog-of-war reveal progress indicator, distinct
// from the dot bars, vertical rope, and crystal chain used elsewhere.
// ─────────────────────────────────────────────────────────────────────────────

class _ExplorerMapReveal extends StatelessWidget {
  final int correctCount;
  final int totalQuestions;

  const _ExplorerMapReveal(
      {required this.correctCount, required this.totalQuestions});

  @override
  Widget build(BuildContext context) {
    final progress =
        totalQuestions > 0 ? (correctCount / totalQuestions).clamp(0.0, 1.0) : 0.0;
    return SizedBox(
      height: 88,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            return Stack(
              children: [
                Positioned.fill(child: CustomPaint(painter: _TreasureMapPainter())),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOut,
                  left: w * progress,
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(color: const Color(0xFF0D2818).withValues(alpha: 0.88)),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOut,
                  left: (w * progress - 16).clamp(0.0, w - 32),
                  top: 26,
                  child: const Text('🧭', style: TextStyle(fontSize: 30)),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TreasureMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = const Color(0xFFE8D4A0),
    );

    final dotPaint = Paint()
      ..color = const Color(0xFF8B6B3A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final path = Path()..moveTo(10, h * 0.55);
    path.quadraticBezierTo(w * 0.25, h * 0.15, w * 0.5, h * 0.55);
    path.quadraticBezierTo(w * 0.75, h * 0.9, w - 10, h * 0.5);

    final dashed = _dashPath(path, dashLength: 6, gapLength: 6);
    canvas.drawPath(dashed, dotPaint);

    const landmarks = ['🌴', '🗿', '⛩️', '🏆'];
    for (var i = 0; i < landmarks.length; i++) {
      final tp = TextPainter(
        text: TextSpan(
            text: landmarks[i], style: const TextStyle(fontSize: 22)),
        textDirection: TextDirection.ltr,
      )..layout();
      final fx = (i + 0.5) / landmarks.length;
      tp.paint(canvas, Offset(fx * w - tp.width / 2, h * 0.32));
    }
  }

  Path _dashPath(Path source, {required double dashLength, required double gapLength}) {
    final dest = Path();
    for (final metric in source.computeMetrics()) {
      var distance = 0.0;
      var draw = true;
      while (distance < metric.length) {
        final len = draw ? dashLength : gapLength;
        final next = math.min(distance + len, metric.length);
        if (draw) {
          dest.addPath(metric.extractPath(distance, next), Offset.zero);
        }
        distance = next;
        draw = !draw;
      }
    }
    return dest;
  }

  @override
  bool shouldRepaint(covariant _TreasureMapPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Header: zone name + question progress + letters-found count
// ─────────────────────────────────────────────────────────────────────────────

class _RuinsHeader extends StatelessWidget {
  final String zoneName;
  final int zoneIdx, totalZones, qIdx, totalQ, correctCount;

  const _RuinsHeader({
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
            color: const Color(0xFFFFD54F).withValues(alpha: 0.5), width: 1.5),
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
                  color: const Color(0xFFFFD54F).withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('📜 $correctCount',
                    style: const TextStyle(
                        color: Color(0xFF0D2818),
                        fontSize: 15,
                        fontWeight: FontWeight.w900)),
              ),
              Column(
                children: [
                  Text(
                    'Zone ${zoneIdx + 1}/$totalZones',
                    style: const TextStyle(
                        color: Color(0xFFC5E1A5),
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
                      ? const Color(0xFFFFD54F)
                      : active
                          ? const Color(0xFFFFF3C4)
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
// Question area: owl guide + letter prompt + leaf-shaped choices
// ─────────────────────────────────────────────────────────────────────────────

class _QuestionArea extends StatelessWidget {
  final _Q q;
  final _Phase phase;
  final String? picked;
  final void Function(String) onAnswer;
  final double bounce;
  final double stumble;

  const _QuestionArea({
    required this.q,
    required this.phase,
    required this.picked,
    required this.onAnswer,
    required this.bounce,
    required this.stumble,
  });

  String get _instruction => switch (q.type) {
        _QType.matchUpper => 'Find the matching lowercase letter!',
        _QType.matchLower => 'Find the matching UPPERCASE letter!',
        _QType.nextLetter => 'What letter comes next?',
      };

  @override
  Widget build(BuildContext context) {
    final wobble = phase == _Phase.wrong
        ? math.sin(stumble * math.pi * 3) * 6
        : 0.0;
    final hop = phase == _Phase.correct || phase == _Phase.streak
        ? -bounce * 10
        : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Transform.translate(
            offset: Offset(wobble, hop),
            child: const Text('🦉', style: TextStyle(fontSize: 56)),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.32),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: const Color(0xFFFFD54F).withValues(alpha: 0.55),
                  width: 1.5),
            ),
            child: Column(
              children: [
                Text(
                  _instruction,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  q.prompt,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    shadows: [Shadow(blurRadius: 10, color: Colors.black45)],
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
                .map((c) => _LeafBtn(
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

class _LeafBtn extends StatelessWidget {
  final String value, correct;
  final _Phase phase;
  final String? picked;
  final VoidCallback onTap;

  const _LeafBtn({
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

    Color bg1 = const Color(0xFF66BB6A);
    Color bg2 = const Color(0xFF2E7D32);

    if (isAnswered) {
      if (isCorrectThis) {
        bg1 = const Color(0xFFFFD54F);
        bg2 = const Color(0xFFF9A825);
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
        clipper: _LeafClipper(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 74,
          height: 88,
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [bg1, bg2],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter),
          ),
          child: Center(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
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

/// A pointed-oval leaf silhouette -- the sixth distinct answer-button
/// shape across the Grade 1 games (rounded square, circle, wood plank,
/// diamond, hexagon, leaf).
class _LeafClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()..moveTo(w / 2, 0);
    path.quadraticBezierTo(w, h * 0.15, w, h * 0.5);
    path.quadraticBezierTo(w, h * 0.85, w / 2, h);
    path.quadraticBezierTo(0, h * 0.85, 0, h * 0.5);
    path.quadraticBezierTo(0, h * 0.15, w / 2, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Feedback banner
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
      _Phase.correct => ('🦉 The owl nods — well spotted!', const Color(0xFF2E7D32)),
      _Phase.wrong => (wrongReaction, const Color(0xFF4E342E)),
      _Phase.streak => (
          '✨ ${streak}x EXPLORER STREAK! ✨',
          const Color(0xFFF9A825)
        ),
      _Phase.zoneDone => ('🗺️  Map Unlocked!', const Color(0xFF1F4A2C)),
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
              const Text('🗺️ 🦉 🗺️', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 12),
              Text('Map $zoneNum Uncovered!',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              const Text('Deeper into the ruins!',
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
      backgroundColor: Color(0xFF0D2818),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🦉', style: TextStyle(fontSize: 72)),
            SizedBox(height: 16),
            Text('Alphabet Explorer',
                style: TextStyle(
                    color: Color(0xFFFFD54F),
                    fontSize: 24,
                    fontWeight: FontWeight.w900)),
            SizedBox(height: 8),
            Text('Uncover the letters of the temple!',
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
            colors: [Color(0xFF0D2818), Color(0xFF1F4A2C), Color(0xFFFFD54F)],
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
                  const Text('🏆 Temple Explored!',
                      style: TextStyle(
                          color: Color(0xFFFFF8E1),
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
                              const Color(0xFFFFD54F).withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Column(
                          children: [
                            const Text('📜 Found',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 12)),
                            Text('$correctCount',
                                style: const TextStyle(
                                    color: Color(0xFFFFD54F),
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
                          label: '🔄 Explore Again',
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
                  colors: [Color(0xFFFFD54F), Color(0xFFF9A825)])
              : null,
          color: primary ? null : Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: primary ? const Color(0xFFFFD54F) : Colors.white38,
            width: 1.5,
          ),
        ),
        child: Text(label,
            style: TextStyle(
                color: primary ? const Color(0xFF0D2818) : Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Firefly swirl painter (streak celebration) — a spiral of glowing gold
// motes, distinct from fireworks, a coin shower, a parade, an aurora
// sweep, and a resonance pulse.
// ─────────────────────────────────────────────────────────────────────────────

class _FireflySwirlPainter extends CustomPainter {
  final double t;
  _FireflySwirlPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.35;
    final paint = Paint()..color = const Color(0xFFFFD54F);

    for (var i = 0; i < 14; i++) {
      final angle = (i / 14) * 2 * math.pi + t * 4 * math.pi;
      final radius = 20 + t * 90 + (i % 3) * 10;
      final dx = cx + math.cos(angle) * radius;
      final dy = cy + math.sin(angle) * radius * 0.6;
      final alpha = (1 - t) * 0.85;
      canvas.drawCircle(
        Offset(dx, dy),
        3 + (i % 3),
        paint..color = const Color(0xFFFFD54F).withValues(alpha: alpha),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FireflySwirlPainter old) => old.t != t;
}
