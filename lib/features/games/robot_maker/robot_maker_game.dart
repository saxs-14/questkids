import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/game_session_model.dart';
import '../core/game_config.dart';
import '../core/game_session_persistence.dart';

// ────────────────────────────────────────────────────────────────────────────
// Robot Maker — Grade 4 Technology: robot parts, the engineering design
// process (Investigate-Design-Make-Evaluate-Communicate), and real-world
// robot uses
//
// 4 Zones (5 questions each = 20 total):
//   1. Choose the Right Part — recall MCQ: pick the part that solves a
//      design need
//   2. The Design Process     — recall MCQ about IDMEC steps
//   3. Build the Robot        — tap TWO parts in order to satisfy a build
//      brief
//   4. Robots at Work         — recall MCQ about real-world robot uses
//
// Structurally distinct from every prior engine: a single robot AVATAR is
// permanently visible above every question for the whole session (all 4
// zones) and physically assembles itself, one named body slot at a time
// (wheels, torso, arms, head, antenna, power core, eyes), as cumulative
// correct answers cross fixed milestones. Unlike Times Table Tower's
// homogeneous brick stack, each part here is a distinct, positioned,
// semantically-named slot on a humanoid frame -- the more you get right,
// the more complete the robot you built actually looks.
// Architecture: fully self-contained StatefulWidget.
// ────────────────────────────────────────────────────────────────────────────

enum _Phase { intro, playing, correct, wrong, streak, zoneDone, victory }

enum _Kind { build, simple }

const _partEmoji = {
  'chassis': '🔲',
  'wheels': '⚙️',
  'gripper': '🦾',
  'sensor': '📡',
  'controller': '🧠',
  'battery': '🔋',
  'motor': '⚡',
};
const _partLabel = {
  'chassis': 'Chassis',
  'wheels': 'Wheels',
  'gripper': 'Gripper Arm',
  'sensor': 'Sensor',
  'controller': 'Controller',
  'battery': 'Battery',
  'motor': 'Motor',
};

// Cumulative-correct-count thresholds at which each avatar slot unlocks.
const _milestones = [3, 6, 9, 11, 14, 17, 20];

class _BuildQ {
  final String description;
  final List<String> correct; // part ids, left-to-right build order
  final List<String> bank; // ids offered to tap (includes correct + decoys)
  const _BuildQ({required this.description, required this.correct, required this.bank});
}

class _SimpleQ {
  final String prompt;
  final List<String> choices; // [0] correct
  const _SimpleQ({required this.prompt, required this.choices});
}

class _Zone {
  final String name;
  final _Kind kind;
  final List<_BuildQ> builds;
  final List<_SimpleQ> simple;
  const _Zone.build(this.name, this.builds)
      : kind = _Kind.build,
        simple = const [];
  const _Zone.simple(this.name, this.simple)
      : kind = _Kind.simple,
        builds = const [];

  int get length => kind == _Kind.build ? builds.length : simple.length;
}

class RobotMakerGame extends StatefulWidget {
  final GameConfig config;
  final dynamic user;
  const RobotMakerGame({super.key, required this.config, this.user});

  @override
  State<RobotMakerGame> createState() => _RMState();
}

class _RMState extends State<RobotMakerGame> with TickerProviderStateMixin {
  static const _zones = [
    _Zone.simple('Choose the Right Part', [
      _SimpleQ(
          prompt: "Your robot needs to move across the classroom floor. What part should you add?",
          choices: ['Wheels', 'Sensor', 'Speaker']),
      _SimpleQ(
          prompt: "Your robot needs to sense when it's getting dark. What part should you add?",
          choices: ['Light sensor', 'Gripper', 'Wheels']),
      _SimpleQ(
          prompt: 'Your robot needs to pick up a small ball. What part should you add?',
          choices: ['Gripper arm', 'Battery', 'Wheels']),
      _SimpleQ(
          prompt: 'Your robot needs energy to run. What part should you add?',
          choices: ['Battery', 'Sensor', 'Antenna']),
      _SimpleQ(
          prompt: "Your robot needs a 'brain' to control its actions. What part should you add?",
          choices: ['Controller (circuit board)', 'Wheels', 'Gripper']),
    ]),
    _Zone.simple('The Design Process', [
      _SimpleQ(
          prompt: 'What is the FIRST step of the engineering design process?',
          choices: ['Investigate the problem', 'Make the product', 'Evaluate the result']),
      _SimpleQ(
          prompt: 'After investigating, what do you do next?',
          choices: ['Design a solution (draw/plan it)', 'Sell the product', 'Throw it away']),
      _SimpleQ(
          prompt: 'After designing, what is the next step?',
          choices: ['Make (build) the solution', 'Investigate again', 'Skip to evaluate']),
      _SimpleQ(
          prompt: 'After making your robot, what should you do?',
          choices: ['Evaluate if it works', 'Forget about it', 'Start a new design immediately']),
      _SimpleQ(
          prompt: 'Why is it important to communicate your design to others?',
          choices: [
            'So others understand and can give feedback',
            'To keep it a secret',
            'It is not important'
          ]),
    ]),
    _Zone.build('Build the Robot', [
      _BuildQ(
          description: 'Build a simple rolling robot: add the chassis, then the wheels.',
          correct: ['chassis', 'wheels'],
          bank: ['chassis', 'wheels', 'sensor', 'battery']),
      _BuildQ(
          description: 'Build a robot that can pick things up: add the chassis, then a gripper arm.',
          correct: ['chassis', 'gripper'],
          bank: ['chassis', 'gripper', 'motor', 'controller']),
      _BuildQ(
          description: 'Build a robot that senses obstacles: add the sensor, then the controller.',
          correct: ['sensor', 'controller'],
          bank: ['sensor', 'controller', 'wheels', 'battery']),
      _BuildQ(
          description: 'Give your robot power: add the battery, then the controller.',
          correct: ['battery', 'controller'],
          bank: ['battery', 'controller', 'gripper', 'motor']),
      _BuildQ(
          description: 'Complete your robot: add the motor, then the wheels.',
          correct: ['motor', 'wheels'],
          bank: ['motor', 'wheels', 'sensor', 'chassis']),
    ]),
    _Zone.simple('Robots at Work', [
      _SimpleQ(
          prompt: 'Robots that build cars in factories are called...?',
          choices: ['Industrial robots', 'Home robots', 'Space robots']),
      _SimpleQ(
          prompt: 'A robot that explores planets like Mars is called a...?',
          choices: ['Rover', 'Blender', 'Calculator']),
      _SimpleQ(
          prompt: 'Why do farmers use robots in some countries?',
          choices: [
            'To plant and harvest crops efficiently',
            'To cook food',
            'To paint pictures'
          ]),
      _SimpleQ(
          prompt: 'What is one thing robots are GOOD at that humans find hard?',
          choices: [
            'Repeating the same task exactly, many times',
            'Feeling emotions',
            'Being creative'
          ]),
      _SimpleQ(
          prompt: 'What is one thing that ONLY humans (not robots) can do well?',
          choices: [
            'Make creative decisions and show empathy',
            'Lift heavy objects repeatedly',
            'Follow exact instructions'
          ]),
    ]),
  ];

  static const _wrongReactions = [
    'Not quite -- check the design brief!',
    "Hmm, that's not the right part!",
    'Almost -- try again next time!',
  ];

  static const _bg1 = Color(0xFF141225);
  static const _bg2 = Color(0xFF241B3F);
  static const _card = Color(0xFF3A2D5C);
  static const _glow = Color(0xFF7FE8D8);

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

  // Build-zone state
  List<String?> _placements = [];
  List<bool> _bankUsed = [];
  bool? _lastBuildCorrect;

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
    });
    _setupCurrentQuestion();
    _fadeCtrl.forward(from: 0);
  }

  void _setupCurrentQuestion() {
    final zone = _zones[_zoneIdx];
    if (zone.kind == _Kind.build) {
      final q = zone.builds[_qIdx];
      _placements = List<String?>.filled(q.correct.length, null);
      _bankUsed = List<bool>.filled(q.bank.length, false);
      _lastBuildCorrect = null;
    }
  }

  void _onSimpleAnswer(int index) {
    if (_phase != _Phase.playing) return;
    final isCorrect = index == 0;
    setState(() => _selectedIndex = index);
    _applyAnswerResult(isCorrect);
  }

  void _onTapBankPart(int bankIdx) {
    if (_phase != _Phase.playing) return;
    final q = _zones[_zoneIdx].builds[_qIdx];
    if (_bankUsed[bankIdx]) return;

    final emptySlot = _placements.indexWhere((p) => p == null);
    if (emptySlot == -1) return;

    setState(() {
      _bankUsed[bankIdx] = true;
      _placements[emptySlot] = q.bank[bankIdx];
    });

    if (!_placements.contains(null)) {
      _delayed(300, _evaluateBuild);
    }
  }

  void _evaluateBuild() {
    if (!mounted) return;
    final q = _zones[_zoneIdx].builds[_qIdx];
    var allCorrect = true;
    for (var i = 0; i < q.correct.length; i++) {
      if (_placements[i] != q.correct[i]) {
        allCorrect = false;
        break;
      }
    }
    setState(() => _lastBuildCorrect = allCorrect);
    _applyAnswerResult(allCorrect);
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
          _setupCurrentQuestion();
          _fadeCtrl.forward(from: 0);
        });
      }
    } else {
      setState(() {
        _qIdx = next;
        _selectedIndex = null;
        _phase = _Phase.playing;
      });
      _setupCurrentQuestion();
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
                  CustomPaint(painter: _GearBgPainter(_ambientAnim.value)),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _RobotHeader(
                  zoneName: zone.name,
                  zoneIdx: _zoneIdx,
                  totalZones: _zones.length,
                  completedSteps: completedSteps,
                  totalSteps: total,
                ),
                _RobotAvatar(correctCount: _correctCount),
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: zone.kind == _Kind.build
                          ? _buildBuildQuestion(zone.builds[_qIdx])
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
                  child: Container(color: _glow),
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

  Widget _buildBuildQuestion(_BuildQ q) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Text(
          q.description,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: [
            for (var i = 0; i < q.correct.length; i++)
              _BuildSlot(id: _placements[i], index: i),
          ],
        ),
        if (_phase == _Phase.wrong && _lastBuildCorrect == false)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              '$_wrongReaction Correct: ${q.correct.map((c) => _partLabel[c]).join(', ')}.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        const SizedBox(height: 20),
        AnimatedBuilder(
          animation: _shakeAnim,
          builder: (context, _) {
            final dx = _phase == _Phase.wrong
                ? math.sin(_shakeAnim.value * math.pi * 6) * 5
                : 0.0;
            return Transform.translate(
              offset: Offset(dx, 0),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  for (var i = 0; i < q.bank.length; i++)
                    _PartChip(
                      id: q.bank[i],
                      used: _bankUsed[i],
                      onTap: () => _onTapBankPart(i),
                    ),
                ],
              ),
            );
          },
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

// ── Persistent robot avatar ──────────────────────────────────────────────────

class _RobotAvatar extends StatelessWidget {
  final int correctCount;
  const _RobotAvatar({required this.correctCount});

  bool _unlocked(int slot) => correctCount >= _milestones[slot];

  @override
  Widget build(BuildContext context) {
    final wheels = _unlocked(0);
    final torso = _unlocked(1);
    final arms = _unlocked(2);
    final head = _unlocked(3);
    final antenna = _unlocked(4);
    final powerCore = _unlocked(5);
    final eyes = _unlocked(6);

    return SizedBox(
      height: 108,
      child: Center(
        child: SizedBox(
          width: 140,
          height: 100,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Antenna
              Positioned(
                top: 0,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 400),
                  opacity: antenna ? 1 : 0,
                  child: Column(
                    children: [
                      Container(width: 2, height: 10, color: _RMState._glow),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                            color: _RMState._glow, shape: BoxShape.circle),
                      ),
                    ],
                  ),
                ),
              ),
              // Head
              Positioned(
                top: 14,
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 400),
                  scale: head ? 1 : 0,
                  curve: Curves.easeOutBack,
                  child: Container(
                    width: 36,
                    height: 28,
                    decoration: BoxDecoration(
                      color: _RMState._card,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white38, width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      opacity: eyes ? 1 : 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _eye(),
                          const SizedBox(width: 5),
                          _eye(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Arms + torso row
              Positioned(
                top: 46,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 400),
                      opacity: arms ? 1 : 0,
                      child: Container(
                        width: 10,
                        height: 22,
                        decoration: BoxDecoration(
                          color: _RMState._card,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    AnimatedScale(
                      duration: const Duration(milliseconds: 400),
                      scale: torso ? 1 : 0,
                      curve: Curves.easeOutBack,
                      child: Container(
                        width: 44,
                        height: 34,
                        decoration: BoxDecoration(
                          color: _RMState._card,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white38, width: 1.5),
                        ),
                        alignment: Alignment.center,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: powerCore
                                ? _RMState._glow
                                : Colors.white.withValues(alpha: 0.08),
                            boxShadow: powerCore
                                ? [
                                    BoxShadow(
                                        color: _RMState._glow.withValues(alpha: 0.7),
                                        blurRadius: 10)
                                  ]
                                : null,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 400),
                      opacity: arms ? 1 : 0,
                      child: Container(
                        width: 10,
                        height: 22,
                        decoration: BoxDecoration(
                          color: _RMState._card,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Wheels
              Positioned(
                bottom: 0,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 400),
                  opacity: wheels ? 1 : 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _wheel(),
                      const SizedBox(width: 26),
                      _wheel(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _eye() => Container(
        width: 5,
        height: 5,
        decoration: const BoxDecoration(color: _RMState._glow, shape: BoxShape.circle),
      );

  Widget _wheel() => Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1530),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white38, width: 1.5),
        ),
      );
}

// ── Build slot / part chip ───────────────────────────────────────────────────

class _BuildSlot extends StatelessWidget {
  final String? id;
  final int index;
  const _BuildSlot({required this.id, required this.index});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: id != null ? _RMState._card : Colors.white10,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: id != null ? _RMState._glow : Colors.white38, width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        id != null ? _partEmoji[id]! : '${index + 1}',
        style: TextStyle(fontSize: id != null ? 22 : 16, color: Colors.white70),
      ),
    );
  }
}

class _PartChip extends StatelessWidget {
  final String id;
  final bool used;
  final VoidCallback onTap;
  const _PartChip({required this.id, required this.used, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: used ? null : onTap,
      child: Opacity(
        opacity: used ? 0.35 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _RMState._card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _RMState._glow.withValues(alpha: 0.6), width: 2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_partEmoji[id]!, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Text(_partLabel[id]!,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
            ],
          ),
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
    Color fill = _RMState._card;
    if (revealed && isCorrect) fill = const Color(0xFF4CAF7D);
    if (revealed && selected && !isCorrect) fill = const Color(0xFFE05656);

    return GestureDetector(
      onTap: revealed ? null : onTap,
      child: Container(
        constraints: const BoxConstraints(minWidth: 110, maxWidth: 260),
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _RMState._glow.withValues(alpha: 0.6), width: 2),
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

class _GearBgPainter extends CustomPainter {
  final double t;
  const _GearBgPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(17);
    for (var i = 0; i < 10; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final r = 10 + rng.nextDouble() * 14;
      final paint = Paint()
        ..color = _RMState._glow.withValues(alpha: 0.03 + 0.02 * t)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GearBgPainter oldDelegate) => oldDelegate.t != t;
}

class _SparkleShowerPainter extends CustomPainter {
  final double t;
  const _SparkleShowerPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(41);
    for (var i = 0; i < 18; i++) {
      final startX = rng.nextDouble() * size.width;
      final speed = 0.5 + rng.nextDouble() * 0.6;
      final y = (t * speed) * (size.height + 40) - 20;
      final x = startX + math.sin((t * 6) + i) * 12;
      final paint = Paint()
        ..color = _RMState._glow.withValues(alpha: (1 - t).clamp(0.0, 1.0));
      canvas.drawCircle(Offset(x, y), 3, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparkleShowerPainter oldDelegate) => oldDelegate.t != t;
}

// ── Header / progress ────────────────────────────────────────────────────────

class _RobotHeader extends StatelessWidget {
  final String zoneName;
  final int zoneIdx;
  final int totalZones;
  final int completedSteps;
  final int totalSteps;
  const _RobotHeader({
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
              const Text('🤖', style: TextStyle(fontSize: 22)),
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
          _RobotTrail(completed: completedSteps, total: totalSteps),
        ],
      ),
    );
  }
}

class _RobotTrail extends StatelessWidget {
  final int completed;
  final int total;
  const _RobotTrail({required this.completed, required this.total});

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
                  i < completed ? '🔩' : '·',
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
            color: _RMState._card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _RMState._glow, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🤖', style: TextStyle(fontSize: 40)),
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
            colors: [_RMState._bg1, _RMState._bg2],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🤖🔧', style: TextStyle(fontSize: 44)),
                  SizedBox(height: 16),
                  Text(
                    'Robot Maker',
                    style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Answer correctly to assemble your own robot, one part '
                    'at a time!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  SizedBox(height: 24),
                  CircularProgressIndicator(color: _RMState._glow),
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
            colors: [_RMState._bg1, _RMState._bg2],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _RobotAvatar(correctCount: correctCount),
                  const SizedBox(height: 8),
                  const Text('🏆', style: TextStyle(fontSize: 40)),
                  const SizedBox(height: 8),
                  const Text('Robot Complete!',
                      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  Text('$correctCount / $total correct ($pct%)',
                      style: const TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('+$totalXP XP',
                      style: const TextStyle(color: _RMState._glow, fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: onReplay,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _RMState._card,
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
