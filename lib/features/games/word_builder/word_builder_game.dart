import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/game_session_model.dart';
import '../core/game_config.dart';
import '../core/game_session_persistence.dart';

// ────────────────────────────────────────────────────────────────────────────
// Word Builder — Grade 1 toy-workshop word-spelling quest
//
// 4 Zones (workshop projects get bigger as you go):
//   1. Toy Box    — cat, dog, sun, hat, pig    (3-letter CVC words)
//   2. Block Yard — map, bed, hen, cup, box    (3-letter CVC words)
//   3. Workshop   — frog, star, milk, fish, lamp (4-letter words)
//   4. Grand Build— duck, nest, kite, leaf, boat (4-letter words)
// 5 words per zone = 20 words total.
//
// CAPS Grade 1 English Home Language covers building and spelling simple
// CVC (consonant-vowel-consonant) and familiar sight words from letters --
// letter SOUNDS/blending mechanics are left to the separate Phonics Fun
// engine, and single-letter recognition to Alphabet Explorer, so none of
// the three English games overlap in content.
//
// Structurally distinct from every other Grade 1 engine so far, including
// every other English/Maths game built to this point: instead of picking
// one of 3 multiple-choice answers per question, the learner taps letter
// tiles IN ORDER from a scrambled pool (target letters + 2 decoys) to
// spell each word letter-by-letter -- a genuinely different core loop,
// not a reskin of the multiple-choice pattern. Progress is a brick "wall"
// that fills in as words are completed. A wrong tile tap just wobbles
// and stays available -- no progress lost, try again immediately.
// Architecture: fully self-contained StatefulWidget, no external engine
// (same pattern as the other Grade 1 games).
// ────────────────────────────────────────────────────────────────────────────

enum _Phase { intro, building, wordDone, streak, zoneDone, victory }

// ── Word + tile models ───────────────────────────────────────────────────────

class _WordQ {
  final String word; // lowercase target word
  final String emoji;
  const _WordQ(this.word, this.emoji);
}

class _Tile {
  final int id;
  final String letter; // uppercase
  bool consumed = false;
  _Tile(this.id, this.letter);
}

// ── Zone definitions ─────────────────────────────────────────────────────────

class _Zone {
  final String name;
  final List<_WordQ> words;
  const _Zone(this.name, this.words);
}

// ── Main game widget ───────────────────────────────────────────────────────

class WordBuilderGame extends StatefulWidget {
  final GameConfig config;
  final dynamic user;
  const WordBuilderGame({super.key, required this.config, this.user});

  @override
  State<WordBuilderGame> createState() => _WBState();
}

class _WBState extends State<WordBuilderGame> with TickerProviderStateMixin {
  static const _zones = [
    _Zone('Toy Box', [
      _WordQ('cat', '🐱'),
      _WordQ('dog', '🐶'),
      _WordQ('sun', '☀️'),
      _WordQ('hat', '🎩'),
      _WordQ('pig', '🐷'),
    ]),
    _Zone('Block Yard', [
      _WordQ('map', '🗺️'),
      _WordQ('bed', '🛏️'),
      _WordQ('hen', '🐔'),
      _WordQ('cup', '🥤'),
      _WordQ('box', '📦'),
    ]),
    _Zone('Workshop', [
      _WordQ('frog', '🐸'),
      _WordQ('star', '⭐'),
      _WordQ('milk', '🥛'),
      _WordQ('fish', '🐟'),
      _WordQ('lamp', '💡'),
    ]),
    _Zone('Grand Build', [
      _WordQ('duck', '🦆'),
      _WordQ('nest', '🪺'),
      _WordQ('kite', '🪁'),
      _WordQ('leaf', '🍃'),
      _WordQ('boat', '⛵'),
    ]),
  ];

  static const _wrongReactions = [
    'Not that block! Try another.',
    'Hmm, try a different block!',
    'Almost — pick another block!',
  ];

  // ── Animations ──────────────────────────────────────────────────────────
  late AnimationController _glowCtrl; // ambient sawdust glow, looping
  late AnimationController _snapCtrl; // letter tile snaps into place
  late AnimationController _wobbleCtrl; // wrong tile wobble
  late AnimationController _toolCtrl; // tool-shower streak celebration
  late AnimationController _fadeCtrl; // word fade-in

  late Animation<double> _glowAnim;
  late Animation<double> _snapAnim;
  late Animation<double> _wobbleAnim;
  late Animation<double> _toolAnim;
  late Animation<double> _fadeAnim;

  // ── Game state ──────────────────────────────────────────────────────────
  int _zoneIdx = 0;
  int _qIdx = 0;
  int _wordsCompleted = 0; // drives the brick-wall progress
  int _cleanCount = 0; // words spelled with zero wrong taps -- scoring metric
  int _streak = 0;
  int _totalXP = 0;

  _Phase _phase = _Phase.intro;
  _WordQ? _currentWord;
  List<_Tile> _tiles = [];
  String _filled = '';
  bool _hadWrongTapThisWord = false;
  int? _wobbleTileId;
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

    _snapCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _snapAnim = CurvedAnimation(parent: _snapCtrl, curve: Curves.elasticOut);

    _wobbleCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _wobbleAnim = CurvedAnimation(parent: _wobbleCtrl, curve: Curves.easeInOut);

    _toolCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600));
    _toolAnim = CurvedAnimation(parent: _toolCtrl, curve: Curves.easeOut);

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
    _wobbleCtrl.dispose();
    _toolCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Game flow ────────────────────────────────────────────────────────────

  void _startGame() {
    setState(() {
      _zoneIdx = 0;
      _qIdx = 0;
      _wordsCompleted = 0;
      _cleanCount = 0;
      _streak = 0;
      _totalXP = 0;
    });
    _nextWord();
  }

  void _nextWord() {
    final wordQ = _zones[_zoneIdx].words[_qIdx];
    _fadeCtrl.reset();
    setState(() {
      _currentWord = wordQ;
      _tiles = _makeTiles(wordQ.word);
      _filled = '';
      _hadWrongTapThisWord = false;
      _wobbleTileId = null;
      _phase = _Phase.building;
    });
    _fadeCtrl.forward();
  }

  List<_Tile> _makeTiles(String word) {
    final letters = word.toUpperCase().split('');
    final used = letters.toSet();
    final decoyPool = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
        .split('')
        .where((l) => !used.contains(l))
        .toList()
      ..shuffle(_rng);
    final all = [...letters, ...decoyPool.take(2)]..shuffle(_rng);
    return [for (var i = 0; i < all.length; i++) _Tile(i, all[i])];
  }

  void _onTapTile(int tileId) {
    if (_phase != _Phase.building) return;
    final tile = _tiles.firstWhere((t) => t.id == tileId);
    if (tile.consumed) return;

    final word = _currentWord!.word;
    final nextChar = word[_filled.length].toUpperCase();

    if (tile.letter == nextChar) {
      setState(() {
        tile.consumed = true;
        _filled += word[_filled.length];
      });
      _snapCtrl.forward(from: 0);
      if (_filled.length == word.length) {
        _delayed(400, _onWordComplete);
      }
    } else {
      setState(() {
        _hadWrongTapThisWord = true;
        _wobbleTileId = tileId;
        _wrongReaction =
            _wrongReactions[_rng.nextInt(_wrongReactions.length)];
      });
      _wobbleCtrl.forward(from: 0);
      _delayed(450, () {
        if (mounted) setState(() => _wobbleTileId = null);
      });
    }
  }

  void _onWordComplete() {
    final clean = !_hadWrongTapThisWord;
    setState(() {
      _wordsCompleted++;
      if (clean) {
        _cleanCount++;
        _streak++;
        _totalXP += 10;
      } else {
        _streak = 0;
        _totalXP += 5;
      }
    });

    final isStreak = clean && _streak > 0 && _streak % 3 == 0;
    if (isStreak) {
      setState(() => _phase = _Phase.streak);
      _toolCtrl.forward(from: 0);
      _delayed(1800, _advance);
    } else {
      setState(() => _phase = _Phase.wordDone);
      _delayed(1200, _advance);
    }
  }

  void _advance() {
    if (!mounted) return;
    final zone = _zones[_zoneIdx];
    final next = _qIdx + 1;

    if (next >= zone.words.length) {
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
          _nextWord();
        });
      }
    } else {
      setState(() => _qIdx = next);
      _delayed(300, _nextWord);
    }
  }

  void _persistSession() {
    final totalWords =
        _zones.fold<int>(0, (sum, z) => sum + z.words.length); // 20
    final accuracy = totalWords > 0 ? _cleanCount / totalWords : 0.0;
    final isPerfect = _cleanCount == totalWords;
    final isWin = _cleanCount > totalWords / 2;
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
        cleanCount: _cleanCount,
        totalXP: _totalXP,
        onReplay: _startGame,
        onExit: () => Navigator.of(context).pop(),
      );
    }

    final zone = _zones[_zoneIdx];
    final wordQ = _currentWord;
    final totalWords = _zones.fold<int>(0, (sum, z) => sum + z.words.length);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _glowAnim,
              builder: (_, __) =>
                  CustomPaint(painter: _WorkshopBg(glow: _glowAnim.value)),
            ),
          ),

          if (_phase == _Phase.streak)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _toolAnim,
                builder: (_, __) =>
                    CustomPaint(painter: _ToolShowerPainter(_toolAnim.value)),
              ),
            ),

          SafeArea(
            child: Column(
              children: [
                _WorkshopHeader(
                  zoneName: zone.name,
                  zoneIdx: _zoneIdx,
                  totalZones: _zones.length,
                  qIdx: _qIdx,
                  totalQ: zone.words.length,
                  wordsCompleted: _wordsCompleted,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  child: _BuildWall(
                      wordsCompleted: _wordsCompleted, totalWords: totalWords),
                ),
                Expanded(
                  child: wordQ == null
                      ? const SizedBox()
                      : FadeTransition(
                          opacity: _fadeAnim,
                          child: _WordArea(
                            wordQ: wordQ,
                            tiles: _tiles,
                            filled: _filled,
                            phase: _phase,
                            wobbleTileId: _wobbleTileId,
                            wobbleAnim: _wobbleAnim,
                            snapAnim: _snapAnim,
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
// Workshop background CustomPainter — warm amber/wood-brown palette,
// distinct from the arena, ocean, savanna, mountain, cavern, and jungle
// palettes used in the other Grade 1 games.
// ─────────────────────────────────────────────────────────────────────────────

class _WorkshopBg extends CustomPainter {
  final double glow;
  _WorkshopBg({required this.glow});

  static final _rng = math.Random(33);
  static final _motes = List.generate(
      10,
      (i) => (
            x: _rng.nextDouble(),
            y: _rng.nextDouble() * 0.6,
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
            Color(0xFF3E2415),
            Color(0xFF5C371E),
            Color(0xFF7A4A26),
            Color(0xFF9C6530),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    for (final m in _motes) {
      canvas.drawCircle(
        Offset(m.x * w, m.y * h),
        m.size * (0.8 + glow * 0.4),
        Paint()..color = const Color(0xFFFFD54F).withValues(alpha: 0.6 * glow),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WorkshopBg old) => old.glow != glow;
}

// ─────────────────────────────────────────────────────────────────────────────
// Brick "wall" progress indicator — fills in brick by brick as words are
// completed, distinct from the dot bars, rope, chain, and fog-reveal map
// used in the other Grade 1 games.
// ─────────────────────────────────────────────────────────────────────────────

class _BuildWall extends StatelessWidget {
  final int wordsCompleted;
  final int totalWords;

  const _BuildWall({required this.wordsCompleted, required this.totalWords});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: const Color(0xFFD4863A).withValues(alpha: 0.5)),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 5,
        runSpacing: 5,
        children: List.generate(totalWords, (i) {
          final done = i < wordsCompleted;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 26,
            height: 18,
            decoration: BoxDecoration(
              color: done
                  ? const Color(0xFFD4863A)
                  : Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(
                color:
                    done ? const Color(0xFF6B3B12) : Colors.white24,
                width: 1,
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header: zone name + word progress + words-built count
// ─────────────────────────────────────────────────────────────────────────────

class _WorkshopHeader extends StatelessWidget {
  final String zoneName;
  final int zoneIdx, totalZones, qIdx, totalQ, wordsCompleted;

  const _WorkshopHeader({
    required this.zoneName,
    required this.zoneIdx,
    required this.totalZones,
    required this.qIdx,
    required this.totalQ,
    required this.wordsCompleted,
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
            color: const Color(0xFFD4863A).withValues(alpha: 0.6), width: 1.5),
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
                  color: const Color(0xFFD4863A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('🧱 $wordsCompleted',
                    style: const TextStyle(
                        color: Color(0xFF3E2415),
                        fontSize: 15,
                        fontWeight: FontWeight.w900)),
              ),
              Column(
                children: [
                  Text(
                    'Zone ${zoneIdx + 1}/$totalZones',
                    style: const TextStyle(
                        color: Color(0xFFFFCC80),
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
                      ? const Color(0xFFD4863A)
                      : active
                          ? const Color(0xFFFFE0B2)
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
// Word area: picture clue + letter blanks + letter-tile pool
// ─────────────────────────────────────────────────────────────────────────────

class _WordArea extends StatelessWidget {
  final _WordQ wordQ;
  final List<_Tile> tiles;
  final String filled;
  final _Phase phase;
  final int? wobbleTileId;
  final Animation<double> wobbleAnim;
  final Animation<double> snapAnim;
  final void Function(int) onTapTile;

  const _WordArea({
    required this.wordQ,
    required this.tiles,
    required this.filled,
    required this.phase,
    required this.wobbleTileId,
    required this.wobbleAnim,
    required this.snapAnim,
    required this.onTapTile,
  });

  @override
  Widget build(BuildContext context) {
    final available = tiles.where((t) => !t.consumed).toList();
    final wordComplete =
        phase == _Phase.wordDone || phase == _Phase.streak;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          AnimatedScale(
            duration: const Duration(milliseconds: 300),
            scale: wordComplete ? 1.25 : 1.0,
            curve: Curves.elasticOut,
            child: Text(wordQ.emoji, style: const TextStyle(fontSize: 64)),
          ),
          AnimatedBuilder(
            animation: snapAnim,
            builder: (_, __) => _BlankRow(word: wordQ.word, filled: filled),
          ),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: available
                .map((t) => AnimatedBuilder(
                      animation: wobbleAnim,
                      builder: (_, __) {
                        final wobbling = wobbleTileId == t.id;
                        final dx = wobbling
                            ? math.sin(wobbleAnim.value * math.pi * 4) * 6
                            : 0.0;
                        return Transform.translate(
                          offset: Offset(dx, 0),
                          child: _TileBtn(
                              letter: t.letter,
                              onTap: () => onTapTile(t.id)),
                        );
                      },
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _BlankRow extends StatelessWidget {
  final String word;
  final String filled;
  const _BlankRow({required this.word, required this.filled});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(word.length, (i) {
        final isFilled = i < filled.length;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: 38,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isFilled
                ? const Color(0xFFFFE0B2)
                : Colors.black.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFD4863A), width: 2),
          ),
          child: Text(
            isFilled ? filled[i].toUpperCase() : '',
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFF6B3B12)),
          ),
        );
      }),
    );
  }
}

class _TileBtn extends StatelessWidget {
  final String letter;
  final VoidCallback onTap;
  const _TileBtn({required this.letter, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFE8A45C), Color(0xFFC97A34)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF6B3B12), width: 2),
          boxShadow: const [
            BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 3)),
          ],
        ),
        child: Center(
          child: Text(
            letter,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              shadows: [Shadow(blurRadius: 4, color: Colors.black45)],
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
  final String wrongReaction;
  const _FeedbackBanner(
      {required this.phase, required this.streak, required this.wrongReaction});

  @override
  Widget build(BuildContext context) {
    final (text, bg) = switch (phase) {
      _Phase.wordDone => ('🔨 Word built! Nice work!', const Color(0xFF6B3B12)),
      _Phase.streak => (
          '✨ ${streak}x BUILDER STREAK! ✨',
          const Color(0xFFF9A825)
        ),
      _Phase.zoneDone => ('🏗️  Section Complete!', const Color(0xFF5C371E)),
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
              const Text('🏗️ 🧱 🏗️', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 12),
              Text('Section $zoneNum Built!',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              const Text('On to the next project!',
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
      backgroundColor: Color(0xFF3E2415),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🔨', style: TextStyle(fontSize: 72)),
            SizedBox(height: 16),
            Text('Word Builder',
                style: TextStyle(
                    color: Color(0xFFFFCC80),
                    fontSize: 24,
                    fontWeight: FontWeight.w900)),
            SizedBox(height: 8),
            Text('Build words, block by block!',
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
  final int cleanCount, totalXP;
  final VoidCallback onReplay, onExit;

  const _VictoryScreen({
    required this.cleanCount,
    required this.totalXP,
    required this.onReplay,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    final stars = cleanCount >= 18
        ? 3
        : cleanCount >= 12
            ? 2
            : 1;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF3E2415), Color(0xFF7A4A26), Color(0xFFFFCC80)],
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
                  const Text('🏆 Workshop Complete!',
                      style: TextStyle(
                          color: Color(0xFFFFF3E0),
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
                              const Color(0xFFD4863A).withValues(alpha: 0.6)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Column(
                          children: [
                            const Text('🧱 Clean Builds',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 12)),
                            Text('$cleanCount',
                                style: const TextStyle(
                                    color: Color(0xFFFFCC80),
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
                          label: '🔄 Build Again',
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
                  colors: [Color(0xFFE8A45C), Color(0xFFC97A34)])
              : null,
          color: primary ? null : Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: primary ? const Color(0xFFD4863A) : Colors.white38,
            width: 1.5,
          ),
        ),
        child: Text(label,
            style: TextStyle(
                color: primary ? const Color(0xFF3E2415) : Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tool shower painter (streak celebration) — falling tool emoji, distinct
// from every other streak effect used in the Grade 1 games so far.
// ─────────────────────────────────────────────────────────────────────────────

class _ToolShowerPainter extends CustomPainter {
  final double t;
  _ToolShowerPainter(this.t);

  static final _rng = math.Random(21);
  static final _tools = List.generate(
      10,
      (i) => (
            x: _rng.nextDouble(),
            phase: _rng.nextDouble(),
            emoji: ['🔨', '🔧', '🪛', '🧱'][i % 4],
          ));

  @override
  void paint(Canvas canvas, Size size) {
    for (final tool in _tools) {
      final progress = (t + tool.phase) % 1.0;
      final dy = progress * size.height;
      final scale = 0.6 + (1 - progress) * 0.6;
      final tp = TextPainter(
        text: TextSpan(
            text: tool.emoji, style: const TextStyle(fontSize: 24)),
        textDirection: TextDirection.ltr,
      )..layout();
      canvas.save();
      canvas.translate(tool.x * size.width, dy);
      canvas.scale(scale);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ToolShowerPainter old) => old.t != t;
}
