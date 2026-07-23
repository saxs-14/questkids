import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/game_session_model.dart';
import '../core/game_config.dart';
import '../core/game_session_persistence.dart';

// ────────────────────────────────────────────────────────────────────────────
// Social Skills — Grade 4 Life Skills: teamwork, communication, and conflict
// resolution
//
// NOTE: this is a DIFFERENT engine from adventure_journey/ (engineType
// 'adventureJourney'), which is a shared generic engine still used by 15
// other catalog entries. This engine (engineType 'socialSkills') is
// registered ONLY against ls_g4_social.
//
// 4 Zones (5 questions each = 20 total):
//   1. Build the Bridge  — given a social scenario, tap the best response;
//      each correct answer adds a plank to a rope bridge connecting two
//      characters standing on opposite cliffs, ending in a handshake
//      once all 5 planks are placed
//   2. Teamwork            — recall MCQ
//   3. Communication        — recall MCQ
//   4. Conflict Resolution  — recall MCQ
//
// Structurally distinct from every prior engine: Zone 1's sequentially
// extending rope bridge between two fixed characters, capped with a
// handshake completion, is a new combination -- unlike Healthy Living's
// orbiting icons, Financial Literacy's falling coin jar, or Career
// Explorer's card flip. Architecture: fully self-contained StatefulWidget.
// ────────────────────────────────────────────────────────────────────────────

enum _Phase { intro, playing, correct, wrong, streak, zoneDone, victory }

enum _Kind { bridge, simple }

class _BridgeQ {
  final String prompt;
  final List<String> choices; // [0] correct (best social response)
  const _BridgeQ({required this.prompt, required this.choices});
}

class _SimpleQ {
  final String prompt;
  final List<String> choices; // [0] correct
  const _SimpleQ({required this.prompt, required this.choices});
}

class _Zone {
  final String name;
  final _Kind kind;
  final List<_BridgeQ> bridge;
  final List<_SimpleQ> simple;
  const _Zone.bridge(this.name, this.bridge)
      : kind = _Kind.bridge,
        simple = const [];
  const _Zone.simple(this.name, this.simple)
      : kind = _Kind.simple,
        bridge = const [];

  int get length => kind == _Kind.bridge ? bridge.length : simple.length;
}

class SocialSkillsGame extends StatefulWidget {
  final GameConfig config;
  final dynamic user;
  const SocialSkillsGame({super.key, required this.config, this.user});

  @override
  State<SocialSkillsGame> createState() => _SSState();
}

class _SSState extends State<SocialSkillsGame> with TickerProviderStateMixin {
  static const _zones = [
    _Zone.bridge('Build the Bridge', [
      _BridgeQ(
        prompt: "Your group project partner isn't doing their share of the work. What's the best first step?",
        choices: [
          'Talk to them calmly and ask if everything is okay',
          'Do all the work yourself without saying anything',
          'Complain about them to everyone else in the class',
        ],
      ),
      _BridgeQ(
        prompt: 'Two classmates want to use the same ball at break time. What is the fairest solution?',
        choices: [
          'Take turns or play together',
          'Whoever grabs it first keeps it all break',
          'Nobody gets to use it',
        ],
      ),
      _BridgeQ(
        prompt: 'A friend disagrees with your idea in a group discussion. What should you do?',
        choices: [
          'Listen to their point of view and discuss it respectfully',
          'Ignore them and do it your way anyway',
          'Get angry and stop talking to them',
        ],
      ),
      _BridgeQ(
        prompt: "Your team lost a class competition. What's a good way to respond?",
        choices: [
          'Congratulate the winners and think about what you can improve',
          'Blame your teammates for losing',
          'Refuse to play again',
        ],
      ),
      _BridgeQ(
        prompt: 'A new learner joins your class and looks nervous. What is a kind thing to do?',
        choices: [
          'Introduce yourself and invite them to join in',
          'Ignore them completely',
          'Whisper about them to your friends',
        ],
      ),
    ]),
    _Zone.simple('Teamwork', [
      _SimpleQ(
        prompt: 'Working well in a team means...?',
        choices: ['Listening to others and sharing responsibilities', 'Doing everything by yourself', 'Only doing what you want to do'],
      ),
      _SimpleQ(
        prompt: 'Why is teamwork important?',
        choices: ['It helps a group achieve more than one person alone', 'It slows everyone down', 'It has no real benefit'],
      ),
      _SimpleQ(
        prompt: 'A good team member...?',
        choices: ["Helps others and shares credit fairly", "Takes all the credit for the group's work", 'Refuses to help anyone else'],
      ),
      _SimpleQ(
        prompt: 'If a teammate makes a mistake, a good response is to...?',
        choices: ['Help them fix it and encourage them', 'Laugh at them in front of others', 'Tell the teacher to punish them'],
      ),
      _SimpleQ(
        prompt: 'Which is an example of good cooperation?',
        choices: ['Sharing ideas and taking turns leading', 'Arguing over who is in charge', 'Refusing to compromise'],
      ),
    ]),
    _Zone.simple('Communication', [
      _SimpleQ(
        prompt: 'Good communication means...?',
        choices: ['Listening carefully and speaking clearly and kindly', 'Talking over other people', 'Never saying what you think'],
      ),
      _SimpleQ(
        prompt: 'Why is it important to listen when someone is speaking?',
        choices: ['It shows respect and helps you understand them better', 'It wastes your time', 'It is not important at all'],
      ),
      _SimpleQ(
        prompt: 'If you disagree with a friend, what is the best way to communicate that?',
        choices: ['Explain your view calmly and respectfully', 'Shout to make your point', 'Refuse to speak to them'],
      ),
      _SimpleQ(
        prompt: 'Body language, like eye contact and a friendly tone, is part of...?',
        choices: ['Good communication', 'Something unimportant', 'Only how you look'],
      ),
      _SimpleQ(
        prompt: "If you don't understand an instruction, what should you do?",
        choices: ['Politely ask for it to be explained again', 'Guess and hope for the best', 'Pretend you understood'],
      ),
    ]),
    _Zone.simple('Conflict Resolution', [
      _SimpleQ(
        prompt: 'When two friends argue, a good way to resolve it is to...?',
        choices: [
          'Talk calmly, listen to each side, and find a fair solution',
          'Choose a side and gang up on the other person',
          'Stay angry and never speak to them again',
        ],
      ),
      _SimpleQ(
        prompt: 'Which is a peaceful way to solve a disagreement?',
        choices: ['Compromising so both sides are happy', 'Fighting until someone gives up', 'Getting others involved to take sides'],
      ),
      _SimpleQ(
        prompt: "If you accidentally hurt a friend's feelings, what should you do?",
        choices: ['Apologise sincerely and try to make things right', 'Pretend it did not happen', 'Blame them for being upset'],
      ),
      _SimpleQ(
        prompt: 'Why is it helpful to stay calm during a disagreement?',
        choices: ['It helps you think clearly and find a fair solution', 'It makes the problem worse', 'It has no effect'],
      ),
      _SimpleQ(
        prompt: 'If a conflict cannot be solved between friends, who could help?',
        choices: [
          'A trusted adult, like a teacher or parent',
          'No one, you should handle it alone always',
          'Someone who will take your side no matter what',
        ],
      ),
    ]),
  ];

  static const _wrongReactions = [
    'Not quite -- what would a good friend or teammate do?',
    'Hmm, think about the kindest, fairest response!',
    'Close -- try the choice that solves things calmly!',
  ];

  static const _bg1 = Color(0xFF1E2A3A);
  static const _bg2 = Color(0xFF2E4560);
  static const _card = Color(0xFF223350);
  static const _gold = Color(0xFFE8A855);

  late AnimationController _ambientCtrl;
  late AnimationController _fadeCtrl;
  late AnimationController _flashCtrl;
  late AnimationController _burstCtrl;
  late AnimationController _shakeCtrl;
  late AnimationController _plankCtrl;

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
  int _planksPlaced = 0;

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

    _plankCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
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
    _plankCtrl.dispose();
    super.dispose();
  }

  void _startGame() {
    setState(() {
      _zoneIdx = 0;
      _qIdx = 0;
      _correctCount = 0;
      _streak = 0;
      _totalXP = 0;
      _planksPlaced = 0;
      _phase = _Phase.playing;
      _selectedIndex = null;
    });
    _fadeCtrl.forward(from: 0);
  }

  void _onBridgeAnswer(int index) {
    if (_phase != _Phase.playing) return;
    final isCorrect = index == 0;
    setState(() => _selectedIndex = index);
    if (isCorrect) {
      setState(() => _planksPlaced++);
      _plankCtrl.forward(from: 0);
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
                  CustomPaint(painter: _CloudBgPainter(_ambientAnim.value)),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _BridgeHeader(
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
                      child: zone.kind == _Kind.bridge
                          ? _buildBridgeQuestion(zone.bridge[_qIdx], revealed)
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

  Widget _buildBridgeQuestion(_BridgeQ q, bool revealed) {
    return Column(
      children: [
        const SizedBox(height: 8),
        _BridgeScene(planksPlaced: _planksPlaced, popCtrl: _plankCtrl),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF141F30),
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
                        onTap: () => _onBridgeAnswer(i),
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
              '$_wrongReaction The best response was: "${q.choices[0]}"',
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

// ── Bridge scene (sequential planks + handshake completion) ────────────────

class _BridgeScene extends StatelessWidget {
  final int planksPlaced;
  final AnimationController popCtrl;
  const _BridgeScene({required this.planksPlaced, required this.popCtrl});

  static const _totalPlanks = 5;
  static const _sceneWidth = 260.0;
  static const _plankGap = 8.0;

  @override
  Widget build(BuildContext context) {
    final complete = planksPlaced >= _totalPlanks;
    const plankWidth = (_sceneWidth - (_totalPlanks - 1) * _plankGap) / _totalPlanks;

    return AnimatedBuilder(
      animation: popCtrl,
      builder: (context, _) {
        final popT = Curves.easeOutBack.transform(popCtrl.value.clamp(0.0, 1.0));
        return SizedBox(
          width: _sceneWidth + 60,
          height: 110,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Canyon gap backdrop
              Positioned(
                bottom: 20,
                child: Container(
                  width: _sceneWidth,
                  height: 8,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B121C),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              // Left cliff + character
              const Positioned(
                left: 0,
                bottom: 8,
                child: Text('🧗', style: TextStyle(fontSize: 30)),
              ),
              // Right cliff + character
              const Positioned(
                right: 0,
                bottom: 8,
                child: Text('🧗', style: TextStyle(fontSize: 30)),
              ),
              // Planks, placed sequentially left-to-right
              Positioned(
                bottom: 22,
                child: SizedBox(
                  width: _sceneWidth,
                  height: 14,
                  child: Row(
                    children: [
                      for (var i = 0; i < _totalPlanks; i++) ...[
                        if (i > 0) const SizedBox(width: _plankGap),
                        Builder(builder: (context) {
                          final placed = i < planksPlaced;
                          final isNewest = i == planksPlaced - 1;
                          final scale = placed ? (isNewest ? popT : 1.0) : 0.0;
                          return Transform.scale(
                            scale: scale,
                            child: Container(
                              width: plankWidth,
                              height: 14,
                              decoration: BoxDecoration(
                                color: const Color(0xFF8A5A2E),
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(color: _SSState._gold, width: 1),
                              ),
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              ),
              // Handshake, appears once the bridge is complete
              if (complete)
                Positioned(
                  bottom: 34,
                  child: Transform.scale(
                    scale: popT,
                    child: const Text('🤝', style: TextStyle(fontSize: 26)),
                  ),
                ),
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
    Color fill = _SSState._card;
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
          border: Border.all(color: _SSState._gold.withValues(alpha: 0.8), width: 2),
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
    Color fill = _SSState._card;
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
          border: Border.all(color: _SSState._gold.withValues(alpha: 0.8), width: 2),
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

class _CloudBgPainter extends CustomPainter {
  final double t;
  const _CloudBgPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _SSState._gold.withValues(alpha: 0.04 + 0.03 * t)
      ..style = PaintingStyle.fill;
    for (var i = 0; i < 3; i++) {
      final cx = size.width * (0.15 + i * 0.35) + t * 8;
      final cy = size.height * (0.12 + i * 0.05);
      canvas.drawCircle(Offset(cx, cy), 22, paint);
      canvas.drawCircle(Offset(cx + 20, cy + 4), 16, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CloudBgPainter oldDelegate) => oldDelegate.t != t;
}

class _ConfettiShowerPainter extends CustomPainter {
  final double t;
  const _ConfettiShowerPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(815);
    for (var i = 0; i < 18; i++) {
      final startX = rng.nextDouble() * size.width;
      final speed = 0.5 + rng.nextDouble() * 0.6;
      final y = (t * speed) * (size.height + 40) - 20;
      final x = startX + math.sin((t * 6) + i) * 12;
      final paint = Paint()
        ..color = _SSState._gold.withValues(alpha: (1 - t).clamp(0.0, 1.0));
      canvas.drawCircle(Offset(x, y), 3, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiShowerPainter oldDelegate) => oldDelegate.t != t;
}

// ── Header / progress ────────────────────────────────────────────────────────

class _BridgeHeader extends StatelessWidget {
  final String zoneName;
  final int zoneIdx;
  final int totalZones;
  final int completedSteps;
  final int totalSteps;
  const _BridgeHeader({
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
              const Text('🤝', style: TextStyle(fontSize: 22)),
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
          _BridgeTrail(completed: completedSteps, total: totalSteps),
        ],
      ),
    );
  }
}

class _BridgeTrail extends StatelessWidget {
  final int completed;
  final int total;
  const _BridgeTrail({required this.completed, required this.total});

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
                  i < completed ? '🤝' : '·',
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
            color: _SSState._card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _SSState._gold, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🤝', style: TextStyle(fontSize: 40)),
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
            colors: [_SSState._bg1, _SSState._bg2],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🤝🌉', style: TextStyle(fontSize: 44)),
                  SizedBox(height: 16),
                  Text(
                    'Social Skills',
                    style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Build teamwork, communication and conflict resolution skills!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  SizedBox(height: 24),
                  CircularProgressIndicator(color: _SSState._gold),
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
            colors: [_SSState._bg1, _SSState._bg2],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🏆🤝', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  const Text('Super Teammate!',
                      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  Text('$correctCount / $total correct ($pct%)',
                      style: const TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('+$totalXP XP',
                      style: const TextStyle(color: _SSState._gold, fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: onReplay,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _SSState._card,
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
