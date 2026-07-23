import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/game_session_model.dart';
import '../core/game_config.dart';
import '../core/game_session_persistence.dart';

// ────────────────────────────────────────────────────────────────────────────
// Environmental Awareness — Grade 4 Life Skills: conservation, reduce/
// reuse/recycle, sustainability, and pollution
//
// NOTE: this is a DIFFERENT engine from runner_collector/ (engineType
// 'runnerCollector'), which is a shared generic engine still used by 13
// other catalog entries. This engine (engineType 'environmentalAwareness')
// is registered ONLY against ls_g4_environment.
//
// 4 Zones (5 questions each = 20 total):
//   1. Clean Up the Park  — given a conservation scenario, tap the best
//      eco-friendly action; each correct answer sends one piece of
//      litter flying into a recycling bin, and the whole scene's
//      background gradually shifts from a dull, littered brown to a
//      vibrant clean green as the park is restored
//   2. Reduce, Reuse, Recycle    — recall MCQ
//   3. Conservation & Sustainability — recall MCQ
//   4. Pollution & Our Impact    — recall MCQ
//
// Structurally distinct from every prior engine: Zone 1 is the first
// SUBTRACTIVE mechanic -- clutter disappears and the whole page
// background continuously interpolates with progress -- unlike every
// earlier ADDITIVE accumulation (Social Skills' bridge planks, Healthy
// Living's orbiting icons, Financial Literacy's falling coins). This is
// also the 45th and final Grade 4 game in the full engagement.
// Architecture: fully self-contained StatefulWidget.
// ────────────────────────────────────────────────────────────────────────────

enum _Phase { intro, playing, correct, wrong, streak, zoneDone, victory }

enum _Kind { cleanup, simple }

class _CleanupQ {
  final String prompt;
  final List<String> choices; // [0] correct (best eco-friendly action)
  const _CleanupQ({required this.prompt, required this.choices});
}

class _SimpleQ {
  final String prompt;
  final List<String> choices; // [0] correct
  const _SimpleQ({required this.prompt, required this.choices});
}

class _Zone {
  final String name;
  final _Kind kind;
  final List<_CleanupQ> cleanup;
  final List<_SimpleQ> simple;
  const _Zone.cleanup(this.name, this.cleanup)
      : kind = _Kind.cleanup,
        simple = const [];
  const _Zone.simple(this.name, this.simple)
      : kind = _Kind.simple,
        cleanup = const [];

  int get length => kind == _Kind.cleanup ? cleanup.length : simple.length;
}

class EnvironmentalAwarenessGame extends StatefulWidget {
  final GameConfig config;
  final dynamic user;
  const EnvironmentalAwarenessGame({super.key, required this.config, this.user});

  @override
  State<EnvironmentalAwarenessGame> createState() => _EAState();
}

class _EAState extends State<EnvironmentalAwarenessGame> with TickerProviderStateMixin {
  static const _zones = [
    _Zone.cleanup('Clean Up the Park', [
      _CleanupQ(
        prompt: 'You finish a plastic bottle at the park. What should you do with it?',
        choices: [
          'Put it in the recycling bin',
          'Throw it on the ground',
          'Leave it on a bench for someone else to deal with',
        ],
      ),
      _CleanupQ(
        prompt: 'Your school is looking for ways to save water. Which is the best idea?',
        choices: [
          'Fix leaking taps and turn off the tap while brushing your teeth',
          'Leave taps running all day',
          'Use as much water as possible',
        ],
      ),
      _CleanupQ(
        prompt: 'Which of these helps protect trees and forests?',
        choices: [
          'Recycling paper and planting new trees',
          'Cutting down trees for no reason',
          'Burning rubbish in the forest',
        ],
      ),
      _CleanupQ(
        prompt: 'What is the best way to reduce electricity use at home?',
        choices: [
          'Switching off lights and appliances when not in use',
          'Leaving all the lights on all day and night',
          'Using more electrical devices than needed',
        ],
      ),
      _CleanupQ(
        prompt: 'Which of these actions helps keep rivers and oceans clean?',
        choices: [
          'Not littering and picking up rubbish near water',
          'Throwing rubbish into rivers',
          'Pouring chemicals into water sources',
        ],
      ),
    ]),
    _Zone.simple('Reduce, Reuse, Recycle', [
      _SimpleQ(
        prompt: "What does 'reduce' mean in conservation?",
        choices: ['Using less of something, like water or electricity', 'Using as much as you want', 'Throwing things away faster'],
      ),
      _SimpleQ(
        prompt: 'Reusing an item means...?',
        choices: ['Using it again instead of throwing it away', 'Buying a new one every time', 'Throwing it in the ocean'],
      ),
      _SimpleQ(
        prompt: 'Which of these can usually be recycled?',
        choices: ['Paper, glass, plastic and cans', 'Food waste only', 'Nothing can be recycled'],
      ),
      _SimpleQ(
        prompt: 'Why is recycling important?',
        choices: ['It reduces waste and saves natural resources', 'It creates more pollution', 'It has no benefit at all'],
      ),
      _SimpleQ(
        prompt: 'An example of reusing is...?',
        choices: [
          'Using an old jar to store things instead of throwing it away',
          'Throwing away a jar after one use',
          'Buying a new jar every week',
        ],
      ),
    ]),
    _Zone.simple('Conservation & Sustainability', [
      _SimpleQ(
        prompt: "What does 'sustainability' mean?",
        choices: [
          'Using resources in a way that protects them for the future',
          'Using up all resources as fast as possible',
          'Ignoring the environment completely',
        ],
      ),
      _SimpleQ(
        prompt: 'Which is a renewable source of energy?',
        choices: ['Solar power from the sun', 'Coal', 'Oil'],
      ),
      _SimpleQ(
        prompt: 'Why do we need to protect endangered animals?',
        choices: [
          "To keep them from disappearing forever and protect nature's balance",
          'Because it does not matter if they disappear',
          'Endangered animals are not important',
        ],
      ),
      _SimpleQ(
        prompt: 'Planting trees helps the environment because...?',
        choices: ['Trees produce oxygen and support wildlife', 'Trees have no environmental benefit', 'Trees only take up space'],
      ),
      _SimpleQ(
        prompt: 'Walking, cycling, or carpooling instead of driving alone helps...?',
        choices: ['Reduce pollution and save fuel', 'Increase pollution', 'Waste more fuel'],
      ),
    ]),
    _Zone.simple('Pollution & Our Impact', [
      _SimpleQ(
        prompt: 'What is pollution?',
        choices: ['Harmful substances that damage air, water or land', 'Clean fresh air', 'Something that helps nature'],
      ),
      _SimpleQ(
        prompt: 'Which of these causes air pollution?',
        choices: ['Smoke from factories and vehicles', 'Fresh oxygen', 'Clean rainwater'],
      ),
      _SimpleQ(
        prompt: 'How can littering harm animals?',
        choices: ['Animals can get hurt or eat plastic waste by mistake', 'It helps animals build homes', 'It has no effect on animals'],
      ),
      _SimpleQ(
        prompt: 'What can YOU do to help reduce pollution?',
        choices: [
          'Recycle, reduce waste, and use less electricity and water',
          'Litter as much as possible',
          'Waste as many resources as you can',
        ],
      ),
      _SimpleQ(
        prompt: 'Why should everyone play a part in protecting the environment?',
        choices: [
          'Because our actions today affect the planet for future generations',
          'Because it does not matter what we do',
          'Only adults need to care about the environment',
        ],
      ),
    ]),
  ];

  static const _wrongReactions = [
    'Not quite -- which choice is best for our planet?',
    'Hmm, think about what an eco-champion would do!',
    'Close -- try the more sustainable choice!',
  ];

  // Dull, littered starting tones and vibrant, clean ending tones -- the
  // Scaffold background continuously interpolates between them as the
  // park is cleaned up.
  static const _dirtyBg1 = Color(0xFF463B2E);
  static const _dirtyBg2 = Color(0xFF5A4B38);
  static const _cleanBg1 = Color(0xFF123A22);
  static const _cleanBg2 = Color(0xFF1F6B3F);
  static const _card = Color(0xFF2A3B2E);
  static const _gold = Color(0xFF8BD17C);

  late AnimationController _fadeCtrl;
  late AnimationController _flashCtrl;
  late AnimationController _burstCtrl;
  late AnimationController _shakeCtrl;
  late AnimationController _cleanupCtrl;

  late Animation<double> _fadeAnim;
  late Animation<double> _flashAnim;
  late Animation<double> _burstAnim;
  late Animation<double> _shakeAnim;

  int _zoneIdx = 0;
  int _qIdx = 0;
  int _correctCount = 0;
  int _streak = 0;
  int _totalXP = 0;
  int _itemsCleaned = 0;

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
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);

    _flashCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _flashAnim = CurvedAnimation(parent: _flashCtrl, curve: Curves.easeOut);

    _burstCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
    _burstAnim = CurvedAnimation(parent: _burstCtrl, curve: Curves.easeOut);

    _shakeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
    _shakeAnim = CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut);

    _cleanupCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
  }

  @override
  void dispose() {
    for (final timer in List<Timer>.from(_pendingTimers)) {
      timer.cancel();
    }
    _pendingTimers.clear();
    _fadeCtrl.dispose();
    _flashCtrl.dispose();
    _burstCtrl.dispose();
    _shakeCtrl.dispose();
    _cleanupCtrl.dispose();
    super.dispose();
  }

  void _startGame() {
    setState(() {
      _zoneIdx = 0;
      _qIdx = 0;
      _correctCount = 0;
      _streak = 0;
      _totalXP = 0;
      _itemsCleaned = 0;
      _phase = _Phase.playing;
      _selectedIndex = null;
    });
    _fadeCtrl.forward(from: 0);
  }

  void _onCleanupAnswer(int index) {
    if (_phase != _Phase.playing) return;
    final isCorrect = index == 0;
    setState(() => _selectedIndex = index);
    if (isCorrect) {
      setState(() => _itemsCleaned++);
      _cleanupCtrl.forward(from: 0);
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

    // The whole scene's background continuously shifts from dull/littered
    // to vibrant/clean based on cleanup progress across all 20 questions
    // (not just zone 1) so the "restoration" reads across the whole game.
    final cleanFrac = (total > 0 ? completedSteps / total : 0.0).clamp(0.0, 1.0);
    final bg1 = Color.lerp(_dirtyBg1, _cleanBg1, cleanFrac)!;
    final bg2 = Color.lerp(_dirtyBg2, _cleanBg2, cleanFrac)!;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [bg1, bg2],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _ParkHeader(
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
                      child: zone.kind == _Kind.cleanup
                          ? _buildCleanupQuestion(zone.cleanup[_qIdx], revealed)
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
                  painter: _LeafShowerPainter(_burstAnim.value),
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

  Widget _buildCleanupQuestion(_CleanupQ q, bool revealed) {
    return Column(
      children: [
        const SizedBox(height: 8),
        _ParkScene(itemsCleaned: _itemsCleaned, cleanupCtrl: _cleanupCtrl),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF16220F).withValues(alpha: 0.85),
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
                        onTap: () => _onCleanupAnswer(i),
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
              '$_wrongReaction The best action was: "${q.choices[0]}"',
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

// ── Park scene (litter items fly away into the bin as it's cleaned) ────────

class _ParkScene extends StatelessWidget {
  final int itemsCleaned;
  final AnimationController cleanupCtrl;
  const _ParkScene({required this.itemsCleaned, required this.cleanupCtrl});

  static const _sceneSize = Size(240, 130);
  static const _litterIcons = ['🍾', '🥤', '🍟', '📰', '🥫'];
  static const _litterPositions = [
    Offset(16, 14),
    Offset(180, 10),
    Offset(50, 78),
    Offset(150, 88),
    Offset(96, 42),
  ];
  static const _binPosition = Offset(206, 96);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: cleanupCtrl,
      builder: (context, _) {
        final t = Curves.easeIn.transform(cleanupCtrl.value.clamp(0.0, 1.0));
        return SizedBox(
          width: _sceneSize.width,
          height: _sceneSize.height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Park ground
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _EAState._gold.withValues(alpha: 0.4), width: 1.5),
                  ),
                ),
              ),
              // Recycling bin, fixed in the corner
              Positioned(
                left: _binPosition.dx,
                top: _binPosition.dy,
                child: const Text('🗑️', style: TextStyle(fontSize: 26)),
              ),
              // Litter items: static if untouched, flying-away if newest
              // cleanup, invisible once fully cleaned.
              for (var i = 0; i < _litterIcons.length; i++)
                Builder(builder: (context) {
                  if (i < itemsCleaned - 1) return const SizedBox.shrink();
                  final original = _litterPositions[i];
                  final isAnimating = i == itemsCleaned - 1;
                  final pos = isAnimating
                      ? Offset.lerp(original, _binPosition, t)!
                      : original;
                  final scale = isAnimating ? (1 - t).clamp(0.0, 1.0) : 1.0;
                  final opacity = isAnimating ? (1 - t).clamp(0.0, 1.0) : 1.0;
                  return Positioned(
                    left: pos.dx,
                    top: pos.dy,
                    child: Opacity(
                      opacity: opacity,
                      child: Transform.scale(
                        scale: scale,
                        child: Text(_litterIcons[i], style: const TextStyle(fontSize: 22)),
                      ),
                    ),
                  );
                }),
            ],
          ),
        );
      },
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
    Color fill = _EAState._card;
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
          border: Border.all(color: _EAState._gold.withValues(alpha: 0.8), width: 2),
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
    Color fill = _EAState._card;
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
          border: Border.all(color: _EAState._gold.withValues(alpha: 0.8), width: 2),
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

class _LeafShowerPainter extends CustomPainter {
  final double t;
  const _LeafShowerPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(916);
    for (var i = 0; i < 18; i++) {
      final startX = rng.nextDouble() * size.width;
      final speed = 0.5 + rng.nextDouble() * 0.6;
      final y = (t * speed) * (size.height + 40) - 20;
      final x = startX + math.sin((t * 6) + i) * 12;
      final paint = Paint()
        ..color = _EAState._gold.withValues(alpha: (1 - t).clamp(0.0, 1.0));
      canvas.drawCircle(Offset(x, y), 3, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LeafShowerPainter oldDelegate) => oldDelegate.t != t;
}

// ── Header / progress ────────────────────────────────────────────────────────

class _ParkHeader extends StatelessWidget {
  final String zoneName;
  final int zoneIdx;
  final int totalZones;
  final int completedSteps;
  final int totalSteps;
  const _ParkHeader({
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
              const Text('♻️', style: TextStyle(fontSize: 22)),
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
          _ParkTrail(completed: completedSteps, total: totalSteps),
        ],
      ),
    );
  }
}

class _ParkTrail extends StatelessWidget {
  final int completed;
  final int total;
  const _ParkTrail({required this.completed, required this.total});

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
                  i < completed ? '♻️' : '·',
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
            color: _EAState._card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _EAState._gold, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('♻️', style: TextStyle(fontSize: 40)),
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
            colors: [_EAState._dirtyBg1, _EAState._dirtyBg2],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('♻️🌳', style: TextStyle(fontSize: 44)),
                  SizedBox(height: 16),
                  Text(
                    'Environmental Awareness',
                    style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Become an eco-champion — learn about conservation and sustainability!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  SizedBox(height: 24),
                  CircularProgressIndicator(color: _EAState._gold),
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
            colors: [_EAState._cleanBg1, _EAState._cleanBg2],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🏆♻️', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  const Text('Eco-Champion!',
                      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  Text('$correctCount / $total correct ($pct%)',
                      style: const TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('+$totalXP XP',
                      style: const TextStyle(color: _EAState._gold, fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: onReplay,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _EAState._card,
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
