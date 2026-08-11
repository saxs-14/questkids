import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/game_session_model.dart';
import '../core/game_config.dart';
import '../core/game_session_persistence.dart';

// ────────────────────────────────────────────────────────────────────────────
// Problem Solver — Grade 4 Mathematics: word problems using all four
// operations
//
// 4 Zones (5 questions each = 20 total), all four detective "case files":
//   1. Missing Persons — addition / subtraction
//   2. The Heist       — multiplication / division
//   3. Stakeout        — comparison problems
//   4. Final Verdict   — hardest, mixed operations
//
// Structurally distinct from every prior engine: every question is solved
// in two guided detective steps -- first "which operation solves this
// case?" (tap one of four fixed +, -, ×, ÷ stamp badges), THEN "what's the
// answer?" (numeric case-file tiles). No prior engine asks the learner to
// identify the operation itself; every other engine hands over a
// ready-made expression. This directly targets the actual word-problem
// skill CAPS is after: choosing the right operation, not just computing.
// Architecture: fully self-contained StatefulWidget.
// ────────────────────────────────────────────────────────────────────────────

enum _Phase { intro, playing, correct, wrong, streak, zoneDone, victory }

enum _Op { add, sub, mul, div }

class _CaseQ {
  final String prompt;
  final _Op op;
  final List<String> answerChoices; // [0] is always correct
  const _CaseQ({
    required this.prompt,
    required this.op,
    required this.answerChoices,
  });
}

class _Zone {
  final String name;
  final List<_CaseQ> questions;
  const _Zone(this.name, this.questions);
}

const _opOrder = [_Op.add, _Op.sub, _Op.mul, _Op.div];
const _opSymbols = {_Op.add: '+', _Op.sub: '−', _Op.mul: '×', _Op.div: '÷'};

class ProblemSolverGame extends StatefulWidget {
  final GameConfig config;
  final dynamic user;
  const ProblemSolverGame({super.key, required this.config, this.user});

  @override
  State<ProblemSolverGame> createState() => _PSState();
}

class _PSState extends State<ProblemSolverGame> with TickerProviderStateMixin {
  static const _zones = [
    _Zone('Missing Persons', [
      _CaseQ(
          prompt: 'A detective drove 18 km, then 25 km more. '
              'How far did she drive in total?',
          op: _Op.add,
          answerChoices: ['43', '42', '45']),
      _CaseQ(
          prompt: 'There were 60 clues on the board. 24 were solved. '
              'How many remain?',
          op: _Op.sub,
          answerChoices: ['36', '34', '38']),
      _CaseQ(
          prompt: 'A witness saw 32 people, then 15 more arrived. '
              'How many in total?',
          op: _Op.add,
          answerChoices: ['47', '46', '48']),
      _CaseQ(
          prompt: 'The case file had 50 pages. 18 were removed. '
              'How many are left?',
          op: _Op.sub,
          answerChoices: ['32', '30', '34']),
      _CaseQ(
          prompt: 'Agent Cole found 27 fingerprints, then 19 more. '
              'How many in total?',
          op: _Op.add,
          answerChoices: ['46', '45', '47']),
    ]),
    _Zone('The Heist', [
      _CaseQ(
          prompt: 'The thief stole 6 bags with 8 coins each. '
              'How many coins in total?',
          op: _Op.mul,
          answerChoices: ['48', '42', '54']),
      _CaseQ(
          prompt: '45 stolen jewels were split equally among 5 suspects. '
              'How many does each get?',
          op: _Op.div,
          answerChoices: ['9', '8', '10']),
      _CaseQ(
          prompt: 'The safe had 7 shelves with 9 gold bars each. '
              'How many bars in total?',
          op: _Op.mul,
          answerChoices: ['63', '56', '72']),
      _CaseQ(
          prompt: '64 stolen notes were shared equally among 8 gang members. '
              'How many does each get?',
          op: _Op.div,
          answerChoices: ['8', '7', '9']),
      _CaseQ(
          prompt: 'A getaway car made 4 trips carrying 12 boxes each. '
              'How many boxes in total?',
          op: _Op.mul,
          answerChoices: ['48', '44', '52']),
    ]),
    _Zone('Stakeout', [
      _CaseQ(
          prompt: 'Officer A watched for 45 minutes, Officer B for 28 '
              'minutes. How much longer did A watch?',
          op: _Op.sub,
          answerChoices: ['17', '16', '18']),
      _CaseQ(
          prompt: 'The stakeout van has 3 rows of 6 seats. '
              'How many seats in total?',
          op: _Op.mul,
          answerChoices: ['18', '15', '21']),
      _CaseQ(
          prompt: '72 photos were divided equally into 9 folders. '
              'How many photos per folder?',
          op: _Op.div,
          answerChoices: ['8', '7', '9']),
      _CaseQ(
          prompt: 'Team 1 logged 34 hours, Team 2 logged 19 hours. '
              'How many more hours did Team 1 log?',
          op: _Op.sub,
          answerChoices: ['15', '14', '16']),
      _CaseQ(
          prompt: '5 detectives each filed 7 reports. '
              'How many reports in total?',
          op: _Op.mul,
          answerChoices: ['35', '30', '40']),
    ]),
    _Zone('Final Verdict', [
      _CaseQ(
          prompt: '84 pieces of evidence were shared equally among 6 '
              'investigators. How many does each get?',
          op: _Op.div,
          answerChoices: ['14', '13', '15']),
      _CaseQ(
          prompt: 'A courtroom has 12 rows of 15 seats. '
              'How many seats in total?',
          op: _Op.mul,
          answerChoices: ['180', '170', '190']),
      _CaseQ(
          prompt: 'The trial lasted 95 minutes. The verdict reading took '
              '18 minutes. How long was the trial before the verdict?',
          op: _Op.sub,
          answerChoices: ['77', '76', '78']),
      _CaseQ(
          prompt: '126 case files plus 47 new files. '
              'How many case files in total?',
          op: _Op.add,
          answerChoices: ['173', '172', '174']),
      _CaseQ(
          prompt: '9 boxes each hold 14 documents. '
              'How many documents in total?',
          op: _Op.mul,
          answerChoices: ['126', '120', '132']),
    ]),
  ];

  static const _wrongReactions = [
    'Not quite -- re-examine the case!',
    'Close -- check the clue again!',
    'Try again, detective!',
  ];

  static const _noir = Color(0xFF1A1D26);
  static const _noir2 = Color(0xFF2E2A3D);
  static const _amber = Color(0xFFD9A441);
  static const _badgeBlue = Color(0xFF3B6FA0);

  late AnimationController _ambientCtrl;
  late AnimationController _fadeCtrl;
  late AnimationController _flashCtrl;
  late AnimationController _bulbCtrl;
  late AnimationController _shakeCtrl;

  late Animation<double> _ambientAnim;
  late Animation<double> _fadeAnim;
  late Animation<double> _flashAnim;
  late Animation<double> _bulbAnim;
  late Animation<double> _shakeAnim;

  int _zoneIdx = 0;
  int _qIdx = 0;
  int _correctCount = 0;
  int _streak = 0;
  int _totalXP = 0;

  _Phase _phase = _Phase.intro;
  int? _selectedIndex;
  int _subStep = 0; // 0 = pick operation, 1 = pick answer
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

    _bulbCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600));
    _bulbAnim = CurvedAnimation(parent: _bulbCtrl, curve: Curves.easeOut);

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
    _bulbCtrl.dispose();
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

  void _onOperatorTap(int index) {
    if (_phase != _Phase.playing || _subStep != 0) return;
    final q = _zones[_zoneIdx].questions[_qIdx];
    final isCorrect = _opOrder[index] == q.op;
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
  }

  Object? _cachedQ;
  List<String> _cachedChoices = [];

  List<String> _getShuffledChoices(_CaseQ q) {
    if (!identical(_cachedQ, q)) {
      _cachedQ = q;
      _cachedChoices = List<String>.from(q.answerChoices)..shuffle(_rng);
    }
    return _cachedChoices;
  }

  void _onAnswerTap(int index) {
    if (_phase != _Phase.playing || _subStep != 1) return;
    final q = _zones[_zoneIdx].questions[_qIdx];
    final choices = _getShuffledChoices(q);
    final step2Correct = choices[index] == q.answerChoices[0];
    final overallCorrect = _step1WasCorrect && step2Correct;
    setState(() => _selectedIndex = index);
    _applyAnswerResult(overallCorrect);
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
          _bulbCtrl.forward(from: 0);
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

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_noir, _noir2],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _ambientAnim,
              builder: (context, _) =>
                  CustomPaint(painter: _SpotlightPainter(_ambientAnim.value)),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _CaseHeader(
                  zoneName: zone.name,
                  zoneIdx: _zoneIdx,
                  totalZones: _zones.length,
                  completedSteps: completedSteps,
                  totalSteps: total,
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _subStep == 0
                          ? 'Step 1/2: Which operation solves this case?'
                          : 'Step 2/2: What is the answer?',
                      style: const TextStyle(
                          color: _amber, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(14),
                              border:
                                  Border.all(color: _amber.withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              q.prompt,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                height: 1.4,
                              ),
                            ),
                          ),
                          const SizedBox(height: 26),
                          AnimatedBuilder(
                            animation: _shakeAnim,
                            builder: (context, _) {
                              final dx = _phase == _Phase.wrong
                                  ? math.sin(_shakeAnim.value * math.pi * 6) *
                                      6
                                  : 0.0;
                              return Transform.translate(
                                offset: Offset(dx, 0),
                                child: _subStep == 0
                                    ? _buildOperatorRow(q, revealed)
                                    : _buildAnswerRow(q, revealed),
                              );
                            },
                          ),
                          if (_phase == _Phase.wrong)
                            Padding(
                              padding: const EdgeInsets.only(top: 18),
                              child: Text(
                                _subStep == 0
                                    ? '$_wrongReaction It needed ${_opSymbols[q.op]}.'
                                    : '$_wrongReaction The answer was ${q.answerChoices[0]}.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: _amber,
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
                  child: Container(color: const Color(0xFF4CAF7D)),
                ),
              ),
            ),
          if (_phase == _Phase.streak)
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _bulbAnim,
                builder: (context, _) => CustomPaint(
                  painter: _FlashbulbPainter(_bulbAnim.value),
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

  Widget _buildOperatorRow(_CaseQ q, bool revealed) {
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      alignment: WrapAlignment.center,
      children: [
        for (var i = 0; i < _opOrder.length; i++)
          _StampBadge(
            symbol: _opSymbols[_opOrder[i]]!,
            selected: _selectedIndex == i,
            isCorrect: _opOrder[i] == q.op,
            revealed: revealed,
            onTap: () => _onOperatorTap(i),
          ),
      ],
    );
  }

  Widget _buildAnswerRow(_CaseQ q, bool revealed) {
    final choices = _getShuffledChoices(q);
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      alignment: WrapAlignment.center,
      children: [
        for (var i = 0; i < choices.length; i++)
          _CaseFileTile(
            label: choices[i],
            selected: _selectedIndex == i,
            isCorrect: choices[i] == q.answerChoices[0],
            revealed: revealed,
            onTap: () => _onAnswerTap(i),
          ),
      ],
    );
  }
}

// ── Operator stamp badge ─────────────────────────────────────────────────────

class _StampBadge extends StatelessWidget {
  final String symbol;
  final bool selected;
  final bool isCorrect;
  final bool revealed;
  final VoidCallback onTap;
  const _StampBadge({
    required this.symbol,
    required this.selected,
    required this.isCorrect,
    required this.revealed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color fill = _PSState._badgeBlue;
    if (revealed && isCorrect) fill = const Color(0xFF4CAF7D);
    if (revealed && selected && !isCorrect) fill = const Color(0xFFE05656);

    return GestureDetector(
      onTap: revealed ? null : onTap,
      child: Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: fill,
          border: Border.all(color: Colors.white24, width: 3),
        ),
        alignment: Alignment.center,
        child: Text(
          symbol,
          style: const TextStyle(
              color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

// ── Answer tile (case-file folder) ──────────────────────────────────────────

class _CaseFileTile extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isCorrect;
  final bool revealed;
  final VoidCallback onTap;
  const _CaseFileTile({
    required this.label,
    required this.selected,
    required this.isCorrect,
    required this.revealed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color fill = const Color(0xFF4A4460);
    if (revealed && isCorrect) fill = const Color(0xFF4CAF7D);
    if (revealed && selected && !isCorrect) fill = const Color(0xFFE05656);

    return GestureDetector(
      onTap: revealed ? null : onTap,
      child: ClipPath(
        clipper: const _FolderClipper(),
        child: Container(
          width: 96,
          height: 68,
          alignment: Alignment.center,
          padding: const EdgeInsets.only(top: 8),
          color: fill,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _FolderClipper extends CustomClipper<Path> {
  const _FolderClipper();
  @override
  Path getClip(Size size) {
    final w = size.width, h = size.height;
    final tabH = h * 0.18;
    final path = Path()
      ..moveTo(0, tabH)
      ..lineTo(w * 0.08, 0)
      ..lineTo(w * 0.4, 0)
      ..lineTo(w * 0.48, tabH)
      ..lineTo(w, tabH)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

// ── Painters ─────────────────────────────────────────────────────────────────

class _SpotlightPainter extends CustomPainter {
  final double t;
  const _SpotlightPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width * 0.5 + math.sin(t * math.pi * 2) * size.width * 0.2;
    final gradient = RadialGradient(
      colors: [
        _PSState._amber.withValues(alpha: 0.1),
        Colors.transparent,
      ],
    );
    final rect = Rect.fromCircle(center: Offset(x, 0), radius: size.width * 0.7);
    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height), Paint()..shader = gradient.createShader(rect));
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) => oldDelegate.t != t;
}

class _FlashbulbPainter extends CustomPainter {
  final double t;
  const _FlashbulbPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(29);
    for (var i = 0; i < 10; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height * 0.6;
      final flicker = (math.sin(t * 20 + i * 3) + 1) / 2;
      final paint = Paint()
        ..color = Colors.white
            .withValues(alpha: (1 - t).clamp(0.0, 1.0) * flicker * 0.9);
      canvas.drawCircle(Offset(x, y), 14, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FlashbulbPainter oldDelegate) => oldDelegate.t != t;
}

// ── Header / progress ────────────────────────────────────────────────────────

class _CaseHeader extends StatelessWidget {
  final String zoneName;
  final int zoneIdx;
  final int totalZones;
  final int completedSteps;
  final int totalSteps;
  const _CaseHeader({
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
              const Text('🕵️', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  children: [
                    Text('Case ${zoneIdx + 1}/$totalZones',
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
          _CaseTrail(completed: completedSteps, total: totalSteps),
        ],
      ),
    );
  }
}

class _CaseTrail extends StatelessWidget {
  final int completed;
  final int total;
  const _CaseTrail({required this.completed, required this.total});

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
                  i < completed ? '🔍' : '·',
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
  const _ZoneDoneOverlay(
      {required this.completedZoneName, required this.nextZoneName});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        alignment: Alignment.center,
        child: Container(
          padding: const EdgeInsets.all(24),
          margin: const EdgeInsets.symmetric(horizontal: 40),
          decoration: BoxDecoration(
            color: _PSState._noir2,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _PSState._amber, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('📁', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 8),
              Text('$completedZoneName closed!',
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
            colors: [_PSState._noir, _PSState._noir2],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🕵️🔍', style: TextStyle(fontSize: 44)),
                  SizedBox(height: 16),
                  Text(
                    'Problem Solver',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Crack every case -- pick the right operation, '
                    'then solve it to find the answer!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  SizedBox(height: 24),
                  CircularProgressIndicator(color: _PSState._amber),
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
            colors: [_PSState._noir, _PSState._noir2],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🏆🕵️', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  const Text('Case Closed!',
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
                          color: _PSState._amber,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: onReplay,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _PSState._badgeBlue,
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
