import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/game_session_model.dart';
import '../core/game_config.dart';
import '../core/game_session_persistence.dart';

// ────────────────────────────────────────────────────────────────────────────
// Division Desert — Grade 4 Mathematics: division (sharing/grouping,
// remainders, multiplication/division fact families)
//
// 4 Zones (5 questions each = 20 total):
//   1. Even Split    — exact division, no remainder (single-step MCQ)
//   2. Leftover Oasis — division WITH a remainder, answered in TWO guided
//      steps: first the quotient, then the remainder
//   3. Fact Families  — derive a division fact from a given multiplication
//      fact
//   4. Desert Trek    — sharing/grouping word problems with remainders
//
// Structurally distinct from every prior engine: Leftover Oasis is the
// first genuinely multi-step guided question in Grade 4 -- the learner
// answers "how many groups?" and THEN "how many are left over?" as two
// separate, sequential taps within the same question, mirroring how a
// learner actually works out a division with a remainder rather than
// picking a single finished answer.
// Architecture: fully self-contained StatefulWidget.
// ────────────────────────────────────────────────────────────────────────────

enum _Phase { intro, playing, correct, wrong, streak, zoneDone, victory }

enum _Kind { simple, twoStep }

class _DivQ {
  final String prompt;
  final List<String> choices; // simple kind: choices[0] correct
  final String subPrompt1;
  final List<String> quotientChoices; // twoStep: [0] correct
  final String subPrompt2;
  final List<String> remainderChoices; // twoStep: [0] correct
  const _DivQ({
    required this.prompt,
    this.choices = const [],
    this.subPrompt1 = '',
    this.quotientChoices = const [],
    this.subPrompt2 = '',
    this.remainderChoices = const [],
  });
}

class _Zone {
  final String name;
  final _Kind kind;
  final List<_DivQ> questions;
  const _Zone({required this.name, required this.kind, required this.questions});
}

class DivisionDesertGame extends StatefulWidget {
  final GameConfig config;
  final dynamic user;
  const DivisionDesertGame({super.key, required this.config, this.user});

  @override
  State<DivisionDesertGame> createState() => _DivState();
}

class _DivState extends State<DivisionDesertGame>
    with TickerProviderStateMixin {
  static const _zones = [
    _Zone(name: 'Even Split', kind: _Kind.simple, questions: [
      _DivQ(prompt: '24 ÷ 4 = ?', choices: ['6', '5', '7']),
      _DivQ(prompt: '45 ÷ 5 = ?', choices: ['9', '8', '10']),
      _DivQ(prompt: '32 ÷ 8 = ?', choices: ['4', '5', '3']),
      _DivQ(prompt: '63 ÷ 7 = ?', choices: ['9', '8', '7']),
      _DivQ(prompt: '48 ÷ 6 = ?', choices: ['8', '7', '9']),
    ]),
    _Zone(name: 'Leftover Oasis', kind: _Kind.twoStep, questions: [
      _DivQ(
          prompt: '26 ÷ 4 = ?',
          subPrompt1: 'How many groups of 4?',
          quotientChoices: ['6', '5', '7'],
          subPrompt2: 'How many are left over?',
          remainderChoices: ['2', '1', '3']),
      _DivQ(
          prompt: '29 ÷ 5 = ?',
          subPrompt1: 'How many groups of 5?',
          quotientChoices: ['5', '4', '6'],
          subPrompt2: 'How many are left over?',
          remainderChoices: ['4', '3', '2']),
      _DivQ(
          prompt: '34 ÷ 6 = ?',
          subPrompt1: 'How many groups of 6?',
          quotientChoices: ['5', '4', '6'],
          subPrompt2: 'How many are left over?',
          remainderChoices: ['4', '2', '5']),
      _DivQ(
          prompt: '41 ÷ 8 = ?',
          subPrompt1: 'How many groups of 8?',
          quotientChoices: ['5', '4', '6'],
          subPrompt2: 'How many are left over?',
          remainderChoices: ['1', '3', '2']),
      _DivQ(
          prompt: '23 ÷ 3 = ?',
          subPrompt1: 'How many groups of 3?',
          quotientChoices: ['7', '6', '8'],
          subPrompt2: 'How many are left over?',
          remainderChoices: ['2', '1', '3']),
    ]),
    _Zone(name: 'Fact Families', kind: _Kind.simple, questions: [
      _DivQ(prompt: '6 × 7 = 42, so 42 ÷ 7 = ?', choices: ['6', '7', '8']),
      _DivQ(prompt: '8 × 5 = 40, so 40 ÷ 8 = ?', choices: ['5', '8', '4']),
      _DivQ(prompt: '9 × 4 = 36, so 36 ÷ 9 = ?', choices: ['4', '9', '5']),
      _DivQ(prompt: '7 × 6 = 42, so 42 ÷ 6 = ?', choices: ['7', '6', '8']),
      _DivQ(prompt: '8 × 9 = 72, so 72 ÷ 8 = ?', choices: ['9', '8', '7']),
    ]),
    _Zone(name: 'Desert Trek', kind: _Kind.simple, questions: [
      _DivQ(
          prompt: '27 dates are shared equally among 5 camels. '
              'How many does each camel get?',
          choices: [
            '5 each, 2 left over',
            '5 each, 1 left over',
            '4 each, 7 left over'
          ]),
      _DivQ(
          prompt: '35 coins are put into bags of 6. '
              'How many full bags are there?',
          choices: [
            '5 bags, 5 left over',
            '6 bags, 0 left over',
            '5 bags, 4 left over'
          ]),
      _DivQ(
          prompt: '44 water bottles are shared among 7 hikers. '
              'How many does each hiker get?',
          choices: [
            '6 each, 2 left over',
            '6 each, 1 left over',
            '7 each, 2 left over'
          ]),
      _DivQ(
          prompt: '19 apples are put into baskets of 4. '
              'How many full baskets are there?',
          choices: [
            '4 baskets, 3 left over',
            '5 baskets, 0 left over',
            '4 baskets, 2 left over'
          ]),
      _DivQ(
          prompt: '50 pencils are shared among 8 learners. '
              'How many does each learner get?',
          choices: [
            '6 each, 2 left over',
            '6 each, 1 left over',
            '7 each, 0 left over'
          ]),
    ]),
  ];

  static const _wrongReactions = [
    'Not quite -- try the grouping again!',
    'Close -- check your facts!',
    'Almost -- count the groups again!',
  ];

  static const _skyTop = Color(0xFF4FBDBD);
  static const _skyBottom = Color(0xFFC1502E);
  static const _mesa = Color(0xFF8B4A3B);
  static const _sand = Color(0xFFE8A33D);

  late AnimationController _ambientCtrl;
  late AnimationController _fadeCtrl;
  late AnimationController _flashCtrl;
  late AnimationController _windCtrl;
  late AnimationController _shakeCtrl;

  late Animation<double> _ambientAnim;
  late Animation<double> _fadeAnim;
  late Animation<double> _flashAnim;
  late Animation<double> _windAnim;
  late Animation<double> _shakeAnim;

  int _zoneIdx = 0;
  int _qIdx = 0;
  int _correctCount = 0;
  int _streak = 0;
  int _totalXP = 0;

  _Phase _phase = _Phase.intro;
  int? _selectedIndex;
  int _subStep = 0; // 0 = quotient/only step, 1 = remainder step
  bool _step1WasCorrect = false;
  String _wrongReaction = '';

  final _rng = math.Random();

  String get _uid => (widget.user?.uid as String?) ?? '';

  int get _totalQuestions =>
      _zones.fold<int>(0, (sum, z) => sum + z.questions.length);

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

    _windCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1700));
    _windAnim = CurvedAnimation(parent: _windCtrl, curve: Curves.easeOut);

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
    _windCtrl.dispose();
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
      _subStep = 0;
      _step1WasCorrect = false;
    });
    _fadeCtrl.forward(from: 0);
  }

  Object? _cachedQKey;
  List<String> _cachedChoices = [];

  List<String> _getShuffledChoices(List<String> rawChoices, Object key) {
    if (!identical(_cachedQKey, key)) {
      _cachedQKey = key;
      _cachedChoices = List<String>.from(rawChoices)..shuffle(_rng);
    }
    return _cachedChoices;
  }

  void _onSimpleAnswer(int index) {
    if (_phase != _Phase.playing) return;
    final q = _zones[_zoneIdx].questions[_qIdx];
    final choices = _getShuffledChoices(q.choices, q);
    final isCorrect = choices[index] == q.choices[0];
    setState(() => _selectedIndex = index);
    _applyAnswerResult(isCorrect);
  }

  void _onTwoStepAnswer(int index) {
    if (_phase != _Phase.playing) return;
    final q = _zones[_zoneIdx].questions[_qIdx];
    if (_subStep == 0) {
      final choices = _getShuffledChoices(q.quotientChoices, '${_zoneIdx}_${_qIdx}_0');
      final isCorrect = choices[index] == q.quotientChoices[0];
      setState(() {
        _selectedIndex = index;
        _step1WasCorrect = isCorrect;
        _phase = isCorrect ? _Phase.correct : _Phase.wrong;
      });
      if (!isCorrect) _shakeCtrl.forward(from: 0);
      _delayed(1100, () {
        if (!mounted) return;
        setState(() {
          _subStep = 1;
          _selectedIndex = null;
          _phase = _Phase.playing;
        });
      });
    } else {
      final choices = _getShuffledChoices(q.remainderChoices, '${_zoneIdx}_${_qIdx}_1');
      final step2Correct = choices[index] == q.remainderChoices[0];
      final overallCorrect = _step1WasCorrect && step2Correct;
      setState(() => _selectedIndex = index);
      _applyAnswerResult(overallCorrect);
    }
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
          _windCtrl.forward(from: 0);
          _delayed(1600, _advance);
        });
      } else {
        _delayed(1000, _advance);
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

    if (next >= zone.questions.length) {
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
            _subStep = 0;
            _step1WasCorrect = false;
            _phase = _Phase.playing;
          });
          _fadeCtrl.forward(from: 0);
        });
      }
    } else {
      setState(() {
        _qIdx = next;
        _selectedIndex = null;
        _subStep = 0;
        _step1WasCorrect = false;
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
    final q = zone.questions[_qIdx];
    final total = _totalQuestions;
    final completedSteps = _zones
            .take(_zoneIdx)
            .fold<int>(0, (sum, z) => sum + z.questions.length) +
        _qIdx;
    final revealed = _phase == _Phase.correct || _phase == _Phase.wrong;
    final isTwoStep = zone.kind == _Kind.twoStep;
    final subPrompt = isTwoStep
        ? (_subStep == 0 ? q.subPrompt1 : q.subPrompt2)
        : '';
    final rawChoices = isTwoStep
        ? (_subStep == 0 ? q.quotientChoices : q.remainderChoices)
        : q.choices;
    final key = isTwoStep ? '${_zoneIdx}_${_qIdx}_$_subStep' : q;
    final choices = _getShuffledChoices(rawChoices, key);
    final onAnswer = isTwoStep ? _onTwoStepAnswer : _onSimpleAnswer;

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
                  CustomPaint(painter: _MesaBgPainter(_ambientAnim.value)),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _DesertHeader(
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
                      child: Column(
                        children: [
                          const SizedBox(height: 8),
                          Text(
                            q.prompt,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (isTwoStep) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Step ${_subStep + 1}/2: $subPrompt',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                          const SizedBox(height: 22),
                          AnimatedBuilder(
                            animation: _shakeAnim,
                            builder: (context, _) {
                              final dx = _phase == _Phase.wrong
                                  ? math.sin(_shakeAnim.value * math.pi * 6) *
                                      6
                                  : 0.0;
                              return Transform.translate(
                                offset: Offset(dx, 0),
                                child: Wrap(
                                  spacing: 14,
                                  runSpacing: 14,
                                  alignment: WrapAlignment.center,
                                  children: [
                                    for (var i = 0; i < choices.length; i++)
                                      _MesaTile(
                                        label: choices[i],
                                        selected: _selectedIndex == i,
                                        isCorrect: choices[i] == rawChoices[0],
                                        revealed: revealed,
                                        onTap: () => onAnswer(i),
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
                                '$_wrongReaction The answer was ${rawChoices[0]}.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          const SizedBox(height: 24),
                        ],
                      ),
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
                  child: Container(color: _sand),
                ),
              ),
            ),
          if (_phase == _Phase.streak)
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _windAnim,
                builder: (context, _) => CustomPaint(
                  painter: _SandGustPainter(_windAnim.value),
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
}

// ── Tile ─────────────────────────────────────────────────────────────────────

class _MesaTile extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isCorrect;
  final bool revealed;
  final VoidCallback onTap;
  const _MesaTile({
    required this.label,
    required this.selected,
    required this.isCorrect,
    required this.revealed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color fill = _DivState._mesa;
    if (revealed && isCorrect) fill = const Color(0xFF4CAF7D);
    if (revealed && selected && !isCorrect) fill = const Color(0xFFE05656);

    return GestureDetector(
      onTap: revealed ? null : onTap,
      child: ClipPath(
        clipper: const _MesaClipper(),
        child: Container(
          width: 110,
          height: 74,
          alignment: Alignment.center,
          color: fill,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _MesaClipper extends CustomClipper<Path> {
  const _MesaClipper();
  @override
  Path getClip(Size size) {
    final w = size.width, h = size.height;
    final inset = w * 0.12;
    final path = Path()
      ..moveTo(inset, 0)
      ..lineTo(w - inset, 0)
      ..lineTo(w, h * 0.35)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..lineTo(0, h * 0.35)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

// ── Painters ─────────────────────────────────────────────────────────────────

class _MesaBgPainter extends CustomPainter {
  final double t;
  const _MesaBgPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final farPaint = Paint()..color = const Color(0xFFB56B4A).withValues(alpha: 0.5);
    final nearPaint = Paint()..color = const Color(0xFF8B4A3B).withValues(alpha: 0.6);

    void mesa(Paint paint, double baseY, double h, double x0, double w) {
      final rect = Rect.fromLTWH(x0, baseY - h, w, h + 200);
      canvas.drawRect(rect, paint);
    }

    final shift = math.sin(t * math.pi * 2) * 4;
    mesa(farPaint, size.height * 0.4, 60, size.width * 0.05 + shift, size.width * 0.3);
    mesa(farPaint, size.height * 0.42, 45, size.width * 0.55 - shift, size.width * 0.2);
    mesa(nearPaint, size.height * 0.5, 80, -20 + shift, size.width * 0.45);
    mesa(nearPaint, size.height * 0.52, 65, size.width * 0.6 - shift, size.width * 0.5);
  }

  @override
  bool shouldRepaint(covariant _MesaBgPainter oldDelegate) => oldDelegate.t != t;
}

class _SandGustPainter extends CustomPainter {
  final double t;
  const _SandGustPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(21);
    for (var i = 0; i < 22; i++) {
      final startY = rng.nextDouble() * size.height;
      final speed = 0.5 + rng.nextDouble() * 0.6;
      final x = (t * speed) * (size.width + 40) - 20;
      final y = startY + math.sin((t * 6) + i) * 10;
      final paint = Paint()
        ..color = const Color(0xFFE8A33D)
            .withValues(alpha: (1 - t).clamp(0.0, 1.0) * 0.8);
      canvas.drawCircle(Offset(x, y), 3, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SandGustPainter oldDelegate) => oldDelegate.t != t;
}

// ── Header / progress ────────────────────────────────────────────────────────

class _DesertHeader extends StatelessWidget {
  final String zoneName;
  final int zoneIdx;
  final int totalZones;
  final int completedSteps;
  final int totalSteps;
  const _DesertHeader({
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
              const Text('🏜️', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  children: [
                    Text('Zone ${zoneIdx + 1}/$totalZones',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11)),
                    Text(
                      zoneName,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
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
          _DivisionTrail(completed: completedSteps, total: totalSteps),
        ],
      ),
    );
  }
}

class _DivisionTrail extends StatelessWidget {
  final int completed;
  final int total;
  const _DivisionTrail({required this.completed, required this.total});

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
                  i < completed ? '➗' : '·',
                  style: TextStyle(
                    fontSize: i < completed ? 12 : 10,
                    color: i < completed ? Colors.white : Colors.white38,
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
        color: Colors.black38,
        alignment: Alignment.center,
        child: Container(
          padding: const EdgeInsets.all(24),
          margin: const EdgeInsets.symmetric(horizontal: 40),
          decoration: BoxDecoration(
            color: _DivState._mesa,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _DivState._sand, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🏺', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 8),
              Text('$completedZoneName complete!',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
              if (nextZoneName != null) ...[
                const SizedBox(height: 6),
                Text('Next: $nextZoneName',
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
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
            colors: [_DivState._skyTop, _DivState._skyBottom],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🏜️🦂', style: TextStyle(fontSize: 44)),
                  SizedBox(height: 16),
                  Text(
                    'Division Desert',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Divide and conquer -- share, group and work out '
                    'what is left over to cross the desert!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  SizedBox(height: 24),
                  CircularProgressIndicator(color: Colors.white),
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
            colors: [_DivState._skyTop, _DivState._skyBottom],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🏆🏜️', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  const Text('Desert Crossed!',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  Text('$correctCount / $total correct ($pct%)',
                      style: const TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('+$totalXP XP',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: onReplay,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _DivState._mesa,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 14),
                    ),
                    child: const Text('Play Again'),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: onExit,
                    child: const Text('Exit',
                        style: TextStyle(color: Colors.white70)),
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
