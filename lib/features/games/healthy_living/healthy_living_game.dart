import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/game_session_model.dart';
import '../core/game_config.dart';
import '../core/game_feedback_service.dart';
import '../core/game_session_persistence.dart';

// ────────────────────────────────────────────────────────────────────────────
// Healthy Living — Grade 4 Life Skills: nutrition, exercise, hygiene, sleep,
// and mental/emotional wellbeing
//
// NOTE: this is a DIFFERENT engine from runner_collector/ (engineType
// 'runnerCollector'), which is a shared generic engine still used by 14
// other catalog entries. This engine (engineType 'healthyLiving') is
// registered ONLY against ls_g4_health.
//
// 4 Zones (5 steps/questions each = 20 total):
//   1. Balance Your Day    — a picture for each part of the day, shuffled;
//      tap them in the correct chronological order (wake up -> breakfast
//      -> school -> play -> sleep). No caption on the pictures themselves --
//      the point is recognising the stage from the image alone.
//   2. Nutrition & Exercise  — recall MCQ
//   3. Hygiene & Sleep       — recall MCQ
//   4. Mind & Emotions       — recall MCQ
//
// Structurally distinct from every prior engine: Zone 1 is an
// order-sensitive picture-tap sequence (correctness depends on WHICH step
// you tap next, not picking from a set of choices) -- unlike Financial
// Literacy's falling coin jar, Debate Duel's growing star row, or Career
// Explorer's card flip.
// Architecture: fully self-contained StatefulWidget.
// ────────────────────────────────────────────────────────────────────────────

enum _Phase { intro, playing, correct, wrong, streak, zoneDone, victory }

enum _Kind { dayOrder, simple }

/// One picture in the "Balance Your Day" ordering sequence. [order] is the
/// 1-based correct position; the picture itself carries no label (see the
/// doc comment above).
class _DayStep {
  final String emoji;
  final int order;
  const _DayStep({required this.emoji, required this.order});
}

class _SimpleQ {
  final String prompt;
  final List<String> choices; // [0] correct
  const _SimpleQ({required this.prompt, required this.choices});
}

class _Zone {
  final String name;
  final _Kind kind;
  final List<_DayStep> daySteps;
  final List<_SimpleQ> simple;
  const _Zone.dayOrder(this.name, this.daySteps)
      : kind = _Kind.dayOrder,
        simple = const [];
  const _Zone.simple(this.name, this.simple)
      : kind = _Kind.simple,
        daySteps = const [];

  int get length => kind == _Kind.dayOrder ? daySteps.length : simple.length;
}

class HealthyLivingGame extends StatefulWidget {
  final GameConfig config;
  final dynamic user;
  const HealthyLivingGame({super.key, required this.config, this.user});

  @override
  State<HealthyLivingGame> createState() => _HLState();
}

class _HLState extends State<HealthyLivingGame> with TickerProviderStateMixin {
  static const _zoneTemplates = [
    _Zone.dayOrder('Balance Your Day', [
      _DayStep(emoji: '🌅', order: 1), // Wake up
      _DayStep(emoji: '🍳', order: 2), // Breakfast
      _DayStep(emoji: '🏫', order: 3), // School / learning
      _DayStep(emoji: '⚽', order: 4), // Play / exercise
      _DayStep(emoji: '🌙', order: 5), // Bedtime / sleep
    ]),
    _Zone.simple('Nutrition & Exercise', [
      _SimpleQ(
        prompt: 'Which food group should make up a big part of a healthy plate?',
        choices: ['Fruits and vegetables', 'Sweets and chips', 'Fizzy drinks'],
      ),
      _SimpleQ(
        prompt: 'Why is regular exercise important?',
        choices: ['It keeps your heart, muscles and body strong', 'It makes you tired for no reason', 'It has no real benefit'],
      ),
      _SimpleQ(
        prompt: 'Which is a healthy snack choice?',
        choices: ['A piece of fruit', 'A packet of sweets', 'A can of cooldrink'],
      ),
      _SimpleQ(
        prompt: 'How often should you try to be physically active?',
        choices: ['Most days of the week', 'Once a year', 'Never'],
      ),
      _SimpleQ(
        prompt: 'Eating too much sugary food can lead to...?',
        choices: ['Health problems like tooth decay and weight gain', 'Becoming stronger', 'Better concentration'],
      ),
    ]),
    _Zone.simple('Hygiene & Sleep', [
      _SimpleQ(
        prompt: 'Washing your hands regularly helps prevent...?',
        choices: ['The spread of germs and illness', 'You from growing taller', 'You from feeling hungry'],
      ),
      _SimpleQ(
        prompt: 'When should you wash your hands?',
        choices: ['Before eating and after using the toilet', 'Only once a week', 'Only when they look dirty'],
      ),
      _SimpleQ(
        prompt: 'Why is a regular sleep routine important?',
        choices: ['It helps your body and brain rest and recover', 'It makes you weaker', 'It has no effect on health'],
      ),
      _SimpleQ(
        prompt: 'Brushing your teeth twice a day helps prevent...?',
        choices: ['Cavities and gum problems', 'Your teeth from being white', 'Nothing important'],
      ),
      _SimpleQ(
        prompt: 'What is a good habit before going to bed?',
        choices: ['Turning off screens and relaxing', 'Eating lots of sugar', 'Watching exciting videos for hours'],
      ),
    ]),
    _Zone.simple('Mind & Emotions', [
      _SimpleQ(
        prompt: 'Mental health is about...?',
        choices: [
          'How you think, feel and cope with everyday life',
          'Only about physical fitness',
          'Something that never changes',
        ],
      ),
      _SimpleQ(
        prompt: 'Which is a healthy way to express your feelings?',
        choices: [
          'Talking about how you feel with someone you trust',
          'Hiding your feelings and never expressing them',
          'Hurting others when you are upset',
        ],
      ),
      _SimpleQ(
        prompt: 'Taking deep breaths when you feel anxious can help you...?',
        choices: ['Feel calmer and more in control', 'Feel more anxious', 'Fall asleep instantly'],
      ),
      _SimpleQ(
        prompt: 'Spending time on hobbies you enjoy is good for your...?',
        choices: ['Mental and emotional wellbeing', 'Physical strength only', 'School marks only'],
      ),
      _SimpleQ(
        prompt: 'If a friend seems sad or worried, what is a caring thing to do?',
        choices: ['Ask if they are okay and listen to them', 'Ignore them completely', 'Make fun of them'],
      ),
    ]),
  ];

  static const _wrongReactions = [
    'Not quite -- which choice is really the healthiest?',
    'Hmm, think about what your body and mind actually need!',
    'Close -- try the option that helps you feel your best!',
  ];

  static const _bg1 = Color(0xFF102A2E);
  static const _bg2 = Color(0xFF1E4F52);
  static const _card = Color(0xFF1B4548);
  static const _gold = Color(0xFF5FD8C7);

  late AnimationController _ambientCtrl;
  late AnimationController _fadeCtrl;
  late AnimationController _flashCtrl;
  late AnimationController _burstCtrl;
  late AnimationController _shakeCtrl;

  late Animation<double> _ambientAnim;
  late Animation<double> _fadeAnim;
  late Animation<double> _flashAnim;
  late Animation<double> _burstAnim;
  late Animation<double> _shakeAnim;

  int _zoneIdx = 0;
  int _qIdx = 0;
  int _correctCount = 0;
  int _streak = 0;
  int _totalXP = 0;
  // Which day-step orders have been correctly tapped so far in Zone 1 --
  // _qIdx alone can't say WHICH steps are done, since the player can try
  // them in any screen order even though only one is accepted at a time.
  final Set<int> _placedStepOrders = {};
  // Unlike _phase == _Phase.wrong (cleared automatically when _advance()
  // moves on), a bad day-step tap never changes _phase -- see
  // _onDayStepTap -- so this drives the "try again" hint on its own timer.
  bool _dayOrderShowHint = false;

  _Phase _phase = _Phase.intro;
  int? _selectedIndex;

  String _wrongReaction = '';

  final _rng = math.Random();

  // Shuffled per-session copy of _zoneTemplates: preserves zone order but
  // randomizes question order within each zone across replays.
  late final List<_Zone> _zones = _zoneTemplates.map((z) {
    return z.kind == _Kind.dayOrder
        ? _Zone.dayOrder(z.name, List<_DayStep>.from(z.daySteps)..shuffle(_rng))
        : _Zone.simple(z.name, List<_SimpleQ>.from(z.simple)..shuffle(_rng));
  }).toList();

  String get _uid => (widget.user?.uid as String?) ?? '';

  int get _totalQuestions => _zones.fold<int>(0, (sum, z) => sum + z.length);

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
    _delayed(700, _startGame);
  }

  void _initAnims() {
    _ambientCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 6))
      ..repeat(reverse: true);
    _ambientAnim = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _ambientCtrl, curve: Curves.easeInOut));

    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);

    _flashCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _flashAnim = CurvedAnimation(parent: _flashCtrl, curve: Curves.easeOut);

    _burstCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
    _burstAnim = CurvedAnimation(parent: _burstCtrl, curve: Curves.easeOut);

    _shakeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
    _shakeAnim = CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    for (final timer in List<Timer>.from(_pendingTimers)) {
      timer.cancel();
    }
    _pendingTimers.clear();
    _ambientCtrl.dispose();
    _fadeCtrl.dispose();
    _flashCtrl.dispose();
    _burstCtrl.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }

  void _startGame() {
    setState(() {
      _zoneIdx = 0;
      _qIdx = 0;
      _correctCount = 0;
      _streak = 0;
      _totalXP = 0;
      _placedStepOrders.clear();
      _dayOrderShowHint = false;
      _phase = _Phase.playing;
      _selectedIndex = null;
    });
    _fadeCtrl.forward(from: 0);
  }

  Object? _cachedQ;
  List<String> _cachedChoices = [];

  List<String> _getShuffledChoices(dynamic q) {
    if (!identical(_cachedQ, q)) {
      _cachedQ = q;
      _cachedChoices = List<String>.from(q.choices as List<String>)..shuffle(_rng);
    }
    return _cachedChoices;
  }

  /// Handles a tap on a day-step picture. Correct routes through the same
  /// _applyAnswerResult/_advance path every MCQ answer uses (_qIdx tracks
  /// "how many steps placed so far"). Wrong deliberately skips both -- like
  /// the water cycle's drag-to-label zone, a bad tap should just bounce
  /// back and let the child try again among the remaining pictures, not
  /// consume one of the 5 ordering slots.
  void _onDayStepTap(_DayStep step) {
    if (_phase != _Phase.playing) return;
    final expectedOrder = _qIdx + 1;
    if (step.order == expectedOrder) {
      setState(() => _placedStepOrders.add(step.order));
      _applyAnswerResult(true);
    } else {
      unawaited(GameFeedbackService.incorrect());
      setState(() {
        _streak = 0;
        _wrongReaction = _wrongReactions[_rng.nextInt(_wrongReactions.length)];
        _dayOrderShowHint = true;
      });
      _shakeCtrl.forward(from: 0);
      _delayed(1500, () {
        if (mounted) setState(() => _dayOrderShowHint = false);
      });
    }
  }

  void _onSimpleAnswer(int index) {
    if (_phase != _Phase.playing) return;
    final q = _zones[_zoneIdx].simple[_qIdx];
    final choices = _getShuffledChoices(q);
    final isCorrect = choices[index] == q.choices[0];
    setState(() => _selectedIndex = index);
    _applyAnswerResult(isCorrect);
  }

  void _applyAnswerResult(bool isCorrect) {
    unawaited(
        isCorrect ? GameFeedbackService.correct() : GameFeedbackService.incorrect());
    setState(() {
      if (isCorrect) {
        _correctCount++;
        _streak++;
        _totalXP += 10;
      } else {
        _streak = 0;
        _totalXP += 2;
        _wrongReaction = _wrongReactions[_rng.nextInt(_wrongReactions.length)];
      }
      _phase = isCorrect ? _Phase.correct : _Phase.wrong;
    });

    if (isCorrect) {
      _flashCtrl.forward(from: 0);
      final isStreak = _streak > 0 && _streak % 3 == 0;
      if (isStreak) {
        _delayed(300, () {
          setState(() => _phase = _Phase.streak);
          _burstCtrl.forward(from: 0);
          _delayed(1600, _advance);
        });
      } else {
        _delayed(1200, _advance);
      }
    } else {
      _shakeCtrl.forward(from: 0);
      _delayed(1800, _advance);
    }
  }

  void _advance() {
    if (!mounted) return;
    final zone = _zones[_zoneIdx];
    final next = _qIdx + 1;

    if (next >= zone.length) {
      if (_zoneIdx + 1 >= _zones.length) {
        _persistSession();
        setState(() => _phase = _Phase.victory);
      } else {
        setState(() => _phase = _Phase.zoneDone);
        _delayed(2000, () {
          setState(() {
            _zoneIdx++;
            _qIdx = 0;
            _selectedIndex = null;
            _phase = _Phase.playing;
          });
          _fadeCtrl.forward(from: 0);
        });
      }
    } else {
      setState(() {
        _qIdx = next;
        _selectedIndex = null;
        _phase = _Phase.playing;
      });
      _fadeCtrl.forward(from: 0);
    }
  }

  void _persistSession() {
    final total = _totalQuestions;
    final accuracy = total > 0 ? _correctCount / total : 0.0;
    final isPerfect = _correctCount == total;
    final isWin = _correctCount > total / 2;
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
      result: isWin ? 'win' : 'complete',
      metadata: {
        'topicId': widget.config.topicId,
        'subtopicId': widget.config.subtopicId,
        'correctCount': _correctCount,
        'totalQuestions': total,
      },
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
        total: _totalQuestions,
        totalXP: _totalXP,
        onReplay: _startGame,
        onExit: () => Navigator.of(context).pop(),
      );
    }

    final zone = _zones[_zoneIdx];
    final total = _totalQuestions;
    final completedSteps =
        _zones.take(_zoneIdx).fold<int>(0, (sum, z) => sum + z.length) + _qIdx;
    final revealed = _phase == _Phase.correct || _phase == _Phase.wrong;

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_bg1, _bg2],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _ambientAnim,
              builder: (context, _) =>
                  CustomPaint(painter: _RippleBgPainter(_ambientAnim.value)),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _WellnessHeader(
                  zoneName: zone.name,
                  zoneIdx: _zoneIdx,
                  totalZones: _zones.length,
                  completedSteps: completedSteps,
                  totalSteps: total,
                ),
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: zone.kind == _Kind.dayOrder
                          ? _buildDayOrderZone(zone)
                          : _buildSimpleQuestion(zone.simple[_qIdx], revealed),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_phase == _Phase.correct)
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _flashAnim,
                builder: (context, _) => Opacity(
                  opacity: (1 - _flashAnim.value).clamp(0.0, 1.0) * 0.3,
                  child: Container(color: _gold),
                ),
              ),
            ),
          if (_phase == _Phase.streak)
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _burstAnim,
                builder: (context, _) => CustomPaint(
                  painter: _ConfettiShowerPainter(_burstAnim.value),
                  size: Size.infinite,
                ),
              ),
            ),
          if (_phase == _Phase.zoneDone)
            _ZoneDoneOverlay(
              completedZoneName: zone.name,
              nextZoneName: _zoneIdx + 1 < _zones.length ? _zones[_zoneIdx + 1].name : null,
            ),
        ],
      ),
    );
  }

  Widget _buildDayOrderZone(_Zone zone) {
    final placedInOrder = zone.daySteps
        .where((s) => _placedStepOrders.contains(s.order))
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    return Column(
      children: [
        const SizedBox(height: 8),
        const Text(
          'Tap the pictures in the order of your day.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 18),
        AnimatedBuilder(
          animation: _shakeAnim,
          builder: (context, _) {
            final dx = _shakeAnim.value > 0
                ? math.sin(_shakeAnim.value * math.pi * 6) * 6 * _shakeAnim.value
                : 0.0;
            return Transform.translate(
              offset: Offset(dx, 0),
              child: Wrap(
                spacing: 14,
                runSpacing: 14,
                alignment: WrapAlignment.center,
                children: [
                  for (final step in zone.daySteps)
                    _DayStepTile(
                      key: ValueKey('day_step_${step.order}'),
                      step: step,
                      placed: _placedStepOrders.contains(step.order),
                      onTap: () => _onDayStepTap(step),
                    ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        if (placedInOrder.isNotEmpty) ...[
          Text(
            'Your day so far:',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (var i = 0; i < placedInOrder.length; i++) ...[
                if (i > 0) const Text('→', style: TextStyle(color: Colors.white54, fontSize: 16)),
                Text(placedInOrder[i].emoji, style: const TextStyle(fontSize: 22)),
              ],
            ],
          ),
        ],
        if (_dayOrderShowHint)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              '$_wrongReaction Not that one yet -- try a different picture.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSimpleQuestion(_SimpleQ q, bool revealed) {
    final choices = _getShuffledChoices(q);
    return Column(
      children: [
        const SizedBox(height: 12),
        Text(
          q.prompt,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 22),
        AnimatedBuilder(
          animation: _shakeAnim,
          builder: (context, _) {
            final dx = _phase == _Phase.wrong
                ? math.sin(_shakeAnim.value * math.pi * 6) * 6
                : 0.0;
            return Transform.translate(
              offset: Offset(dx, 0),
              child: Wrap(
                spacing: 14,
                runSpacing: 14,
                alignment: WrapAlignment.center,
                children: [
                  for (var i = 0; i < choices.length; i++)
                    _SimpleTile(
                      label: choices[i],
                      selected: _selectedIndex == i,
                      isCorrect: choices[i] == q.choices[0],
                      revealed: revealed,
                      onTap: () => _onSimpleAnswer(i),
                    ),
                ],
              ),
            );
          },
        ),
        if (_phase == _Phase.wrong)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              '$_wrongReaction The answer was ${q.choices[0]}.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        const SizedBox(height: 20),
      ],
    );
  }
}

// ── Day-step tile (Balance Your Day picture, no caption) ────────────────────

class _DayStepTile extends StatelessWidget {
  final _DayStep step;
  final bool placed;
  final VoidCallback onTap;
  const _DayStepTile({super.key, required this.step, required this.placed, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: placed ? null : onTap,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: placed ? _HLState._gold.withValues(alpha: 0.25) : _HLState._card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: placed ? _HLState._gold : Colors.white24,
            width: placed ? 2.5 : 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: placed ? 0.55 : 1.0,
              child: Text(step.emoji, style: const TextStyle(fontSize: 34)),
            ),
            if (placed)
              const Positioned(
                bottom: 4,
                right: 4,
                child: Icon(Icons.check_circle, color: Color(0xFF4CAF7D), size: 18),
              ),
          ],
        ),
      ),
    );
  }
}


// ── Simple tile (MCQ) ────────────────────────────────────────────────────────

class _SimpleTile extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isCorrect;
  final bool revealed;
  final VoidCallback onTap;
  const _SimpleTile({
    required this.label,
    required this.selected,
    required this.isCorrect,
    required this.revealed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color fill = _HLState._card;
    if (revealed && isCorrect) fill = const Color(0xFF4CAF7D);
    if (revealed && selected && !isCorrect) fill = const Color(0xFFE05656);

    return GestureDetector(
      onTap: revealed ? null : onTap,
      child: Container(
        constraints: const BoxConstraints(minWidth: 90, maxWidth: 300),
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _HLState._gold.withValues(alpha: 0.8), width: 2),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

// ── Painters ─────────────────────────────────────────────────────────────────

class _RippleBgPainter extends CustomPainter {
  final double t;
  const _RippleBgPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _HLState._gold.withValues(alpha: 0.04 + 0.03 * t)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final center = Offset(size.width / 2, size.height * 0.3);
    for (var i = 0; i < 3; i++) {
      canvas.drawCircle(center, 40 + i * 30 + t * 12, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RippleBgPainter oldDelegate) => oldDelegate.t != t;
}

class _ConfettiShowerPainter extends CustomPainter {
  final double t;
  const _ConfettiShowerPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(714);
    for (var i = 0; i < 18; i++) {
      final startX = rng.nextDouble() * size.width;
      final speed = 0.5 + rng.nextDouble() * 0.6;
      final y = (t * speed) * (size.height + 40) - 20;
      final x = startX + math.sin((t * 6) + i) * 12;
      final paint = Paint()
        ..color = _HLState._gold.withValues(alpha: (1 - t).clamp(0.0, 1.0));
      canvas.drawCircle(Offset(x, y), 3, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiShowerPainter oldDelegate) => oldDelegate.t != t;
}

// ── Header / progress ────────────────────────────────────────────────────────

class _WellnessHeader extends StatelessWidget {
  final String zoneName;
  final int zoneIdx;
  final int totalZones;
  final int completedSteps;
  final int totalSteps;
  const _WellnessHeader({
    required this.zoneName,
    required this.zoneIdx,
    required this.totalZones,
    required this.completedSteps,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        children: [
          Row(
            children: [
              const Text('🏃', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  children: [
                    Text('Zone ${zoneIdx + 1}/$totalZones',
                        style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    Text(
                      zoneName,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 30),
            ],
          ),
          const SizedBox(height: 8),
          _WellnessTrail(completed: completedSteps, total: totalSteps),
        ],
      ),
    );
  }
}

class _WellnessTrail extends StatelessWidget {
  final int completed;
  final int total;
  const _WellnessTrail({required this.completed, required this.total});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 22,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          Container(
            height: 3,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            color: Colors.white24,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < total; i++)
                Text(
                  i < completed ? '🏃' : '·',
                  style: TextStyle(
                    fontSize: i < completed ? 12 : 10,
                    color: i < completed ? null : Colors.white38,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ZoneDoneOverlay extends StatelessWidget {
  final String completedZoneName;
  final String? nextZoneName;
  const _ZoneDoneOverlay({required this.completedZoneName, required this.nextZoneName});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black45,
        alignment: Alignment.center,
        child: Container(
          padding: const EdgeInsets.all(24),
          margin: const EdgeInsets.symmetric(horizontal: 40),
          decoration: BoxDecoration(
            color: _HLState._card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _HLState._gold, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🏃', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 8),
              Text('$completedZoneName complete!',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
              if (nextZoneName != null) ...[
                const SizedBox(height: 6),
                Text('Next: $nextZoneName', style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _IntroScreen extends StatelessWidget {
  const _IntroScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_HLState._bg1, _HLState._bg2],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🏃🧘', style: TextStyle(fontSize: 44)),
                  SizedBox(height: 16),
                  Text(
                    'Healthy Living',
                    style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Explore physical and mental health — exercise, nutrition and mindfulness!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  SizedBox(height: 24),
                  CircularProgressIndicator(color: _HLState._gold),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VictoryScreen extends StatelessWidget {
  final int correctCount;
  final int total;
  final int totalXP;
  final VoidCallback onReplay;
  final VoidCallback onExit;
  const _VictoryScreen({
    required this.correctCount,
    required this.total,
    required this.totalXP,
    required this.onReplay,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (correctCount / total * 100).round() : 0;
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_HLState._bg1, _HLState._bg2],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🏆🧘', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  const Text('Wellness Champion!',
                      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  Text('$correctCount / $total correct ($pct%)',
                      style: const TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('+$totalXP XP',
                      style: const TextStyle(color: _HLState._gold, fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: onReplay,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _HLState._card,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    ),
                    child: const Text('Play Again'),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: onExit,
                    child: const Text('Exit', style: TextStyle(color: Colors.white70)),
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
