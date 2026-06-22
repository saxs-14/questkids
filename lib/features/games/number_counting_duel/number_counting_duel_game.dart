import 'dart:math' as math;
import 'package:flutter/material.dart';

// ────────────────────────────────────────────────────────────────────────────
// Number Counting Duel — Grade 1 magical arena counting game
//
// 5 Levels:
//   1. Count objects 1–20
//   2. Count objects 20–50
//   3. Count objects 50–100
//   4. Compare two numbers (bigger / smaller)
//   5. Find largest or smallest from 4 numbers
//
// Architecture: fully self-contained StatefulWidget, no external engine.
// ────────────────────────────────────────────────────────────────────────────

enum _Phase { intro, question, correct, wrong, streak, levelDone, victory }

// ── Question model ─────────────────────────────────────────────────────────

class _Q {
  final String type;      // 'count' | 'compare' | 'extreme'
  final String prompt;
  final String objEmoji;  // for count type
  final int    objCount;  // for count type
  final List<int> choices;
  final int correct;

  const _Q({
    required this.type,
    required this.prompt,
    this.objEmoji = '⭐',
    this.objCount = 0,
    required this.choices,
    required this.correct,
  });
}

// ── Level definitions ──────────────────────────────────────────────────────

class _Level {
  final String name;
  final int min, max;
  final String type;
  final int questionCount;
  const _Level(this.name, this.min, this.max, this.type, {this.questionCount = 5});
}

// ── Main game widget ───────────────────────────────────────────────────────

class NumberCountingDuelGame extends StatefulWidget {
  final dynamic user;
  const NumberCountingDuelGame({super.key, this.user});

  @override
  State<NumberCountingDuelGame> createState() => _NCDState();
}

class _NCDState extends State<NumberCountingDuelGame>
    with TickerProviderStateMixin {

  // ── Levels ──────────────────────────────────────────────────────────────
  static const _levels = [
    _Level('Count 1 – 20',   1,  20,  'count'),
    _Level('Count 20 – 50',  20, 50,  'count'),
    _Level('Count 50 – 100', 50, 100, 'count'),
    _Level('Compare',        1,  100, 'compare'),
    _Level('Find the Number',1,  100, 'extreme'),
  ];

  // ── Object emojis for count levels ──────────────────────────────────────
  static const _countEmojis = ['⭐', '🍎', '🌸', '🦋', '🎈'];

  // ── Animations ──────────────────────────────────────────────────────────
  late AnimationController _floatCtrl;    // crystals bob
  late AnimationController _playerJump;  // player champ jumps
  late AnimationController _aiJump;      // AI champ jumps
  late AnimationController _shakeCtrl;   // wrong-answer shake
  late AnimationController _fireworks;   // streak fireworks
  late AnimationController _fadeCtrl;    // question fade-in

  late Animation<double> _floatAnim;
  late Animation<double> _playerJumpAnim;
  late Animation<double> _aiJumpAnim;
  late Animation<Offset> _shakeAnim;
  late Animation<double> _fireworksAnim;
  late Animation<double> _fadeAnim;

  // ── Game state ──────────────────────────────────────────────────────────
  int _levelIdx  = 0;
  int _qIdx      = 0;
  int _playerSco = 0;
  int _aiSco     = 0;
  int _streak    = 0;
  int _totalXP   = 0;

  _Phase _phase  = _Phase.intro;
  _Q?    _current;
  int?   _picked;      // player's chosen answer
  bool   _aiAnswered = false;

  final _rng = math.Random();

  // ── Timers ──────────────────────────────────────────────────────────────
  Future<void> _delay(int ms) =>
      Future.delayed(Duration(milliseconds: ms));

  @override
  void initState() {
    super.initState();
    _initAnims();
    _delay(800).then((_) => _startGame());
  }

  void _initAnims() {
    _floatCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: -5, end: 5)
        .animate(CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));

    _playerJump = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _playerJumpAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -30), weight: 45),
      TweenSequenceItem(tween: Tween(begin: -30, end: 0), weight: 55),
    ]).animate(CurvedAnimation(parent: _playerJump, curve: Curves.easeOut));

    _aiJump = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _aiJumpAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -30), weight: 45),
      TweenSequenceItem(tween: Tween(begin: -30, end: 0), weight: 55),
    ]).animate(CurvedAnimation(parent: _aiJump, curve: Curves.easeOut));

    _shakeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _shakeAnim = TweenSequence<Offset>([
      TweenSequenceItem(tween: Tween(begin: Offset.zero, end: const Offset(-12, 0)), weight: 25),
      TweenSequenceItem(tween: Tween(begin: const Offset(-12, 0), end: const Offset(12, 0)), weight: 50),
      TweenSequenceItem(tween: Tween(begin: const Offset(12, 0), end: Offset.zero), weight: 25),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut));

    _fireworks = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _fireworksAnim = CurvedAnimation(parent: _fireworks, curve: Curves.easeOut);

    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    _playerJump.dispose();
    _aiJump.dispose();
    _shakeCtrl.dispose();
    _fireworks.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Game flow ────────────────────────────────────────────────────────────

  void _startGame() {
    setState(() {
      _levelIdx  = 0;
      _qIdx      = 0;
      _playerSco = 0;
      _aiSco     = 0;
      _streak    = 0;
      _totalXP   = 0;
    });
    _nextQuestion();
  }

  void _nextQuestion() {
    final lev = _levels[_levelIdx];
    final q   = _makeQuestion(lev);
    _fadeCtrl.reset();
    setState(() {
      _current   = q;
      _picked    = null;
      _aiAnswered = false;
      _phase     = _Phase.question;
    });
    _fadeCtrl.forward();
    _scheduleAI(lev);
  }

  // AI answers after a random delay (slower on early levels, faster later)
  void _scheduleAI(_Level lev) {
    final baseMs = [4500, 4000, 3500, 3000, 2500][_levelIdx];
    final delayMs = baseMs + _rng.nextInt(2000) - 1000;
    Future.delayed(Duration(milliseconds: delayMs.clamp(1500, 6000)), () {
      if (!mounted || _picked != null || _phase != _Phase.question) return;
      // AI has 70% chance of correct answer
      final q = _current!;
      final aiPick = _rng.nextDouble() < 0.70
          ? q.correct
          : q.choices[_rng.nextInt(q.choices.length)];
      if (aiPick == q.correct) {
        setState(() { _aiSco++; _aiAnswered = true; });
        _aiJump.forward(from: 0);
      }
      _advance(aiAnsweredCorrectly: aiPick == q.correct);
    });
  }

  void _onAnswer(int choice) {
    if (_picked != null || _phase != _Phase.question) return;
    final q = _current!;
    setState(() => _picked = choice);
    final correct = choice == q.correct;

    if (correct) {
      setState(() { _playerSco++; _streak++; _totalXP += 10; });
      _playerJump.forward(from: 0);
      final isStreak = _streak > 0 && _streak % 3 == 0;
      if (isStreak) {
        setState(() => _phase = _Phase.streak);
        _fireworks.forward(from: 0);
        _delay(1800).then((_) => _advance());
      } else {
        setState(() => _phase = _Phase.correct);
        _delay(1200).then((_) => _advance());
      }
    } else {
      setState(() { _streak = 0; _phase = _Phase.wrong; });
      _shakeCtrl.forward(from: 0);
      _delay(1200).then((_) => _advance());
    }
  }

  void _advance({bool aiAnsweredCorrectly = false}) {
    if (!mounted) return;
    final lev  = _levels[_levelIdx];
    final next = _qIdx + 1;

    if (next >= lev.questionCount) {
      // Level done
      if (_levelIdx + 1 >= _levels.length) {
        setState(() => _phase = _Phase.victory);
      } else {
        setState(() { _phase = _Phase.levelDone; });
        _delay(2200).then((_) {
          if (!mounted) return;
          setState(() { _levelIdx++; _qIdx = 0; });
          _nextQuestion();
        });
      }
    } else {
      setState(() => _qIdx = next);
      _delay(300).then((_) { if (mounted) _nextQuestion(); });
    }
  }

  // ── Question generation ──────────────────────────────────────────────────

  _Q _makeQuestion(_Level lev) {
    return switch (lev.type) {
      'count'   => _makeCountQ(lev),
      'compare' => _makeCompareQ(lev),
      _         => _makeExtremeQ(lev),
    };
  }

  _Q _makeCountQ(_Level lev) {
    final n = lev.min + _rng.nextInt(lev.max - lev.min + 1);
    final emoji = _countEmojis[_levelIdx % _countEmojis.length];
    final choices = _threeChoices(n, lo: lev.min, hi: lev.max);
    return _Q(
      type: 'count',
      prompt: 'How many ${emoji}s are there?',
      objEmoji: emoji,
      objCount: n,
      choices: choices,
      correct: n,
    );
  }

  _Q _makeCompareQ(_Level lev) {
    int a = lev.min + _rng.nextInt(lev.max - lev.min + 1);
    int b = lev.min + _rng.nextInt(lev.max - lev.min + 1);
    while (b == a) b = lev.min + _rng.nextInt(lev.max - lev.min + 1);
    final askBigger = _rng.nextBool();
    return _Q(
      type: 'compare',
      prompt: askBigger ? 'Pick the BIGGER number! 👆' : 'Pick the SMALLER number! 👇',
      choices: [a, b]..shuffle(_rng),
      correct: askBigger ? math.max(a, b) : math.min(a, b),
    );
  }

  _Q _makeExtremeQ(_Level lev) {
    final nums = <int>{};
    while (nums.length < 4) nums.add(lev.min + _rng.nextInt(lev.max - lev.min + 1));
    final list = nums.toList()..shuffle(_rng);
    final askMax = _rng.nextBool();
    return _Q(
      type: 'extreme',
      prompt: askMax ? 'Find the BIGGEST number! 🏆' : 'Find the SMALLEST number! 🔍',
      choices: list,
      correct: askMax ? list.reduce(math.max) : list.reduce(math.min),
    );
  }

  List<int> _threeChoices(int correct, {required int lo, required int hi}) {
    final s = <int>{correct};
    int attempts = 0;
    while (s.length < 3 && attempts < 200) {
      final delta = 1 + _rng.nextInt(8);
      final c = _rng.nextBool() ? correct + delta : correct - delta;
      if (c >= lo && c != correct) s.add(c);
      attempts++;
    }
    while (s.length < 3) s.add(correct + s.length);
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
        playerScore: _playerSco,
        aiScore: _aiSco,
        totalXP: _totalXP,
        onReplay: _startGame,
        onExit: () => Navigator.of(context).pop(),
      );
    }

    final lev   = _levels[_levelIdx];
    final q     = _current;
    final total = lev.questionCount;

    return Scaffold(
      body: Stack(
        children: [
          // ── Arena background ─────────────────────────────────────────────
          const Positioned.fill(child: _ArenaBg()),

          // ── Fireworks overlay (streak) ───────────────────────────────────
          if (_phase == _Phase.streak)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _fireworksAnim,
                builder: (_, __) => CustomPaint(
                  painter: _FireworksPainter(_fireworksAnim.value),
                ),
              ),
            ),

          // ── Main content ─────────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                // Header: level name + scores + dots
                _Header(
                  levelName: lev.name,
                  levelIdx: _levelIdx,
                  totalLevels: _levels.length,
                  qIdx: _qIdx,
                  totalQ: total,
                  playerSco: _playerSco,
                  aiSco: _aiSco,
                ),

                // Arena scene with two champions
                SizedBox(
                  height: 130,
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_playerJumpAnim, _aiJumpAnim, _floatAnim]),
                    builder: (_, __) => _ArenaScene(
                      playerJumpY:  _playerJumpAnim.value,
                      aiJumpY:      _aiJumpAnim.value,
                      phase:        _phase,
                      aiAnswered:   _aiAnswered,
                    ),
                  ),
                ),

                // Question area (fade in)
                Expanded(
                  child: q == null
                      ? const SizedBox()
                      : FadeTransition(
                          opacity: _fadeAnim,
                          child: AnimatedBuilder(
                            animation: _shakeAnim,
                            builder: (_, child) => Transform.translate(
                              offset: _phase == _Phase.wrong ? _shakeAnim.value : Offset.zero,
                              child: child,
                            ),
                            child: _QuestionArea(
                              q: q,
                              phase: _phase,
                              picked: _picked,
                              floatVal: _floatAnim.value,
                              onAnswer: _onAnswer,
                            ),
                          ),
                        ),
                ),

                // Phase feedback banner
                _FeedbackBanner(phase: _phase, streak: _streak),

                // Level done overlay
                if (_phase == _Phase.levelDone)
                  _LevelDone(level: _levelIdx + 1),

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
// Arena background CustomPainter
// ─────────────────────────────────────────────────────────────────────────────

class _ArenaBg extends StatelessWidget {
  const _ArenaBg();
  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _ArenaPainter());
  }
}

class _ArenaPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Sky gradient
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF1A0050), Color(0xFF3B0080), Color(0xFF6A1B9A)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // Stars
    final starPaint = Paint()..color = Colors.white.withValues(alpha: 0.55);
    final rng = math.Random(42);
    for (int i = 0; i < 60; i++) {
      canvas.drawCircle(
        Offset(rng.nextDouble() * w, rng.nextDouble() * h * 0.55),
        rng.nextDouble() * 1.8 + 0.4,
        starPaint,
      );
    }

    // Arena floor (oval)
    final floorY = h * 0.55;
    final floorPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFD4A017), Color(0xFF8B6914)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, floorY - 40, w, h - floorY + 60));
    canvas.drawOval(Rect.fromLTWH(-w * 0.1, floorY - 30, w * 1.2, 90), floorPaint);

    // Crowd left bleachers
    _drawBleachers(canvas, Rect.fromLTWH(0, h * 0.05, w * 0.20, h * 0.50), true);
    // Crowd right bleachers
    _drawBleachers(canvas, Rect.fromLTWH(w * 0.80, h * 0.05, w * 0.20, h * 0.50), false);

    // Spotlights from top corners
    final spotPaint = Paint()
      ..color = Colors.yellow.withValues(alpha: 0.07)
      ..style = PaintingStyle.fill;
    final path1 = Path()
      ..moveTo(0, 0)
      ..lineTo(w * 0.5, h * 0.55);
    final spot1 = Path()
      ..moveTo(-30, 0)
      ..lineTo(w * 0.15, 0)
      ..lineTo(w * 0.6, h * 0.55)
      ..lineTo(w * 0.4, h * 0.55)
      ..close();
    canvas.drawPath(spot1, spotPaint);
    final spot2 = Path()
      ..moveTo(w + 30, 0)
      ..lineTo(w * 0.85, 0)
      ..lineTo(w * 0.4, h * 0.55)
      ..lineTo(w * 0.6, h * 0.55)
      ..close();
    canvas.drawPath(spot2, spotPaint);
    canvas.drawPath(path1, Paint()); // suppress unused
  }

  void _drawBleachers(Canvas canvas, Rect rect, bool leftSide) {
    final rng = math.Random(leftSide ? 1 : 2);
    final rowColors = [
      const Color(0xFFE53935),
      const Color(0xFFE91E63),
      const Color(0xFF3F51B5),
      const Color(0xFF1E88E5),
      const Color(0xFF43A047),
      const Color(0xFFFDD835),
    ];
    const rows = 6;
    final rowH = rect.height / rows;
    for (int r = 0; r < rows; r++) {
      final y = rect.top + r * rowH;
      final cols = (rect.width / 14).floor();
      for (int c = 0; c < cols; c++) {
        final x = rect.left + c * 14.0;
        // silhouette head
        canvas.drawCircle(
          Offset(x + 7, y + rowH * 0.3),
          4.5,
          Paint()..color = rowColors[rng.nextInt(rowColors.length)].withValues(alpha: 0.7),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Header: level + score + question dots
// ─────────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final String levelName;
  final int levelIdx, totalLevels, qIdx, totalQ, playerSco, aiSco;

  const _Header({
    required this.levelName,
    required this.levelIdx,
    required this.totalLevels,
    required this.qIdx,
    required this.totalQ,
    required this.playerSco,
    required this.aiSco,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.40), width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Player score
              _ScorePill(label: '🧒 YOU', score: playerSco, color: const Color(0xFF1565C0)),
              // Level name
              Column(
                children: [
                  Text(
                    'Level ${levelIdx + 1}/$totalLevels',
                    style: const TextStyle(color: Color(0xFFFFD700), fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    levelName,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              // AI score
              _ScorePill(label: '🤖 CPU', score: aiSco, color: const Color(0xFFC62828)),
            ],
          ),
          const SizedBox(height: 8),
          // Question progress dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(totalQ, (i) {
              final done = i < qIdx;
              final active = i == qIdx;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width:  active ? 20 : 10,
                height: 10,
                decoration: BoxDecoration(
                  color: done
                      ? const Color(0xFF4CAF50)
                      : active
                          ? const Color(0xFFFFD700)
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

class _ScorePill extends StatelessWidget {
  final String label;
  final int score;
  final Color color;
  const _ScorePill({required this.label, required this.score, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600)),
          Text('$score', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Arena scene: two champions with jump animations
// ─────────────────────────────────────────────────────────────────────────────

class _ArenaScene extends StatelessWidget {
  final double playerJumpY;
  final double aiJumpY;
  final _Phase phase;
  final bool aiAnswered;

  const _ArenaScene({
    required this.playerJumpY,
    required this.aiJumpY,
    required this.phase,
    required this.aiAnswered,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _Champion(
            emoji: '🧒',
            name: 'YOU',
            color: const Color(0xFF1565C0),
            jumpY: playerJumpY,
            showStar: phase == _Phase.correct || phase == _Phase.streak,
            showX:    phase == _Phase.wrong,
          ),
          // VS badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: const Color(0xFFFFD700).withValues(alpha: 0.5), blurRadius: 12)],
            ),
            child: const Text('VS',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20,
                    shadows: [Shadow(blurRadius: 4, color: Colors.black45)])),
          ),
          _Champion(
            emoji: '🤖',
            name: 'CPU',
            color: const Color(0xFFC62828),
            jumpY: aiJumpY,
            showStar: aiAnswered,
            showX:    false,
          ),
        ],
      ),
    );
  }
}

class _Champion extends StatelessWidget {
  final String emoji, name;
  final Color color;
  final double jumpY;
  final bool showStar, showX;

  const _Champion({
    required this.emoji,
    required this.name,
    required this.color,
    required this.jumpY,
    this.showStar = false,
    this.showX    = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.topRight,
          children: [
            Transform.translate(
              offset: Offset(0, jumpY),
              child: Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.85),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFFD700), width: 2.5),
                  boxShadow: [BoxShadow(color: color.withValues(alpha: 0.50), blurRadius: 16)],
                ),
                child: Center(child: Text(emoji, style: const TextStyle(fontSize: 30))),
              ),
            ),
            if (showStar)
              Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(color: Color(0xFF4CAF50), shape: BoxShape.circle),
                child: const Text('⭐', style: TextStyle(fontSize: 13)),
              ),
            if (showX)
              Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(color: Color(0xFFC62828), shape: BoxShape.circle),
                child: const Text('✗', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w900)),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(name,
            style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                shadows: [Shadow(color: color, blurRadius: 8)])),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Question area: prompt + objects (for count) + crystal choice buttons
// ─────────────────────────────────────────────────────────────────────────────

class _QuestionArea extends StatelessWidget {
  final _Q q;
  final _Phase phase;
  final int? picked;
  final double floatVal;
  final void Function(int) onAnswer;

  const _QuestionArea({
    required this.q,
    required this.phase,
    required this.picked,
    required this.floatVal,
    required this.onAnswer,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Prompt
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.50),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.50), width: 1.5),
            ),
            child: Text(
              q.prompt,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                shadows: [Shadow(blurRadius: 8, color: Colors.black54)],
              ),
            ),
          ),

          // Object display (count type) or number crystals (compare/extreme shown inline)
          if (q.type == 'count') ...[
            Transform.translate(
              offset: Offset(0, floatVal * 0.6),
              child: _ObjectGrid(emoji: q.objEmoji, count: q.objCount),
            ),
          ],

          // Answer choices
          if (q.type == 'count')
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: q.choices.map((c) => _CrystalBtn(
                value: c,
                phase: phase,
                picked: picked,
                correct: q.correct,
                onTap: () => onAnswer(c),
              )).toList(),
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: q.choices.map((c) => _CrystalBtn(
                value: c,
                phase: phase,
                picked: picked,
                correct: q.correct,
                onTap: () => onAnswer(c),
                large: true,
              )).toList(),
            ),
        ],
      ),
    );
  }
}

class _ObjectGrid extends StatelessWidget {
  final String emoji;
  final int count;

  const _ObjectGrid({required this.emoji, required this.count});

  @override
  Widget build(BuildContext context) {
    const itemSize = 28.0;
    const maxPerRow = 10;
    final rows = (count / maxPerRow).ceil();

    return Container(
      constraints: const BoxConstraints(maxHeight: 100),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(rows, (r) {
          final start = r * maxPerRow;
          final end   = math.min(start + maxPerRow, count);
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(end - start, (_) => Padding(
              padding: const EdgeInsets.all(1),
              child: Text(emoji, style: const TextStyle(fontSize: itemSize)),
            )),
          );
        }),
      ),
    );
  }
}

class _CrystalBtn extends StatelessWidget {
  final int value, correct;
  final _Phase phase;
  final int? picked;
  final VoidCallback onTap;
  final bool large;

  const _CrystalBtn({
    required this.value,
    required this.correct,
    required this.phase,
    required this.picked,
    required this.onTap,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    final isAnswered = phase == _Phase.correct || phase == _Phase.wrong ||
                       phase == _Phase.streak  || phase == _Phase.levelDone;
    final isPickedThis   = picked == value;
    final isCorrectThis  = value  == correct;

    Color bg1 = const Color(0xFF5C35F5);
    Color bg2 = const Color(0xFF9C27B0);
    Color border = Colors.white.withValues(alpha: 0.30);
    Color textC  = Colors.white;

    if (isAnswered) {
      if (isCorrectThis) {
        bg1 = const Color(0xFF2E7D32);
        bg2 = const Color(0xFF43A047);
        border = const Color(0xFF80FF80);
      } else if (isPickedThis) {
        bg1 = const Color(0xFFC62828);
        bg2 = const Color(0xFFE53935);
        border = const Color(0xFFFF8080);
      } else {
        bg1 = Colors.grey.shade800;
        bg2 = Colors.grey.shade700;
        textC = Colors.white54;
      }
    }

    final size = large ? 80.0 : 72.0;

    return GestureDetector(
      onTap: isAnswered ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [bg1, bg2], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border, width: 2),
          boxShadow: [
            BoxShadow(
              color: isCorrectThis && isAnswered
                  ? const Color(0xFF4CAF50).withValues(alpha: 0.60)
                  : bg1.withValues(alpha: 0.45),
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
              fontSize: large ? 26 : 24,
              fontWeight: FontWeight.w900,
              shadows: const [Shadow(blurRadius: 6, color: Colors.black54)],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Feedback banner
// ─────────────────────────────────────────────────────────────────────────────

class _FeedbackBanner extends StatelessWidget {
  final _Phase phase;
  final int streak;
  const _FeedbackBanner({required this.phase, required this.streak});

  @override
  Widget build(BuildContext context) {
    final (text, bg) = switch (phase) {
      _Phase.correct  => ('✅  Amazing! Keep going!', const Color(0xFF2E7D32)),
      _Phase.wrong    => ('❌  Oops! Try next one!', const Color(0xFFC62828)),
      _Phase.streak   => ('🔥 ${streak}x STREAK! Incredible! 🎆', const Color(0xFFE65100)),
      _Phase.levelDone=> ('🎉  Level Complete!',     const Color(0xFF4A148C)),
      _             => (null, Colors.transparent),
    };
    if (text == null) return const SizedBox(height: 40);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Center(
        child: Text(text,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Level done temporary overlay
// ─────────────────────────────────────────────────────────────────────────────

class _LevelDone extends StatelessWidget {
  final int level;
  const _LevelDone({required this.level});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.65),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('⭐ ⭐ ⭐', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 12),
              Text('Level $level Complete!',
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              const Text('Get ready for the next level!',
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
      backgroundColor: Color(0xFF1A0050),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🏟️', style: TextStyle(fontSize: 72)),
            SizedBox(height: 16),
            Text('Number Counting Duel',
                style: TextStyle(color: Color(0xFFFFD700), fontSize: 24, fontWeight: FontWeight.w900)),
            SizedBox(height: 8),
            Text('Get ready to count!',
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
  final int playerScore, aiScore, totalXP;
  final VoidCallback onReplay, onExit;

  const _VictoryScreen({
    required this.playerScore,
    required this.aiScore,
    required this.totalXP,
    required this.onReplay,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    final won   = playerScore >= aiScore;
    final stars = playerScore >= 20 ? 3 : playerScore >= 12 ? 2 : 1;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1A0050), Color(0xFF6A1B9A), Color(0xFFAD1457)],
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
                  Text(won ? '🏆 You Won!' : '💪 Good Try!',
                      style: const TextStyle(
                          color: Color(0xFFFFD700), fontSize: 36, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 12),
                  // Stars
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (i) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(i < stars ? '⭐' : '☆',
                          style: const TextStyle(fontSize: 44)),
                    )),
                  ),
                  const SizedBox(height: 20),
                  // Scores
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.40),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.40)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _ScorePill(label: '🧒 YOU', score: playerScore, color: const Color(0xFF1565C0)),
                        Column(
                          children: [
                            const Text('⭐ XP', style: TextStyle(color: Colors.white70, fontSize: 12)),
                            Text('+$totalXP',
                                style: const TextStyle(color: Color(0xFFFFD700), fontSize: 26, fontWeight: FontWeight.w900)),
                          ],
                        ),
                        _ScorePill(label: '🤖 CPU', score: aiScore, color: const Color(0xFFC62828)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _VBtn(label: '🔄 Play Again', onTap: onReplay, primary: true),
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
  const _VBtn({required this.label, required this.onTap, required this.primary});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          gradient: primary
              ? const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFF8C00)])
              : null,
          color: primary ? null : Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: primary ? const Color(0xFFFFD700) : Colors.white38,
            width: 1.5,
          ),
        ),
        child: Text(label,
            style: TextStyle(
                color: primary ? const Color(0xFF1A0050) : Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Fireworks particle painter (streak celebration)
// ─────────────────────────────────────────────────────────────────────────────

class _FireworksPainter extends CustomPainter {
  final double t;
  _FireworksPainter(this.t);

  static final _rng = math.Random(77);
  static final _bursts = List.generate(6, (i) => (
    x:    _rng.nextDouble(),
    y:    0.1 + _rng.nextDouble() * 0.5,
    col:  Color.fromARGB(255, _rng.nextInt(200) + 55, _rng.nextInt(200) + 55, _rng.nextInt(200) + 55),
    spd:  0.06 + _rng.nextDouble() * 0.08,
    rays: 8 + _rng.nextInt(6),
    delay: _rng.nextDouble() * 0.3,
  ));

  @override
  void paint(Canvas canvas, Size size) {
    for (final b in _bursts) {
      final tt = ((t - b.delay) / (1 - b.delay)).clamp(0.0, 1.0);
      if (tt <= 0) continue;
      final alpha = (1 - tt * tt).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = b.col.withValues(alpha: alpha)
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      final cx = b.x * size.width;
      final cy = b.y * size.height;
      final maxR = size.width * b.spd;
      for (int r = 0; r < b.rays; r++) {
        final angle = r * 2 * math.pi / b.rays;
        final dist  = tt * maxR;
        canvas.drawLine(
          Offset(cx + math.cos(angle) * dist * 0.2, cy + math.sin(angle) * dist * 0.2),
          Offset(cx + math.cos(angle) * dist,        cy + math.sin(angle) * dist),
          paint,
        );
        // Sparkle dot at tip
        canvas.drawCircle(
          Offset(cx + math.cos(angle) * dist, cy + math.sin(angle) * dist),
          3.0 * (1 - tt),
          Paint()..color = Colors.white.withValues(alpha: alpha * 0.8),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FireworksPainter old) => old.t != t;
}
