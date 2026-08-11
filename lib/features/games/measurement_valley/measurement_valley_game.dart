import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/game_session_model.dart';
import '../core/game_config.dart';
import '../core/game_session_persistence.dart';

// ────────────────────────────────────────────────────────────────────────────
// Measurement Valley — Grade 4 Mathematics: length, mass, capacity, time
//
// 4 Zones (5 questions each = 20 total):
//   1. Length Lane    — mm/cm/m/km conversions
//   2. Mass Meadow    — g/kg conversions
//   3. Capacity Creek — ml/l conversions
//   4. Time Torrent   — reading clocks, elapsed time, units of time
//
// Structurally distinct from every prior engine: a river-crossing "stepping
// stone" mechanic. Every question is a set of 3 irregular stone-shaped
// answer buttons; tapping the right stone makes a little hiker hop onto it
// with a bounce, tapping the wrong stone makes the hiker wobble in place
// (no progress lost). Progress is a row of stone/footprint icons instead of
// a bar. Content is real-world word problems (no diagram), unlike Fraction
// Forest's pie/bar diagrams or Geometry Jungle's drag targets.
// Architecture: fully self-contained StatefulWidget.
// ────────────────────────────────────────────────────────────────────────────

enum _Phase { intro, playing, correct, wrong, streak, zoneDone, victory }

class _MeasureQ {
  final String prompt;
  final List<String> choices; // choices[0] is always correct
  const _MeasureQ(this.prompt, this.choices);
}

class _Zone {
  final String name;
  final List<_MeasureQ> questions;
  const _Zone(this.name, this.questions);
}

class MeasurementValleyGame extends StatefulWidget {
  final GameConfig config;
  final dynamic user;
  const MeasurementValleyGame({super.key, required this.config, this.user});

  @override
  State<MeasurementValleyGame> createState() => _MVState();
}

class _MVState extends State<MeasurementValleyGame>
    with TickerProviderStateMixin {
  static const _zones = [
    _Zone('Length Lane', [
      _MeasureQ('100 cm = ? m', ['1 m', '10 m', '0.1 m']),
      _MeasureQ('5 m = ? cm', ['500 cm', '50 cm', '5000 cm']),
      _MeasureQ('2000 m = ? km', ['2 km', '20 km', '0.2 km']),
      _MeasureQ('50 mm = ? cm', ['5 cm', '50 cm', '0.5 cm']),
      _MeasureQ('3 km = ? m', ['3000 m', '300 m', '30000 m']),
    ]),
    _Zone('Mass Meadow', [
      _MeasureQ('1000 g = ? kg', ['1 kg', '10 kg', '100 kg']),
      _MeasureQ('3 kg = ? g', ['3000 g', '300 g', '30 g']),
      _MeasureQ('2500 g = ? kg', ['2.5 kg', '25 kg', '0.25 kg']),
      _MeasureQ('4 kg = ? g', ['4000 g', '400 g', '40 g']),
      _MeasureQ('6000 g = ? kg', ['6 kg', '60 kg', '0.6 kg']),
    ]),
    _Zone('Capacity Creek', [
      _MeasureQ('1000 ml = ? l', ['1 l', '10 l', '0.1 l']),
      _MeasureQ('2 l = ? ml', ['2000 ml', '200 ml', '20 ml']),
      _MeasureQ('500 ml = ? l', ['0.5 l', '5 l', '50 l']),
      _MeasureQ('3000 ml = ? l', ['3 l', '30 l', '0.3 l']),
      _MeasureQ('4 l = ? ml', ['4000 ml', '400 ml', '40000 ml']),
    ]),
    _Zone('Time Torrent', [
      _MeasureQ('A movie starts at 14:00 and lasts 1 hour. '
          'What time does it end?', ['15:00', '14:30', '16:00']),
      _MeasureQ('School starts at 08:00. Break is 2 hours later. '
          'What time is break?', ['10:00', '09:00', '11:00']),
      _MeasureQ('A recipe takes 45 minutes, starting at 10:00. '
          'When is it ready?', ['10:45', '11:00', '10:30']),
      _MeasureQ('How many minutes are in 2 hours?', ['120', '100', '60']),
      _MeasureQ('How many days are in 2 weeks?', ['14', '7', '21']),
    ]),
  ];

  static const _wrongReactions = [
    'Oops, wobbly stone! Look again.',
    'Careful -- try another stone!',
    'Not that one -- check the numbers again!',
  ];

  static const _skyTop = Color(0xFF6EC6E8);
  static const _skyBottom = Color(0xFF1E7A9C);
  static const _stoneGrey = Color(0xFF8B9A9E);
  static const _gold = Color(0xFFFFC94A);

  late AnimationController _ambientCtrl;
  late AnimationController _fadeCtrl;
  late AnimationController _flashCtrl;
  late AnimationController _splashCtrl;
  late AnimationController _wobbleCtrl;
  late AnimationController _hopCtrl;

  late Animation<double> _ambientAnim;
  late Animation<double> _fadeAnim;
  late Animation<double> _flashAnim;
  late Animation<double> _splashAnim;
  late Animation<double> _wobbleAnim;
  late Animation<double> _hopAnim;

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
        vsync: this, duration: const Duration(seconds: 5))
      ..repeat(reverse: true);
    _ambientAnim = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _ambientCtrl, curve: Curves.easeInOut));

    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);

    _flashCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _flashAnim = CurvedAnimation(parent: _flashCtrl, curve: Curves.easeOut);

    _splashCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1700));
    _splashAnim = CurvedAnimation(parent: _splashCtrl, curve: Curves.easeOut);

    _wobbleCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _wobbleAnim = CurvedAnimation(parent: _wobbleCtrl, curve: Curves.easeInOut);

    _hopCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _hopAnim = CurvedAnimation(parent: _hopCtrl, curve: Curves.elasticOut);
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
    _splashCtrl.dispose();
    _wobbleCtrl.dispose();
    _hopCtrl.dispose();
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

  Object? _cachedQ;
  List<String> _cachedChoices = [];

  List<String> _getShuffledChoices(_MeasureQ q) {
    if (!identical(_cachedQ, q)) {
      _cachedQ = q;
      _cachedChoices = List<String>.from(q.choices)..shuffle(_rng);
    }
    return _cachedChoices;
  }

  void _onAnswer(int index) {
    if (_phase != _Phase.playing) return;
    final q = _zones[_zoneIdx].questions[_qIdx];
    final choices = _getShuffledChoices(q);
    final isCorrect = choices[index] == q.choices[0];

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
      _hopCtrl.forward(from: 0);
      final isStreak = _streak > 0 && _streak % 3 == 0;
      if (isStreak) {
        _delayed(300, () {
          setState(() => _phase = _Phase.streak);
          _splashCtrl.forward(from: 0);
          _delayed(1600, _advance);
        });
      } else {
        _delayed(1000, _advance);
      }
    } else {
      _wobbleCtrl.forward(from: 0);
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
                  CustomPaint(painter: _RiverBgPainter(_ambientAnim.value)),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _ValleyHeader(
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
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 16),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              q.prompt,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          AnimatedBuilder(
                            animation: _wobbleAnim,
                            builder: (context, _) {
                              final dx = _phase == _Phase.wrong
                                  ? math.sin(_wobbleAnim.value * math.pi * 6) *
                                      6
                                  : 0.0;
                              final choices = _getShuffledChoices(q);
                              return Transform.translate(
                                offset: Offset(dx, 0),
                                child: Wrap(
                                  spacing: 16,
                                  runSpacing: 24,
                                  alignment: WrapAlignment.center,
                                  children: [
                                    for (var i = 0; i < choices.length; i++)
                                      _StoneButton(
                                        label: choices[i],
                                        selected: _selectedIndex == i,
                                        isCorrect: choices[i] == q.choices[0],
                                        revealed: revealed,
                                        hopAnim: choices[i] == q.choices[0] ? _hopAnim : null,
                                        onTap: () => _onAnswer(i),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                          if (_phase == _Phase.wrong)
                            Padding(
                              padding: const EdgeInsets.only(top: 20),
                              child: Text(
                                '$_wrongReaction The answer was ${q.choices[0]}.',
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
                  opacity: (1 - _flashAnim.value).clamp(0.0, 1.0) * 0.3,
                  child: Container(color: Colors.white),
                ),
              ),
            ),
          if (_phase == _Phase.streak)
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _splashAnim,
                builder: (context, _) => CustomPaint(
                  painter: _SplashShowerPainter(_splashAnim.value),
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

// ── Stone button (blob shape) ───────────────────────────────────────────────

class _StoneButton extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isCorrect;
  final bool revealed;
  final Animation<double>? hopAnim;
  final VoidCallback onTap;
  const _StoneButton({
    required this.label,
    required this.selected,
    required this.isCorrect,
    required this.revealed,
    required this.hopAnim,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color fill = _MVState._stoneGrey;
    if (revealed && isCorrect) fill = const Color(0xFF4CAF7D);
    if (revealed && selected && !isCorrect) fill = const Color(0xFFE05656);

    final stone = GestureDetector(
      onTap: revealed ? null : onTap,
      child: ClipPath(
        clipper: const _BlobClipper(),
        child: Container(
          width: 108,
          height: 92,
          alignment: Alignment.center,
          color: fill,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );

    if (hopAnim == null || !revealed || !isCorrect) return stone;

    return AnimatedBuilder(
      animation: hopAnim!,
      builder: (context, child) => Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          child!,
          Positioned(
            top: -28 * hopAnim!.value,
            child: Opacity(
              opacity: hopAnim!.value.clamp(0.0, 1.0),
              child: const Text('🧗', style: TextStyle(fontSize: 26)),
            ),
          ),
        ],
      ),
      child: stone,
    );
  }
}

class _BlobClipper extends CustomClipper<Path> {
  const _BlobClipper();
  @override
  Path getClip(Size size) {
    final w = size.width, h = size.height;
    final path = Path()
      ..moveTo(w * 0.15, h * 0.35)
      ..quadraticBezierTo(w * 0.05, h * 0.05, w * 0.4, h * 0.05)
      ..quadraticBezierTo(w * 0.75, -h * 0.05, w * 0.9, h * 0.3)
      ..quadraticBezierTo(w * 1.05, h * 0.55, w * 0.85, h * 0.85)
      ..quadraticBezierTo(w * 0.6, h * 1.05, w * 0.3, h * 0.9)
      ..quadraticBezierTo(w * 0.0, h * 0.75, w * 0.15, h * 0.35)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

// ── Painters ─────────────────────────────────────────────────────────────────

class _RiverBgPainter extends CustomPainter {
  final double t;
  const _RiverBgPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.12);
    for (var i = 0; i < 3; i++) {
      final y = size.height * (0.55 + i * 0.14) + math.sin(t * math.pi * 2 + i) * 6;
      final path = Path()..moveTo(0, y);
      for (double x = 0; x <= size.width; x += 40) {
        path.quadraticBezierTo(
            x + 20, y + (i.isEven ? 10 : -10), x + 40, y);
      }
      path
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RiverBgPainter oldDelegate) =>
      oldDelegate.t != t;
}

class _SplashShowerPainter extends CustomPainter {
  final double t;
  const _SplashShowerPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(5);
    for (var i = 0; i < 20; i++) {
      final startX = rng.nextDouble() * size.width;
      final speed = 0.5 + rng.nextDouble() * 0.6;
      final y = (t * speed) * (size.height + 40) - 20;
      final x = startX + math.sin((t * 6) + i) * 12;
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: (1 - t).clamp(0.0, 1.0) * 0.8);
      canvas.drawCircle(Offset(x, y), 4, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SplashShowerPainter oldDelegate) =>
      oldDelegate.t != t;
}

// ── Header / progress ────────────────────────────────────────────────────────

class _ValleyHeader extends StatelessWidget {
  final String zoneName;
  final int zoneIdx;
  final int totalZones;
  final int completedSteps;
  final int totalSteps;
  const _ValleyHeader({
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
              const Text('⛰️', style: TextStyle(fontSize: 22)),
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
          _StoneTrail(completed: completedSteps, total: totalSteps),
        ],
      ),
    );
  }
}

class _StoneTrail extends StatelessWidget {
  final int completed;
  final int total;
  const _StoneTrail({required this.completed, required this.total});

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
                  i < completed ? '🪨' : '·',
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
        color: Colors.black38,
        alignment: Alignment.center,
        child: Container(
          padding: const EdgeInsets.all(24),
          margin: const EdgeInsets.symmetric(horizontal: 40),
          decoration: BoxDecoration(
            color: _MVState._skyBottom,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _MVState._gold, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🏞️', style: TextStyle(fontSize: 40)),
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
            colors: [_MVState._skyTop, _MVState._skyBottom],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🏞️🧗', style: TextStyle(fontSize: 44)),
                  SizedBox(height: 16),
                  Text(
                    'Measurement Valley',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Hop across the river by choosing the right stone -- '
                    'get the conversions right to cross!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  SizedBox(height: 24),
                  CircularProgressIndicator(color: _MVState._gold),
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
            colors: [_MVState._skyTop, _MVState._skyBottom],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🏆🏞️', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  const Text('Valley Crossed!',
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
                          color: _MVState._gold,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: onReplay,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF7D),
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
