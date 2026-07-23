import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/game_session_model.dart';
import '../core/game_config.dart';
import '../core/game_session_persistence.dart';

// ────────────────────────────────────────────────────────────────────────────
// Reading Rainbow — Grade 1 storybook-valley sequencing quest
//
// 4 Zones (a pastel rainbow arching over a storybook valley):
//   1. Story Meadow — growth/nature sequences (seed → sprout → flower...)
//   2. Daily Life   — everyday routine sequences (wake → breakfast → school...)
//   3. Story Cove   — simple cause-and-effect mini narratives
//   4. Rainbow Peak — mixed cause-and-effect, the trickiest set
// 5 three-step stories per zone = 20 total.
//
// CAPS Grade 1 English Home Language covers sequencing events in a simple
// story/process and basic reading comprehension -- letter recognition,
// spelling, and phonics are each owned by the other three English
// engines, so nothing overlaps.
//
// Structurally distinct from every other Grade 1 engine so far: the
// learner taps three scrambled picture-and-word cards, IN THE ORDER they
// believe the story happens, to fill three numbered slots -- an ordering/
// sequencing puzzle, not a multiple-choice pick, a binary sort, or a
// single-target letter build. Correctness is revealed only once all
// three slots are filled (each slot then tints green or red to show
// exactly where the story went right or wrong), which is a different
// feedback timing to every other engine's immediate per-tap feedback.
// A wrong sequence never loses progress -- it just reveals the mistake
// and moves on to the next story. Architecture: fully self-contained
// StatefulWidget, no external engine (same pattern as the other Grade 1
// games).
// ────────────────────────────────────────────────────────────────────────────

enum _Phase { intro, question, correct, wrong, streak, zoneDone, victory }

// ── Story + zone models ──────────────────────────────────────────────────────

class _StoryQ {
  final List<String> labels; // 3, in correct order
  final List<String> emojis; // 3, in correct order matching labels
  const _StoryQ(this.labels, this.emojis);
}

class _Zone {
  final String name;
  final List<_StoryQ> stories; // 5
  const _Zone(this.name, this.stories);
}

// ── Main game widget ───────────────────────────────────────────────────────

class ReadingRainbowGame extends StatefulWidget {
  final GameConfig config;
  final dynamic user;
  const ReadingRainbowGame({super.key, required this.config, this.user});

  @override
  State<ReadingRainbowGame> createState() => _RRState();
}

class _RRState extends State<ReadingRainbowGame> with TickerProviderStateMixin {
  static const _zones = [
    _Zone('Story Meadow', [
      _StoryQ(['Seed', 'Sprout', 'Flower'], ['🌱', '🌿', '🌻']),
      _StoryQ(['Egg', 'Chick', 'Hen'], ['🥚', '🐤', '🐔']),
      _StoryQ(['Cloud', 'Rain', 'Rainbow'], ['☁️', '🌧️', '🌈']),
      _StoryQ(['Caterpillar', 'Cocoon', 'Butterfly'], ['🐛', '🍃', '🦋']),
      _StoryQ(['Sunrise', 'Midday', 'Sunset'], ['🌅', '☀️', '🌇']),
    ]),
    _Zone('Daily Life', [
      _StoryQ(['Wake Up', 'Breakfast', 'School'], ['🛌', '🍳', '🎒']),
      _StoryQ(['Homework', 'Dinner', 'Sleep'], ['📚', '🍽️', '😴']),
      _StoryQ(['Brush Teeth', 'Wash Face', 'Bed'], ['🪥', '🧼', '🛏️']),
      _StoryQ(['Rain', 'Umbrella', 'Puddle'], ['🌧️', '☂️', '💧']),
      _StoryQ(['Plant', 'Sun', 'Grow'], ['🌱', '☀️', '🌳']),
    ]),
    _Zone('Story Cove', [
      _StoryQ(['Ball', 'Goal', 'Cheer'], ['⚽', '🥅', '🎉']),
      _StoryQ(['Hungry', 'Cook', 'Eat'], ['😋', '🍳', '🍽️']),
      _StoryQ(['Thirsty', 'Cup', 'Happy'], ['🥵', '🥤', '😊']),
      _StoryQ(['Dark', 'Lamp', 'Light'], ['🌙', '💡', '✨']),
      _StoryQ(['Cold', 'Jacket', 'Warm'], ['🥶', '🧥', '😊']),
    ]),
    _Zone('Rainbow Peak', [
      _StoryQ(['Trash', 'Recycle', 'Clean'], ['🗑️', '♻️', '✨']),
      _StoryQ(['Closed Book', 'Read', 'Smart'], ['📕', '📖', '🎓']),
      _StoryQ(['Ice', 'Melt', 'Water'], ['🧊', '💧', '🌊']),
      _StoryQ(['Apple Tree', 'Apple', 'Pie'], ['🌳', '🍎', '🥧']),
      _StoryQ(['Wind', 'Kite', 'Sky'], ['💨', '🪁', '☁️']),
    ]),
  ];

  static const _wrongReactions = [
    'Not quite the right order! On to the next story.',
    'Close! Some steps were swapped. Next story!',
    'Almost there! Let\'s try another story.',
  ];

  // ── Animations ──────────────────────────────────────────────────────────
  late AnimationController _glowCtrl; // ambient rainbow shimmer, looping
  late AnimationController _snapCtrl; // card snaps into a slot
  late AnimationController _starCtrl; // shooting-stars streak celebration
  late AnimationController _fadeCtrl; // story fade-in

  late Animation<double> _glowAnim;
  late Animation<double> _snapAnim;
  late Animation<double> _starAnim;
  late Animation<double> _fadeAnim;

  // ── Game state ──────────────────────────────────────────────────────────
  int _zoneIdx = 0;
  int _qIdx = 0;
  int _correctCount = 0;
  int _streak = 0;
  int _totalXP = 0;

  _Phase _phase = _Phase.intro;
  _StoryQ? _current;
  List<int> _poolOrder = []; // scrambled display order (original indices)
  List<bool> _poolConsumed = [false, false, false];
  List<int> _placed = []; // original indices, in the order the learner tapped
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
        vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.5, end: 1.0)
        .animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));

    _snapCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _snapAnim = CurvedAnimation(parent: _snapCtrl, curve: Curves.elasticOut);

    _starCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600));
    _starAnim = CurvedAnimation(parent: _starCtrl, curve: Curves.easeOut);

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
    _starCtrl.dispose();
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
    _nextStory();
  }

  void _nextStory() {
    final story = _zones[_zoneIdx].stories[_qIdx];
    var order = [0, 1, 2]..shuffle(_rng);
    while (order[0] == 0 && order[1] == 1 && order[2] == 2) {
      order = [0, 1, 2]..shuffle(_rng);
    }
    _fadeCtrl.reset();
    setState(() {
      _current = story;
      _poolOrder = order;
      _poolConsumed = [false, false, false];
      _placed = [];
      _phase = _Phase.question;
    });
    _fadeCtrl.forward();
  }

  void _onTapCard(int originalIndex) {
    if (_phase != _Phase.question) return;
    if (_poolConsumed[originalIndex]) return;
    setState(() {
      _poolConsumed[originalIndex] = true;
      _placed.add(originalIndex);
    });
    _snapCtrl.forward(from: 0);
    if (_placed.length == 3) {
      _delayed(500, _onSequenceComplete);
    }
  }

  void _onSequenceComplete() {
    final correct = _placed[0] == 0 && _placed[1] == 1 && _placed[2] == 2;
    setState(() {
      if (correct) {
        _correctCount++;
        _streak++;
        _totalXP += 10;
      } else {
        _streak = 0;
      }
    });

    if (correct) {
      final isStreak = _streak > 0 && _streak % 3 == 0;
      if (isStreak) {
        setState(() => _phase = _Phase.streak);
        _starCtrl.forward(from: 0);
        _delayed(1800, _advance);
      } else {
        setState(() => _phase = _Phase.correct);
        _delayed(1200, _advance);
      }
    } else {
      setState(() {
        _phase = _Phase.wrong;
        _wrongReaction =
            _wrongReactions[_rng.nextInt(_wrongReactions.length)];
      });
      _delayed(1700, _advance);
    }
  }

  void _advance() {
    if (!mounted) return;
    final zone = _zones[_zoneIdx];
    final next = _qIdx + 1;

    if (next >= zone.stories.length) {
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
          _nextStory();
        });
      }
    } else {
      setState(() => _qIdx = next);
      _delayed(300, _nextStory);
    }
  }

  void _persistSession() {
    final totalQuestions =
        _zones.fold<int>(0, (sum, z) => sum + z.stories.length); // 20
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
    final story = _current;
    final totalQuestions = _zones.fold<int>(0, (sum, z) => sum + z.stories.length);
    final revealCorrectness = _phase != _Phase.question;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _glowAnim,
              builder: (_, __) =>
                  CustomPaint(painter: _ValleyBg(shimmer: _glowAnim.value)),
            ),
          ),

          if (_phase == _Phase.streak)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _starAnim,
                builder: (_, __) => CustomPaint(
                    painter: _ShootingStarsPainter(_starAnim.value)),
              ),
            ),

          SafeArea(
            child: Column(
              children: [
                _ValleyHeader(
                  zoneName: zone.name,
                  zoneIdx: _zoneIdx,
                  totalZones: _zones.length,
                  qIdx: _qIdx,
                  totalQ: zone.stories.length,
                  correctCount: _correctCount,
                ),
                _RainbowProgress(
                    correctCount: _correctCount, totalQuestions: totalQuestions),
                Expanded(
                  child: story == null
                      ? const SizedBox()
                      : FadeTransition(
                          opacity: _fadeAnim,
                          child: _StoryArea(
                            story: story,
                            poolOrder: _poolOrder,
                            poolConsumed: _poolConsumed,
                            placed: _placed,
                            revealCorrectness: revealCorrectness,
                            snapAnim: _snapAnim,
                            onTapCard: _onTapCard,
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
// Storybook valley background — soft pastel gradient, distinct from every
// other Grade 1 palette so far.
// ─────────────────────────────────────────────────────────────────────────────

class _ValleyBg extends CustomPainter {
  final double shimmer;
  _ValleyBg({required this.shimmer});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = const LinearGradient(
          colors: [
            Color(0xFFFFF3E0),
            Color(0xFFFFE0F0),
            Color(0xFFE1F5FE),
            Color(0xFFE8F5E9),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // A few soft sparkle motes drifting near the top only.
    final rng = math.Random(3);
    for (var i = 0; i < 8; i++) {
      final x = rng.nextDouble() * w;
      final y = rng.nextDouble() * h * 0.18;
      canvas.drawCircle(
        Offset(x, y),
        2.5 * (0.6 + shimmer * 0.4),
        Paint()..color = const Color(0xFFFFD54F).withValues(alpha: 0.5 * shimmer),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ValleyBg old) => old.shimmer != shimmer;
}

// ─────────────────────────────────────────────────────────────────────────────
// Rainbow-arc progress indicator — a literal rainbow that fills in as
// stories are sequenced correctly, distinct from every other progress
// style used in the Grade 1 games so far.
// ─────────────────────────────────────────────────────────────────────────────

class _RainbowProgress extends StatelessWidget {
  final int correctCount;
  final int totalQuestions;

  const _RainbowProgress(
      {required this.correctCount, required this.totalQuestions});

  @override
  Widget build(BuildContext context) {
    final progress =
        totalQuestions > 0 ? (correctCount / totalQuestions).clamp(0.0, 1.0) : 0.0;
    return SizedBox(
      height: 90,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return CustomPaint(
            size: Size(constraints.maxWidth, 90),
            painter: _RainbowArcPainter(progress: progress),
          );
        },
      ),
    );
  }
}

class _RainbowArcPainter extends CustomPainter {
  final double progress;
  _RainbowArcPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final radius = math.min(size.width / 2 - 10, 80.0);
    final center = Offset(size.width / 2, radius + 6);
    final rect = Rect.fromCircle(center: center, radius: radius);

    final bgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.5);
    canvas.drawArc(rect, math.pi, -math.pi, false, bgPaint);

    if (progress > 0) {
      final sweep = math.pi * progress;
      const gradient = SweepGradient(
        colors: [
          Color(0xFFE53935),
          Color(0xFFFB8C00),
          Color(0xFFFDD835),
          Color(0xFF43A047),
          Color(0xFF1E88E5),
          Color(0xFF8E24AA),
          Color(0xFFE53935),
        ],
        transform: GradientRotation(math.pi),
      );
      final fgPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round
        ..shader = gradient.createShader(rect);
      canvas.drawArc(rect, math.pi, -sweep, false, fgPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RainbowArcPainter old) => old.progress != progress;
}

// ─────────────────────────────────────────────────────────────────────────────
// Header: zone name + story progress + sequenced count
// ─────────────────────────────────────────────────────────────────────────────

class _ValleyHeader extends StatelessWidget {
  final String zoneName;
  final int zoneIdx, totalZones, qIdx, totalQ, correctCount;

  const _ValleyHeader({
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
        color: Colors.white.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.5),
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
                  color: const Color(0xFF8E24AA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('📖 $correctCount',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900)),
              ),
              Column(
                children: [
                  Text(
                    'Zone ${zoneIdx + 1}/$totalZones',
                    style: const TextStyle(
                        color: Color(0xFF6A1B9A),
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                  Text(
                    zoneName,
                    style: const TextStyle(
                        color: Color(0xFF4E342E),
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
                      ? const Color(0xFF8E24AA)
                      : active
                          ? const Color(0xFFE1BEE7)
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
// Story area: numbered slots to fill + scrambled bookmark-shaped cards
// ─────────────────────────────────────────────────────────────────────────────

class _StoryArea extends StatelessWidget {
  final _StoryQ story;
  final List<int> poolOrder;
  final List<bool> poolConsumed;
  final List<int> placed;
  final bool revealCorrectness;
  final Animation<double> snapAnim;
  final void Function(int) onTapCard;

  const _StoryArea({
    required this.story,
    required this.poolOrder,
    required this.poolConsumed,
    required this.placed,
    required this.revealCorrectness,
    required this.snapAnim,
    required this.onTapCard,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          const Text('Tap the cards in story order!',
              style: TextStyle(
                  color: Color(0xFF4E342E),
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
          AnimatedBuilder(
            animation: snapAnim,
            builder: (_, __) => _SlotRow(
                story: story, placed: placed, revealCorrectness: revealCorrectness),
          ),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            alignment: WrapAlignment.center,
            children: poolOrder
                .where((originalIndex) => !poolConsumed[originalIndex])
                .map((originalIndex) => _BookmarkCard(
                      label: story.labels[originalIndex],
                      emoji: story.emojis[originalIndex],
                      onTap: () => onTapCard(originalIndex),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _SlotRow extends StatelessWidget {
  final _StoryQ story;
  final List<int> placed;
  final bool revealCorrectness;

  const _SlotRow(
      {required this.story, required this.placed, required this.revealCorrectness});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (slot) {
        final filled = slot < placed.length;
        final originalIndex = filled ? placed[slot] : null;
        final isCorrectSlot = filled && originalIndex == slot;

        Color bg = filled
            ? Colors.white.withValues(alpha: 0.9)
            : Colors.black.withValues(alpha: 0.15);
        Color border = const Color(0xFF8E24AA);
        if (filled && revealCorrectness) {
          bg = isCorrectSlot
              ? const Color(0xFFA5D6A7)
              : const Color(0xFFEF9A9A);
          border = isCorrectSlot
              ? const Color(0xFF2E7D32)
              : const Color(0xFFC62828);
        }

        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 6),
          width: 84,
          height: 84,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border, width: 2),
          ),
          child: filled
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(story.emojis[originalIndex!],
                        style: const TextStyle(fontSize: 26)),
                    const SizedBox(height: 2),
                    Text(
                      story.labels[originalIndex],
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF4E342E)),
                    ),
                  ],
                )
              : Text('${slot + 1}',
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 22,
                      fontWeight: FontWeight.w900)),
        );
      }),
    );
  }
}

class _BookmarkCard extends StatelessWidget {
  final String label;
  final String emoji;
  final VoidCallback onTap;

  const _BookmarkCard(
      {required this.label, required this.emoji, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipPath(
        clipper: _BookmarkClipper(),
        child: Container(
          width: 78,
          height: 92,
          padding: const EdgeInsets.only(top: 10, bottom: 18),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFBA68C8), Color(0xFF8E24AA)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A bookmark-ribbon silhouette (flat top, V-notch bottom) -- the eighth
/// distinct interactive shape across the Grade 1 games, fitting the
/// "Reading" theme.
class _BookmarkClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(w, h)
      ..lineTo(w / 2, h - 16)
      ..lineTo(0, h)
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
      _Phase.correct => ('📖 Great sequence!', const Color(0xFF2E7D32)),
      _Phase.wrong => (wrongReaction, const Color(0xFFC62828)),
      _Phase.streak => (
          '✨ ${streak}x STORY STREAK! ✨',
          const Color(0xFF8E24AA)
        ),
      _Phase.zoneDone => ('🌈  Chapter Complete!', const Color(0xFF6A1B9A)),
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
              const Text('🌈 📖 🌈', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 12),
              Text('Chapter $zoneNum Complete!',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              const Text('The next chapter awaits!',
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
      backgroundColor: Color(0xFFFFF3E0),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🌈', style: TextStyle(fontSize: 72)),
            SizedBox(height: 16),
            Text('Reading Rainbow',
                style: TextStyle(
                    color: Color(0xFF8E24AA),
                    fontSize: 24,
                    fontWeight: FontWeight.w900)),
            SizedBox(height: 8),
            Text('Put the story in the right order!',
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
            colors: [Color(0xFFFFF3E0), Color(0xFFE1F5FE), Color(0xFFE1BEE7)],
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
                  const Text('🏆 Storybook Complete!',
                      style: TextStyle(
                          color: Color(0xFF6A1B9A),
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
                      color: Colors.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: const Color(0xFF8E24AA).withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Column(
                          children: [
                            const Text('📖 Sequenced',
                                style: TextStyle(
                                    color: Color(0xFF4E342E), fontSize: 12)),
                            Text('$correctCount',
                                style: const TextStyle(
                                    color: Color(0xFF8E24AA),
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
                                    color: Color(0xFF6A1B9A),
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
                          label: '🔄 Read Again',
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
                  colors: [Color(0xFFBA68C8), Color(0xFF8E24AA)])
              : null,
          color: primary ? null : Colors.white.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: primary ? const Color(0xFF8E24AA) : Colors.white70,
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
// Shooting stars painter (streak celebration) — stars shooting diagonally
// across the screen with a trailing sparkle, distinct from every other
// streak effect used in the Grade 1 games so far.
// ─────────────────────────────────────────────────────────────────────────────

class _ShootingStarsPainter extends CustomPainter {
  final double t;
  _ShootingStarsPainter(this.t);

  static final _rng = math.Random(41);
  static final _stars = List.generate(
      8, (i) => (y: _rng.nextDouble() * 0.5, phase: _rng.nextDouble()));

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in _stars) {
      final progress = (t + s.phase) % 1.0;
      final dx = progress * (size.width + 80) - 40;
      final dy = s.y * size.height + progress * 70;
      final tp = TextPainter(
        text: const TextSpan(text: '⭐', style: TextStyle(fontSize: 18)),
        textDirection: TextDirection.ltr,
      )..layout();
      final scale = 0.6 + (1 - progress).clamp(0.0, 1.0) * 0.6;
      canvas.save();
      canvas.translate(dx, dy);
      canvas.scale(scale);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ShootingStarsPainter old) => old.t != t;
}
