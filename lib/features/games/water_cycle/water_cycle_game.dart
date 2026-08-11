import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/game_session_model.dart';
import '../core/game_config.dart';
import '../core/game_session_persistence.dart';

// ────────────────────────────────────────────────────────────────────────────
// Water Cycle — Grade 4 Social Sciences: evaporation, condensation,
// precipitation and collection
//
// NOTE: this is a DIFFERENT engine from sequence_builder/ (engineType
// 'sequenceBuilder'), which is a shared generic engine still used by 15
// other catalog entries. This engine (engineType 'waterCycle') is
// registered ONLY against ss_g4_water.
//
// 4 Zones (5 questions each = 20 total):
//   1. Guide the Droplet   — pick what happens next; a droplet visually
//      travels around a looped cycle diagram, changing form (wave, vapour,
//      cloud, rain, river) at each correct stage
//   2. Water Cycle Vocabulary — recall MCQ (evaporation, condensation, ...)
//   3. What Happens When... — recall MCQ (cause and effect reasoning)
//   4. Water Cycle in Nature — recall MCQ (sources, importance, conservation)
//
// Structurally distinct from every prior engine: Zone 1 is the first
// looped-path journey where a single character travels a closed circuit
// and visually TRANSFORMS (not just relocates) at each stage, unlike
// Coding Adventure's grid movement or Life Cycles' order-flexible circular
// taps.
// Architecture: fully self-contained StatefulWidget.
// ────────────────────────────────────────────────────────────────────────────

enum _Phase { intro, playing, correct, wrong, streak, zoneDone, victory }

enum _Kind { droplet, simple }

// The 5 stops around the loop (index matches _stagePositions/_stageEmoji).
const _stageNames = ['Ocean', 'Vapour', 'Cloud', 'Rain', 'River'];
const _stageEmoji = ['🌊', '💨', '☁️', '🌧️', '🏞️'];
const _stagePositions = [
  Offset(0.22, 0.85), // Ocean -- bottom-left
  Offset(0.10, 0.45), // Vapour -- rising, left-mid
  Offset(0.50, 0.10), // Cloud -- top-centre
  Offset(0.88, 0.45), // Rain -- falling, right-mid
  Offset(0.78, 0.85), // River -- collection, bottom-right
];

class _DropletQ {
  final String prompt;
  final List<String> choices; // [0] correct
  final int fromStage; // 0..4
  final int toStage; // 0..4 (5 wraps to 0)
  const _DropletQ({
    required this.prompt,
    required this.choices,
    required this.fromStage,
    required this.toStage,
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
  final List<_DropletQ> droplet;
  final List<_SimpleQ> simple;
  const _Zone.droplet(this.name, this.droplet)
      : kind = _Kind.droplet,
        simple = const [];
  const _Zone.simple(this.name, this.simple)
      : kind = _Kind.simple,
        droplet = const [];

  int get length => kind == _Kind.droplet ? droplet.length : simple.length;
}

class WaterCycleGame extends StatefulWidget {
  final GameConfig config;
  final dynamic user;
  const WaterCycleGame({super.key, required this.config, this.user});

  @override
  State<WaterCycleGame> createState() => _WCState();
}

class _WCState extends State<WaterCycleGame> with TickerProviderStateMixin {
  static const _zones = [
    _Zone.droplet('Guide the Droplet', [
      _DropletQ(
          prompt: 'The sun heats the ocean and warms the water. What happens next?',
          choices: ['Evaporation', 'Precipitation', 'Collection'],
          fromStage: 0,
          toStage: 1),
      _DropletQ(
          prompt: 'Water vapour rises into the sky and cools down. What happens next?',
          choices: ['Condensation', 'Evaporation', 'Collection'],
          fromStage: 1,
          toStage: 2),
      _DropletQ(
          prompt:
              'Tiny water droplets gather together in clouds until they get heavy. What happens next?',
          choices: ['Precipitation', 'Evaporation', 'Condensation'],
          fromStage: 2,
          toStage: 3),
      _DropletQ(
          prompt: 'Rain falls from the clouds onto the land. Where does the water go next?',
          choices: ['Collection (rivers and oceans)', 'Evaporation', 'Condensation'],
          fromStage: 3,
          toStage: 4),
      _DropletQ(
          prompt:
              'The water has collected in the river and flows back to the ocean. What starts the cycle again?',
          choices: ['The sun heats it and evaporation begins again', 'It freezes forever', 'It disappears'],
          fromStage: 4,
          toStage: 0),
    ]),
    _Zone.simple('Water Cycle Vocabulary', [
      _SimpleQ(
          prompt: 'What is EVAPORATION?',
          choices: [
            'Water turning into vapour (gas) when heated',
            'Water freezing into ice',
            'Rain falling from clouds'
          ]),
      _SimpleQ(
          prompt: 'What is CONDENSATION?',
          choices: [
            'Water vapour cooling and turning back into tiny droplets',
            'Water flowing downhill',
            'Water heating up'
          ]),
      _SimpleQ(
          prompt: 'What is PRECIPITATION?',
          choices: [
            'Water falling from clouds as rain, hail or snow',
            'Water evaporating from the ocean',
            'Water collecting in a dam'
          ]),
      _SimpleQ(
          prompt: 'What is COLLECTION?',
          choices: [
            'Water gathering in rivers, dams and oceans',
            'Water turning into gas',
            'Clouds forming in the sky'
          ]),
      _SimpleQ(
          prompt: 'What is TRANSPIRATION?',
          choices: [
            'Water vapour released by plants and trees',
            'Water freezing in winter',
            'Rain soaking into soil'
          ]),
    ]),
    _Zone.simple('What Happens When...', [
      _SimpleQ(
          prompt: 'As water vapour rises high into the sky, the air gets cooler. What happens to the vapour?',
          choices: [
            'It condenses into tiny droplets, forming clouds',
            'It disappears completely',
            'It turns into ice cream'
          ]),
      _SimpleQ(
          prompt: 'Why does it rain?',
          choices: [
            'Water droplets in clouds join together until they are too heavy to stay up',
            'The sun pushes them down',
            'Clouds get bored'
          ]),
      _SimpleQ(
          prompt: 'What provides the ENERGY that powers the whole water cycle?',
          choices: ['The sun', 'The moon', 'The wind only']),
      _SimpleQ(
          prompt: 'What happens to rainwater that falls on a mountain?',
          choices: [
            'It flows downhill into streams and rivers',
            'It stays frozen forever',
            'It evaporates instantly'
          ]),
      _SimpleQ(
          prompt: 'Why is the water cycle described as a CYCLE?',
          choices: [
            'Because the same water keeps moving through the same stages again and again',
            'Because it only happens once a year',
            'Because new water is created every time'
          ]),
    ]),
    _Zone.simple('Water Cycle in Nature', [
      _SimpleQ(
          prompt: 'Which of these is NOT a natural water source?',
          choices: ['A swimming pool', 'A river', 'An ocean']),
      _SimpleQ(
          prompt: 'Why is the water cycle important for life on Earth?',
          choices: [
            'It provides fresh water for plants, animals and people',
            'It makes the sky blue',
            'It only affects fish'
          ]),
      _SimpleQ(
          prompt: 'Which of these can speed up evaporation?',
          choices: ['Hot, sunny weather', 'Cold, cloudy weather', 'Night time']),
      _SimpleQ(
          prompt: "Where does most of Earth's water come from before it evaporates?",
          choices: ['The oceans', 'Underground caves', 'Outer space']),
      _SimpleQ(
          prompt: 'How can people help protect the water cycle?',
          choices: [
            'By not polluting rivers and using water wisely',
            'By building more swimming pools',
            'By pouring oil into rivers'
          ]),
    ]),
  ];

  static const _wrongReactions = [
    'Not quite -- think about what water does next!',
    'Hmm, try a different stage!',
    'Almost -- picture the droplet\'s journey!',
  ];

  static const _bg1 = Color(0xFF0D2436);
  static const _bg2 = Color(0xFF184A5E);
  static const _card = Color(0xFF236279);
  static const _sky = Color(0xFF8FD9E8);

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
  int _dropletStage = 0;

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
      _dropletStage = 0;
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

  void _onDropletAnswer(int index, _DropletQ q) {
    if (_phase != _Phase.playing) return;
    final choices = _getShuffledChoices(q);
    final isCorrect = choices[index] == q.choices[0];
    setState(() {
      _selectedIndex = index;
      if (isCorrect) _dropletStage = q.toStage;
    });
    _applyAnswerResult(isCorrect);
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
                _WaterHeader(
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
                      child: zone.kind == _Kind.droplet
                          ? _buildDropletQuestion(zone.droplet[_qIdx], revealed)
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
                  child: Container(color: _sky),
                ),
              ),
            ),
          if (_phase == _Phase.streak)
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _burstAnim,
                builder: (context, _) => CustomPaint(
                  painter: _SparkleShowerPainter(_burstAnim.value),
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

  Widget _buildDropletQuestion(_DropletQ q, bool revealed) {
    const boxWidth = 260.0;
    const boxHeight = 220.0;

    return Column(
      children: [
        const SizedBox(height: 8),
        Text(
          q.prompt,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: boxWidth,
          height: boxHeight,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(painter: _CyclePathPainter()),
              ),
              for (var i = 0; i < _stagePositions.length; i++)
                Positioned(
                  left: _stagePositions[i].dx * boxWidth - 20,
                  top: _stagePositions[i].dy * boxHeight - 14,
                  child: SizedBox(
                    width: 40,
                    child: Text(
                      _stageNames[i],
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeInOut,
                left: _stagePositions[_dropletStage].dx * boxWidth - 18,
                top: _stagePositions[_dropletStage].dy * boxHeight - 18,
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: Center(
                    child: Text(_stageEmoji[_dropletStage], style: const TextStyle(fontSize: 28)),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AnimatedBuilder(
          animation: _shakeAnim,
          builder: (context, _) {
            final dx = _phase == _Phase.wrong
                ? math.sin(_shakeAnim.value * math.pi * 6) * 6
                : 0.0;
            final choices = _getShuffledChoices(q);
            return Transform.translate(
              offset: Offset(dx, 0),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  for (var i = 0; i < choices.length; i++)
                    _SimpleTile(
                      label: choices[i],
                      selected: _selectedIndex == i,
                      isCorrect: choices[i] == q.choices[0],
                      revealed: revealed,
                      onTap: () => _onDropletAnswer(i, q),
                    ),
                ],
              ),
            );
          },
        ),
        if (_phase == _Phase.wrong)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text(
              '$_wrongReaction The answer was ${q.choices[0]}.',
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
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
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
    Color fill = _WCState._card;
    if (revealed && isCorrect) fill = const Color(0xFF4CAF7D);
    if (revealed && selected && !isCorrect) fill = const Color(0xFFE05656);

    return GestureDetector(
      onTap: revealed ? null : onTap,
      child: Container(
        constraints: const BoxConstraints(minWidth: 110, maxWidth: 280),
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _WCState._sky.withValues(alpha: 0.7), width: 2),
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

class _CyclePathPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final path = Path();
    final points = _stagePositions
        .map((p) => Offset(p.dx * size.width, p.dy * size.height))
        .toList();
    path.moveTo(points[0].dx, points[0].dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    path.lineTo(points[0].dx, points[0].dy);
    _drawDashedPath(canvas, path, paint);
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    const dashWidth = 5.0;
    const dashSpace = 4.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = math.min(distance + dashWidth, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CyclePathPainter oldDelegate) => false;
}

class _RippleBgPainter extends CustomPainter {
  final double t;
  const _RippleBgPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _WCState._sky.withValues(alpha: 0.05 + 0.03 * t)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (var i = 0; i < 3; i++) {
      final y = size.height * (0.2 + i * 0.3);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RippleBgPainter oldDelegate) => oldDelegate.t != t;
}

class _SparkleShowerPainter extends CustomPainter {
  final double t;
  const _SparkleShowerPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(83);
    for (var i = 0; i < 18; i++) {
      final startX = rng.nextDouble() * size.width;
      final speed = 0.5 + rng.nextDouble() * 0.6;
      final y = (t * speed) * (size.height + 40) - 20;
      final x = startX + math.sin((t * 6) + i) * 12;
      final paint = Paint()
        ..color = _WCState._sky.withValues(alpha: (1 - t).clamp(0.0, 1.0));
      canvas.drawCircle(Offset(x, y), 3, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparkleShowerPainter oldDelegate) => oldDelegate.t != t;
}

// ── Header / progress ────────────────────────────────────────────────────────

class _WaterHeader extends StatelessWidget {
  final String zoneName;
  final int zoneIdx;
  final int totalZones;
  final int completedSteps;
  final int totalSteps;
  const _WaterHeader({
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
              const Text('💧', style: TextStyle(fontSize: 22)),
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
          _WaterTrail(completed: completedSteps, total: totalSteps),
        ],
      ),
    );
  }
}

class _WaterTrail extends StatelessWidget {
  final int completed;
  final int total;
  const _WaterTrail({required this.completed, required this.total});

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
                  i < completed ? '💧' : '·',
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
            color: _WCState._card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _WCState._sky, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('💧', style: TextStyle(fontSize: 40)),
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
            colors: [_WCState._bg1, _WCState._bg2],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('💧☁️', style: TextStyle(fontSize: 44)),
                  SizedBox(height: 16),
                  Text(
                    'Water Cycle',
                    style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Guide a droplet through evaporation, condensation and '
                    'precipitation!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  SizedBox(height: 24),
                  CircularProgressIndicator(color: _WCState._sky),
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
            colors: [_WCState._bg1, _WCState._bg2],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🏆💧', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  const Text('Water Cycle Master!',
                      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  Text('$correctCount / $total correct ($pct%)',
                      style: const TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('+$totalXP XP',
                      style: const TextStyle(color: _WCState._sky, fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: onReplay,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _WCState._card,
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
