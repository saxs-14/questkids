import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/game_session_model.dart';
import '../core/game_config.dart';
import '../core/game_session_persistence.dart';

// ────────────────────────────────────────────────────────────────────────────
// Ecosystem Explorer — Grade 4 Natural Sciences: food chains, habitats,
// ecosystems across South Africa
//
// 4 Zones (5 questions each = 20 total):
//   1. Grassland Web — drag 3 organisms into the correct food-chain order
//      (producer → consumer → predator)
//   2. Wetland Web    — same drag-chain mechanic, wetland/river organisms
//   3. Who Eats Whom? — recall MCQ
//   4. Roles in Nature — classify an organism as producer/consumer/decomposer
//
// Structurally distinct from every prior engine: Grassland Web and Wetland
// Web are the first questions where MULTIPLE draggable items must each be
// placed into their own distinct slot within a single question (every
// prior drag-based engine placed exactly one item per question). All 3
// organisms must be correctly ordered before the question resolves.
// Architecture: fully self-contained StatefulWidget.
// ────────────────────────────────────────────────────────────────────────────

enum _Phase { intro, playing, correct, wrong, streak, zoneDone, victory }

enum _Kind { chainBuild, simple }

class _ChainQ {
  final List<String> organisms; // index 0=producer,1=consumer,2=predator
  final List<String> emojis;
  final List<int> displayOrder; // scrambled indices for the pool
  const _ChainQ({
    required this.organisms,
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
  final List<_ChainQ> chains;
  final List<_SimpleQ> simple;
  const _Zone.chain(this.name, this.chains)
      : kind = _Kind.chainBuild,
        simple = const [];
  const _Zone.simple(this.name, this.simple)
      : kind = _Kind.simple,
        chains = const [];

  int get length => kind == _Kind.chainBuild ? chains.length : simple.length;
}

class EcosystemExplorerGame extends StatefulWidget {
  final GameConfig config;
  final dynamic user;
  const EcosystemExplorerGame({super.key, required this.config, this.user});

  @override
  State<EcosystemExplorerGame> createState() => _EEState();
}

class _EEState extends State<EcosystemExplorerGame>
    with TickerProviderStateMixin {
  static const _slotLabels = ['Producer', 'Consumer', 'Predator'];

  static const _zones = [
    _Zone.chain('Grassland Web', [
      _ChainQ(
          organisms: ['Grass', 'Grasshopper', 'Frog'],
          emojis: ['🌾', '🦗', '🐸'],
          displayOrder: [1, 2, 0]),
      _ChainQ(
          organisms: ['Grass', 'Springbok', 'Lion'],
          emojis: ['🌾', '🦌', '🦁'],
          displayOrder: [2, 0, 1]),
      _ChainQ(
          organisms: ['Grass', 'Mouse', 'Owl'],
          emojis: ['🌾', '🐭', '🦉'],
          displayOrder: [1, 0, 2]),
      _ChainQ(
          organisms: ['Grass', 'Caterpillar', 'Bird'],
          emojis: ['🌾', '🐛', '🐦'],
          displayOrder: [2, 1, 0]),
      _ChainQ(
          organisms: ['Grass', 'Locust', 'Lizard'],
          emojis: ['🌾', '🦗', '🦎'],
          displayOrder: [0, 2, 1]),
    ]),
    _Zone.chain('Wetland Web', [
      _ChainQ(
          organisms: ['Algae', 'Tadpole', 'Fish'],
          emojis: ['🟢', '🐸', '🐟'],
          displayOrder: [1, 2, 0]),
      _ChainQ(
          organisms: ['Algae', 'Snail', 'Duck'],
          emojis: ['🟢', '🐌', '🦆'],
          displayOrder: [2, 0, 1]),
      _ChainQ(
          organisms: ['Reeds', 'Dragonfly Larva', 'Frog'],
          emojis: ['🌿', '🦟', '🐸'],
          displayOrder: [1, 0, 2]),
      _ChainQ(
          organisms: ['Algae', 'Small Fish', 'Heron'],
          emojis: ['🟢', '🐟', '🦩'],
          displayOrder: [2, 1, 0]),
      _ChainQ(
          organisms: ['Water Plants', 'Insect', 'Fish'],
          emojis: ['🌿', '🦟', '🐟'],
          displayOrder: [0, 2, 1]),
    ]),
    _Zone.simple('Who Eats Whom?', [
      _SimpleQ(
          prompt: 'What does a lion eat?',
          choices: ['Springbok', 'Grass', 'Eagle']),
      _SimpleQ(
          prompt: 'What does an owl eat?',
          choices: ['Mouse', 'Grass', 'Hawk']),
      _SimpleQ(
          prompt: 'What does a frog eat?',
          choices: ['Grasshopper', 'Snake', 'Grass']),
      _SimpleQ(
          prompt: 'What does a heron eat?',
          choices: ['Fish', 'Reeds', 'Crocodile']),
      _SimpleQ(
          prompt: 'What does a caterpillar eat?',
          choices: ['Leaves', 'Insects', 'Mice']),
    ]),
    _Zone.simple('Roles in Nature', [
      _SimpleQ(
          prompt: 'Grass -- what role does it play?',
          choices: ['Producer', 'Consumer', 'Decomposer']),
      _SimpleQ(
          prompt: 'Lion -- what role does it play?',
          choices: ['Consumer', 'Producer', 'Decomposer']),
      _SimpleQ(
          prompt: 'Mushroom -- what role does it play?',
          choices: ['Decomposer', 'Producer', 'Consumer']),
      _SimpleQ(
          prompt: 'Algae -- what role does it play?',
          choices: ['Producer', 'Decomposer', 'Consumer']),
      _SimpleQ(
          prompt: 'Earthworm -- what role does it play?',
          choices: ['Decomposer', 'Consumer', 'Producer']),
    ]),
  ];

  static const _wrongReactions = [
    'Not quite -- check the food chain again!',
    'Close -- look at who eats whom!',
    'Try again -- think about the habitat!',
  ];

  static const _skyTop = Color(0xFF7FC8E8);
  static const _skyBottom = Color(0xFF5FA85A);
  static const _leafGreen = Color(0xFF3F8F4F);
  static const _bark = Color(0xFF6B4423);

  late AnimationController _ambientCtrl;
  late AnimationController _fadeCtrl;
  late AnimationController _flashCtrl;
  late AnimationController _flutterCtrl;
  late AnimationController _shakeCtrl;

  late Animation<double> _ambientAnim;
  late Animation<double> _fadeAnim;
  late Animation<double> _flashAnim;
  late Animation<double> _flutterAnim;
  late Animation<double> _shakeAnim;

  int _zoneIdx = 0;
  int _qIdx = 0;
  int _correctCount = 0;
  int _streak = 0;
  int _totalXP = 0;

  _Phase _phase = _Phase.intro;
  int? _selectedIndex;
  List<int?> _placements = [null, null, null];
  final Set<int> _placedOrganisms = {};
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

    _flutterCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1700));
    _flutterAnim =
        CurvedAnimation(parent: _flutterCtrl, curve: Curves.easeOut);

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
    _flutterCtrl.dispose();
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
      _placedOrganisms.clear();
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

  void _onDropOrganism(int slotIndex, int organismIndex) {
    if (_phase != _Phase.playing) return;
    if (_placedOrganisms.contains(organismIndex)) return;
    setState(() {
      _placements[slotIndex] = organismIndex;
      _placedOrganisms.add(organismIndex);
    });
    if (_placedOrganisms.length == 3) {
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
          _flutterCtrl.forward(from: 0);
          _delayed(1600, _advance);
        });
      } else {
        _delayed(1000, _advance);
      }
    } else {
      _shakeCtrl.forward(from: 0);
      _delayed(2000, _advance);
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
            _placedOrganisms.clear();
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
        _placedOrganisms.clear();
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
                  colors: [_skyTop, _skyBottom],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _ambientAnim,
              builder: (context, _) =>
                  CustomPaint(painter: _MeadowBgPainter(_ambientAnim.value)),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _EcoHeader(
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
                      child: zone.kind == _Kind.chainBuild
                          ? _buildChainQuestion(zone.chains[_qIdx], revealed)
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
                  child: Container(color: _leafGreen),
                ),
              ),
            ),
          if (_phase == _Phase.streak)
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _flutterAnim,
                builder: (context, _) => CustomPaint(
                  painter: _ButterflyShowerPainter(_flutterAnim.value),
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

  Widget _buildChainQuestion(_ChainQ q, bool revealed) {
    return Column(
      children: [
        const SizedBox(height: 8),
        const Text(
          'Drag each organism into the correct spot in the food chain!',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 22),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (var i = 0; i < 3; i++)
              _ChainSlot(
                label: _slotLabels[i],
                organism: _placements[i] != null
                    ? q.organisms[_placements[i]!]
                    : null,
                emoji: _placements[i] != null ? q.emojis[_placements[i]!] : null,
                isCorrect: revealed ? _placements[i] == i : null,
                onAccept: (organismIndex) => _onDropOrganism(i, organismIndex),
              ),
          ],
        ),
        const SizedBox(height: 28),
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
                  for (final organismIndex in q.displayOrder)
                    if (!_placedOrganisms.contains(organismIndex))
                      _OrganismCard(
                        label: q.organisms[organismIndex],
                        emoji: q.emojis[organismIndex],
                        organismIndex: organismIndex,
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
              '$_wrongReaction The order was: '
              '${q.organisms.join(" → ")}.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600),
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
                    _FieldTile(
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
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600),
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ── Chain slot (drop target) ────────────────────────────────────────────────

class _ChainSlot extends StatelessWidget {
  final String label;
  final String? organism;
  final String? emoji;
  final bool? isCorrect; // null = not yet revealed
  final ValueChanged<int> onAccept;
  const _ChainSlot({
    required this.label,
    required this.organism,
    required this.emoji,
    required this.isCorrect,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    Color borderColor = Colors.white70;
    Color fillColor = Colors.white.withValues(alpha: 0.15);
    if (isCorrect == true) {
      borderColor = const Color(0xFF4CAF7D);
      fillColor = const Color(0xFF4CAF7D).withValues(alpha: 0.3);
    } else if (isCorrect == false) {
      borderColor = const Color(0xFFE05656);
      fillColor = const Color(0xFFE05656).withValues(alpha: 0.3);
    }

    return DragTarget<int>(
      onAcceptWithDetails: (details) => onAccept(details.data),
      builder: (context, candidateData, rejectedData) {
        return Column(
          children: [
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: fillColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: candidateData.isNotEmpty ? Colors.white : borderColor,
                  width: candidateData.isNotEmpty ? 3 : 2,
                ),
              ),
              alignment: Alignment.center,
              child: organism == null
                  ? const Text('?',
                      style: TextStyle(color: Colors.white54, fontSize: 24))
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(emoji!, style: const TextStyle(fontSize: 26)),
                        const SizedBox(height: 4),
                        Text(organism!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _OrganismCard extends StatelessWidget {
  final String label;
  final String emoji;
  final int organismIndex;
  const _OrganismCard({
    required this.label,
    required this.emoji,
    required this.organismIndex,
  });

  Widget _card({double opacity = 1}) => Opacity(
        opacity: opacity,
        child: Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            color: _EEState._bark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white38, width: 2),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(height: 4),
              Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Draggable<int>(
      data: organismIndex,
      feedback: Material(color: Colors.transparent, child: _card(opacity: 0.85)),
      childWhenDragging: _card(opacity: 0.25),
      child: _card(),
    );
  }
}

// ── Field tile (simple MCQ) ─────────────────────────────────────────────────

class _FieldTile extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isCorrect;
  final bool revealed;
  final VoidCallback onTap;
  const _FieldTile({
    required this.label,
    required this.selected,
    required this.isCorrect,
    required this.revealed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color fill = _EEState._leafGreen;
    if (revealed && isCorrect) fill = const Color(0xFF4CAF7D);
    if (revealed && selected && !isCorrect) fill = const Color(0xFFE05656);

    return GestureDetector(
      onTap: revealed ? null : onTap,
      child: Container(
        width: 108,
        height: 60,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

// ── Painters ─────────────────────────────────────────────────────────────────

class _MeadowBgPainter extends CustomPainter {
  final double t;
  const _MeadowBgPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.3);
    for (var i = 0; i < 4; i++) {
      final x = size.width * (0.15 + i * 0.25) + math.sin(t * math.pi * 2 + i) * 8;
      canvas.drawOval(
          Rect.fromCenter(center: Offset(x, size.height * 0.1), width: 50, height: 20),
          paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MeadowBgPainter oldDelegate) => oldDelegate.t != t;
}

class _ButterflyShowerPainter extends CustomPainter {
  final double t;
  const _ButterflyShowerPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(37);
    for (var i = 0; i < 18; i++) {
      final startX = rng.nextDouble() * size.width;
      final speed = 0.5 + rng.nextDouble() * 0.6;
      final y = (t * speed) * (size.height + 40) - 20;
      final x = startX + math.sin((t * 6) + i) * 14;
      final paint = Paint()
        ..color = (i.isEven ? const Color(0xFFF4C95D) : Colors.white)
            .withValues(alpha: (1 - t).clamp(0.0, 1.0));
      canvas.drawCircle(Offset(x, y), 4, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ButterflyShowerPainter oldDelegate) =>
      oldDelegate.t != t;
}

// ── Header / progress ────────────────────────────────────────────────────────

class _EcoHeader extends StatelessWidget {
  final String zoneName;
  final int zoneIdx;
  final int totalZones;
  final int completedSteps;
  final int totalSteps;
  const _EcoHeader({
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
              const Text('🌍', style: TextStyle(fontSize: 22)),
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
          _EcoTrail(completed: completedSteps, total: totalSteps),
        ],
      ),
    );
  }
}

class _EcoTrail extends StatelessWidget {
  final int completed;
  final int total;
  const _EcoTrail({required this.completed, required this.total});

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
                  i < completed ? '🌿' : '·',
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
            color: _EEState._leafGreen,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🌎', style: TextStyle(fontSize: 40)),
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
            colors: [_EEState._skyTop, _EEState._skyBottom],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🌍🦁', style: TextStyle(fontSize: 44)),
                  SizedBox(height: 16),
                  Text(
                    'Ecosystem Explorer',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Build food chains, learn who eats whom, and explore '
                    'the roles every living thing plays!',
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
            colors: [_EEState._skyTop, _EEState._skyBottom],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🏆🌍', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  const Text('Ecosystem Mastered!',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
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
                      backgroundColor: _EEState._leafGreen,
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
