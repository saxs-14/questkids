import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/game_session_model.dart';
import '../core/game_config.dart';
import '../core/game_session_persistence.dart';

// ────────────────────────────────────────────────────────────────────────────
// Grammar Garden — Grade 1 blooming-garden error-spotting quest
//
// 4 Zones (garden beds, each growing a different grammar skill):
//   1. Capital Letter Corner — spot the missing capital letter
//   2. Full Stop Field       — spot the missing/wrong end punctuation
//   3. Plural Patch          — spot the missing plural "-s"
//   4. Verb Valley           — spot the wrong subject-verb agreement
// 5 sentences per zone = 20 total.
//
// CAPS Grade 1 English Home Language covers basic sentence conventions:
// starting with a capital letter, ending with a full stop, simple plural
// forms, and simple subject-verb agreement -- letter knowledge, spelling,
// phonics, and sequencing are each owned by the other four English
// engines, so nothing overlaps.
//
// Structurally distinct from every other Grade 1 engine so far: each
// sentence is shown as a row of word "plant marker" tiles, exactly one
// of which is wrong. The learner taps the ONE tile they think is the
// mistake -- an error-spotting tap among a variable-length row (4-5
// tiles), not a fixed 3-choice pick, a binary sort, a sequential build,
// or an ordering puzzle. Once answered, the actual mistake always
// reveals its correction regardless of whether the learner guessed
// right, so every round teaches the fix. A wrong guess never loses
// progress, just a gentle note and the correction shown before moving
// on. Architecture: fully self-contained StatefulWidget, no external
// engine (same pattern as the other Grade 1 games).
// ────────────────────────────────────────────────────────────────────────────

enum _Phase { intro, question, correct, wrong, streak, zoneDone, victory }

// ── Sentence + zone models ───────────────────────────────────────────────────

class _SentenceQ {
  final List<String> correctTiles; // the fully correct sentence, tile by tile
  final int errorIndex; // which tile is wrong in the displayed version
  final String brokenText; // the incorrect text shown at errorIndex
  const _SentenceQ({
    required this.correctTiles,
    required this.errorIndex,
    required this.brokenText,
  });
}

class _Zone {
  final String name;
  final List<_SentenceQ> sentences; // 5
  const _Zone(this.name, this.sentences);
}

// ── Main game widget ───────────────────────────────────────────────────────

class GrammarGardenGame extends StatefulWidget {
  final GameConfig config;
  final dynamic user;
  const GrammarGardenGame({super.key, required this.config, this.user});

  @override
  State<GrammarGardenGame> createState() => _GGState();
}

class _GGState extends State<GrammarGardenGame> with TickerProviderStateMixin {
  static const _zones = [
    _Zone('Capital Letter Corner', [
      _SentenceQ(correctTiles: ['The', 'sun', 'is', 'hot', '.'], errorIndex: 0, brokenText: 'the'),
      _SentenceQ(correctTiles: ['I', 'like', 'cats', '.'], errorIndex: 0, brokenText: 'i'),
      _SentenceQ(correctTiles: ['She', 'has', 'a', 'hat', '.'], errorIndex: 0, brokenText: 'she'),
      _SentenceQ(correctTiles: ['We', 'play', 'outside', '.'], errorIndex: 0, brokenText: 'we'),
      _SentenceQ(correctTiles: ['He', 'can', 'run', '.'], errorIndex: 0, brokenText: 'he'),
    ]),
    _Zone('Full Stop Field', [
      _SentenceQ(correctTiles: ['The', 'dog', 'barks', '.'], errorIndex: 3, brokenText: ','),
      _SentenceQ(correctTiles: ['I', 'see', 'a', 'bird', '.'], errorIndex: 4, brokenText: ','),
      _SentenceQ(correctTiles: ['We', 'went', 'home', '.'], errorIndex: 3, brokenText: ','),
      _SentenceQ(correctTiles: ['The', 'sky', 'is', 'blue', '.'], errorIndex: 4, brokenText: ','),
      _SentenceQ(correctTiles: ['She', 'can', 'sing', '.'], errorIndex: 3, brokenText: ','),
    ]),
    _Zone('Plural Patch', [
      _SentenceQ(correctTiles: ['I', 'have', 'two', 'dogs', '.'], errorIndex: 3, brokenText: 'dog'),
      _SentenceQ(correctTiles: ['We', 'see', 'three', 'cats', '.'], errorIndex: 3, brokenText: 'cat'),
      _SentenceQ(correctTiles: ['She', 'has', 'five', 'toys', '.'], errorIndex: 3, brokenText: 'toy'),
      _SentenceQ(correctTiles: ['They', 'ate', 'four', 'apples', '.'], errorIndex: 3, brokenText: 'apple'),
      _SentenceQ(correctTiles: ['He', 'found', 'two', 'boxes', '.'], errorIndex: 3, brokenText: 'box'),
    ]),
    _Zone('Verb Valley', [
      _SentenceQ(correctTiles: ['The', 'dog', 'runs', '.'], errorIndex: 2, brokenText: 'run'),
      _SentenceQ(correctTiles: ['The', 'cat', 'sleeps', '.'], errorIndex: 2, brokenText: 'sleep'),
      _SentenceQ(correctTiles: ['The', 'bird', 'flies', '.'], errorIndex: 2, brokenText: 'fly'),
      _SentenceQ(correctTiles: ['The', 'boy', 'jumps', '.'], errorIndex: 2, brokenText: 'jump'),
      _SentenceQ(correctTiles: ['The', 'girl', 'sings', '.'], errorIndex: 2, brokenText: 'sing'),
    ]),
  ];

  static const _wrongReactions = [
    'Not that one — look again!',
    'Close! Try spotting a different word.',
    'Almost — check the other words!',
  ];

  // ── Animations ──────────────────────────────────────────────────────────
  late AnimationController _glowCtrl; // ambient bloom shimmer, looping
  late AnimationController _bloomCtrl; // tile bloom on correct
  late AnimationController _wiltCtrl; // tile wilt-shake on wrong guess
  late AnimationController _petalCtrl; // petal-shower streak celebration
  late AnimationController _fadeCtrl; // sentence fade-in

  late Animation<double> _glowAnim;
  late Animation<double> _bloomAnim;
  late Animation<double> _wiltAnim;
  late Animation<double> _petalAnim;
  late Animation<double> _fadeAnim;

  // ── Game state ──────────────────────────────────────────────────────────
  int _zoneIdx = 0;
  int _qIdx = 0;
  int _correctCount = 0;
  int _streak = 0;
  int _totalXP = 0;

  _Phase _phase = _Phase.intro;
  _SentenceQ? _current;
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

    _bloomCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _bloomAnim = CurvedAnimation(parent: _bloomCtrl, curve: Curves.elasticOut);

    _wiltCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _wiltAnim = CurvedAnimation(parent: _wiltCtrl, curve: Curves.easeInOut);

    _petalCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600));
    _petalAnim = CurvedAnimation(parent: _petalCtrl, curve: Curves.easeOut);

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
    _bloomCtrl.dispose();
    _wiltCtrl.dispose();
    _petalCtrl.dispose();
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
    _nextSentence();
  }

  void _nextSentence() {
    final sentence = _zones[_zoneIdx].sentences[_qIdx];
    _fadeCtrl.reset();
    setState(() {
      _current = sentence;
      _picked = null;
      _phase = _Phase.question;
    });
    _fadeCtrl.forward();
  }

  void _onTapTile(int index) {
    if (_phase != _Phase.question) return;
    final sentence = _current!;
    setState(() => _picked = index);
    final correct = index == sentence.errorIndex;

    if (correct) {
      setState(() {
        _correctCount++;
        _streak++;
        _totalXP += 10;
      });
      _bloomCtrl.forward(from: 0);
      final isStreak = _streak > 0 && _streak % 3 == 0;
      if (isStreak) {
        setState(() => _phase = _Phase.streak);
        _petalCtrl.forward(from: 0);
        _delayed(1800, _advance);
      } else {
        setState(() => _phase = _Phase.correct);
        _delayed(1400, _advance);
      }
    } else {
      setState(() {
        _streak = 0;
        _phase = _Phase.wrong;
        _wrongReaction =
            _wrongReactions[_rng.nextInt(_wrongReactions.length)];
      });
      _wiltCtrl.forward(from: 0);
      _delayed(1800, _advance);
    }
  }

  void _advance() {
    if (!mounted) return;
    final zone = _zones[_zoneIdx];
    final next = _qIdx + 1;

    if (next >= zone.sentences.length) {
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
          _nextSentence();
        });
      }
    } else {
      setState(() => _qIdx = next);
      _delayed(300, _nextSentence);
    }
  }

  void _persistSession() {
    final totalQuestions =
        _zones.fold<int>(0, (sum, z) => sum + z.sentences.length); // 20
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
    final sentence = _current;
    final totalQuestions =
        _zones.fold<int>(0, (sum, z) => sum + z.sentences.length);
    final revealed = _phase != _Phase.question;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _glowAnim,
              builder: (_, __) =>
                  CustomPaint(painter: _GardenBg(glow: _glowAnim.value)),
            ),
          ),

          if (_phase == _Phase.streak)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _petalAnim,
                builder: (_, __) =>
                    CustomPaint(painter: _PetalShowerPainter(_petalAnim.value)),
              ),
            ),

          SafeArea(
            child: Column(
              children: [
                _GardenHeader(
                  zoneName: zone.name,
                  zoneIdx: _zoneIdx,
                  totalZones: _zones.length,
                  qIdx: _qIdx,
                  totalQ: zone.sentences.length,
                  correctCount: _correctCount,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  child: _FlowerRow(
                      correctCount: _correctCount, totalQuestions: totalQuestions),
                ),
                Expanded(
                  child: sentence == null
                      ? const SizedBox()
                      : FadeTransition(
                          opacity: _fadeAnim,
                          child: _SentenceArea(
                            sentence: sentence,
                            picked: _picked,
                            revealed: revealed,
                            bloomAnim: _bloomAnim,
                            wiltAnim: _wiltAnim,
                            onTapTile: _onTapTile,
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
// Garden background CustomPainter — rose-pink-to-green blossoming garden
// palette, distinct from every other Grade 1 palette used so far.
// ─────────────────────────────────────────────────────────────────────────────

class _GardenBg extends CustomPainter {
  final double glow;
  _GardenBg({required this.glow});

  static final _rng = math.Random(51);
  static final _blooms = List.generate(
      8,
      (i) => (
            x: _rng.nextDouble(),
            y: _rng.nextDouble() * 0.16,
            size: 3.0 + _rng.nextDouble() * 3,
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
            Color(0xFFFCE4EC),
            Color(0xFFF8BBD0),
            Color(0xFFC8E6C9),
            Color(0xFF81C784),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // Small blossom dots confined to the top strip only.
    for (final b in _blooms) {
      canvas.drawCircle(
        Offset(b.x * w, b.y * h),
        b.size * (0.7 + glow * 0.3),
        Paint()..color = const Color(0xFFE91E63).withValues(alpha: 0.5 * glow),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GardenBg old) => old.glow != glow;
}

// ─────────────────────────────────────────────────────────────────────────────
// Flower-row progress indicator — flowers bloom one by one as sentences
// are fixed correctly, distinct from every other progress style used in
// the Grade 1 games so far.
// ─────────────────────────────────────────────────────────────────────────────

class _FlowerRow extends StatelessWidget {
  final int correctCount;
  final int totalQuestions;

  const _FlowerRow({required this.correctCount, required this.totalQuestions});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 4,
        runSpacing: 4,
        children: List.generate(totalQuestions, (i) {
          final bloomed = i < correctCount;
          return AnimatedScale(
            duration: const Duration(milliseconds: 300),
            scale: bloomed ? 1.0 : 0.6,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: bloomed ? 1.0 : 0.3,
              child: Text(bloomed ? '🌸' : '🌱', style: const TextStyle(fontSize: 16)),
            ),
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header: zone name + sentence progress + fixed count
// ─────────────────────────────────────────────────────────────────────────────

class _GardenHeader extends StatelessWidget {
  final String zoneName;
  final int zoneIdx, totalZones, qIdx, totalQ, correctCount;

  const _GardenHeader({
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
        color: Colors.white.withValues(alpha: 0.40),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.75), width: 1.5),
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
                  color: const Color(0xFFE91E63),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('🌸 $correctCount',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900)),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'Zone ${zoneIdx + 1}/$totalZones',
                      style: const TextStyle(
                          color: Color(0xFF2E7D32),
                          fontSize: 11,
                          fontWeight: FontWeight.w700),
                    ),
                    Text(
                      zoneName,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Color(0xFF4E342E),
                          fontSize: 13,
                          fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
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
                      ? const Color(0xFFE91E63)
                      : active
                          ? const Color(0xFFF8BBD0)
                          : Colors.white.withValues(alpha: 0.5),
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
// Sentence area: a row of tappable "plant marker" word tiles, exactly one
// of which is wrong.
// ─────────────────────────────────────────────────────────────────────────────

class _SentenceArea extends StatelessWidget {
  final _SentenceQ sentence;
  final int? picked;
  final bool revealed;
  final Animation<double> bloomAnim;
  final Animation<double> wiltAnim;
  final void Function(int) onTapTile;

  const _SentenceArea({
    required this.sentence,
    required this.picked,
    required this.revealed,
    required this.bloomAnim,
    required this.wiltAnim,
    required this.onTapTile,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Tap the word that looks wrong!',
              style: TextStyle(
                  color: Color(0xFF4E342E),
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 24),
          AnimatedBuilder(
            animation: Listenable.merge([bloomAnim, wiltAnim]),
            builder: (_, __) => Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: List.generate(sentence.correctTiles.length, (i) {
                final isErrorTile = i == sentence.errorIndex;
                final isPickedTile = picked == i;
                final displayText = (isErrorTile && !revealed)
                    ? sentence.brokenText
                    : sentence.correctTiles[i];

                double bounce = 0;
                double wobble = 0;
                if (revealed && isErrorTile && isPickedTile) {
                  bounce = -bloomAnim.value * 8;
                } else if (revealed && isPickedTile && !isErrorTile) {
                  wobble = math.sin(wiltAnim.value * math.pi * 4) * 6;
                }

                Color bg = const Color(0xFF8D6E63);
                Color border = const Color(0xFF4E342E);
                if (revealed) {
                  if (isErrorTile) {
                    bg = const Color(0xFF66BB6A);
                    border = const Color(0xFF2E7D32);
                  } else if (isPickedTile) {
                    bg = const Color(0xFFFFB74D);
                    border = const Color(0xFFE65100);
                  }
                }

                return Transform.translate(
                  offset: Offset(wobble, bounce),
                  child: _WordTile(
                    text: displayText,
                    bg: bg,
                    border: border,
                    onTap: revealed ? null : () => onTapTile(i),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _WordTile extends StatelessWidget {
  final String text;
  final Color bg;
  final Color border;
  final VoidCallback? onTap;

  const _WordTile(
      {required this.text, required this.bg, required this.border, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipPath(
        clipper: _PlantMarkerClipper(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          constraints: const BoxConstraints(minWidth: 58),
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [bg, border],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Align(
            alignment: const Alignment(0, -0.3),
            widthFactor: 1.0,
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A rounded-top, single-point-bottom "plant marker stake" silhouette --
/// the ninth distinct interactive shape across the Grade 1 games, fitting
/// the garden theme.
class _PlantMarkerClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final stemH = h * 0.22;
    final path = Path()
      ..moveTo(0, h * 0.15)
      ..quadraticBezierTo(0, 0, w * 0.15, 0)
      ..lineTo(w * 0.85, 0)
      ..quadraticBezierTo(w, 0, w, h * 0.15)
      ..lineTo(w, h - stemH)
      ..lineTo(w / 2, h)
      ..lineTo(0, h - stemH)
      ..close();
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
      _Phase.correct => ('🌸 You spotted it! Great eye!', const Color(0xFF2E7D32)),
      _Phase.wrong => (wrongReaction, const Color(0xFFAD1457)),
      _Phase.streak => (
          '✨ ${streak}x GARDEN STREAK! ✨',
          const Color(0xFFE91E63)
        ),
      _Phase.zoneDone => ('🌷  Garden Bed Cleared!', const Color(0xFF2E7D32)),
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
        color: Colors.black.withValues(alpha: 0.50),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🌷 🌸 🌷', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 12),
              Text('Garden Bed $zoneNum Cleared!',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              const Text('On to the next flower bed!',
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
      backgroundColor: Color(0xFFFCE4EC),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🌷', style: TextStyle(fontSize: 72)),
            SizedBox(height: 16),
            Text('Grammar Garden',
                style: TextStyle(
                    color: Color(0xFFE91E63),
                    fontSize: 24,
                    fontWeight: FontWeight.w900)),
            SizedBox(height: 8),
            Text('Spot the word that needs fixing!',
                style: TextStyle(color: Color(0xFF4E342E), fontSize: 16)),
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
            colors: [Color(0xFFFCE4EC), Color(0xFFC8E6C9), Color(0xFF81C784)],
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
                  const Text('🏆 Garden in Full Bloom!',
                      style: TextStyle(
                          color: Color(0xFF2E7D32),
                          fontSize: 26,
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
                      color: Colors.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: const Color(0xFFE91E63).withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Column(
                          children: [
                            const Text('🌸 Fixed',
                                style: TextStyle(
                                    color: Color(0xFF4E342E), fontSize: 12)),
                            Text('$correctCount',
                                style: const TextStyle(
                                    color: Color(0xFFE91E63),
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900)),
                          ],
                        ),
                        Column(
                          children: [
                            const Text('⭐ XP',
                                style: TextStyle(
                                    color: Color(0xFF4E342E), fontSize: 12)),
                            Text('+$totalXP',
                                style: const TextStyle(
                                    color: Color(0xFF2E7D32),
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
                          label: '🔄 Plant Again',
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
                  colors: [Color(0xFFE91E63), Color(0xFFAD1457)])
              : null,
          color: primary ? null : Colors.white.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: primary ? const Color(0xFFAD1457) : Colors.white70,
            width: 1.5,
          ),
        ),
        child: Text(label,
            style: TextStyle(
                color: primary ? Colors.white : const Color(0xFF4E342E),
                fontWeight: FontWeight.w800,
                fontSize: 15)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Petal shower painter (streak celebration) — flower petals drifting down
// with a gentle sway, distinct from every other streak effect used in
// the Grade 1 games so far.
// ─────────────────────────────────────────────────────────────────────────────

class _PetalShowerPainter extends CustomPainter {
  final double t;
  _PetalShowerPainter(this.t);

  static final _rng = math.Random(63);
  static final _petals = List.generate(
      10,
      (i) => (
            x: _rng.nextDouble(),
            phase: _rng.nextDouble(),
            emoji: ['🌸', '🌺', '🌼'][i % 3],
          ));

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in _petals) {
      final progress = (t + p.phase) % 1.0;
      final dy = progress * size.height;
      final dx = p.x * size.width + math.sin(progress * math.pi * 3) * 18;
      final tp = TextPainter(
        text: TextSpan(text: p.emoji, style: const TextStyle(fontSize: 20)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(dx, dy));
    }
  }

  @override
  bool shouldRepaint(covariant _PetalShowerPainter old) => old.t != t;
}
