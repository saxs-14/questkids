import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/game_session_model.dart';
import '../core/game_config.dart';
import '../core/game_session_persistence.dart';

// ────────────────────────────────────────────────────────────────────────────
// Life Cycles — Grade 4 Natural Sciences: life cycles of frogs, butterflies,
// chickens, plants and metamorphosis
//
// 4 Zones (5 questions each = 20 total):
//   1. Animal Life Cycles — tap 4 stages, arranged in a CIRCLE, in the
//      correct cyclical order
//   2. Plant Life Cycles  — same circular-order mechanic, plant cycles
//   3. Which Comes Next?  — recall MCQ
//   4. Metamorphosis Match — complete vs incomplete metamorphosis MCQ
//
// Structurally distinct from every prior engine: Animal/Plant Life Cycles
// are the first questions arranged in a genuine CIRCLE rather than a line,
// grid, or set of slots -- because a life cycle has no true starting
// point, the learner may tap the four stages starting anywhere, and any
// forward rotation of the correct order is accepted, with a connecting
// line drawn between each tap to visibly trace the loop as it forms.
// Architecture: fully self-contained StatefulWidget.
// ────────────────────────────────────────────────────────────────────────────

enum _Phase { intro, playing, correct, wrong, streak, zoneDone, victory }

enum _Kind { cycleWheel, simple }

class _CycleQ {
  final String title;
  final List<String> stages; // canonical order
  final List<String> emojis;
  final List<int> displayOrder; // position index -> stage index (scrambled)
  const _CycleQ({
    required this.title,
    required this.stages,
    required this.emojis,
    required this.displayOrder,
  });
}

class _SimpleQ {
  final String prompt;
  final List<String> choices; // [0] correct
  const _SimpleQ({required this.prompt, required this.choices});
}

class _Zone {
  final String name;
  final _Kind kind;
  final List<_CycleQ> cycles;
  final List<_SimpleQ> simple;
  const _Zone.cycle(this.name, this.cycles)
      : kind = _Kind.cycleWheel,
        simple = const [];
  const _Zone.simple(this.name, this.simple)
      : kind = _Kind.simple,
        cycles = const [];

  int get length => kind == _Kind.cycleWheel ? cycles.length : simple.length;
}

class LifeCyclesGame extends StatefulWidget {
  final GameConfig config;
  final dynamic user;
  const LifeCyclesGame({super.key, required this.config, this.user});

  @override
  State<LifeCyclesGame> createState() => _LCState();
}

class _LCState extends State<LifeCyclesGame> with TickerProviderStateMixin {
  static const _positionAngles = <double>[-math.pi / 2, 0, math.pi / 2, math.pi];

  static const _zones = [
    _Zone.cycle('Animal Life Cycles', [
      _CycleQ(
          title: 'Frog',
          stages: ['Egg', 'Tadpole', 'Froglet', 'Adult Frog'],
          emojis: ['🥚', '🐟', '🐸', '🐸'],
          displayOrder: [2, 0, 3, 1]),
      _CycleQ(
          title: 'Butterfly',
          stages: ['Egg', 'Caterpillar', 'Chrysalis', 'Butterfly'],
          emojis: ['🥚', '🐛', '🦋', '🦋'],
          displayOrder: [1, 3, 0, 2]),
      _CycleQ(
          title: 'Chicken',
          stages: ['Egg', 'Chick', 'Pullet', 'Hen'],
          emojis: ['🥚', '🐣', '🐤', '🐔'],
          displayOrder: [3, 0, 2, 1]),
      _CycleQ(
          title: 'Ladybird',
          stages: ['Egg', 'Larva', 'Pupa', 'Adult Ladybird'],
          emojis: ['🥚', '🐛', '🛡️', '🐞'],
          displayOrder: [0, 2, 1, 3]),
      _CycleQ(
          title: 'Dragonfly',
          stages: ['Egg', 'Nymph', 'Sub-adult', 'Adult Dragonfly'],
          emojis: ['🥚', '🦗', '🪰', '🐉'],
          displayOrder: [2, 1, 3, 0]),
    ]),
    _Zone.cycle('Plant Life Cycles', [
      _CycleQ(
          title: 'Bean Plant',
          stages: ['Seed', 'Germination', 'Seedling', 'Mature Plant'],
          emojis: ['🌱', '🌱', '🌿', '🪴'],
          displayOrder: [2, 0, 3, 1]),
      _CycleQ(
          title: 'Sunflower',
          stages: ['Seed', 'Sprout', 'Young Plant', 'Flowering Plant'],
          emojis: ['🌰', '🌱', '🌿', '🌻'],
          displayOrder: [3, 1, 0, 2]),
      _CycleQ(
          title: 'Apple Tree',
          stages: ['Seed', 'Seedling', 'Sapling', 'Fruit-Bearing Tree'],
          emojis: ['🌰', '🌱', '🌳', '🍎'],
          displayOrder: [1, 3, 0, 2]),
      _CycleQ(
          title: 'Maize',
          stages: ['Seed', 'Root & Shoot', 'Young Plant', 'Mature Maize'],
          emojis: ['🌽', '🌱', '🌿', '🌽'],
          displayOrder: [2, 0, 3, 1]),
      _CycleQ(
          title: 'Flower',
          stages: ['Seed', 'Germinate', 'Grow Leaves', 'Flower & Seed'],
          emojis: ['🌰', '🌱', '🌿', '🌸'],
          displayOrder: [3, 0, 2, 1]),
    ]),
    _Zone.simple('Which Comes Next?', [
      _SimpleQ(
          prompt: "After the egg stage in a frog's life cycle comes...?",
          choices: ['Tadpole', 'Froglet', 'Adult Frog']),
      _SimpleQ(
          prompt: 'After the caterpillar stage comes...?',
          choices: ['Chrysalis', 'Butterfly', 'Egg']),
      _SimpleQ(
          prompt: 'What comes right before the adult stage in most insects?',
          choices: ['Pupa', 'Egg', 'Larva']),
      _SimpleQ(
          prompt: "In a plant's life cycle, what comes after germination?",
          choices: ['Seedling', 'Flower', 'Seed']),
      _SimpleQ(
          prompt: 'What is the FIRST stage in almost every life cycle?',
          choices: ['Egg or Seed', 'Adult', 'Larva']),
    ]),
    _Zone.simple('Metamorphosis Match', [
      _SimpleQ(
          prompt: "A butterfly's cycle (egg-larva-pupa-adult) is called...?",
          choices: [
            'Complete metamorphosis',
            'Incomplete metamorphosis',
            'No metamorphosis'
          ]),
      _SimpleQ(
          prompt: "A grasshopper's cycle (egg-nymph-adult) is called...?",
          choices: [
            'Incomplete metamorphosis',
            'Complete metamorphosis',
            'No metamorphosis'
          ]),
      _SimpleQ(
          prompt: 'Which stage is the resting/transformation stage in '
              'complete metamorphosis?',
          choices: ['Pupa', 'Nymph', 'Larva']),
      _SimpleQ(
          prompt: 'A tadpole turning into a frog is an example of...?',
          choices: ['Metamorphosis', 'Germination', 'Pollination']),
      _SimpleQ(
          prompt: 'Which of these undergoes complete metamorphosis?',
          choices: ['Butterfly', 'Grasshopper', 'Dragonfly']),
    ]),
  ];

  static const _wrongReactions = [
    'Not quite -- follow the cycle again!',
    'Close -- check the growth stages!',
    'Try again -- think about what happens next!',
  ];

  static const _skyTop = Color(0xFFBEE3DB);
  static const _skyBottom = Color(0xFF4E9A6E);
  static const _card = Color(0xFF2E6B48);
  static const _ink = Color(0xFF1E3A2A);

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

  _Phase _phase = _Phase.intro;
  int? _selectedIndex;
  final List<int> _tappedStages = []; // stage indices, in tap order
  bool? _cycleCorrect;
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
    _ambientCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 6))
      ..repeat(reverse: true);
    _ambientAnim = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _ambientCtrl, curve: Curves.easeInOut));

    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);

    _flashCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _flashAnim = CurvedAnimation(parent: _flashCtrl, curve: Curves.easeOut);

    _burstCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600));
    _burstAnim = CurvedAnimation(parent: _burstCtrl, curve: Curves.easeOut);

    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
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
      _phase = _Phase.playing;
      _selectedIndex = null;
      _tappedStages.clear();
      _cycleCorrect = null;
    });
    _fadeCtrl.forward(from: 0);
  }

  Object? _cachedQ;
  List<String> _cachedChoices = [];

  List<String> _getShuffledChoices(_SimpleQ q) {
    if (!identical(_cachedQ, q)) {
      _cachedQ = q;
      _cachedChoices = List<String>.from(q.choices)..shuffle(_rng);
    }
    return _cachedChoices;
  }

  void _onSimpleAnswer(int index) {
    if (_phase != _Phase.playing) return;
    final q = _zones[_zoneIdx].simple[_qIdx];
    final choices = _getShuffledChoices(q);
    final isCorrect = choices[index] == q.choices[0];
    setState(() => _selectedIndex = index);
    _applyAnswerResult(isCorrect);
  }

  void _onTapStage(_CycleQ q, int stageIndex) {
    if (_phase != _Phase.playing) return;
    if (_tappedStages.contains(stageIndex)) return;
    setState(() => _tappedStages.add(stageIndex));
    if (_tappedStages.length == q.stages.length) {
      final isCorrect = _isValidCycleOrder(
          List.generate(q.stages.length, (i) => i), _tappedStages);
      setState(() => _cycleCorrect = isCorrect);
      _applyAnswerResult(isCorrect);
    }
  }

  bool _isValidCycleOrder(List<int> trueOrder, List<int> tapped) {
    final startIdx = trueOrder.indexOf(tapped[0]);
    for (var i = 0; i < trueOrder.length; i++) {
      if (trueOrder[(startIdx + i) % trueOrder.length] != tapped[i]) {
        return false;
      }
    }
    return true;
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
        _delayed(1000, _advance);
      }
    } else {
      _shakeCtrl.forward(from: 0);
      _delayed(2200, _advance);
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
            _tappedStages.clear();
            _cycleCorrect = null;
            _phase = _Phase.playing;
          });
          _fadeCtrl.forward(from: 0);
        });
      }
    } else {
      setState(() {
        _qIdx = next;
        _selectedIndex = null;
        _tappedStages.clear();
        _cycleCorrect = null;
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
                  colors: [_skyTop, _skyBottom],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _ambientAnim,
              builder: (context, _) =>
                  CustomPaint(painter: _LeafBgPainter(_ambientAnim.value)),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _CycleHeader(
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
                      child: zone.kind == _Kind.cycleWheel
                          ? _buildCycleQuestion(zone.cycles[_qIdx], revealed)
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
                  child: Container(color: _card),
                ),
              ),
            ),
          if (_phase == _Phase.streak)
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _burstAnim,
                builder: (context, _) => CustomPaint(
                  painter: _PetalShowerPainter(_burstAnim.value),
                  size: Size.infinite,
                ),
              ),
            ),
          if (_phase == _Phase.zoneDone)
            _ZoneDoneOverlay(
              completedZoneName: zone.name,
              nextZoneName: _zoneIdx + 1 < _zones.length
                  ? _zones[_zoneIdx + 1].name
                  : null,
            ),
        ],
      ),
    );
  }

  Widget _buildCycleQuestion(_CycleQ q, bool revealed) {
    const size = 260.0;
    const radius = 95.0;
    return Column(
      children: [
        const SizedBox(height: 8),
        Text(
          '${q.title}: tap the stages in life-cycle order!',
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: _ink, fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(size, size),
                painter: _CycleLinesPainter(
                  positions: _positionAngles,
                  tappedPositions: _tappedStages
                      .map((s) => q.displayOrder.indexOf(s))
                      .toList(),
                  correct: _cycleCorrect,
                ),
              ),
              for (var p = 0; p < 4; p++)
                Positioned(
                  left: size / 2 + radius * math.cos(_positionAngles[p]) - 46,
                  top: size / 2 + radius * math.sin(_positionAngles[p]) - 46,
                  child: _StageCard(
                    label: q.stages[q.displayOrder[p]],
                    emoji: q.emojis[q.displayOrder[p]],
                    order: _tappedStages.contains(q.displayOrder[p])
                        ? _tappedStages.indexOf(q.displayOrder[p]) + 1
                        : null,
                    revealed: revealed,
                    correct: _cycleCorrect,
                    onTap: () => _onTapStage(q, q.displayOrder[p]),
                  ),
                ),
            ],
          ),
        ),
        if (_phase == _Phase.wrong)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text(
              '$_wrongReaction The order was: ${q.stages.join(" → ")}.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: _ink, fontSize: 13, fontWeight: FontWeight.w600),
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
        const SizedBox(height: 16),
        Text(
          q.prompt,
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: _ink, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 26),
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
                    _LeafButton(
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
            padding: const EdgeInsets.only(top: 18),
            child: Text(
              '$_wrongReaction The answer was ${q.choices[0]}.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: _ink, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ── Stage card (circle position) ────────────────────────────────────────────

class _StageCard extends StatelessWidget {
  final String label;
  final String emoji;
  final int? order; // tap order number, or null if not yet tapped
  final bool revealed;
  final bool? correct;
  final VoidCallback onTap;
  const _StageCard({
    required this.label,
    required this.emoji,
    required this.order,
    required this.revealed,
    required this.correct,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color fill = Colors.white;
    if (order != null) fill = const Color(0xFFDCEFE2);
    if (revealed && order != null) {
      fill = correct == true
          ? const Color(0xFF4CAF7D)
          : const Color(0xFFE05656);
    }

    return GestureDetector(
      onTap: revealed ? null : onTap,
      child: Container(
        width: 92,
        height: 92,
        decoration: BoxDecoration(
          color: fill,
          shape: BoxShape.circle,
          border: Border.all(color: _LCState._card, width: 2.5),
        ),
        alignment: Alignment.center,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(height: 2),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: _LCState._ink,
                      fontSize: 10,
                      fontWeight: FontWeight.w700),
                ),
              ],
            ),
            if (order != null)
              Positioned(
                top: 0,
                right: 4,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle, color: _LCState._card),
                  alignment: Alignment.center,
                  child: Text('$order',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CycleLinesPainter extends CustomPainter {
  final List<double> positions;
  final List<int> tappedPositions; // position-indices in tap order
  final bool? correct;
  const _CycleLinesPainter({
    required this.positions,
    required this.tappedPositions,
    required this.correct,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (tappedPositions.length < 2) return;
    final center = size.center(Offset.zero);
    const radius = 95.0;
    final paint = Paint()
      ..color = correct == null
          ? _LCState._card.withValues(alpha: 0.6)
          : (correct == true ? const Color(0xFF4CAF7D) : const Color(0xFFE05656))
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    for (var i = 0; i < tappedPositions.length - 1; i++) {
      final a1 = positions[tappedPositions[i]];
      final a2 = positions[tappedPositions[i + 1]];
      final p1 = center + Offset(math.cos(a1), math.sin(a1)) * radius;
      final p2 = center + Offset(math.cos(a2), math.sin(a2)) * radius;
      canvas.drawLine(p1, p2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CycleLinesPainter oldDelegate) =>
      oldDelegate.tappedPositions.length != tappedPositions.length ||
      oldDelegate.correct != correct;
}

// ── Leaf button (simple MCQ) ─────────────────────────────────────────────────

class _LeafButton extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isCorrect;
  final bool revealed;
  final VoidCallback onTap;
  const _LeafButton({
    required this.label,
    required this.selected,
    required this.isCorrect,
    required this.revealed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color fill = _LCState._card;
    if (revealed && isCorrect) fill = const Color(0xFF4CAF7D);
    if (revealed && selected && !isCorrect) fill = const Color(0xFFE05656);

    return GestureDetector(
      onTap: revealed ? null : onTap,
      child: Container(
        width: 150,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(28),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

// ── Painters ─────────────────────────────────────────────────────────────────

class _LeafBgPainter extends CustomPainter {
  final double t;
  const _LeafBgPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.25);
    for (var i = 0; i < 3; i++) {
      final x = size.width * (0.2 + i * 0.3) + math.sin(t * math.pi * 2 + i) * 8;
      canvas.drawOval(
          Rect.fromCenter(center: Offset(x, size.height * 0.08), width: 40, height: 16),
          paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LeafBgPainter oldDelegate) => oldDelegate.t != t;
}

class _PetalShowerPainter extends CustomPainter {
  final double t;
  const _PetalShowerPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(53);
    for (var i = 0; i < 18; i++) {
      final startX = rng.nextDouble() * size.width;
      final speed = 0.5 + rng.nextDouble() * 0.6;
      final y = (t * speed) * (size.height + 40) - 20;
      final x = startX + math.sin((t * 6) + i) * 12;
      final paint = Paint()
        ..color = const Color(0xFFDCEFE2)
            .withValues(alpha: (1 - t).clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(t * 6 + i);
      canvas.drawOval(const Rect.fromLTWH(-5, -3, 10, 6), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _PetalShowerPainter oldDelegate) =>
      oldDelegate.t != t;
}

// ── Header / progress ────────────────────────────────────────────────────────

class _CycleHeader extends StatelessWidget {
  final String zoneName;
  final int zoneIdx;
  final int totalZones;
  final int completedSteps;
  final int totalSteps;
  const _CycleHeader({
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
              const Text('🦋', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  children: [
                    Text('Zone ${zoneIdx + 1}/$totalZones',
                        style: const TextStyle(
                            color: _LCState._ink, fontSize: 11)),
                    Text(
                      zoneName,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: _LCState._ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 30),
            ],
          ),
          const SizedBox(height: 8),
          _CycleTrail(completed: completedSteps, total: totalSteps),
        ],
      ),
    );
  }
}

class _CycleTrail extends StatelessWidget {
  final int completed;
  final int total;
  const _CycleTrail({required this.completed, required this.total});

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
            color: _LCState._ink.withValues(alpha: 0.15),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < total; i++)
                Text(
                  i < completed ? '🐛' : '·',
                  style: TextStyle(
                    fontSize: i < completed ? 12 : 10,
                    color: i < completed
                        ? null
                        : _LCState._ink.withValues(alpha: 0.35),
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
  const _ZoneDoneOverlay(
      {required this.completedZoneName, required this.nextZoneName});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black26,
        alignment: Alignment.center,
        child: Container(
          padding: const EdgeInsets.all(24),
          margin: const EdgeInsets.symmetric(horizontal: 40),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _LCState._card, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🦋', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 8),
              Text('$completedZoneName complete!',
                  style: const TextStyle(
                      color: _LCState._ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
              if (nextZoneName != null) ...[
                const SizedBox(height: 6),
                Text('Next: $nextZoneName',
                    style: const TextStyle(color: _LCState._ink, fontSize: 13)),
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
            colors: [_LCState._skyTop, _LCState._skyBottom],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🦋🐸', style: TextStyle(fontSize: 44)),
                  SizedBox(height: 16),
                  Text(
                    'Life Cycles',
                    style: TextStyle(
                      color: _LCState._ink,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Tap the stages in order to trace the circle of life '
                    'for animals and plants!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF2E5A3F), fontSize: 14),
                  ),
                  SizedBox(height: 24),
                  CircularProgressIndicator(color: _LCState._card),
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
            colors: [_LCState._skyTop, _LCState._skyBottom],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🏆🦋', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  const Text('Cycle Complete!',
                      style: TextStyle(
                          color: _LCState._ink,
                          fontSize: 26,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  Text('$correctCount / $total correct ($pct%)',
                      style: const TextStyle(
                          color: Color(0xFF2E5A3F), fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('+$totalXP XP',
                      style: const TextStyle(
                          color: _LCState._ink,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: onReplay,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _LCState._card,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 14),
                    ),
                    child: const Text('Play Again'),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: onExit,
                    child: const Text('Exit',
                        style: TextStyle(color: Color(0xFF2E5A3F))),
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
