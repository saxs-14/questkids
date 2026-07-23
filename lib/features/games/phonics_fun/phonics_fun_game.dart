import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/game_session_model.dart';
import '../core/game_config.dart';
import '../core/game_session_persistence.dart';

// ────────────────────────────────────────────────────────────────────────────
// Phonics Fun — Grade 1 sunny-meadow sound-sorting quest
//
// 4 Zones (bright daytime meadow, deepening into the woods):
//   1. Sunny Meadow — sort by initial sound: S vs M
//   2. Rhyme Pond    — sort by rhyme family: -AT vs -OG
//   3. Echo Cave     — sort by short vowel sound: short A vs short I
//   4. Treetop       — sort by initial sound: B vs C
// 5 cards per zone = 20 total.
//
// CAPS Grade 1 English Home Language phonics covers initial/final sound
// identification, rhyme recognition, and short-vowel discrimination --
// letter RECOGNITION is left to Alphabet Explorer and word SPELLING to
// Word Builder, so none of the three English games overlap in content.
//
// Structurally distinct from every other Grade 1 engine so far: instead
// of choosing among several small answer tiles, the learner sorts one
// picture-and-word card at a time into one of two large basket-shaped
// "nests" -- a binary categorisation tap, not a multiple-choice pick or
// a sequential build. An optional speaker button lets the learner hear
// the word read aloud via text-to-speech (best-effort: if TTS is
// unavailable on a platform, the game remains fully playable visually --
// this is the first Grade 1 engine to use audio, and it is deliberately
// never required to progress). A wrong sort never loses progress, just a
// gentle shake and friendly correction before moving to the next card.
// Architecture: fully self-contained StatefulWidget, no external engine
// (same pattern as the other Grade 1 games).
// ────────────────────────────────────────────────────────────────────────────

enum _Phase { intro, question, correct, wrong, streak, zoneDone, victory }

// ── Card + zone models ───────────────────────────────────────────────────────

class _CardQ {
  final String word;
  final String emoji;
  final bool isNestA;
  const _CardQ(this.word, this.emoji, this.isNestA);
}

class _Zone {
  final String name;
  final String nestALabel;
  final String nestAEmoji;
  final String nestBLabel;
  final String nestBEmoji;
  final List<_CardQ> cards;
  const _Zone(this.name, this.nestALabel, this.nestAEmoji, this.nestBLabel,
      this.nestBEmoji, this.cards);
}

// ── Main game widget ───────────────────────────────────────────────────────

class PhonicsFunGame extends StatefulWidget {
  final GameConfig config;
  final dynamic user;
  const PhonicsFunGame({super.key, required this.config, this.user});

  @override
  State<PhonicsFunGame> createState() => _PFState();
}

class _PFState extends State<PhonicsFunGame> with TickerProviderStateMixin {
  static const _zones = [
    _Zone('Sunny Meadow', 'Starts like Sun', '☀️', 'Starts like Moon', '🌙', [
      _CardQ('sock', '🧦', true),
      _CardQ('star', '⭐', true),
      _CardQ('seed', '🌱', true),
      _CardQ('mouse', '🐭', false),
      _CardQ('map', '🗺️', false),
    ]),
    _Zone('Rhyme Pond', 'Rhymes with Cat', '🐱', 'Rhymes with Dog', '🐶', [
      _CardQ('hat', '🎩', true),
      _CardQ('bat', '🦇', true),
      _CardQ('rat', '🐀', true),
      _CardQ('frog', '🐸', false),
      _CardQ('log', '🪵', false),
    ]),
    _Zone('Echo Cave', 'Short A like Cap', '🧢', 'Short I like Pig', '🐷', [
      _CardQ('cap', '🧢', true),
      _CardQ('bag', '👜', true),
      _CardQ('ant', '🐜', true),
      _CardQ('fish', '🐟', false),
      _CardQ('pig', '🐷', false),
    ]),
    _Zone('Treetop', 'Starts like Ball', '⚽', 'Starts like Cup', '🥤', [
      _CardQ('bed', '🛏️', true),
      _CardQ('box', '📦', true),
      _CardQ('bus', '🚌', true),
      _CardQ('cat', '🐱', false),
      _CardQ('cup', '🥤', false),
    ]),
  ];

  static const _wrongReactions = [
    'Oops, listen again! Try the other nest.',
    'Not quite — try the other nest!',
    'Almost — give it another listen!',
  ];

  // ── Animations ──────────────────────────────────────────────────────────
  late AnimationController _glowCtrl; // ambient cloud drift, looping
  late AnimationController _flyCtrl; // card flies into nest on correct
  late AnimationController _shakeCtrl; // card shake on wrong
  late AnimationController _birdCtrl; // flying-birds streak celebration
  late AnimationController _fadeCtrl; // card fade-in

  late Animation<double> _glowAnim;
  late Animation<double> _flyAnim;
  late Animation<double> _shakeAnim;
  late Animation<double> _birdAnim;
  late Animation<double> _fadeAnim;

  // ── Game state ──────────────────────────────────────────────────────────
  int _zoneIdx = 0;
  int _qIdx = 0;
  int _correctCount = 0;
  int _streak = 0;
  int _totalXP = 0;

  _Phase _phase = _Phase.intro;
  _CardQ? _current;
  bool? _picked; // true = nest A tapped, false = nest B tapped
  String _wrongReaction = '';

  final _rng = math.Random();
  FlutterTts? _tts;

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

  // Best-effort word pronunciation. Speaking is entirely optional flavour
  // triggered only by an explicit tap on the speaker button -- if the TTS
  // plugin is unavailable on a platform (or in a test environment with no
  // registered platform channel), this fails silently and the game stays
  // fully playable without audio.
  Future<void> _speak(String text) async {
    try {
      _tts ??= FlutterTts();
      await _tts!.setLanguage('en-US');
      await _tts!.setPitch(1.05);
      await _tts!.speak(text);
    } catch (_) {
      // TTS unavailable -- ignore, audio is a bonus, not a requirement.
    }
  }

  @override
  void initState() {
    super.initState();
    _initAnims();
    _delayed(800, _startGame);
  }

  void _initAnims() {
    _glowCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.5, end: 1.0)
        .animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));

    _flyCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _flyAnim = CurvedAnimation(parent: _flyCtrl, curve: Curves.easeIn);

    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _shakeAnim = CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut);

    _birdCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600));
    _birdAnim = CurvedAnimation(parent: _birdCtrl, curve: Curves.easeOut);

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
    try {
      _tts?.stop();
    } catch (_) {
      // best-effort cleanup only
    }
    _glowCtrl.dispose();
    _flyCtrl.dispose();
    _shakeCtrl.dispose();
    _birdCtrl.dispose();
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
    _nextCard();
  }

  void _nextCard() {
    final card = _zones[_zoneIdx].cards[_qIdx];
    _fadeCtrl.reset();
    setState(() {
      _current = card;
      _picked = null;
      _phase = _Phase.question;
    });
    _fadeCtrl.forward();
  }

  void _onTapNest(bool tappedA) {
    if (_phase != _Phase.question) return;
    final card = _current!;
    setState(() => _picked = tappedA);
    final correct = tappedA == card.isNestA;

    if (correct) {
      setState(() {
        _correctCount++;
        _streak++;
        _totalXP += 10;
      });
      _flyCtrl.forward(from: 0);
      final isStreak = _streak > 0 && _streak % 3 == 0;
      if (isStreak) {
        setState(() => _phase = _Phase.streak);
        _birdCtrl.forward(from: 0);
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
      _shakeCtrl.forward(from: 0);
      _delayed(1300, _advance);
    }
  }

  void _advance() {
    if (!mounted) return;
    final zone = _zones[_zoneIdx];
    final next = _qIdx + 1;

    if (next >= zone.cards.length) {
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
          _nextCard();
        });
      }
    } else {
      setState(() => _qIdx = next);
      _delayed(300, _nextCard);
    }
  }

  void _persistSession() {
    final totalQuestions =
        _zones.fold<int>(0, (sum, z) => sum + z.cards.length); // 20
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
    final card = _current;
    final totalQuestions = _zones.fold<int>(0, (sum, z) => sum + z.cards.length);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _glowAnim,
              builder: (_, __) =>
                  CustomPaint(painter: _MeadowBg(drift: _glowAnim.value)),
            ),
          ),

          if (_phase == _Phase.streak)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _birdAnim,
                builder: (_, __) =>
                    CustomPaint(painter: _FlyingBirdsPainter(_birdAnim.value)),
              ),
            ),

          SafeArea(
            child: Column(
              children: [
                _MeadowHeader(
                  zoneName: zone.name,
                  zoneIdx: _zoneIdx,
                  totalZones: _zones.length,
                  qIdx: _qIdx,
                  totalQ: zone.cards.length,
                  correctCount: _correctCount,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  child: _BirdFlock(
                      correctCount: _correctCount, totalQuestions: totalQuestions),
                ),
                Expanded(
                  child: card == null
                      ? const SizedBox()
                      : FadeTransition(
                          opacity: _fadeAnim,
                          child: AnimatedBuilder(
                            animation:
                                Listenable.merge([_flyAnim, _shakeAnim]),
                            builder: (_, __) => _CardArea(
                              card: card,
                              phase: _phase,
                              picked: _picked,
                              flyAnim: _flyAnim.value,
                              shakeAnim: _shakeAnim.value,
                              onSpeak: () => _speak(card.word),
                            ),
                          ),
                        ),
                ),
                _FeedbackBanner(
                    phase: _phase,
                    streak: _streak,
                    wrongReaction: _wrongReaction),
                if (card != null && _phase != _Phase.zoneDone)
                  _NestRow(
                    zone: zone,
                    phase: _phase,
                    picked: _picked,
                    onTapNest: _onTapNest,
                  ),
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
// Meadow background CustomPainter — bright sky-blue daytime palette,
// distinct from every darker/moodier palette used in the other Grade 1
// games (arena, ocean, savanna, mountain, cavern, jungle, workshop).
// ─────────────────────────────────────────────────────────────────────────────

class _MeadowBg extends CustomPainter {
  final double drift;
  _MeadowBg({required this.drift});

  static final _rng = math.Random(9);
  static final _clouds = List.generate(
      5,
      (i) => (
            x: _rng.nextDouble(),
            y: 0.06 + _rng.nextDouble() * 0.18,
            size: 26.0 + _rng.nextDouble() * 20,
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
            Color(0xFF64B5F6),
            Color(0xFF90CAF9),
            Color(0xFFAED581),
            Color(0xFF7CB342),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // Soft drifting clouds confined to the top strip only, well clear of
    // any card/nest content below.
    for (final c in _clouds) {
      final dx = (c.x + drift * 0.03) % 1.0;
      final cx = dx * w;
      final cy = c.y * h;
      final paint = Paint()..color = Colors.white.withValues(alpha: 0.75);
      canvas.drawCircle(Offset(cx, cy), c.size * 0.5, paint);
      canvas.drawCircle(Offset(cx + c.size * 0.4, cy + 4), c.size * 0.38, paint);
      canvas.drawCircle(Offset(cx - c.size * 0.4, cy + 4), c.size * 0.38, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MeadowBg old) => old.drift != drift;
}

// ─────────────────────────────────────────────────────────────────────────────
// Bird flock progress indicator — a flock of small birds accumulates as
// cards are sorted correctly, distinct from the dot bars, rope, chain,
// fog-reveal map, and brick wall used in the other Grade 1 games.
// ─────────────────────────────────────────────────────────────────────────────

class _BirdFlock extends StatelessWidget {
  final int correctCount;
  final int totalQuestions;

  const _BirdFlock({required this.correctCount, required this.totalQuestions});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 4,
        runSpacing: 4,
        children: List.generate(totalQuestions, (i) {
          final done = i < correctCount;
          return AnimatedScale(
            duration: const Duration(milliseconds: 300),
            scale: done ? 1.0 : 0.6,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: done ? 1.0 : 0.25,
              child: const Text('🐦', style: TextStyle(fontSize: 16)),
            ),
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header: zone name + card progress + sorted count
// ─────────────────────────────────────────────────────────────────────────────

class _MeadowHeader extends StatelessWidget {
  final String zoneName;
  final int zoneIdx, totalZones, qIdx, totalQ, correctCount;

  const _MeadowHeader({
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
        color: Colors.white.withValues(alpha: 0.30),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 1.5),
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
                  color: const Color(0xFFFFB74D),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('🐦 $correctCount',
                    style: const TextStyle(
                        color: Color(0xFF4E342E),
                        fontSize: 15,
                        fontWeight: FontWeight.w900)),
              ),
              Column(
                children: [
                  Text(
                    'Zone ${zoneIdx + 1}/$totalZones',
                    style: const TextStyle(
                        color: Color(0xFF1B5E20),
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                  Text(
                    zoneName,
                    style: const TextStyle(
                        color: Color(0xFF0D47A1),
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
                      ? const Color(0xFFFFB74D)
                      : active
                          ? const Color(0xFFFFE0B2)
                          : Colors.white.withValues(alpha: 0.4),
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
// Card area: picture + word + speaker button
// ─────────────────────────────────────────────────────────────────────────────

class _CardArea extends StatelessWidget {
  final _CardQ card;
  final _Phase phase;
  final bool? picked;
  final double flyAnim;
  final double shakeAnim;
  final VoidCallback onSpeak;

  const _CardArea({
    required this.card,
    required this.phase,
    required this.picked,
    required this.flyAnim,
    required this.shakeAnim,
    required this.onSpeak,
  });

  @override
  Widget build(BuildContext context) {
    final isCorrectPhase = phase == _Phase.correct || phase == _Phase.streak;
    final isWrongPhase = phase == _Phase.wrong;

    double dx = 0, dy = 0, scale = 1.0;
    if (isCorrectPhase) {
      final towardA = picked == true;
      dx = (towardA ? -1 : 1) * flyAnim * 110;
      dy = -flyAnim * 40;
      scale = 1.0 - flyAnim * 0.4;
    } else if (isWrongPhase) {
      dx = math.sin(shakeAnim * math.pi * 4) * 8;
    }

    return Center(
      child: Transform.translate(
        offset: Offset(dx, dy),
        child: Transform.scale(
          scale: scale,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFFFB74D), width: 3),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(card.emoji, style: const TextStyle(fontSize: 60)),
                const SizedBox(height: 10),
                Text(
                  card.word,
                  style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF4E342E)),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: onSpeak,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFF0D47A1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.volume_up,
                        color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Nest row: two large basket-shaped sort targets, the core novel
// interaction of this engine -- a binary categorisation tap, not a
// small multiple-choice tile pick or a sequential build.
// ─────────────────────────────────────────────────────────────────────────────

class _NestRow extends StatelessWidget {
  final _Zone zone;
  final _Phase phase;
  final bool? picked;
  final void Function(bool) onTapNest;

  const _NestRow({
    required this.zone,
    required this.phase,
    required this.picked,
    required this.onTapNest,
  });

  @override
  Widget build(BuildContext context) {
    final isAnswered = phase != _Phase.question;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: _NestBtn(
              label: zone.nestALabel,
              emoji: zone.nestAEmoji,
              highlighted: isAnswered && picked == true,
              onTap: isAnswered ? null : () => onTapNest(true),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _NestBtn(
              label: zone.nestBLabel,
              emoji: zone.nestBEmoji,
              highlighted: isAnswered && picked == false,
              onTap: isAnswered ? null : () => onTapNest(false),
            ),
          ),
        ],
      ),
    );
  }
}

class _NestBtn extends StatelessWidget {
  final String label;
  final String emoji;
  final bool highlighted;
  final VoidCallback? onTap;

  const _NestBtn({
    required this.label,
    required this.emoji,
    required this.highlighted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipPath(
        clipper: _BasketClipper(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: 92,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: highlighted
                  ? [const Color(0xFFFFB74D), const Color(0xFFE65100)]
                  : [const Color(0xFF8D6E63), const Color(0xFF5D4037)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(height: 2),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A basket/trapezoid silhouette -- the seventh distinct interactive-shape
/// across the Grade 1 games (rounded square, circle, wood plank, diamond,
/// hexagon, leaf, basket), fitting the "sort into a nest" theme.
class _BasketClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final inset = w * 0.10;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(w - inset, h - 14)
      ..quadraticBezierTo(w - inset, h, w - inset - 14, h)
      ..lineTo(inset + 14, h)
      ..quadraticBezierTo(inset, h, inset, h - 14)
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
      _Phase.correct => ('🐦 Nice sorting!', const Color(0xFF2E7D32)),
      _Phase.wrong => (wrongReaction, const Color(0xFF5D4037)),
      _Phase.streak => (
          '✨ ${streak}x SOUND STREAK! ✨',
          const Color(0xFFEF6C00)
        ),
      _Phase.zoneDone => ('🌳  Meadow Cleared!', const Color(0xFF1B5E20)),
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
        color: Colors.black.withValues(alpha: 0.55),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🌳 🐦 🌳', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 12),
              Text('Meadow $zoneNum Cleared!',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              const Text('On to the next sound patch!',
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
      backgroundColor: Color(0xFF64B5F6),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🐦', style: TextStyle(fontSize: 72)),
            SizedBox(height: 16),
            Text('Phonics Fun',
                style: TextStyle(
                    color: Color(0xFF0D47A1),
                    fontSize: 24,
                    fontWeight: FontWeight.w900)),
            SizedBox(height: 8),
            Text('Sort words by their sounds!',
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
            colors: [Color(0xFF64B5F6), Color(0xFFAED581), Color(0xFFFFB74D)],
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
                  const Text('🏆 Meadow Mastered!',
                      style: TextStyle(
                          color: Color(0xFF0D47A1),
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
                      color: Colors.white.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.7)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Column(
                          children: [
                            const Text('🐦 Sorted',
                                style: TextStyle(
                                    color: Color(0xFF4E342E), fontSize: 12)),
                            Text('$correctCount',
                                style: const TextStyle(
                                    color: Color(0xFFE65100),
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
                                    color: Color(0xFF0D47A1),
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
                          label: '🔄 Sort Again',
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
                  colors: [Color(0xFFFFB74D), Color(0xFFE65100)])
              : null,
          color: primary ? null : Colors.white.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: primary ? const Color(0xFFE65100) : Colors.white70,
            width: 1.5,
          ),
        ),
        child: Text(label,
            style: TextStyle(
                color: primary ? const Color(0xFF4E342E) : Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Flying birds painter (streak celebration) — a flock swooping across the
// screen, distinct from every other streak effect used in the Grade 1
// games so far.
// ─────────────────────────────────────────────────────────────────────────────

class _FlyingBirdsPainter extends CustomPainter {
  final double t;
  _FlyingBirdsPainter(this.t);

  static final _rng = math.Random(14);
  static final _birds =
      List.generate(7, (i) => (y: _rng.nextDouble() * 0.5, phase: _rng.nextDouble()));

  @override
  void paint(Canvas canvas, Size size) {
    for (final b in _birds) {
      final progress = (t + b.phase) % 1.0;
      final dx = progress * (size.width + 60) - 30;
      final dy = b.y * size.height + math.sin(progress * math.pi * 3) * 12;
      final tp = TextPainter(
        text: const TextSpan(text: '🐦', style: TextStyle(fontSize: 20)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(dx, dy));
    }
  }

  @override
  bool shouldRepaint(covariant _FlyingBirdsPainter old) => old.t != t;
}
