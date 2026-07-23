import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/game_session_model.dart';
import '../core/game_config.dart';
import '../core/game_session_persistence.dart';

// ────────────────────────────────────────────────────────────────────────────
// SA Provinces Explorer — Grade 4 Social Sciences: South Africa's 9
// provinces, their capitals, and famous landmarks
//
// NOTE: this is a DIFFERENT engine from explorer_map/ (engineType
// 'explorerMap'), which is a shared generic engine still used by other
// catalog entries. This engine (engineType 'saProvincesExplorer') is
// registered ONLY against ss_g4_provinces.
//
// 4 Zones (5 questions each = 20 total):
//   1. Find the Province   — given a capital city, tap the matching
//      province on a schematic map of South Africa
//   2. Provincial Capitals — recall MCQ
//   3. Famous Landmarks    — given a landmark, tap the matching province
//      on the same schematic map
//   4. Province Facts      — recall MCQ (size, population, borders)
//
// Structurally distinct from every prior engine: the map is a schematic,
// country-specific layout of South Africa's 9 real provinces positioned
// at their approximate real relative locations -- unlike Map Master's
// abstract compass/grid, this is a specific named-region country map,
// tapped directly rather than built, sequenced, or dialed.
// Architecture: fully self-contained StatefulWidget.
// ────────────────────────────────────────────────────────────────────────────

enum _Phase { intro, playing, correct, wrong, streak, zoneDone, victory }

enum _Kind { mapTap, simple }

// Approximate relative positions (0..1 fractional offsets within the map
// box) matching each province's real position within South Africa.
const _provincePositions = {
  'limpopo': Offset(0.55, 0.06),
  'north_west': Offset(0.28, 0.24),
  'gauteng': Offset(0.55, 0.26),
  'mpumalanga': Offset(0.80, 0.22),
  'kzn': Offset(0.82, 0.52),
  'free_state': Offset(0.52, 0.50),
  'northern_cape': Offset(0.20, 0.52),
  'western_cape': Offset(0.20, 0.82),
  'eastern_cape': Offset(0.55, 0.84),
};
const _provinceLabel = {
  'limpopo': 'Limpopo',
  'north_west': 'North West',
  'gauteng': 'Gauteng',
  'mpumalanga': 'Mpumalanga',
  'kzn': 'KwaZulu-Natal',
  'free_state': 'Free State',
  'northern_cape': 'Northern Cape',
  'western_cape': 'Western Cape',
  'eastern_cape': 'Eastern Cape',
};

class _MapQ {
  final String prompt;
  final String correct; // province id
  const _MapQ({required this.prompt, required this.correct});
}

class _SimpleQ {
  final String prompt;
  final List<String> choices; // [0] correct
  const _SimpleQ({required this.prompt, required this.choices});
}

class _Zone {
  final String name;
  final _Kind kind;
  final List<_MapQ> mapQs;
  final List<_SimpleQ> simple;
  const _Zone.map(this.name, this.mapQs)
      : kind = _Kind.mapTap,
        simple = const [];
  const _Zone.simple(this.name, this.simple)
      : kind = _Kind.simple,
        mapQs = const [];

  int get length => kind == _Kind.mapTap ? mapQs.length : simple.length;
}

class SaProvincesExplorerGame extends StatefulWidget {
  final GameConfig config;
  final dynamic user;
  const SaProvincesExplorerGame({super.key, required this.config, this.user});

  @override
  State<SaProvincesExplorerGame> createState() => _SPState();
}

class _SPState extends State<SaProvincesExplorerGame> with TickerProviderStateMixin {
  static const _zones = [
    _Zone.map('Find the Province', [
      _MapQ(prompt: "Which province's capital is Cape Town?", correct: 'western_cape'),
      _MapQ(prompt: "Which province's capital is Bloemfontein?", correct: 'free_state'),
      _MapQ(prompt: "Which province's capital is Polokwane?", correct: 'limpopo'),
      _MapQ(prompt: "Which province's capital is Kimberley?", correct: 'northern_cape'),
      _MapQ(prompt: "Which province's capital is Pietermaritzburg?", correct: 'kzn'),
    ]),
    _Zone.simple('Provincial Capitals', [
      _SimpleQ(
          prompt: 'What is the capital of Gauteng?',
          choices: ['Johannesburg', 'Durban', 'Polokwane']),
      _SimpleQ(
          prompt: 'What is the capital of Mpumalanga?',
          choices: ['Mbombela', 'Kimberley', 'Bhisho']),
      _SimpleQ(
          prompt: 'What is the capital of the Eastern Cape?',
          choices: ['Bhisho', 'Cape Town', 'Mahikeng']),
      _SimpleQ(
          prompt: 'What is the capital of North West?',
          choices: ['Mahikeng', 'Polokwane', 'Bloemfontein']),
      _SimpleQ(
          prompt: 'What is the capital of the Free State?',
          choices: ['Bloemfontein', 'Kimberley', 'Durban']),
    ]),
    _Zone.map('Famous Landmarks', [
      _MapQ(
          prompt: 'Table Mountain is a famous landmark in which province?',
          correct: 'western_cape'),
      _MapQ(
          prompt: 'The Drakensberg Mountains stretch through which province?',
          correct: 'kzn'),
      _MapQ(
          prompt: 'The Blyde River Canyon is found in which province?',
          correct: 'mpumalanga'),
      _MapQ(
          prompt: 'The Kalahari Desert stretches into which province?',
          correct: 'northern_cape'),
      _MapQ(
          prompt: 'Addo Elephant National Park is found in which province?',
          correct: 'eastern_cape'),
    ]),
    _Zone.simple('Province Facts', [
      _SimpleQ(
          prompt: 'Which is the smallest province in South Africa by area?',
          choices: ['Gauteng', 'Free State', 'Limpopo']),
      _SimpleQ(
          prompt: 'Which is the largest province in South Africa by area?',
          choices: ['Northern Cape', 'KwaZulu-Natal', 'Free State']),
      _SimpleQ(
          prompt: 'How many provinces does South Africa have?',
          choices: ['9', '7', '11']),
      _SimpleQ(
          prompt: "Which province is known as South Africa's economic hub, with the most people?",
          choices: ['Gauteng', 'Limpopo', 'Northern Cape']),
      _SimpleQ(
          prompt: 'Which of these provinces does NOT touch the ocean?',
          choices: ['Gauteng', 'Western Cape', 'KwaZulu-Natal']),
    ]),
  ];

  static const _wrongReactions = [
    'Not quite -- look again on the map!',
    "Hmm, that's a different province!",
    'Almost -- try to picture where it is!',
  ];

  static const _bg1 = Color(0xFF0F2417);
  static const _bg2 = Color(0xFF193A24);
  static const _card = Color(0xFF4A3826);
  static const _gold = Color(0xFFE8B84B);

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
  String? _pickedProvince;

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
    _pickedProvince = null;
  }

  void _onSimpleAnswer(int index) {
    if (_phase != _Phase.playing) return;
    final isCorrect = index == 0;
    setState(() => _selectedIndex = index);
    _applyAnswerResult(isCorrect);
  }

  void _onProvinceTap(String provinceId) {
    if (_phase != _Phase.playing) return;
    final q = _zones[_zoneIdx].mapQs[_qIdx];
    final isCorrect = provinceId == q.correct;
    setState(() => _pickedProvince = provinceId);
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
                  CustomPaint(painter: _SavannaBgPainter(_ambientAnim.value)),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _ProvincesHeader(
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
                      child: zone.kind == _Kind.mapTap
                          ? _buildMapQuestion(zone.mapQs[_qIdx])
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

  Widget _buildMapQuestion(_MapQ q) {
    const mapWidth = 280.0;
    const mapHeight = 300.0;
    final revealed = _phase == _Phase.correct || _phase == _Phase.wrong;

    return Column(
      children: [
        const SizedBox(height: 8),
        Text(
          q.prompt,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: mapWidth,
          height: mapHeight,
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A1C10),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                ),
              ),
              for (final entry in _provincePositions.entries)
                _provinceButton(entry.key, entry.value, mapWidth, mapHeight, q, revealed),
            ],
          ),
        ),
        if (_phase == _Phase.wrong)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              '$_wrongReaction Correct: ${_provinceLabel[q.correct]}.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _provinceButton(
      String id, Offset frac, double mapWidth, double mapHeight, _MapQ q, bool revealed) {
    final isCorrectProvince = id == q.correct;
    final isPicked = id == _pickedProvince;

    Color fill = _card;
    if (revealed && isCorrectProvince) fill = const Color(0xFF4CAF7D);
    if (revealed && isPicked && !isCorrectProvince) fill = const Color(0xFFE05656);

    const btnSize = 46.0;
    return Positioned(
      left: frac.dx * mapWidth - btnSize / 2,
      top: frac.dy * mapHeight - btnSize / 2,
      child: GestureDetector(
        onTap: () => _onProvinceTap(id),
        child: Container(
          width: btnSize,
          height: btnSize,
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
            border: Border.all(color: _gold, width: 1.5),
          ),
          alignment: Alignment.center,
          child: Text(
            _provinceLabel[id]!,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800),
          ),
        ),
      ),
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
    Color fill = _SPState._card;
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
          border: Border.all(color: _SPState._gold.withValues(alpha: 0.7), width: 2),
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

class _SavannaBgPainter extends CustomPainter {
  final double t;
  const _SavannaBgPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = _SPState._gold.withValues(alpha: 0.04 + 0.03 * t);
    const spacing = 30.0;
    for (var y = 0.0; y < size.height; y += spacing) {
      for (var x = 0.0; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), 1.3, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SavannaBgPainter oldDelegate) => oldDelegate.t != t;
}

class _SparkleShowerPainter extends CustomPainter {
  final double t;
  const _SparkleShowerPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(61);
    for (var i = 0; i < 18; i++) {
      final startX = rng.nextDouble() * size.width;
      final speed = 0.5 + rng.nextDouble() * 0.6;
      final y = (t * speed) * (size.height + 40) - 20;
      final x = startX + math.sin((t * 6) + i) * 12;
      final paint = Paint()
        ..color = _SPState._gold.withValues(alpha: (1 - t).clamp(0.0, 1.0));
      canvas.drawCircle(Offset(x, y), 3, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparkleShowerPainter oldDelegate) => oldDelegate.t != t;
}

// ── Header / progress ────────────────────────────────────────────────────────

class _ProvincesHeader extends StatelessWidget {
  final String zoneName;
  final int zoneIdx;
  final int totalZones;
  final int completedSteps;
  final int totalSteps;
  const _ProvincesHeader({
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
              const Text('🇿🇦', style: TextStyle(fontSize: 22)),
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
          _ProvincesTrail(completed: completedSteps, total: totalSteps),
        ],
      ),
    );
  }
}

class _ProvincesTrail extends StatelessWidget {
  final int completed;
  final int total;
  const _ProvincesTrail({required this.completed, required this.total});

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
            color: _SPState._card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _SPState._gold, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🇿🇦', style: TextStyle(fontSize: 40)),
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
            colors: [_SPState._bg1, _SPState._bg2],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🇿🇦🗺️', style: TextStyle(fontSize: 44)),
                  SizedBox(height: 16),
                  Text(
                    'SA Provinces Explorer',
                    style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Tap your way across South Africa\'s 9 provinces, capitals '
                    'and landmarks!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  SizedBox(height: 24),
                  CircularProgressIndicator(color: _SPState._gold),
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
            colors: [_SPState._bg1, _SPState._bg2],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🏆🇿🇦', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  const Text('Provinces Master!',
                      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  Text('$correctCount / $total correct ($pct%)',
                      style: const TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('+$totalXP XP',
                      style: const TextStyle(color: _SPState._gold, fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: onReplay,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _SPState._card,
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
