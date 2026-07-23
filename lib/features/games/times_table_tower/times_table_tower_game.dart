import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/game_session_model.dart';
import '../core/game_config.dart';
import '../core/game_session_persistence.dart';

// ────────────────────────────────────────────────────────────────────────────
// Times Table Tower — Grade 4 Mathematics: times tables 1×1 to 12×12
//
// 4 Zones (5 questions each = 20 total):
//   1. Foundation Floor   — ×2, ×3, ×4, ×5
//   2. Middle Floor       — ×6, ×7, ×8
//   3. Sky Floor          — ×9, ×11, ×12
//   4. Penthouse Challenge — hardest / near-square facts
//
// Structurally distinct from every prior engine: answering fast (under 3
// seconds) adds a GOLD brick and a speed-bonus instead of a normal one --
// this rewards automatic recall (the actual point of times tables) without
// ever punishing a slower correct answer, unlike Number Ninja's countdown
// timer which can time a question out. Every brick, gold or not, is added
// to a persistent tower that keeps growing across the WHOLE game (not per
// zone, and never reset), visible in the corner the entire time.
// Architecture: fully self-contained StatefulWidget.
// ────────────────────────────────────────────────────────────────────────────

enum _Phase { intro, playing, correct, wrong, streak, zoneDone, victory }

class _TableQ {
  final String prompt;
  final List<String> choices; // choices[0] is always correct
  const _TableQ({required this.prompt, required this.choices});
}

class _Zone {
  final String name;
  final List<_TableQ> questions;
  const _Zone(this.name, this.questions);
}

class TimesTableTowerGame extends StatefulWidget {
  final GameConfig config;
  final dynamic user;
  const TimesTableTowerGame({super.key, required this.config, this.user});

  @override
  State<TimesTableTowerGame> createState() => _TTState();
}

class _TTState extends State<TimesTableTowerGame>
    with TickerProviderStateMixin {
  static const _zones = [
    _Zone('Foundation Floor', [
      _TableQ(prompt: '4 × 5 = ?', choices: ['20', '16', '24']),
      _TableQ(prompt: '3 × 6 = ?', choices: ['18', '15', '21']),
      _TableQ(prompt: '5 × 7 = ?', choices: ['35', '30', '40']),
      _TableQ(prompt: '2 × 9 = ?', choices: ['18', '16', '20']),
      _TableQ(prompt: '4 × 8 = ?', choices: ['32', '28', '36']),
    ]),
    _Zone('Middle Floor', [
      _TableQ(prompt: '6 × 7 = ?', choices: ['42', '36', '48']),
      _TableQ(prompt: '7 × 8 = ?', choices: ['56', '48', '63']),
      _TableQ(prompt: '6 × 9 = ?', choices: ['54', '48', '60']),
      _TableQ(prompt: '8 × 5 = ?', choices: ['40', '35', '45']),
      _TableQ(prompt: '7 × 6 = ?', choices: ['42', '35', '49']),
    ]),
    _Zone('Sky Floor', [
      _TableQ(prompt: '9 × 8 = ?', choices: ['72', '64', '81']),
      _TableQ(prompt: '11 × 4 = ?', choices: ['44', '40', '48']),
      _TableQ(prompt: '12 × 3 = ?', choices: ['36', '33', '39']),
      _TableQ(prompt: '9 × 9 = ?', choices: ['81', '72', '90']),
      _TableQ(prompt: '11 × 6 = ?', choices: ['66', '60', '72']),
    ]),
    _Zone('Penthouse Challenge', [
      _TableQ(prompt: '12 × 7 = ?', choices: ['84', '77', '91']),
      _TableQ(prompt: '9 × 12 = ?', choices: ['108', '99', '117']),
      _TableQ(prompt: '11 × 11 = ?', choices: ['121', '110', '132']),
      _TableQ(prompt: '12 × 12 = ?', choices: ['144', '132', '156']),
      _TableQ(prompt: '8 × 9 = ?', choices: ['72', '64', '81']),
    ]),
  ];

  static const _wrongReactions = [
    'Not quite -- try that fact again!',
    'Close -- check your table!',
    'Try again -- you know this one!',
  ];

  static const _skyTop = Color(0xFF6EC6E8);
  static const _skyBottom = Color(0xFFF4C95D);
  static const _brick = Color(0xFFB05C3A);
  static const _brickGold = Color(0xFFF4C95D);

  static const _fastThresholdMs = 3000;

  late AnimationController _ambientCtrl;
  late AnimationController _fadeCtrl;
  late AnimationController _flashCtrl;
  late AnimationController _sparkCtrl;
  late AnimationController _shakeCtrl;

  late Animation<double> _ambientAnim;
  late Animation<double> _fadeAnim;
  late Animation<double> _flashAnim;
  late Animation<double> _sparkAnim;
  late Animation<double> _shakeAnim;

  int _zoneIdx = 0;
  int _qIdx = 0;
  int _correctCount = 0;
  int _streak = 0;
  int _totalXP = 0;

  _Phase _phase = _Phase.intro;
  int? _selectedIndex;
  bool _wasFast = false;
  String _wrongReaction = '';
  DateTime _questionStart = DateTime.now();
  final List<bool> _towerBricks = []; // true = gold/fast brick

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

    _sparkCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600));
    _sparkAnim = CurvedAnimation(parent: _sparkCtrl, curve: Curves.easeOut);

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
    _sparkCtrl.dispose();
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
      _wasFast = false;
      _towerBricks.clear();
      _questionStart = DateTime.now();
    });
    _fadeCtrl.forward(from: 0);
  }

  void _onAnswer(int index) {
    if (_phase != _Phase.playing) return;
    final isCorrect = index == 0;
    final elapsedMs = DateTime.now().difference(_questionStart).inMilliseconds;
    final isFast = isCorrect && elapsedMs < _fastThresholdMs;

    setState(() {
      _selectedIndex = index;
      _wasFast = isFast;
      if (isCorrect) {
        _correctCount++;
        _streak++;
        _totalXP += isFast ? 15 : 10;
        _towerBricks.add(isFast);
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
          _sparkCtrl.forward(from: 0);
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
            _wasFast = false;
            _phase = _Phase.playing;
            _questionStart = DateTime.now();
          });
          _fadeCtrl.forward(from: 0);
        });
      }
    } else {
      setState(() {
        _qIdx = next;
        _selectedIndex = null;
        _wasFast = false;
        _phase = _Phase.playing;
        _questionStart = DateTime.now();
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
        towerHeight: _towerBricks.length,
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
                  CustomPaint(painter: _CloudBgPainter(_ambientAnim.value)),
            ),
          ),
          Positioned(
            top: 90,
            right: 12,
            child: _TowerWidget(bricks: _towerBricks),
          ),
          SafeArea(
            child: Column(
              children: [
                _TowerHeader(
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
                      padding: const EdgeInsets.only(left: 20, right: 70),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 16),
                          Text(
                            q.prompt,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF2E3A46),
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 24),
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
                                    for (var i = 0; i < q.choices.length; i++)
                                      _BrickButton(
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
                          if (_phase == _Phase.correct && _wasFast)
                            const Padding(
                              padding: EdgeInsets.only(top: 16),
                              child: Text(
                                '⚡ Speed Bonus!',
                                style: TextStyle(
                                  color: Color(0xFFB05C3A),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          if (_phase == _Phase.wrong)
                            Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: Text(
                                '$_wrongReaction The answer was ${q.choices[0]}.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFF8A4A2E),
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
                  opacity: (1 - _flashAnim.value).clamp(0.0, 1.0) * 0.25,
                  child: Container(color: const Color(0xFF4CAF7D)),
                ),
              ),
            ),
          if (_phase == _Phase.streak)
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _sparkAnim,
                builder: (context, _) => CustomPaint(
                  painter: _SparkShowerPainter(_sparkAnim.value),
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

// ── Growing tower (persistent across the whole game) ────────────────────────

class _TowerWidget extends StatelessWidget {
  final List<bool> bricks;
  const _TowerWidget({required this.bricks});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 220,
      alignment: Alignment.bottomCenter,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          for (final gold in bricks.reversed.take(20).toList().reversed)
            Container(
              margin: const EdgeInsets.only(bottom: 2),
              width: double.infinity,
              height: 8,
              decoration: BoxDecoration(
                color: gold ? _TTState._brickGold : _TTState._brick,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Brick answer button ──────────────────────────────────────────────────────

class _BrickButton extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isCorrect;
  final bool revealed;
  final VoidCallback onTap;
  const _BrickButton({
    required this.label,
    required this.selected,
    required this.isCorrect,
    required this.revealed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color fill = _TTState._brick;
    if (revealed && isCorrect) fill = const Color(0xFF4CAF7D);
    if (revealed && selected && !isCorrect) fill = const Color(0xFFE05656);

    return GestureDetector(
      onTap: revealed ? null : onTap,
      child: Container(
        width: 96,
        height: 60,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: 18,
              left: 0,
              right: 0,
              child: Container(height: 1.5, color: Colors.white24),
            ),
            Positioned(
              top: 38,
              left: 0,
              right: 0,
              child: Container(height: 1.5, color: Colors.white24),
            ),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
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
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.35);
    for (var i = 0; i < 4; i++) {
      final x = size.width * (0.15 + i * 0.25) + math.sin(t * math.pi * 2 + i) * 10;
      final y = size.height * (0.08 + (i % 2) * 0.06);
      canvas.drawOval(Rect.fromCenter(center: Offset(x, y), width: 60, height: 22), paint);
      canvas.drawOval(Rect.fromCenter(center: Offset(x + 18, y - 6), width: 40, height: 20), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CloudBgPainter oldDelegate) => oldDelegate.t != t;
}

class _SparkShowerPainter extends CustomPainter {
  final double t;
  const _SparkShowerPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(31);
    for (var i = 0; i < 20; i++) {
      final startX = rng.nextDouble() * size.width;
      final speed = 0.5 + rng.nextDouble() * 0.6;
      final y = (t * speed) * (size.height + 40) - 20;
      final x = startX + math.sin((t * 6) + i) * 12;
      final paint = Paint()
        ..color = _TTState._brickGold
            .withValues(alpha: (1 - t).clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(t * 8 + i);
      canvas.drawRect(const Rect.fromLTWH(-4, -1.5, 8, 3), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _SparkShowerPainter oldDelegate) => oldDelegate.t != t;
}

// ── Header / progress ────────────────────────────────────────────────────────

class _TowerHeader extends StatelessWidget {
  final String zoneName;
  final int zoneIdx;
  final int totalZones;
  final int completedSteps;
  final int totalSteps;
  const _TowerHeader({
    required this.zoneName,
    required this.zoneIdx,
    required this.totalZones,
    required this.completedSteps,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 76, 4),
      child: Column(
        children: [
          Row(
            children: [
              const Text('🏗️', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  children: [
                    Text('Floor ${zoneIdx + 1}/$totalZones',
                        style: const TextStyle(
                            color: Color(0xFF2E3A46), fontSize: 11)),
                    Text(
                      zoneName,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Color(0xFF2E3A46),
                          fontSize: 16,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _BrickTrail(completed: completedSteps, total: totalSteps),
        ],
      ),
    );
  }
}

class _BrickTrail extends StatelessWidget {
  final int completed;
  final int total;
  const _BrickTrail({required this.completed, required this.total});

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
            color: const Color(0xFF2E3A46).withValues(alpha: 0.2),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < total; i++)
                Text(
                  i < completed ? '🧱' : '·',
                  style: TextStyle(
                    fontSize: i < completed ? 12 : 10,
                    color: i < completed
                        ? null
                        : const Color(0xFF2E3A46).withValues(alpha: 0.35),
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _TTState._brick, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🏗️', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 8),
              Text('$completedZoneName complete!',
                  style: const TextStyle(
                      color: Color(0xFF2E3A46),
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
              if (nextZoneName != null) ...[
                const SizedBox(height: 6),
                Text('Next: $nextZoneName',
                    style: const TextStyle(
                        color: Color(0xFF2E3A46), fontSize: 13)),
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
            colors: [_TTState._skyTop, _TTState._skyBottom],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🏗️🧱', style: TextStyle(fontSize: 44)),
                  SizedBox(height: 16),
                  Text(
                    'Times Table Tower',
                    style: TextStyle(
                      color: Color(0xFF2E3A46),
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Answer fast for a gold brick -- build your tower '
                    'all the way up to 12 × 12!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF3E4A56), fontSize: 14),
                  ),
                  SizedBox(height: 24),
                  CircularProgressIndicator(color: Color(0xFF2E3A46)),
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
  final int towerHeight;
  final VoidCallback onReplay;
  final VoidCallback onExit;
  const _VictoryScreen({
    required this.correctCount,
    required this.total,
    required this.totalXP,
    required this.towerHeight,
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
            colors: [_TTState._skyTop, _TTState._skyBottom],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🏆🏗️', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  const Text('Tower Complete!',
                      style: TextStyle(
                          color: Color(0xFF2E3A46),
                          fontSize: 26,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  Text('$correctCount / $total correct ($pct%)',
                      style: const TextStyle(
                          color: Color(0xFF3E4A56), fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('$towerHeight bricks laid • +$totalXP XP',
                      style: const TextStyle(
                          color: Color(0xFF2E3A46),
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: onReplay,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _TTState._brick,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 14),
                    ),
                    child: const Text('Play Again'),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: onExit,
                    child: const Text('Exit',
                        style: TextStyle(color: Color(0xFF3E4A56))),
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
