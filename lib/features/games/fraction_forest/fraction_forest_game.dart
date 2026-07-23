import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/game_session_model.dart';
import '../core/game_config.dart';
import '../core/game_session_persistence.dart';

// ────────────────────────────────────────────────────────────────────────────
// Fraction Forest — Grade 4 Mathematics: fractions
//
// 4 Zones (5 questions each = 20 total), each teaching a distinct CAPS
// Grade 4 fraction skill with its own visual diagram type:
//   1. Whole Woods    — fraction of a whole, shown as a shaded pie diagram
//   2. Twin Trees     — equivalent fractions, target shown as a bar diagram
//   3. Compare Canopy — comparing fractions: tap the LARGER bar directly
//                       (or the "Equal!" leaf if they're equal) -- the
//                       diagram itself is the answer control, not a
//                       separate button row underneath it
//   4. Vine Adder     — adding fractions with the same denominator
//
// Structurally distinct from every other engine: answers are leaf-tag
// shaped buttons (almond/leaf clip path) with fraction text, EXCEPT zone 3
// where the two comparison bars are themselves the tappable targets.
// A CustomPainter-drawn pie or bar diagram is shown above every question --
// no prior engine renders a data diagram like this. Progress is a
// horizontal vine of leaves that fill in one by one. No-punishment design:
// wrong taps just shake and reveal the right answer, no progress lost.
// Architecture: fully self-contained StatefulWidget (same pattern as every
// other bespoke engine).
// ────────────────────────────────────────────────────────────────────────────

enum _Phase { intro, playing, correct, wrong, streak, zoneDone, victory }

enum _DiagramType { pie, bar, compareBar, addBar }

class _FractionQ {
  final _DiagramType type;
  final int num;
  final int denom;
  final int? num2; // second fraction, for compare/add
  final int? denom2;
  final String prompt;
  final List<String> choices; // unused for compareBar
  final int correctIndex; // for compareBar: 0=first bigger,1=second,2=equal
  const _FractionQ({
    required this.type,
    required this.num,
    required this.denom,
    this.num2,
    this.denom2,
    required this.prompt,
    required this.choices,
    required this.correctIndex,
  });
}

class _Zone {
  final String name;
  final List<_FractionQ> questions;
  const _Zone(this.name, this.questions);
}

class FractionForestGame extends StatefulWidget {
  final GameConfig config;
  final dynamic user;
  const FractionForestGame({super.key, required this.config, this.user});

  @override
  State<FractionForestGame> createState() => _FFState();
}

class _FFState extends State<FractionForestGame>
    with TickerProviderStateMixin {
  static const _zones = [
    _Zone('Whole Woods', [
      _FractionQ(
        type: _DiagramType.pie,
        num: 1,
        denom: 2,
        prompt: 'What fraction of the log is shaded?',
        choices: ['1/2', '1/3', '2/2'],
        correctIndex: 0,
      ),
      _FractionQ(
        type: _DiagramType.pie,
        num: 1,
        denom: 4,
        prompt: 'What fraction of the log is shaded?',
        choices: ['1/4', '1/2', '3/4'],
        correctIndex: 0,
      ),
      _FractionQ(
        type: _DiagramType.pie,
        num: 3,
        denom: 4,
        prompt: 'What fraction of the log is shaded?',
        choices: ['3/4', '1/4', '2/4'],
        correctIndex: 0,
      ),
      _FractionQ(
        type: _DiagramType.pie,
        num: 2,
        denom: 3,
        prompt: 'What fraction of the log is shaded?',
        choices: ['2/3', '1/3', '3/3'],
        correctIndex: 0,
      ),
      _FractionQ(
        type: _DiagramType.pie,
        num: 5,
        denom: 8,
        prompt: 'What fraction of the log is shaded?',
        choices: ['5/8', '3/8', '4/8'],
        correctIndex: 0,
      ),
    ]),
    _Zone('Twin Trees', [
      _FractionQ(
        type: _DiagramType.bar,
        num: 1,
        denom: 2,
        prompt: 'Which fraction is equivalent to 1/2?',
        choices: ['2/4', '1/3', '3/5'],
        correctIndex: 0,
      ),
      _FractionQ(
        type: _DiagramType.bar,
        num: 1,
        denom: 3,
        prompt: 'Which fraction is equivalent to 1/3?',
        choices: ['2/6', '1/2', '3/4'],
        correctIndex: 0,
      ),
      _FractionQ(
        type: _DiagramType.bar,
        num: 3,
        denom: 6,
        prompt: 'Which fraction is equivalent to 3/6?',
        choices: ['1/2', '1/3', '2/3'],
        correctIndex: 0,
      ),
      _FractionQ(
        type: _DiagramType.bar,
        num: 2,
        denom: 3,
        prompt: 'Which fraction is equivalent to 2/3?',
        choices: ['4/6', '3/5', '2/5'],
        correctIndex: 0,
      ),
      _FractionQ(
        type: _DiagramType.bar,
        num: 3,
        denom: 4,
        prompt: 'Which fraction is equivalent to 3/4?',
        choices: ['6/8', '4/5', '5/6'],
        correctIndex: 0,
      ),
    ]),
    _Zone('Compare Canopy', [
      _FractionQ(
        type: _DiagramType.compareBar,
        num: 3,
        denom: 8,
        num2: 5,
        denom2: 8,
        prompt: 'Tap the bigger fraction!',
        choices: [],
        correctIndex: 1,
      ),
      _FractionQ(
        type: _DiagramType.compareBar,
        num: 1,
        denom: 2,
        num2: 2,
        denom2: 4,
        prompt: 'Tap the bigger fraction -- or Equal!',
        choices: [],
        correctIndex: 2,
      ),
      _FractionQ(
        type: _DiagramType.compareBar,
        num: 2,
        denom: 3,
        num2: 3,
        denom2: 4,
        prompt: 'Tap the bigger fraction!',
        choices: [],
        correctIndex: 1,
      ),
      _FractionQ(
        type: _DiagramType.compareBar,
        num: 3,
        denom: 5,
        num2: 1,
        denom2: 2,
        prompt: 'Tap the bigger fraction!',
        choices: [],
        correctIndex: 0,
      ),
      _FractionQ(
        type: _DiagramType.compareBar,
        num: 5,
        denom: 6,
        num2: 4,
        denom2: 5,
        prompt: 'Tap the bigger fraction!',
        choices: [],
        correctIndex: 0,
      ),
    ]),
    _Zone('Vine Adder', [
      _FractionQ(
        type: _DiagramType.addBar,
        num: 1,
        denom: 4,
        num2: 2,
        denom2: 4,
        prompt: '1/4 + 2/4 = ?',
        choices: ['3/4', '2/4', '4/4'],
        correctIndex: 0,
      ),
      _FractionQ(
        type: _DiagramType.addBar,
        num: 2,
        denom: 6,
        num2: 3,
        denom2: 6,
        prompt: '2/6 + 3/6 = ?',
        choices: ['5/6', '4/6', '6/6'],
        correctIndex: 0,
      ),
      _FractionQ(
        type: _DiagramType.addBar,
        num: 1,
        denom: 3,
        num2: 1,
        denom2: 3,
        prompt: '1/3 + 1/3 = ?',
        choices: ['2/3', '1/3', '3/3'],
        correctIndex: 0,
      ),
      _FractionQ(
        type: _DiagramType.addBar,
        num: 3,
        denom: 8,
        num2: 2,
        denom2: 8,
        prompt: '3/8 + 2/8 = ?',
        choices: ['5/8', '4/8', '6/8'],
        correctIndex: 0,
      ),
      _FractionQ(
        type: _DiagramType.addBar,
        num: 2,
        denom: 5,
        num2: 2,
        denom2: 5,
        prompt: '2/5 + 2/5 = ?',
        choices: ['4/5', '3/5', '5/5'],
        correctIndex: 0,
      ),
    ]),
  ];

  static const _wrongReactions = [
    'Not quite -- take another look!',
    'Close! Check the shaded parts again.',
    'Hmm, try counting the parts again!',
  ];

  static const _forestGreen = Color(0xFF1B5E3A);
  static const _leafGreen = Color(0xFF4CAF50);
  static const _barkBrown = Color(0xFF6D4C2A);
  static const _gold = Color(0xFFFFC94A);

  // ── Animations ──────────────────────────────────────────────────────────
  late AnimationController _ambientCtrl; // ambient sway
  late AnimationController _fadeCtrl; // question fade-in
  late AnimationController _flashCtrl; // correct/wrong flash
  late AnimationController _leafShowerCtrl; // streak celebration
  late AnimationController _shakeCtrl; // wrong-answer shake

  late Animation<double> _ambientAnim;
  late Animation<double> _fadeAnim;
  late Animation<double> _flashAnim;
  late Animation<double> _leafShowerAnim;
  late Animation<double> _shakeAnim;

  // ── Game state ──────────────────────────────────────────────────────────
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
        vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);
    _ambientAnim = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _ambientCtrl, curve: Curves.easeInOut));

    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);

    _flashCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _flashAnim = CurvedAnimation(parent: _flashCtrl, curve: Curves.easeOut);

    _leafShowerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1700));
    _leafShowerAnim =
        CurvedAnimation(parent: _leafShowerCtrl, curve: Curves.easeOut);

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
    _leafShowerCtrl.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }

  // ── Game flow ────────────────────────────────────────────────────────────

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
    final q = _zones[_zoneIdx].questions[_qIdx];
    final isCorrect = index == q.correctIndex;

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
          _leafShowerCtrl.forward(from: 0);
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

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_forestGreen, Color(0xFF0E3322)],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _ambientAnim,
              builder: (context, _) =>
                  CustomPaint(painter: _ForestBgPainter(_ambientAnim.value)),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _ForestHeader(
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
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildDiagram(q),
                          const SizedBox(height: 28),
                          if (q.type != _DiagramType.compareBar)
                            _buildChoices(q),
                          if (_phase == _Phase.wrong)
                            Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: Text(
                                '$_wrongReaction The answer was ${q.choices.isNotEmpty ? q.choices[q.correctIndex] : ''}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: _gold,
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
                  opacity: (1 - _flashAnim.value).clamp(0.0, 1.0) * 0.35,
                  child: Container(color: _leafGreen),
                ),
              ),
            ),
          if (_phase == _Phase.streak)
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _leafShowerAnim,
                builder: (context, _) => CustomPaint(
                  painter: _LeafShowerPainter(_leafShowerAnim.value),
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

  Widget _buildDiagram(_FractionQ q) {
    switch (q.type) {
      case _DiagramType.pie:
        return SizedBox(
          width: 140,
          height: 140,
          child: CustomPaint(
            painter: _PieDiagramPainter(num: q.num, denom: q.denom),
          ),
        );
      case _DiagramType.bar:
        return SizedBox(
          width: 260,
          height: 56,
          child: CustomPaint(
            painter: _BarDiagramPainter(num: q.num, denom: q.denom),
          ),
        );
      case _DiagramType.addBar:
        return Column(
          children: [
            SizedBox(
              width: 260,
              height: 44,
              child: CustomPaint(
                painter: _BarDiagramPainter(num: q.num, denom: q.denom),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text('+', style: TextStyle(color: Colors.white, fontSize: 20)),
            ),
            SizedBox(
              width: 260,
              height: 44,
              child: CustomPaint(
                painter:
                    _BarDiagramPainter(num: q.num2!, denom: q.denom2!),
              ),
            ),
          ],
        );
      case _DiagramType.compareBar:
        return AnimatedBuilder(
          animation: _shakeAnim,
          builder: (context, _) {
            final dx = _phase == _Phase.wrong
                ? math.sin(_shakeAnim.value * math.pi * 6) * 6
                : 0.0;
            return Transform.translate(
              offset: Offset(dx, 0),
              child: Column(
                children: [
                  _CompareBar(
                    num: q.num,
                    denom: q.denom,
                    index: 0,
                    selected: _selectedIndex == 0,
                    isCorrect: q.correctIndex == 0,
                    revealed: _phase == _Phase.correct || _phase == _Phase.wrong,
                    onTap: () => _onAnswer(0),
                  ),
                  const SizedBox(height: 10),
                  _CompareBar(
                    num: q.num2!,
                    denom: q.denom2!,
                    index: 1,
                    selected: _selectedIndex == 1,
                    isCorrect: q.correctIndex == 1,
                    revealed: _phase == _Phase.correct || _phase == _Phase.wrong,
                    onTap: () => _onAnswer(1),
                  ),
                  const SizedBox(height: 14),
                  _EqualLeaf(
                    selected: _selectedIndex == 2,
                    isCorrect: q.correctIndex == 2,
                    revealed: _phase == _Phase.correct || _phase == _Phase.wrong,
                    onTap: () => _onAnswer(2),
                  ),
                ],
              ),
            );
          },
        );
    }
  }

  Widget _buildChoices(_FractionQ q) {
    return AnimatedBuilder(
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
                _LeafButton(
                  label: q.choices[i],
                  selected: _selectedIndex == i,
                  isCorrect: i == q.correctIndex,
                  revealed:
                      _phase == _Phase.correct || _phase == _Phase.wrong,
                  onTap: () => _onAnswer(i),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ── Diagrams ────────────────────────────────────────────────────────────────

class _PieDiagramPainter extends CustomPainter {
  final int num;
  final int denom;
  const _PieDiagramPainter({required this.num, required this.denom});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 4;
    final sweep = (2 * math.pi) / denom;
    final ringPaint = Paint()
      ..color = _FFState._barkBrown
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final shadedPaint = Paint()..color = _FFState._leafGreen;
    final unshadedPaint = Paint()..color = const Color(0xFFD9C79A);

    for (var i = 0; i < denom; i++) {
      final start = -math.pi / 2 + i * sweep;
      final paint = i < num ? shadedPaint : unshadedPaint;
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(Rect.fromCircle(center: center, radius: radius), start, sweep,
            false)
        ..close();
      canvas.drawPath(path, paint);
    }
    for (var i = 0; i < denom; i++) {
      final angle = -math.pi / 2 + i * sweep;
      canvas.drawLine(
        center,
        center + Offset(math.cos(angle), math.sin(angle)) * radius,
        ringPaint,
      );
    }
    canvas.drawCircle(center, radius, ringPaint);
  }

  @override
  bool shouldRepaint(covariant _PieDiagramPainter oldDelegate) =>
      oldDelegate.num != num || oldDelegate.denom != denom;
}

class _BarDiagramPainter extends CustomPainter {
  final int num;
  final int denom;
  const _BarDiagramPainter({required this.num, required this.denom});

  @override
  void paint(Canvas canvas, Size size) {
    final segW = size.width / denom;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(8),
    );
    canvas.save();
    canvas.clipRRect(rrect);
    for (var i = 0; i < denom; i++) {
      final rect = Rect.fromLTWH(i * segW, 0, segW, size.height);
      canvas.drawRect(
        rect,
        Paint()
          ..color =
              i < num ? _FFState._leafGreen : const Color(0xFFD9C79A),
      );
    }
    canvas.restore();
    final borderPaint = Paint()
      ..color = _FFState._barkBrown
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawRRect(rrect, borderPaint);
    for (var i = 1; i < denom; i++) {
      canvas.drawLine(
        Offset(i * segW, 0),
        Offset(i * segW, size.height),
        borderPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BarDiagramPainter oldDelegate) =>
      oldDelegate.num != num || oldDelegate.denom != denom;
}

class _LeafShowerPainter extends CustomPainter {
  final double t;
  const _LeafShowerPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(7);
    for (var i = 0; i < 22; i++) {
      final startX = rng.nextDouble() * size.width;
      final speed = 0.6 + rng.nextDouble() * 0.6;
      final y = (t * speed) * (size.height + 40) - 20;
      final x = startX + math.sin((t * 6) + i) * 14;
      final paint = Paint()
        ..color = (i.isEven ? _FFState._leafGreen : _FFState._gold)
            .withValues(alpha: (1 - t).clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(t * 6 + i);
      canvas.drawOval(const Rect.fromLTWH(-6, -3, 12, 6), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _LeafShowerPainter oldDelegate) =>
      oldDelegate.t != t;
}

class _ForestBgPainter extends CustomPainter {
  final double t;
  const _ForestBgPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05 + 0.03 * t);
    for (var i = 0; i < 5; i++) {
      final x = size.width * (0.1 + i * 0.2);
      final sway = math.sin(t * math.pi * 2 + i) * 6;
      canvas.drawCircle(Offset(x + sway, size.height * 0.15 + i * 10), 30, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ForestBgPainter oldDelegate) =>
      oldDelegate.t != t;
}

// ── Shapes ──────────────────────────────────────────────────────────────────

class _LeafClipper extends CustomClipper<Path> {
  const _LeafClipper();
  @override
  Path getClip(Size size) {
    final w = size.width, h = size.height;
    final path = Path()
      ..moveTo(w * 0.5, 0)
      ..quadraticBezierTo(w, h * 0.15, w, h * 0.5)
      ..quadraticBezierTo(w, h * 0.85, w * 0.5, h)
      ..quadraticBezierTo(0, h * 0.85, 0, h * 0.5)
      ..quadraticBezierTo(0, h * 0.15, w * 0.5, 0)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

// ── Widgets ─────────────────────────────────────────────────────────────────

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
    Color fill = const Color(0xFF2E7D4F);
    if (revealed && isCorrect) fill = _FFState._leafGreen;
    if (revealed && selected && !isCorrect) fill = const Color(0xFFE05656);

    return GestureDetector(
      onTap: revealed ? null : onTap,
      child: ClipPath(
        clipper: const _LeafClipper(),
        child: Container(
          width: 92,
          height: 78,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: fill),
          padding: const EdgeInsets.symmetric(horizontal: 6),
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

class _CompareBar extends StatelessWidget {
  final int num;
  final int denom;
  final int index;
  final bool selected;
  final bool isCorrect;
  final bool revealed;
  final VoidCallback onTap;
  const _CompareBar({
    required this.num,
    required this.denom,
    required this.index,
    required this.selected,
    required this.isCorrect,
    required this.revealed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color borderColor = Colors.white24;
    if (revealed && isCorrect) borderColor = _FFState._gold;
    if (revealed && selected && !isCorrect) borderColor = const Color(0xFFE05656);

    return GestureDetector(
      onTap: revealed ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          border: Border.all(color: borderColor, width: 3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            SizedBox(
              width: 240,
              height: 40,
              child: CustomPaint(
                painter: _BarDiagramPainter(num: num, denom: denom),
              ),
            ),
            const SizedBox(height: 4),
            Text('$num/$denom',
                style: const TextStyle(color: Colors.white, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _EqualLeaf extends StatelessWidget {
  final bool selected;
  final bool isCorrect;
  final bool revealed;
  final VoidCallback onTap;
  const _EqualLeaf({
    required this.selected,
    required this.isCorrect,
    required this.revealed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color fill = const Color(0xFF2E7D4F);
    if (revealed && isCorrect) fill = _FFState._leafGreen;
    if (revealed && selected && !isCorrect) fill = const Color(0xFFE05656);
    return GestureDetector(
      onTap: revealed ? null : onTap,
      child: ClipPath(
        clipper: const _LeafClipper(),
        child: Container(
          width: 100,
          height: 60,
          alignment: Alignment.center,
          color: fill,
          child: const Text('Equal!',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }
}

class _ForestHeader extends StatelessWidget {
  final String zoneName;
  final int zoneIdx;
  final int totalZones;
  final int completedSteps;
  final int totalSteps;
  const _ForestHeader({
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
              const Text('🌲', style: TextStyle(fontSize: 22)),
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
          _VineProgress(completed: completedSteps, total: totalSteps),
        ],
      ),
    );
  }
}

class _VineProgress extends StatelessWidget {
  final int completed;
  final int total;
  const _VineProgress({required this.completed, required this.total});

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
          LayoutBuilder(
            builder: (context, constraints) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var i = 0; i < total; i++)
                    Text(
                      i < completed ? '🍃' : '·',
                      style: TextStyle(
                        fontSize: i < completed ? 12 : 10,
                        color: i < completed ? null : Colors.white38,
                      ),
                    ),
                ],
              );
            },
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
        color: Colors.black45,
        alignment: Alignment.center,
        child: Container(
          padding: const EdgeInsets.all(24),
          margin: const EdgeInsets.symmetric(horizontal: 40),
          decoration: BoxDecoration(
            color: _FFState._forestGreen,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _FFState._gold, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🌳', style: TextStyle(fontSize: 40)),
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
            colors: [_FFState._forestGreen, Color(0xFF0E3322)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🌲🍃🌲', style: TextStyle(fontSize: 44)),
                  SizedBox(height: 16),
                  Text(
                    'Fraction Forest',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Zuri the Forest Guide needs your help to compare, '
                    'match and add fractions across the forest!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  SizedBox(height: 24),
                  CircularProgressIndicator(color: _FFState._gold),
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
            colors: [_FFState._forestGreen, Color(0xFF0E3322)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🏆🌲', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  const Text('Forest Complete!',
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
                          color: _FFState._gold,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: onReplay,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _FFState._leafGreen,
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
