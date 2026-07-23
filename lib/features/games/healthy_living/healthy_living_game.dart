import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/game_session_model.dart';
import '../core/game_config.dart';
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
// 4 Zones (5 questions each = 20 total):
//   1. Balance Your Day    — given a health choice, tap the healthiest
//      option; a slowly "breathing" (pulsing) wellness circle gains an
//      orbiting habit icon in a fixed slot around it for each correct pick
//   2. Nutrition & Exercise  — recall MCQ
//   3. Hygiene & Sleep       — recall MCQ
//   4. Mind & Emotions       — recall MCQ
//
// Structurally distinct from every prior engine: Zone 1's breathing
// central circle with icons accumulating in fixed orbit slots around it
// is a new combination -- unlike Financial Literacy's falling coin jar,
// Debate Duel's growing star row, or Career Explorer's card flip.
// Architecture: fully self-contained StatefulWidget.
// ────────────────────────────────────────────────────────────────────────────

enum _Phase { intro, playing, correct, wrong, streak, zoneDone, victory }

enum _Kind { orbit, simple }

class _OrbitQ {
  final String prompt;
  final String icon;
  final List<String> choices; // [0] correct (healthiest choice)
  const _OrbitQ({required this.prompt, required this.icon, required this.choices});
}

class _SimpleQ {
  final String prompt;
  final List<String> choices; // [0] correct
  const _SimpleQ({required this.prompt, required this.choices});
}

class _Zone {
  final String name;
  final _Kind kind;
  final List<_OrbitQ> orbit;
  final List<_SimpleQ> simple;
  const _Zone.orbit(this.name, this.orbit)
      : kind = _Kind.orbit,
        simple = const [];
  const _Zone.simple(this.name, this.simple)
      : kind = _Kind.simple,
        orbit = const [];

  int get length => kind == _Kind.orbit ? orbit.length : simple.length;
}

class HealthyLivingGame extends StatefulWidget {
  final GameConfig config;
  final dynamic user;
  const HealthyLivingGame({super.key, required this.config, this.user});

  @override
  State<HealthyLivingGame> createState() => _HLState();
}

class _HLState extends State<HealthyLivingGame> with TickerProviderStateMixin {
  static const _zones = [
    _Zone.orbit('Balance Your Day', [
      _OrbitQ(
        prompt: 'Which is the healthiest way to start your day?',
        icon: '🍽️',
        choices: [
          'Eating a good breakfast and brushing your teeth',
          'Skipping breakfast to sleep a bit longer',
          'Eating sweets for breakfast',
        ],
      ),
      _OrbitQ(
        prompt: 'Which drink is best for keeping your body hydrated?',
        icon: '💧',
        choices: ['Water', 'Fizzy cooldrink', 'Sugary juice'],
      ),
      _OrbitQ(
        prompt: 'How much sleep does a Grade 4 learner usually need each night?',
        icon: '😴',
        choices: ['About 9 to 11 hours', 'About 3 to 4 hours', 'It does not matter at all'],
      ),
      _OrbitQ(
        prompt: 'Which of these is the best way to manage stress or big feelings?',
        icon: '🧘',
        choices: [
          'Taking slow, deep breaths and talking to someone you trust',
          'Bottling up your feelings and never talking about them',
          'Shouting at whoever is nearby',
        ],
      ),
      _OrbitQ(
        prompt: 'Which activity helps keep your body strong and healthy?',
        icon: '🏃',
        choices: [
          'Regular exercise, like walking, running or playing sport',
          'Sitting still all day every day',
          'Watching TV for many hours without moving',
        ],
      ),
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
  late AnimationController _breatheCtrl;
  late AnimationController _iconPopCtrl;

  late Animation<double> _ambientAnim;
  late Animation<double> _fadeAnim;
  late Animation<double> _flashAnim;
  late Animation<double> _burstAnim;
  late Animation<double> _shakeAnim;
  late Animation<double> _breatheAnim;

  int _zoneIdx = 0;
  int _qIdx = 0;
  int _correctCount = 0;
  int _streak = 0;
  int _totalXP = 0;
  int _filledSlots = 0;

  _Phase _phase = _Phase.intro;
  int? _selectedIndex;

  String _wrongReaction = '';

  final _rng = math.Random();

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

    _breatheCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000))
      ..repeat(reverse: true);
    _breatheAnim = CurvedAnimation(parent: _breatheCtrl, curve: Curves.easeInOut);

    _iconPopCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
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
    _breatheCtrl.dispose();
    _iconPopCtrl.dispose();
    super.dispose();
  }

  void _startGame() {
    setState(() {
      _zoneIdx = 0;
      _qIdx = 0;
      _correctCount = 0;
      _streak = 0;
      _totalXP = 0;
      _filledSlots = 0;
      _phase = _Phase.playing;
      _selectedIndex = null;
    });
    _fadeCtrl.forward(from: 0);
  }

  void _onOrbitAnswer(int index) {
    if (_phase != _Phase.playing) return;
    final isCorrect = index == 0;
    setState(() => _selectedIndex = index);
    if (isCorrect) {
      setState(() => _filledSlots++);
      _iconPopCtrl.forward(from: 0);
    }
    _applyAnswerResult(isCorrect);
  }

  void _onSimpleAnswer(int index) {
    if (_phase != _Phase.playing) return;
    final isCorrect = index == 0;
    setState(() => _selectedIndex = index);
    _applyAnswerResult(isCorrect);
  }

  void _applyAnswerResult(bool isCorrect) {
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
                      child: zone.kind == _Kind.orbit
                          ? _buildOrbitQuestion(zone.orbit[_qIdx], revealed)
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

  Widget _buildOrbitQuestion(_OrbitQ q, bool revealed) {
    final icons = _zones[0].orbit.map((o) => o.icon).toList();
    return Column(
      children: [
        const SizedBox(height: 8),
        _WellnessCircle(
          filledSlots: _filledSlots,
          icons: icons,
          breatheAnim: _breatheAnim,
          popCtrl: _iconPopCtrl,
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0A1E20),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _gold.withValues(alpha: 0.5), width: 2),
          ),
          child: Text(
            q.prompt,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 16),
        AnimatedBuilder(
          animation: _shakeAnim,
          builder: (context, _) {
            final dx = _phase == _Phase.wrong
                ? math.sin(_shakeAnim.value * math.pi * 6) * 6
                : 0.0;
            return Transform.translate(
              offset: Offset(dx, 0),
              child: Column(
                children: [
                  for (var i = 0; i < q.choices.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ChoiceTile(
                        label: q.choices[i],
                        selected: _selectedIndex == i,
                        isCorrect: i == 0,
                        revealed: revealed,
                        onTap: () => _onOrbitAnswer(i),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        if (_phase == _Phase.wrong)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '$_wrongReaction The healthiest choice was: "${q.choices[0]}"',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSimpleQuestion(_SimpleQ q, bool revealed) {
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
                  for (var i = 0; i < q.choices.length; i++)
                    _SimpleTile(
                      label: q.choices[i],
                      selected: _selectedIndex == i,
                      isCorrect: i == 0,
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

// ── Wellness circle (breathing centre + orbiting habit icons) ──────────────

class _WellnessCircle extends StatelessWidget {
  final int filledSlots;
  final List<String> icons;
  final Animation<double> breatheAnim;
  final AnimationController popCtrl;
  const _WellnessCircle({
    required this.filledSlots,
    required this.icons,
    required this.breatheAnim,
    required this.popCtrl,
  });

  static const _radius = 68.0;
  static const _boxSize = 190.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _boxSize,
      height: _boxSize,
      child: AnimatedBuilder(
        animation: Listenable.merge([breatheAnim, popCtrl]),
        builder: (context, _) {
          final breathe = 0.92 + breatheAnim.value * 0.16;
          final popT = Curves.easeOutBack.transform(popCtrl.value.clamp(0.0, 1.0));
          return Stack(
            alignment: Alignment.center,
            children: [
              // Breathing central circle
              Transform.scale(
                scale: breathe,
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _HLState._gold.withValues(alpha: 0.22),
                    border: Border.all(color: _HLState._gold, width: 2.5),
                  ),
                  alignment: Alignment.center,
                  child: const Text('🧘', style: TextStyle(fontSize: 30)),
                ),
              ),
              // Orbiting habit icons, one per filled slot
              for (var i = 0; i < filledSlots; i++)
                Builder(builder: (context) {
                  final angle = -math.pi / 2 + i * (2 * math.pi / icons.length);
                  final isNewest = i == filledSlots - 1;
                  final scale = isNewest ? popT : 1.0;
                  final dx = math.cos(angle) * _radius;
                  final dy = math.sin(angle) * _radius;
                  return Transform.translate(
                    offset: Offset(dx, dy),
                    child: Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _HLState._card,
                          border: Border.all(color: _HLState._gold, width: 1.5),
                        ),
                        alignment: Alignment.center,
                        child: Text(icons[i], style: const TextStyle(fontSize: 16)),
                      ),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}

// ── Choice tile (scenario answers, full-width) ──────────────────────────────

class _ChoiceTile extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isCorrect;
  final bool revealed;
  final VoidCallback onTap;
  const _ChoiceTile({
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
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 56),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _HLState._gold.withValues(alpha: 0.8), width: 2),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
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
