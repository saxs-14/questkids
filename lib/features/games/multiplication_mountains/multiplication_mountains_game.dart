import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/game_session_model.dart';
import '../core/game_config.dart';
import '../core/game_session_persistence.dart';

// ────────────────────────────────────────────────────────────────────────────
// Multiplication Mountains — Grade 4 Mathematics: multi-digit multiplication
//
// 4 Zones (5 questions each = 20 total):
//   1. Grid Camp       — area-model (grid) diagram splits the multiplication
//      into tens x multiplier and ones x multiplier
//   2. Doubling Ridge   — doubling-chain diagram shows the repeated-doubling
//      strategy for x2/x4/x8
//   3. Break-Down Bluff — distributive-property word expression (text only)
//   4. Summit Push      — direct multi-digit multiplication, hardest tier
//
// Structurally distinct from every prior engine: the progress trail runs
// VERTICALLY down the left edge of the screen (a climb) instead of
// horizontally under the header like every other Grade 4 engine so far,
// and two of the four zones show a CAPS-recommended multiplication
// STRATEGY diagram (area-model grid, doubling chain) as visual scaffolding
// above the answer choices, teaching the method, not just the answer.
// Architecture: fully self-contained StatefulWidget.
// ────────────────────────────────────────────────────────────────────────────

enum _Phase { intro, playing, correct, wrong, streak, zoneDone, victory }

enum _Kind { grid, doublingChain, plain }

class _MMQ {
  final String prompt;
  final List<String> choices; // choices[0] is always correct
  final int tensPart;
  final int onesPart;
  final int multiplier;
  final List<int> chainSteps;
  const _MMQ({
    required this.prompt,
    required this.choices,
    this.tensPart = 0,
    this.onesPart = 0,
    this.multiplier = 0,
    this.chainSteps = const [],
  });
}

class _Zone {
  final String name;
  final _Kind kind;
  final List<_MMQ> questions;
  const _Zone({required this.name, required this.kind, required this.questions});
}

class MultiplicationMountainsGame extends StatefulWidget {
  final GameConfig config;
  final dynamic user;
  const MultiplicationMountainsGame({super.key, required this.config, this.user});

  @override
  State<MultiplicationMountainsGame> createState() => _MMState();
}

class _MMState extends State<MultiplicationMountainsGame>
    with TickerProviderStateMixin {
  static const _zones = [
    _Zone(name: 'Grid Camp', kind: _Kind.grid, questions: [
      _MMQ(
          prompt: '23 × 4 = ?',
          choices: ['92', '86', '82'],
          tensPart: 20,
          onesPart: 3,
          multiplier: 4),
      _MMQ(
          prompt: '34 × 3 = ?',
          choices: ['102', '96', '112'],
          tensPart: 30,
          onesPart: 4,
          multiplier: 3),
      _MMQ(
          prompt: '45 × 2 = ?',
          choices: ['90', '85', '95'],
          tensPart: 40,
          onesPart: 5,
          multiplier: 2),
      _MMQ(
          prompt: '52 × 5 = ?',
          choices: ['260', '250', '270'],
          tensPart: 50,
          onesPart: 2,
          multiplier: 5),
      _MMQ(
          prompt: '61 × 3 = ?',
          choices: ['183', '180', '186'],
          tensPart: 60,
          onesPart: 1,
          multiplier: 3),
    ]),
    _Zone(name: 'Doubling Ridge', kind: _Kind.doublingChain, questions: [
      _MMQ(
          prompt: '15 × 4 = ?',
          choices: ['60', '45', '75'],
          chainSteps: [15, 30, 60]),
      _MMQ(
          prompt: '12 × 8 = ?',
          choices: ['96', '84', '108'],
          chainSteps: [12, 24, 48, 96]),
      _MMQ(
          prompt: '18 × 2 = ?',
          choices: ['36', '38', '34'],
          chainSteps: [18, 36]),
      _MMQ(
          prompt: '25 × 4 = ?',
          choices: ['100', '90', '110'],
          chainSteps: [25, 50, 100]),
      _MMQ(
          prompt: '9 × 8 = ?',
          choices: ['72', '64', '80'],
          chainSteps: [9, 18, 36, 72]),
    ]),
    _Zone(name: 'Break-Down Bluff', kind: _Kind.plain, questions: [
      _MMQ(
          prompt: '32 × 3 = (30×3) + (2×3) = ?',
          choices: ['96', '90', '93']),
      _MMQ(
          prompt: '47 × 2 = (40×2) + (7×2) = ?',
          choices: ['94', '88', '96']),
      _MMQ(
          prompt: '56 × 3 = (50×3) + (6×3) = ?',
          choices: ['168', '162', '170']),
      _MMQ(
          prompt: '63 × 4 = (60×4) + (3×4) = ?',
          choices: ['252', '248', '256']),
      _MMQ(
          prompt: '29 × 5 = (30×5) - (1×5) = ?',
          choices: ['145', '150', '140']),
    ]),
    _Zone(name: 'Summit Push', kind: _Kind.plain, questions: [
      _MMQ(prompt: '84 × 3 = ?', choices: ['252', '246', '258']),
      _MMQ(prompt: '97 × 2 = ?', choices: ['194', '188', '196']),
      _MMQ(prompt: '126 × 3 = ?', choices: ['378', '372', '384']),
      _MMQ(prompt: '215 × 4 = ?', choices: ['860', '850', '870']),
      _MMQ(prompt: '142 × 5 = ?', choices: ['710', '700', '720']),
    ]),
  ];

  static const _wrongReactions = [
    'Not quite -- try the strategy again!',
    'Close -- check your steps!',
    'Almost -- look at the working again!',
  ];

  static const _skyTop = Color(0xFF2E4A6B);
  static const _skyBottom = Color(0xFFEDEFF2);
  static const _rock = Color(0xFF5C6B73);
  static const _flagRed = Color(0xFFD64545);

  late AnimationController _ambientCtrl;
  late AnimationController _fadeCtrl;
  late AnimationController _flashCtrl;
  late AnimationController _confettiCtrl;
  late AnimationController _shakeCtrl;

  late Animation<double> _ambientAnim;
  late Animation<double> _fadeAnim;
  late Animation<double> _flashAnim;
  late Animation<double> _confettiAnim;
  late Animation<double> _shakeAnim;

  int _zoneIdx = 0;
  int _qIdx = 0;
  int _correctCount = 0;
  int _streak = 0;
  int _totalXP = 0;

  _Phase _phase = _Phase.intro;
  int? _selectedIndex;
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
        vsync: this, duration: const Duration(seconds: 8))
      ..repeat(reverse: true);
    _ambientAnim = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _ambientCtrl, curve: Curves.easeInOut));

    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);

    _flashCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _flashAnim = CurvedAnimation(parent: _flashCtrl, curve: Curves.easeOut);

    _confettiCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1700));
    _confettiAnim =
        CurvedAnimation(parent: _confettiCtrl, curve: Curves.easeOut);

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
    _confettiCtrl.dispose();
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
    _fadeCtrl.forward(from: 0);
  }

  void _onAnswer(int index) {
    if (_phase != _Phase.playing) return;
    final isCorrect = index == 0;

    setState(() {
      _selectedIndex = index;
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
          _confettiCtrl.forward(from: 0);
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
                  colors: [_skyTop, _skyBottom],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _ambientAnim,
              builder: (context, _) =>
                  CustomPaint(painter: _MountainBgPainter(_ambientAnim.value)),
            ),
          ),
          SafeArea(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _VerticalTrail(completed: completedSteps, total: total),
                Expanded(
                  child: Column(
                    children: [
                      _MountainHeader(
                        zoneName: zone.name,
                        zoneIdx: _zoneIdx,
                        totalZones: _zones.length,
                      ),
                      Expanded(
                        child: FadeTransition(
                          opacity: _fadeAnim,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              children: [
                                const SizedBox(height: 8),
                                Text(
                                  q.prompt,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: _rock,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                if (zone.kind == _Kind.grid)
                                  _GridDiagram(q: q),
                                if (zone.kind == _Kind.doublingChain)
                                  _ChainDiagram(steps: q.chainSteps),
                                const SizedBox(height: 24),
                                AnimatedBuilder(
                                  animation: _shakeAnim,
                                  builder: (context, _) {
                                    final dx = _phase == _Phase.wrong
                                        ? math.sin(
                                                _shakeAnim.value * math.pi * 6) *
                                            6
                                        : 0.0;
                                    return Transform.translate(
                                      offset: Offset(dx, 0),
                                      child: Wrap(
                                        spacing: 14,
                                        runSpacing: 14,
                                        alignment: WrapAlignment.center,
                                        children: [
                                          for (var i = 0; i < q.choices.length; i++)
                                            _FlagButton(
                                              label: q.choices[i],
                                              selected: _selectedIndex == i,
                                              isCorrect: i == 0,
                                              revealed: revealed,
                                              onTap: () => _onAnswer(i),
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
                                      style: const TextStyle(
                                        color: _flagRed,
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
              ],
            ),
          ),
          if (_phase == _Phase.correct)
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _flashAnim,
                builder: (context, _) => Opacity(
                  opacity: (1 - _flashAnim.value).clamp(0.0, 1.0) * 0.25,
                  child: Container(color: const Color(0xFF4CAF7D)),
                ),
              ),
            ),
          if (_phase == _Phase.streak)
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _confettiAnim,
                builder: (context, _) => CustomPaint(
                  painter: _SnowShowerPainter(_confettiAnim.value),
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

// ── Area-model grid diagram ─────────────────────────────────────────────────

class _GridDiagram extends StatelessWidget {
  final _MMQ q;
  const _GridDiagram({required this.q});

  @override
  Widget build(BuildContext context) {
    final tensFlex = q.tensPart;
    final onesFlex = q.onesPart == 0 ? 1 : q.onesPart;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 40),
            Expanded(
              flex: tensFlex,
              child: Text('${q.tensPart}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: _MMState._rock, fontWeight: FontWeight.w700)),
            ),
            Expanded(
              flex: onesFlex,
              child: Text('${q.onesPart}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: _MMState._rock, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 60,
          child: Row(
            children: [
              SizedBox(
                width: 40,
                child: Text('×${q.multiplier}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: _MMState._rock, fontWeight: FontWeight.w700)),
              ),
              Expanded(
                flex: tensFlex,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFB8D4E8),
                    border: Border.all(color: _MMState._rock, width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: Text('${q.tensPart}×${q.multiplier}',
                      style: const TextStyle(fontSize: 12, color: _MMState._rock)),
                ),
              ),
              Expanded(
                flex: onesFlex,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFC8E6C9),
                    border: Border.all(color: _MMState._rock, width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: Text('${q.onesPart}×${q.multiplier}',
                      style: const TextStyle(fontSize: 12, color: _MMState._rock)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Doubling chain diagram ──────────────────────────────────────────────────

class _ChainDiagram extends StatelessWidget {
  final List<int> steps;
  const _ChainDiagram({required this.steps});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _MMState._rock, width: 1.5),
            ),
            child: Text('${steps[i]}',
                style: const TextStyle(
                    color: _MMState._rock, fontWeight: FontWeight.w700)),
          ),
          if (i != steps.length - 1)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Text('→ ×2 →',
                  style: TextStyle(color: _MMState._rock, fontSize: 12)),
            ),
        ],
      ],
    );
  }
}

// ── Flag button ──────────────────────────────────────────────────────────────

class _FlagButton extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isCorrect;
  final bool revealed;
  final VoidCallback onTap;
  const _FlagButton({
    required this.label,
    required this.selected,
    required this.isCorrect,
    required this.revealed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color fill = _MMState._flagRed;
    if (revealed && isCorrect) fill = const Color(0xFF4CAF7D);
    if (revealed && selected && !isCorrect) fill = const Color(0xFF8B8B8B);

    return GestureDetector(
      onTap: revealed ? null : onTap,
      child: ClipPath(
        clipper: const _FlagClipper(),
        child: Container(
          width: 96,
          height: 68,
          alignment: Alignment.center,
          color: fill,
          padding: const EdgeInsets.only(right: 14, left: 4),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _FlagClipper extends CustomClipper<Path> {
  const _FlagClipper();
  @override
  Path getClip(Size size) {
    final w = size.width, h = size.height;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(w * 0.85, 0)
      ..lineTo(w, h * 0.5)
      ..lineTo(w * 0.85, h)
      ..lineTo(0, h)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

// ── Painters ─────────────────────────────────────────────────────────────────

class _MountainBgPainter extends CustomPainter {
  final double t;
  const _MountainBgPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final farPaint = Paint()..color = const Color(0xFF9FB4C7);
    final nearPaint = Paint()..color = const Color(0xFF7A93AB);

    Path peaks(double baseY, double amp, double phase) {
      final path = Path()..moveTo(0, size.height);
      path.lineTo(0, baseY);
      for (double x = 0; x <= size.width; x += 60) {
        final y = baseY - amp * (0.5 + 0.5 * math.sin(x / 60 + phase));
        path.lineTo(x, y);
      }
      path
        ..lineTo(size.width, size.height)
        ..close();
      return path;
    }

    canvas.drawPath(peaks(size.height * 0.35, 40 + t * 4, 0.6), farPaint);
    canvas.drawPath(peaks(size.height * 0.45, 55, 2.1), nearPaint);
  }

  @override
  bool shouldRepaint(covariant _MountainBgPainter oldDelegate) =>
      oldDelegate.t != t;
}

class _SnowShowerPainter extends CustomPainter {
  final double t;
  const _SnowShowerPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(17);
    for (var i = 0; i < 22; i++) {
      final startX = rng.nextDouble() * size.width;
      final speed = 0.5 + rng.nextDouble() * 0.6;
      final y = (t * speed) * (size.height + 40) - 20;
      final x = startX + math.sin((t * 6) + i) * 12;
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: (1 - t).clamp(0.0, 1.0) * 0.9);
      canvas.drawCircle(Offset(x, y), 3, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SnowShowerPainter oldDelegate) =>
      oldDelegate.t != t;
}

// ── Header / vertical progress ─────────────────────────────────────────────

class _MountainHeader extends StatelessWidget {
  final String zoneName;
  final int zoneIdx;
  final int totalZones;
  const _MountainHeader({
    required this.zoneName,
    required this.zoneIdx,
    required this.totalZones,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
      child: Column(
        children: [
          Text('Camp ${zoneIdx + 1}/$totalZones',
              style: const TextStyle(color: _MMState._rock, fontSize: 11)),
          Text(
            zoneName,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: _MMState._rock,
                fontSize: 17,
                fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _VerticalTrail extends StatelessWidget {
  final int completed;
  final int total;
  const _VerticalTrail({required this.completed, required this.total});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Container(
            width: 3,
            margin: const EdgeInsets.symmetric(vertical: 16),
            color: _MMState._rock.withValues(alpha: 0.25),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = total - 1; i >= 0; i--)
                  Text(
                    i < completed ? '🚩' : '·',
                    style: TextStyle(
                      fontSize: i < completed ? 12 : 10,
                      color: i < completed ? null : _MMState._rock.withValues(alpha: 0.4),
                    ),
                  ),
              ],
            ),
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _MMState._rock, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('⛰️', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 8),
              Text('$completedZoneName complete!',
                  style: const TextStyle(
                      color: _MMState._rock,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
              if (nextZoneName != null) ...[
                const SizedBox(height: 6),
                Text('Next: $nextZoneName',
                    style: const TextStyle(color: _MMState._rock, fontSize: 13)),
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
            colors: [_MMState._skyTop, _MMState._skyBottom],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('⛰️🧗', style: TextStyle(fontSize: 44)),
                  SizedBox(height: 16),
                  Text(
                    'Multiplication Mountains',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Climb higher by solving multi-digit multiplication --'
                    ' use the grid and doubling strategies to reach the summit!',
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
            colors: [_MMState._skyTop, _MMState._skyBottom],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🏆⛰️', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  const Text('Summit Reached!',
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
                      backgroundColor: _MMState._flagRed,
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
