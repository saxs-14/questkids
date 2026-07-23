import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/game_session_model.dart';
import '../core/game_config.dart';
import '../core/game_session_persistence.dart';

// ────────────────────────────────────────────────────────────────────────────
// Ancient Civilizations — Grade 4 Social Sciences: Ancient Egypt and
// Mesopotamia, the first great river civilizations
//
// NOTE: this is a DIFFERENT engine from adventure_journey/ (engineType
// 'adventureJourney'), which is a shared generic engine still used by 21
// other catalog entries. This engine (engineType 'ancientCivilizations')
// is registered ONLY against ss_g4_ancient.
//
// 4 Zones (5 questions each = 20 total):
//   1. Excavate the Artifact — answer what an artifact is, then watch a
//      3x3 grid of sand tiles clear away in a staggered dig animation to
//      reveal it
//   2. Ancient Egypt          — recall MCQ (Nile, pharaohs, pyramids)
//   3. Ancient Mesopotamia    — recall MCQ (Tigris/Euphrates, cuneiform,
//      Hammurabi)
//   4. Why Rivers Mattered    — recall MCQ (farming, trade, writing)
//
// Structurally distinct from every prior engine: Zone 1 is the first
// "excavation reveal" -- a staggered tile-clearing animation over a
// hidden artifact, rather than a diagram that lights up or a character
// that moves.
// Architecture: fully self-contained StatefulWidget.
// ────────────────────────────────────────────────────────────────────────────

enum _Phase { intro, playing, correct, wrong, streak, zoneDone, victory }

enum _Kind { dig, simple }

class _DigQ {
  final String prompt;
  final List<String> choices; // [0] correct
  final String artifactEmoji;
  const _DigQ({required this.prompt, required this.choices, required this.artifactEmoji});
}

class _SimpleQ {
  final String prompt;
  final List<String> choices; // [0] correct
  const _SimpleQ({required this.prompt, required this.choices});
}

class _Zone {
  final String name;
  final _Kind kind;
  final List<_DigQ> dig;
  final List<_SimpleQ> simple;
  const _Zone.dig(this.name, this.dig)
      : kind = _Kind.dig,
        simple = const [];
  const _Zone.simple(this.name, this.simple)
      : kind = _Kind.simple,
        dig = const [];

  int get length => kind == _Kind.dig ? dig.length : simple.length;
}

class AncientCivilizationsGame extends StatefulWidget {
  final GameConfig config;
  final dynamic user;
  const AncientCivilizationsGame({super.key, required this.config, this.user});

  @override
  State<AncientCivilizationsGame> createState() => _ACState();
}

class _ACState extends State<AncientCivilizationsGame> with TickerProviderStateMixin {
  static const _zones = [
    _Zone.dig('Excavate the Artifact', [
      _DigQ(
          prompt: 'This ancient Egyptian structure was built as a tomb for a pharaoh. What is it?',
          choices: ['Pyramid', 'Ziggurat', 'Aqueduct'],
          artifactEmoji: '🔺'),
      _DigQ(
          prompt:
              'Egyptians preserved the bodies of their dead through a special process. What is this called?',
          choices: ['Mummification', 'Cremation', 'Sculpting'],
          artifactEmoji: '🧟'),
      _DigQ(
          prompt: 'Mesopotamians built stepped temple towers to honour their gods. What are they called?',
          choices: ['Ziggurats', 'Pyramids', 'Colosseums'],
          artifactEmoji: '🏯'),
      _DigQ(
          prompt:
              'Ancient Mesopotamians wrote using wedge-shaped marks on clay tablets. What is this writing system called?',
          choices: ['Cuneiform', 'Hieroglyphics', 'Braille'],
          artifactEmoji: '📜'),
      _DigQ(
          prompt: 'Egyptians wrote using picture symbols carved into stone and papyrus. What is this called?',
          choices: ['Hieroglyphics', 'Cuneiform', 'Calligraphy'],
          artifactEmoji: '🏺'),
    ]),
    _Zone.simple('Ancient Egypt', [
      _SimpleQ(
          prompt: 'What river was Ancient Egypt built along, giving it fertile farmland?',
          choices: ['The Nile River', 'The Tigris River', 'The Amazon River']),
      _SimpleQ(
          prompt: 'What was the title given to the rulers of Ancient Egypt?',
          choices: ['Pharaoh', 'Emperor', 'Chief']),
      _SimpleQ(
          prompt: 'Which of these was a famous Ancient Egyptian pharaoh?',
          choices: ['Tutankhamun', 'Hammurabi', 'Julius Caesar']),
      _SimpleQ(
          prompt: 'Why did Ancient Egyptians build pyramids?',
          choices: ['As grand tombs for their pharaohs', 'As homes for farmers', 'As schools']),
      _SimpleQ(
          prompt: 'What material did Ancient Egyptians write on, made from a river reed?',
          choices: ['Papyrus', 'Clay tablets', 'Paper']),
    ]),
    _Zone.simple('Ancient Mesopotamia', [
      _SimpleQ(
          prompt: 'Mesopotamia developed between which two rivers?',
          choices: ['The Tigris and Euphrates', 'The Nile and Congo', 'The Amazon and Orinoco']),
      _SimpleQ(
          prompt: "What does the word 'Mesopotamia' mean?",
          choices: ['Land between the rivers', 'Land of the pharaohs', 'Land of ice']),
      _SimpleQ(
          prompt: 'Which Mesopotamian king created one of the first written law codes?',
          choices: ['Hammurabi', 'Tutankhamun', 'Ramses']),
      _SimpleQ(
          prompt: 'Which invention, still used on vehicles today, is credited to ancient Mesopotamia?',
          choices: ['The wheel', 'The telephone', 'The compass']),
      _SimpleQ(
          prompt: 'What did Mesopotamians build their tall, stepped temples out of?',
          choices: ['Mudbrick', 'Steel', 'Glass']),
    ]),
    _Zone.simple('Why Rivers Mattered', [
      _SimpleQ(
          prompt: 'Why did early civilizations usually settle near rivers?',
          choices: [
            'Rivers provided water for drinking, farming and transport',
            'Rivers were good for building pyramids',
            'Rivers kept away wild animals'
          ]),
      _SimpleQ(
          prompt: 'How did farming near rivers help ancient civilizations grow?',
          choices: [
            'It produced enough food to feed large populations',
            'It made the weather colder',
            'It stopped trade with other groups'
          ]),
      _SimpleQ(
          prompt: 'Why was writing important to these ancient civilizations?',
          choices: [
            'It allowed them to keep records, laws and stories',
            'It was only used for art',
            'It was not important'
          ]),
      _SimpleQ(
          prompt: 'What did river flooding do for farmland in Ancient Egypt?',
          choices: [
            'It left behind fertile soil for growing crops',
            'It washed away all the crops permanently',
            'It had no effect on farming'
          ]),
      _SimpleQ(
          prompt: 'Trade along rivers allowed ancient civilizations to...?',
          choices: [
            'Exchange goods and ideas with other peoples',
            'Stay completely isolated',
            'Avoid all contact with neighbours'
          ]),
    ]),
  ];

  static const _wrongReactions = [
    'Not quite -- think about ancient history!',
    'Hmm, try to picture the civilization!',
    'Almost -- dig a little deeper!',
  ];

  static const _bg1 = Color(0xFF2B1B0E);
  static const _bg2 = Color(0xFF4A3218);
  static const _card = Color(0xFF5C4425);
  static const _gold = Color(0xFFD9A441);

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
  int _clearedTiles = 0;

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
      _clearedTiles = 0;
    });
    _fadeCtrl.forward(from: 0);
  }

  void _onDigAnswer(int index) {
    if (_phase != _Phase.playing) return;
    final isCorrect = index == 0;
    setState(() => _selectedIndex = index);
    _applyAnswerResult(isCorrect);
  }

  void _onSimpleAnswer(int index) {
    if (_phase != _Phase.playing) return;
    final isCorrect = index == 0;
    setState(() => _selectedIndex = index);
    _applyAnswerResult(isCorrect);
  }

  void _runExcavation() {
    _clearedTiles = 0;
    void step() {
      if (!mounted) return;
      setState(() => _clearedTiles++);
      if (_clearedTiles < 9) {
        _delayed(70, step);
      }
    }

    step();
  }

  void _applyAnswerResult(bool isCorrect) {
    final zone = _zones[_zoneIdx];
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
      if (zone.kind == _Kind.dig) _runExcavation();
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
            _clearedTiles = 0;
            _phase = _Phase.playing;
          });
          _fadeCtrl.forward(from: 0);
        });
      }
    } else {
      setState(() {
        _qIdx = next;
        _selectedIndex = null;
        _clearedTiles = 0;
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
                  CustomPaint(painter: _DustBgPainter(_ambientAnim.value)),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _AncientHeader(
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
                      child: zone.kind == _Kind.dig
                          ? _buildDigQuestion(zone.dig[_qIdx], revealed)
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

  Widget _buildDigQuestion(_DigQ q, bool revealed) {
    const boxSize = 180.0;
    const tileSize = boxSize / 3;

    return Column(
      children: [
        const SizedBox(height: 8),
        Text(
          q.prompt,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: boxSize,
          height: boxSize,
          child: Stack(
            children: [
              Center(
                child: Text(q.artifactEmoji, style: const TextStyle(fontSize: 64)),
              ),
              for (var row = 0; row < 3; row++)
                for (var col = 0; col < 3; col++)
                  _buildSandTile(row * 3 + col, row, col, tileSize),
            ],
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
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  for (var i = 0; i < q.choices.length; i++)
                    _SimpleTile(
                      label: q.choices[i],
                      selected: _selectedIndex == i,
                      isCorrect: i == 0,
                      revealed: revealed,
                      onTap: () => _onDigAnswer(i),
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
              '$_wrongReaction The answer was ${q.choices[0]}.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSandTile(int index, int row, int col, double tileSize) {
    final cleared = index < _clearedTiles;
    return Positioned(
      left: col * tileSize,
      top: row * tileSize,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: cleared ? 0 : 1,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 250),
          scale: cleared ? 0.6 : 1.0,
          child: Container(
            width: tileSize,
            height: tileSize,
            margin: const EdgeInsets.all(1.5),
            decoration: BoxDecoration(
              color: const Color(0xFFC49A5C),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFF8A6636), width: 1),
            ),
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
    Color fill = _ACState._card;
    if (revealed && isCorrect) fill = const Color(0xFF4CAF7D);
    if (revealed && selected && !isCorrect) fill = const Color(0xFFE05656);

    return GestureDetector(
      onTap: revealed ? null : onTap,
      child: Container(
        constraints: const BoxConstraints(minWidth: 110, maxWidth: 280),
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _ACState._gold.withValues(alpha: 0.7), width: 2),
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

class _DustBgPainter extends CustomPainter {
  final double t;
  const _DustBgPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = _ACState._gold.withValues(alpha: 0.04 + 0.03 * t);
    const spacing = 30.0;
    for (var y = 0.0; y < size.height; y += spacing) {
      for (var x = 0.0; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), 1.3, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DustBgPainter oldDelegate) => oldDelegate.t != t;
}

class _SparkleShowerPainter extends CustomPainter {
  final double t;
  const _SparkleShowerPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(103);
    for (var i = 0; i < 18; i++) {
      final startX = rng.nextDouble() * size.width;
      final speed = 0.5 + rng.nextDouble() * 0.6;
      final y = (t * speed) * (size.height + 40) - 20;
      final x = startX + math.sin((t * 6) + i) * 12;
      final paint = Paint()
        ..color = _ACState._gold.withValues(alpha: (1 - t).clamp(0.0, 1.0));
      canvas.drawCircle(Offset(x, y), 3, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparkleShowerPainter oldDelegate) => oldDelegate.t != t;
}

// ── Header / progress ────────────────────────────────────────────────────────

class _AncientHeader extends StatelessWidget {
  final String zoneName;
  final int zoneIdx;
  final int totalZones;
  final int completedSteps;
  final int totalSteps;
  const _AncientHeader({
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
              const Text('🏺', style: TextStyle(fontSize: 22)),
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
          _AncientTrail(completed: completedSteps, total: totalSteps),
        ],
      ),
    );
  }
}

class _AncientTrail extends StatelessWidget {
  final int completed;
  final int total;
  const _AncientTrail({required this.completed, required this.total});

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
                  i < completed ? '🏺' : '·',
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
            color: _ACState._card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _ACState._gold, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🏺', style: TextStyle(fontSize: 40)),
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
            colors: [_ACState._bg1, _ACState._bg2],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🏺🔺', style: TextStyle(fontSize: 44)),
                  SizedBox(height: 16),
                  Text(
                    'Ancient Civilizations',
                    style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Dig up artifacts and discover Ancient Egypt and '
                    'Mesopotamia!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  SizedBox(height: 24),
                  CircularProgressIndicator(color: _ACState._gold),
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
            colors: [_ACState._bg1, _ACState._bg2],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🏆🏺', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  const Text('Master Archaeologist!',
                      style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  Text('$correctCount / $total correct ($pct%)',
                      style: const TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('+$totalXP XP',
                      style: const TextStyle(color: _ACState._gold, fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: onReplay,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _ACState._card,
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
