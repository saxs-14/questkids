import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/game_session_model.dart';
import '../core/game_config.dart';
import '../core/game_session_persistence.dart';

// ────────────────────────────────────────────────────────────────────────────
// Solar System — Grade 4 Natural Sciences: planets, moons and stars
//
// 4 Zones (5 questions each = 20 total):
//   1. Inner Orbits  — drag the 3 shown rocky planets onto the correct
//      orbit rings, closest-to-Sun first
//   2. Outer Orbits  — same orbital-drag mechanic, gas-giant planets
//   3. Planet Facts  — recall MCQ
//   4. Sun, Moon & Stars — recall MCQ
//
// Structurally distinct from every prior engine: Inner/Outer Orbits arrange
// their drop targets as concentric rings radiating out from a central Sun
// rather than a row of slots or a grid -- the learner drags each planet to
// the ring representing its distance from the Sun, so the CORRECT answer
// is a physical position in space around a fixed centre, not a slot in a
// sequence.
// Architecture: fully self-contained StatefulWidget.
// ────────────────────────────────────────────────────────────────────────────

enum _Phase { intro, playing, correct, wrong, streak, zoneDone, victory }

enum _Kind { orbit, simple }

class _OrbitQ {
  final List<String> planets; // canonical order, closest to Sun first
  final List<String> emojis;
  final List<int> displayOrder; // pool index -> planet index (scrambled)
  const _OrbitQ({
    required this.planets,
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
  final List<_OrbitQ> orbits;
  final List<_SimpleQ> simple;
  const _Zone.orbit(this.name, this.orbits)
      : kind = _Kind.orbit,
        simple = const [];
  const _Zone.simple(this.name, this.simple)
      : kind = _Kind.simple,
        orbits = const [];

  int get length => kind == _Kind.orbit ? orbits.length : simple.length;
}

class SolarSystemGame extends StatefulWidget {
  final GameConfig config;
  final dynamic user;
  const SolarSystemGame({super.key, required this.config, this.user});

  @override
  State<SolarSystemGame> createState() => _SSState();
}

class _SSState extends State<SolarSystemGame> with TickerProviderStateMixin {
  static const _ringRadii = [55.0, 90.0, 125.0];

  static const _zones = [
    _Zone.orbit('Inner Orbits', [
      _OrbitQ(
          planets: ['Mercury', 'Venus', 'Earth'],
          emojis: ['🪨', '🌕', '🌍'],
          displayOrder: [1, 2, 0]),
      _OrbitQ(
          planets: ['Venus', 'Earth', 'Mars'],
          emojis: ['🌕', '🌍', '🔴'],
          displayOrder: [2, 0, 1]),
      _OrbitQ(
          planets: ['Mercury', 'Earth', 'Mars'],
          emojis: ['🪨', '🌍', '🔴'],
          displayOrder: [1, 2, 0]),
      _OrbitQ(
          planets: ['Mercury', 'Venus', 'Mars'],
          emojis: ['🪨', '🌕', '🔴'],
          displayOrder: [2, 0, 1]),
      _OrbitQ(
          planets: ['Mercury', 'Venus', 'Earth'],
          emojis: ['🪨', '🌕', '🌍'],
          displayOrder: [2, 1, 0]),
    ]),
    _Zone.orbit('Outer Orbits', [
      _OrbitQ(
          planets: ['Jupiter', 'Saturn', 'Uranus'],
          emojis: ['🟠', '🪐', '🔵'],
          displayOrder: [1, 2, 0]),
      _OrbitQ(
          planets: ['Saturn', 'Uranus', 'Neptune'],
          emojis: ['🪐', '🔵', '🔷'],
          displayOrder: [2, 0, 1]),
      _OrbitQ(
          planets: ['Jupiter', 'Uranus', 'Neptune'],
          emojis: ['🟠', '🔵', '🔷'],
          displayOrder: [1, 2, 0]),
      _OrbitQ(
          planets: ['Jupiter', 'Saturn', 'Neptune'],
          emojis: ['🟠', '🪐', '🔷'],
          displayOrder: [2, 0, 1]),
      _OrbitQ(
          planets: ['Jupiter', 'Saturn', 'Uranus'],
          emojis: ['🟠', '🪐', '🔵'],
          displayOrder: [0, 2, 1]),
    ]),
    _Zone.simple('Planet Facts', [
      _SimpleQ(
          prompt: 'Which planet is known as the Red Planet?',
          choices: ['Mars', 'Venus', 'Jupiter']),
      _SimpleQ(
          prompt: 'Which is the largest planet in our solar system?',
          choices: ['Jupiter', 'Saturn', 'Earth']),
      _SimpleQ(
          prompt: 'Which planet is closest to the Sun?',
          choices: ['Mercury', 'Venus', 'Earth']),
      _SimpleQ(
          prompt: 'Which planet do we live on?',
          choices: ['Earth', 'Mars', 'Venus']),
      _SimpleQ(
          prompt: 'Which planet has beautiful rings?',
          choices: ['Saturn', 'Jupiter', 'Uranus']),
    ]),
    _Zone.simple('Sun, Moon & Stars', [
      _SimpleQ(
          prompt: 'What is the Sun?',
          choices: ['A star', 'A planet', 'A moon']),
      _SimpleQ(
          prompt: 'What orbits the Earth?',
          choices: ['The Moon', 'The Sun', 'Mars']),
      _SimpleQ(
          prompt: 'Stars appear to twinkle because they are very...?',
          choices: ['Far away', 'Cold', 'Small']),
      _SimpleQ(
          prompt: 'The Moon does NOT produce its own...?',
          choices: ['Light', 'Shape', 'Gravity']),
      _SimpleQ(
          prompt: 'Which of these is a star?',
          choices: ['The Sun', 'The Moon', 'Jupiter']),
    ]),
  ];

  static const _wrongReactions = [
    'Not quite -- check the distance from the Sun!',
    'Close -- look at the order again!',
    'Try again, astronaut!',
  ];

  static const _spaceTop = Color(0xFF0B1030);
  static const _spaceBottom = Color(0xFF2E1A5C);
  static const _card = Color(0xFF3B2E6B);
  static const _gold = Color(0xFFFFC94A);

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
  List<int?> _placements = [null, null, null]; // ring index -> planet index
  final Set<int> _placedPlanets = {};
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
      _placements = [null, null, null];
      _placedPlanets.clear();
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

  void _onDropPlanet(int ringIndex, int planetIndex) {
    if (_phase != _Phase.playing) return;
    if (_placedPlanets.contains(planetIndex)) return;
    setState(() {
      _placements[ringIndex] = planetIndex;
      _placedPlanets.add(planetIndex);
    });
    if (_placedPlanets.length == 3) {
      final isCorrect =
          List.generate(3, (i) => _placements[i] == i).every((x) => x);
      _applyAnswerResult(isCorrect);
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
            _placements = [null, null, null];
            _placedPlanets.clear();
            _phase = _Phase.playing;
          });
          _fadeCtrl.forward(from: 0);
        });
      }
    } else {
      setState(() {
        _qIdx = next;
        _selectedIndex = null;
        _placements = [null, null, null];
        _placedPlanets.clear();
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
                  colors: [_spaceTop, _spaceBottom],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _ambientAnim,
              builder: (context, _) =>
                  CustomPaint(painter: _StarfieldPainter(_ambientAnim.value)),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _SpaceHeader(
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
                      child: zone.kind == _Kind.orbit
                          ? _buildOrbitQuestion(zone.orbits[_qIdx], revealed)
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
                  child: Container(color: const Color(0xFF4CAF7D)),
                ),
              ),
            ),
          if (_phase == _Phase.streak)
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _burstAnim,
                builder: (context, _) => CustomPaint(
                  painter: _StarBurstPainter(_burstAnim.value),
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

  Widget _buildOrbitQuestion(_OrbitQ q, bool revealed) {
    const areaSize = 300.0;
    const center = Offset(areaSize / 2, areaSize - 20);
    return Column(
      children: [
        const SizedBox(height: 8),
        const Text(
          'Drag each planet to its orbit -- closest to the Sun first!',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: areaSize,
          height: areaSize,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const CustomPaint(
                size: Size(areaSize, areaSize),
                painter: _OrbitRingsPainter(center: center, radii: _ringRadii),
              ),
              Positioned(
                left: center.dx - 20,
                top: center.dy - 20,
                child: const Text('☀️', style: TextStyle(fontSize: 40)),
              ),
              for (var r = 0; r < 3; r++)
                Positioned(
                  left: center.dx - 34,
                  top: center.dy - _ringRadii[r] - 34,
                  child: _OrbitSlot(
                    label: _placements[r] != null
                        ? q.planets[_placements[r]!]
                        : null,
                    emoji: _placements[r] != null ? q.emojis[_placements[r]!] : null,
                    isCorrect: revealed ? _placements[r] == r : null,
                    onAccept: (planetIndex) => _onDropPlanet(r, planetIndex),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
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
                  for (var i = 0; i < q.planets.length; i++)
                    if (!_placedPlanets.contains(q.displayOrder[i]))
                      _PlanetCard(
                        label: q.planets[q.displayOrder[i]],
                        emoji: q.emojis[q.displayOrder[i]],
                        planetIndex: q.displayOrder[i],
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
              '$_wrongReaction The order was: ${q.planets.join(" → ")}.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
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
              color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700),
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
                    _StarTile(
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
                  color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ── Orbit slot (drop target) ────────────────────────────────────────────────

class _OrbitSlot extends StatelessWidget {
  final String? label;
  final String? emoji;
  final bool? isCorrect;
  final ValueChanged<int> onAccept;
  const _OrbitSlot({
    required this.label,
    required this.emoji,
    required this.isCorrect,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    Color fill = Colors.white.withValues(alpha: 0.12);
    Color border = Colors.white54;
    if (isCorrect == true) {
      fill = const Color(0xFF4CAF7D).withValues(alpha: 0.35);
      border = const Color(0xFF4CAF7D);
    } else if (isCorrect == false) {
      fill = const Color(0xFFE05656).withValues(alpha: 0.35);
      border = const Color(0xFFE05656);
    }

    return DragTarget<int>(
      onAcceptWithDetails: (details) => onAccept(details.data),
      builder: (context, candidateData, rejectedData) {
        return Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
            border: Border.all(
              color: candidateData.isNotEmpty ? Colors.white : border,
              width: candidateData.isNotEmpty ? 3 : 2,
            ),
          ),
          alignment: Alignment.center,
          child: label == null
              ? const Text('?', style: TextStyle(color: Colors.white54, fontSize: 18))
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(emoji!, style: const TextStyle(fontSize: 18)),
                    Text(label!,
                        style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700)),
                  ],
                ),
        );
      },
    );
  }
}

class _PlanetCard extends StatelessWidget {
  final String label;
  final String emoji;
  final int planetIndex;
  const _PlanetCard({required this.label, required this.emoji, required this.planetIndex});

  Widget _card({double opacity = 1}) => Opacity(
        opacity: opacity,
        child: Container(
          width: 78,
          height: 78,
          decoration: BoxDecoration(
            color: _SSState._card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white38, width: 2),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(height: 2),
              Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Draggable<int>(
      data: planetIndex,
      feedback: Material(color: Colors.transparent, child: _card(opacity: 0.85)),
      childWhenDragging: _card(opacity: 0.25),
      child: _card(),
    );
  }
}

// ── Star tile (simple MCQ) ──────────────────────────────────────────────────

class _StarTile extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isCorrect;
  final bool revealed;
  final VoidCallback onTap;
  const _StarTile({
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
      child: ClipPath(
        clipper: const _StarClipper(),
        child: Container(
          width: 104,
          height: 100,
          alignment: Alignment.center,
          color: fill,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}

class _StarClipper extends CustomClipper<Path> {
  const _StarClipper();
  @override
  Path getClip(Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final outerR = size.shortestSide / 2;
    final innerR = outerR * 0.5;
    const points = 5;
    final path = Path();
    for (var i = 0; i < points * 2; i++) {
      final r = i.isEven ? outerR : innerR;
      final angle = (math.pi / points) * i - math.pi / 2;
      final p = c + Offset(math.cos(angle), math.sin(angle)) * r;
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

// ── Painters ─────────────────────────────────────────────────────────────────

class _OrbitRingsPainter extends CustomPainter {
  final Offset center;
  final List<double> radii;
  const _OrbitRingsPainter({required this.center, required this.radii});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final r in radii) {
      canvas.drawCircle(center, r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _OrbitRingsPainter oldDelegate) => false;
}

class _StarfieldPainter extends CustomPainter {
  final double t;
  const _StarfieldPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(59);
    for (var i = 0; i < 40; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final glow = (math.sin(t * math.pi * 2 + i * 0.7) + 1) / 2;
      canvas.drawCircle(
        Offset(x, y),
        1.2,
        Paint()..color = Colors.white.withValues(alpha: 0.3 + glow * 0.5),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StarfieldPainter oldDelegate) => oldDelegate.t != t;
}

class _StarBurstPainter extends CustomPainter {
  final double t;
  const _StarBurstPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(61);
    final center = Offset(size.width / 2, size.height * 0.4);
    for (var i = 0; i < 18; i++) {
      final angle = (i / 18) * 2 * math.pi;
      final dist = t * (90 + rng.nextDouble() * 130);
      final pos = center + Offset(math.cos(angle), math.sin(angle)) * dist;
      final paint = Paint()
        ..color = _SSState._gold.withValues(alpha: (1 - t).clamp(0.0, 1.0));
      canvas.drawCircle(pos, 3.5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StarBurstPainter oldDelegate) => oldDelegate.t != t;
}

// ── Header / progress ────────────────────────────────────────────────────────

class _SpaceHeader extends StatelessWidget {
  final String zoneName;
  final int zoneIdx;
  final int totalZones;
  final int completedSteps;
  final int totalSteps;
  const _SpaceHeader({
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
              const Text('🪐', style: TextStyle(fontSize: 22)),
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
          _SpaceTrail(completed: completedSteps, total: totalSteps),
        ],
      ),
    );
  }
}

class _SpaceTrail extends StatelessWidget {
  final int completed;
  final int total;
  const _SpaceTrail({required this.completed, required this.total});

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
                  i < completed ? '⭐' : '·',
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
              const Text('🪐', style: TextStyle(fontSize: 40)),
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
            colors: [_SSState._spaceTop, _SSState._spaceBottom],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🪐🌟', style: TextStyle(fontSize: 44)),
                  SizedBox(height: 16),
                  Text(
                    'Solar System',
                    style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Drag each planet into its orbit and discover the '
                    'Sun, Moon and stars above us!',
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
            colors: [_SSState._spaceTop, _SSState._spaceBottom],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🏆🪐', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  const Text('Solar System Explored!',
                      style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
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
