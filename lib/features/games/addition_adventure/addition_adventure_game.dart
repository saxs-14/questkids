import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/game_session_model.dart';
import '../core/game_config.dart';
import '../core/game_session_persistence.dart';

// ────────────────────────────────────────────────────────────────────────────
// Addition Adventure — Grade 1 pirate treasure voyage
//
// 4 Islands (difficulty bands, sums up to 20 overall):
//   1. Coral Cove       — sums to 5
//   2. Palm Bay         — sums to 10
//   3. Shipwreck Shoal  — sums to 15
//   4. Treasure Island  — sums to 20
// 5 questions per island = 20 total.
//
// Deliberately NOT a duel-vs-opponent (Number Counting Duel already owns
// that shape): this is a solo sailing journey. Two coin piles (the
// addends) merge into a treasure chest instead of an object grid; answers
// are bobbing sea shells instead of crystals; wrong answers get a gentle
// splash instead of a shake; streaks trigger a coin shower instead of
// fireworks. Architecture: fully self-contained StatefulWidget, no
// external engine (same pattern as NumberCountingDuelGame).
// ────────────────────────────────────────────────────────────────────────────

enum _Phase { intro, question, correct, wrong, streak, islandDone, victory }

// ── Question model ─────────────────────────────────────────────────────────

class _Q {
  final int a;
  final int b;
  final List<int> choices;
  final int correct;

  _Q({required this.a, required this.b, required this.choices})
      : correct = a + b;
}

// ── Island definitions ───────────────────────────────────────────────────────

class _Island {
  final String name;
  final int maxSum;
  final int questionCount = 5;
  const _Island(this.name, this.maxSum);
}

// ── Main game widget ───────────────────────────────────────────────────────

class AdditionAdventureGame extends StatefulWidget {
  final GameConfig config;
  final dynamic user;
  const AdditionAdventureGame({super.key, required this.config, this.user});

  @override
  State<AdditionAdventureGame> createState() => _AAState();
}

class _AAState extends State<AdditionAdventureGame>
    with TickerProviderStateMixin {
  static const _islands = [
    _Island('Coral Cove', 5),
    _Island('Palm Bay', 10),
    _Island('Shipwreck Shoal', 15),
    _Island('Treasure Island', 20),
  ];

  // ── Animations ──────────────────────────────────────────────────────────
  late AnimationController _bobCtrl; // ship + bubbles bob
  late AnimationController _sailCtrl; // ship sails forward on correct
  late AnimationController _splashCtrl; // wrong-answer ripple
  late AnimationController _coinShowerCtrl; // streak celebration
  late AnimationController _fadeCtrl; // question fade-in
  late AnimationController _mergeCtrl; // coin piles merge into chest

  late Animation<double> _bobAnim;
  late Animation<double> _sailAnim;
  late Animation<double> _splashAnim;
  late Animation<double> _coinShowerAnim;
  late Animation<double> _fadeAnim;
  late Animation<double> _mergeAnim;

  // ── Game state ──────────────────────────────────────────────────────────
  int _islandIdx = 0;
  int _qIdx = 0;
  int _correctCount = 0;
  int _streak = 0;
  int _totalXP = 0;

  _Phase _phase = _Phase.intro;
  _Q? _current;
  int? _picked;

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
    _bobCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _bobAnim = Tween<double>(begin: -6, end: 6)
        .animate(CurvedAnimation(parent: _bobCtrl, curve: Curves.easeInOut));

    _sailCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _sailAnim =
        CurvedAnimation(parent: _sailCtrl, curve: Curves.easeInOutCubic);

    _splashCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _splashAnim = CurvedAnimation(parent: _splashCtrl, curve: Curves.easeOut);

    _coinShowerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400));
    _coinShowerAnim =
        CurvedAnimation(parent: _coinShowerCtrl, curve: Curves.easeOut);

    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);

    _mergeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _mergeAnim = CurvedAnimation(parent: _mergeCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    for (final timer in List<Timer>.from(_pendingTimers)) {
      timer.cancel();
    }
    _pendingTimers.clear();
    _bobCtrl.dispose();
    _sailCtrl.dispose();
    _splashCtrl.dispose();
    _coinShowerCtrl.dispose();
    _fadeCtrl.dispose();
    _mergeCtrl.dispose();
    super.dispose();
  }

  // ── Game flow ────────────────────────────────────────────────────────────

  void _startGame() {
    setState(() {
      _islandIdx = 0;
      _qIdx = 0;
      _correctCount = 0;
      _streak = 0;
      _totalXP = 0;
    });
    _nextQuestion();
  }

  void _nextQuestion() {
    final island = _islands[_islandIdx];
    final q = _makeQuestion(island);
    _fadeCtrl.reset();
    _mergeCtrl.reset();
    setState(() {
      _current = q;
      _picked = null;
      _phase = _Phase.question;
    });
    _fadeCtrl.forward();
    _mergeCtrl.forward();
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
      _sailCtrl.forward(from: 0);
      final isStreak = _streak > 0 && _streak % 3 == 0;
      if (isStreak) {
        setState(() => _phase = _Phase.streak);
        _coinShowerCtrl.forward(from: 0);
        _delayed(1800, _advance);
      } else {
        setState(() => _phase = _Phase.correct);
        _delayed(1200, _advance);
      }
    } else {
      setState(() {
        _streak = 0;
        _phase = _Phase.wrong;
      });
      _splashCtrl.forward(from: 0);
      _delayed(1300, _advance);
    }
  }

  void _advance() {
    if (!mounted) return;
    final island = _islands[_islandIdx];
    final next = _qIdx + 1;

    if (next >= island.questionCount) {
      if (_islandIdx + 1 >= _islands.length) {
        _persistSession();
        setState(() => _phase = _Phase.victory);
      } else {
        setState(() => _phase = _Phase.islandDone);
        _delayed(2200, () {
          setState(() {
            _islandIdx++;
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
  /// NumberCountingDuelGame's established pattern. Applies the same
  /// completion-bonus tiers as GameEngine.defaultResult() so the number
  /// shown on the victory screen matches what actually gets awarded.
  void _persistSession() {
    final totalQuestions =
        _islands.fold<int>(0, (sum, l) => sum + l.questionCount); // 20
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

  _Q _makeQuestion(_Island island) {
    final a = 1 + _rng.nextInt(island.maxSum - 1);
    final maxB = island.maxSum - a;
    final b = 1 + _rng.nextInt(math.max(1, maxB));
    final correct = a + b;
    final choices = _threeChoices(correct);
    return _Q(a: a, b: b, choices: choices);
  }

  List<int> _threeChoices(int correct) {
    final s = <int>{correct};
    int attempts = 0;
    while (s.length < 3 && attempts < 200) {
      final delta = 1 + _rng.nextInt(4);
      final c = _rng.nextBool() ? correct + delta : correct - delta;
      if (c >= 1 && c != correct) s.add(c);
      attempts++;
    }
    while (s.length < 3) {
      s.add(correct + s.length);
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

    final island = _islands[_islandIdx];
    final q = _current;

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: _OceanBg()),

          if (_phase == _Phase.streak)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _coinShowerAnim,
                builder: (_, __) => CustomPaint(
                  painter: _CoinShowerPainter(_coinShowerAnim.value),
                ),
              ),
            ),

          if (_phase == _Phase.wrong)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _splashAnim,
                builder: (_, __) => CustomPaint(
                  painter: _SplashPainter(_splashAnim.value),
                ),
              ),
            ),

          SafeArea(
            child: Column(
              children: [
                _VoyageHeader(
                  islandName: island.name,
                  islandIdx: _islandIdx,
                  totalIslands: _islands.length,
                  qIdx: _qIdx,
                  totalQ: island.questionCount,
                  treasureCount: _correctCount,
                ),
                SizedBox(
                  height: 110,
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_bobAnim, _sailAnim]),
                    builder: (_, __) => _ShipScene(
                      bobY: _bobAnim.value,
                      sailProgress: _sailAnim.value,
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
                            bobVal: _bobAnim.value,
                            mergeVal: _mergeAnim.value,
                            onAnswer: _onAnswer,
                          ),
                        ),
                ),
                _FeedbackBanner(phase: _phase, streak: _streak),
                if (_phase == _Phase.islandDone)
                  _IslandDone(islandNum: _islandIdx + 1),
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
// Ocean background CustomPainter — sun, sky, sea, distant island silhouettes.
// Deliberately a bright daytime beach palette, the opposite of Number
// Counting Duel's purple night arena.
// ─────────────────────────────────────────────────────────────────────────────

class _OceanBg extends StatelessWidget {
  const _OceanBg();
  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _OceanPainter());
  }
}

class _OceanPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = const LinearGradient(
          colors: [
            Color(0xFF4FC3F7),
            Color(0xFF29B6F6),
            Color(0xFF0288D1),
            Color(0xFF01579B),
          ],
          stops: [0.0, 0.30, 0.65, 1.0],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // Sun
    canvas.drawCircle(
      Offset(w * 0.85, h * 0.10),
      28,
      Paint()..color = const Color(0xFFFFF176).withValues(alpha: 0.9),
    );
    canvas.drawCircle(
      Offset(w * 0.85, h * 0.10),
      40,
      Paint()
        ..color = const Color(0xFFFFF176).withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );

    // Distant island silhouettes with palm tufts
    _drawIsland(canvas, Offset(w * 0.12, h * 0.32), 30);
    _drawIsland(canvas, Offset(w * 0.55, h * 0.28), 22);

    // Gentle wave lines across the lower two-thirds
    final wavePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < 6; i++) {
      final y = h * 0.45 + i * (h * 0.09);
      final path = Path()..moveTo(0, y);
      for (double x = 0; x <= w; x += 24) {
        path.quadraticBezierTo(x + 12, y - 6, x + 24, y);
      }
      canvas.drawPath(path, wavePaint);
    }
  }

  void _drawIsland(Canvas canvas, Offset base, double size) {
    canvas.drawOval(
      Rect.fromCenter(center: base, width: size * 1.8, height: size * 0.7),
      Paint()..color = const Color(0xFF2E7D32).withValues(alpha: 0.55),
    );
    final trunkPaint = Paint()
      ..color = const Color(0xFF6D4C41).withValues(alpha: 0.7)
      ..strokeWidth = 3;
    canvas.drawLine(
        base + const Offset(0, -2), base + Offset(4, -size * 0.9), trunkPaint);
    canvas.drawCircle(base + Offset(4, -size * 0.9), size * 0.32,
        Paint()..color = const Color(0xFF388E3C).withValues(alpha: 0.7));
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Voyage header: island name + question progress + treasure collected
// ─────────────────────────────────────────────────────────────────────────────

class _VoyageHeader extends StatelessWidget {
  final String islandName;
  final int islandIdx, totalIslands, qIdx, totalQ, treasureCount;

  const _VoyageHeader({
    required this.islandName,
    required this.islandIdx,
    required this.totalIslands,
    required this.qIdx,
    required this.totalQ,
    required this.treasureCount,
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
            color: const Color(0xFFFFD54A).withValues(alpha: 0.45),
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
                  color: const Color(0xFFFFD54A).withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('🪙 $treasureCount',
                    style: const TextStyle(
                        color: Color(0xFF3E2723),
                        fontSize: 15,
                        fontWeight: FontWeight.w900)),
              ),
              Column(
                children: [
                  Text(
                    'Island ${islandIdx + 1}/$totalIslands',
                    style: const TextStyle(
                        color: Color(0xFFFFD54A),
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                  Text(
                    islandName,
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
                      ? const Color(0xFF43A047)
                      : active
                          ? const Color(0xFFFFD54A)
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
// Ship scene: a single pirate ship that sails forward on correct answers
// ─────────────────────────────────────────────────────────────────────────────

class _ShipScene extends StatelessWidget {
  final double bobY;
  final double sailProgress;
  final _Phase phase;

  const _ShipScene({
    required this.bobY,
    required this.sailProgress,
    required this.phase,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final dx = sailProgress * (c.maxWidth * 0.18);
      return Stack(
        alignment: Alignment.center,
        children: [
          Transform.translate(
            offset: Offset(dx, bobY),
            child: const Text('⛵', style: TextStyle(fontSize: 56)),
          ),
        ],
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Question area: two coin piles merging into a chest + shell answer choices
// ─────────────────────────────────────────────────────────────────────────────

class _QuestionArea extends StatelessWidget {
  final _Q q;
  final _Phase phase;
  final int? picked;
  final double bobVal;
  final double mergeVal;
  final void Function(int) onAnswer;

  const _QuestionArea({
    required this.q,
    required this.phase,
    required this.picked,
    required this.bobVal,
    required this.mergeVal,
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
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: const Color(0xFFFFD54A).withValues(alpha: 0.50),
                  width: 1.5),
            ),
            child: const Text(
              'How many coins in the chest?',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                shadows: [Shadow(blurRadius: 8, color: Colors.black45)],
              ),
            ),
          ),

          // Two coin piles merging toward a chest in the middle
          SizedBox(
            height: 90,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Transform.translate(
                  offset: Offset(mergeVal * 26, 0),
                  child: _CoinPile(count: q.a, color: const Color(0xFFFFD54A)),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('➕',
                      style: TextStyle(fontSize: 26, color: Colors.white)),
                ),
                Transform.translate(
                  offset: Offset(-mergeVal * 26, 0),
                  child: _CoinPile(
                      count: q.b, color: const Color(0xFFB0BEC5)),
                ),
              ],
            ),
          ),

          Wrap(
            spacing: 14,
            runSpacing: 14,
            alignment: WrapAlignment.center,
            children: q.choices
                .map((c) => Transform.translate(
                      offset: Offset(0, bobVal * 0.5),
                      child: _ShellBtn(
                        value: c,
                        phase: phase,
                        picked: picked,
                        correct: q.correct,
                        onTap: () => onAnswer(c),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _CoinPile extends StatelessWidget {
  final int count;
  final Color color;
  const _CoinPile({required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    final shown = math.min(count, 10);
    return SizedBox(
      width: 70,
      height: 70,
      child: Wrap(
        spacing: 2,
        runSpacing: 2,
        alignment: WrapAlignment.center,
        children: [
          for (int i = 0; i < shown; i++)
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                border: Border.all(color: Colors.white, width: 1),
                boxShadow: [
                  BoxShadow(
                      color: color.withValues(alpha: 0.6), blurRadius: 3)
                ],
              ),
            ),
          if (count > shown)
            Text('+${count - shown}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _ShellBtn extends StatelessWidget {
  final int value, correct;
  final _Phase phase;
  final int? picked;
  final VoidCallback onTap;

  const _ShellBtn({
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
        phase == _Phase.islandDone;
    final isPickedThis = picked == value;
    final isCorrectThis = value == correct;

    Color bg1 = const Color(0xFF00ACC1);
    Color bg2 = const Color(0xFF00838F);
    Color border = Colors.white.withValues(alpha: 0.35);
    Color textC = Colors.white;

    if (isAnswered) {
      if (isCorrectThis) {
        bg1 = const Color(0xFF43A047);
        bg2 = const Color(0xFF2E7D32);
        border = const Color(0xFF80FF80);
      } else if (isPickedThis) {
        bg1 = const Color(0xFFEF5350);
        bg2 = const Color(0xFFC62828);
        border = const Color(0xFFFF9E9E);
      } else {
        bg1 = Colors.blueGrey.shade600;
        bg2 = Colors.blueGrey.shade700;
        textC = Colors.white54;
      }
    }

    return GestureDetector(
      onTap: isAnswered ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [bg1, bg2],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          shape: BoxShape.circle,
          border: Border.all(color: border, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: isCorrectThis && isAnswered
                  ? const Color(0xFF4CAF50).withValues(alpha: 0.55)
                  : bg1.withValues(alpha: 0.40),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            '$value',
            style: TextStyle(
              color: textC,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              shadows: const [Shadow(blurRadius: 6, color: Colors.black38)],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Feedback banner — pirate-flavoured copy, distinct from every other engine
// ─────────────────────────────────────────────────────────────────────────────

class _FeedbackBanner extends StatelessWidget {
  final _Phase phase;
  final int streak;
  const _FeedbackBanner({required this.phase, required this.streak});

  @override
  Widget build(BuildContext context) {
    final (text, bg) = switch (phase) {
      _Phase.correct => ('⚓ Yo ho ho! Coins collected!', const Color(0xFF2E7D32)),
      _Phase.wrong => ('🌊 Splash! Try again, matey!', const Color(0xFF01579B)),
      _Phase.streak => (
          '🏴‍☠️ ${streak}x TREASURE STREAK! 💰',
          const Color(0xFFB8860B)
        ),
      _Phase.islandDone => ('🗺️  Island Explored!', const Color(0xFF4A148C)),
      _ => (null, Colors.transparent),
    };
    if (text == null) return const SizedBox(height: 40);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Center(
        child: Text(text,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16)),
      ),
    );
  }
}

class _IslandDone extends StatelessWidget {
  final int islandNum;
  const _IslandDone({required this.islandNum});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.60),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🏝️ ⛵ 🏝️', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 12),
              Text('Island $islandNum Explored!',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              const Text('Setting sail for the next island!',
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
      backgroundColor: Color(0xFF0288D1),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🏝️', style: TextStyle(fontSize: 72)),
            SizedBox(height: 16),
            Text('Addition Adventure',
                style: TextStyle(
                    color: Color(0xFFFFD54A),
                    fontSize: 24,
                    fontWeight: FontWeight.w900)),
            SizedBox(height: 8),
            Text('Set sail for treasure!',
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
            colors: [Color(0xFF01579B), Color(0xFF0288D1), Color(0xFFFFB300)],
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
                  const Text('🏆 Treasure Found!',
                      style: TextStyle(
                          color: Color(0xFFFFD54A),
                          fontSize: 32,
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
                      color: Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color:
                              const Color(0xFFFFD54A).withValues(alpha: 0.45)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Column(
                          children: [
                            const Text('🪙 Coins',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 12)),
                            Text('$correctCount',
                                style: const TextStyle(
                                    color: Color(0xFFFFD54A),
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
                          label: '🔄 Sail Again',
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
                  colors: [Color(0xFFFFD54A), Color(0xFFFFB300)])
              : null,
          color: primary ? null : Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: primary ? const Color(0xFFFFD54A) : Colors.white38,
            width: 1.5,
          ),
        ),
        child: Text(label,
            style: TextStyle(
                color: primary ? const Color(0xFF3E2723) : Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Splash particle painter (wrong-answer feedback)
// ─────────────────────────────────────────────────────────────────────────────

class _SplashPainter extends CustomPainter {
  final double t;
  _SplashPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0) return;
    final cx = size.width / 2;
    final cy = size.height * 0.55;
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: (1 - t) * 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    for (int ring = 0; ring < 3; ring++) {
      final rt = (t - ring * 0.15).clamp(0.0, 1.0);
      if (rt <= 0) continue;
      canvas.drawCircle(Offset(cx, cy), rt * 80, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SplashPainter old) => old.t != t;
}

// ─────────────────────────────────────────────────────────────────────────────
// Coin shower particle painter (streak celebration) — falling gold coins,
// distinct from Number Counting Duel's radial firework bursts.
// ─────────────────────────────────────────────────────────────────────────────

class _CoinShowerPainter extends CustomPainter {
  final double t;
  _CoinShowerPainter(this.t);

  static final _rng = math.Random(99);
  static final _coins = List.generate(
      18,
      (i) => (
            x: _rng.nextDouble(),
            delay: _rng.nextDouble() * 0.4,
            speed: 0.7 + _rng.nextDouble() * 0.4,
            spin: _rng.nextDouble() * 6.28,
          ));

  @override
  void paint(Canvas canvas, Size size) {
    for (final c in _coins) {
      final ct = ((t - c.delay) / (1 - c.delay)).clamp(0.0, 1.0);
      if (ct <= 0) continue;
      final y = ct * size.height * c.speed;
      final alpha = (1 - ct * ct).clamp(0.0, 1.0);
      final cx = c.x * size.width;
      canvas.save();
      canvas.translate(cx, y);
      canvas.rotate(c.spin * ct);
      canvas.drawCircle(
        Offset.zero,
        7,
        Paint()..color = const Color(0xFFFFD54A).withValues(alpha: alpha),
      );
      canvas.drawCircle(
        Offset.zero,
        7,
        Paint()
          ..color = const Color(0xFFB8860B).withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _CoinShowerPainter old) => old.t != t;
}
