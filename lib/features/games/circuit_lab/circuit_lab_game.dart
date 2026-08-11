import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/game_session_model.dart';
import '../core/game_config.dart';
import '../core/game_session_persistence.dart';

// ────────────────────────────────────────────────────────────────────────────
// Circuit Lab — Grade 4 Technology: electric circuits, components, safety
//
// NOTE: this is a DIFFERENT engine from circuit_builder/ (engineType
// 'circuitBuilder'), which is a shared generic engine still used by 8 other
// catalog entries across grade4/grade7 (Atom Adventure, Ecosystem Balance,
// Food Chain Fighter, Series/Parallel Circuit, Structures & Forces,
// Mechanisms Matter, Electronics Explorer). Reusing that file/class would
// have silently changed content for all of those. This engine (engineType
// 'circuitLab') is registered ONLY against tech_g4_coding's sibling entry
// tech_g4_circuit.
//
// 4 Zones (5 questions each = 20 total):
//   1. Series Circuits      — tap ONE component to fill the single gap in a
//      circuit diagram
//   2. Circuit Components    — recall MCQ about what each component does
//   3. Building Circuits     — tap TWO components in order to fill two gaps
//      in sequence
//   4. Safety & Troubleshooting — recall MCQ about circuit behaviour/safety
//
// Structurally distinct from every prior engine: on a correct circuit,
// current visibly "flows" left-to-right through the diagram — each node
// lights up in sequence with a golden glow, and the bulb (if present)
// glows brightest last. No other engine does a sequential path-lighting
// reveal like this.
// Architecture: fully self-contained StatefulWidget.
// ────────────────────────────────────────────────────────────────────────────

enum _Phase { intro, playing, correct, wrong, streak, zoneDone, victory }

enum _Kind { circuit, simple }

const _componentEmoji = {
  'wire': '〰️',
  'bulb': '💡',
  'switch': '🔘',
  'resistor': '⬛',
  'battery': '🔋',
  'buzzer': '🔔',
  'ammeter': '🅰️',
};
const _componentLabel = {
  'wire': 'Wire',
  'bulb': 'Bulb',
  'switch': 'Switch',
  'resistor': 'Resistor',
  'battery': 'Battery',
  'buzzer': 'Buzzer',
  'ammeter': 'Ammeter',
};

class _CircuitQ {
  final String description;
  final List<String> nodes; // fixed component ids, or '?' for a blank
  final List<String> correct; // one id per '?' in nodes, left-to-right
  final List<String> bank; // ids offered to tap (includes correct + decoys)
  const _CircuitQ({
    required this.description,
    required this.nodes,
    required this.correct,
    required this.bank,
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
  final List<_CircuitQ> circuits;
  final List<_SimpleQ> simple;
  const _Zone.circuit(this.name, this.circuits)
      : kind = _Kind.circuit,
        simple = const [];
  const _Zone.simple(this.name, this.simple)
      : kind = _Kind.simple,
        circuits = const [];

  int get length => kind == _Kind.circuit ? circuits.length : simple.length;
}

class CircuitLabGame extends StatefulWidget {
  final GameConfig config;
  final dynamic user;
  const CircuitLabGame({super.key, required this.config, this.user});

  @override
  State<CircuitLabGame> createState() => _CLState();
}

class _CLState extends State<CircuitLabGame> with TickerProviderStateMixin {
  static const _zones = [
    _Zone.circuit('Series Circuits', [
      _CircuitQ(
          description: 'Connect the battery to the bulb.',
          nodes: ['battery', '?', 'bulb'],
          correct: ['wire'],
          bank: ['wire', 'switch', 'resistor', 'buzzer']),
      _CircuitQ(
          description: 'Add a switch so you can turn the circuit on and off.',
          nodes: ['battery', 'bulb', '?'],
          correct: ['switch'],
          bank: ['switch', 'wire', 'battery', 'buzzer']),
      _CircuitQ(
          description: 'This circuit has no power source. What is missing?',
          nodes: ['?', 'switch', 'bulb'],
          correct: ['battery'],
          bank: ['battery', 'resistor', 'buzzer', 'ammeter']),
      _CircuitQ(
          description: 'Protect the bulb from too much current.',
          nodes: ['battery', 'bulb', '?'],
          correct: ['resistor'],
          bank: ['resistor', 'switch', 'wire', 'battery']),
      _CircuitQ(
          description: 'Swap the bulb for something that makes a sound.',
          nodes: ['battery', 'switch', '?'],
          correct: ['buzzer'],
          bank: ['buzzer', 'bulb', 'wire', 'ammeter']),
    ]),
    _Zone.simple('Circuit Components', [
      _SimpleQ(
          prompt: 'What does a SWITCH do in a circuit?',
          choices: ['Opens and closes the circuit', 'Stores electrical energy', 'Makes light']),
      _SimpleQ(
          prompt: 'What does a BATTERY do?',
          choices: ['Provides electrical energy', 'Measures current', 'Blocks electricity']),
      _SimpleQ(
          prompt: 'What does a RESISTOR do?',
          choices: ['Limits the flow of current', 'Provides power', 'Opens the circuit']),
      _SimpleQ(
          prompt: 'What happens when a switch is OPEN?',
          choices: ['No current flows', 'Current flows faster', 'The bulb gets brighter']),
      _SimpleQ(
          prompt: 'What does an AMMETER measure?',
          choices: ['The current in a circuit', 'The voltage', 'The resistance']),
    ]),
    _Zone.circuit('Building Circuits', [
      _CircuitQ(
          description: 'Complete this series circuit with a wire, then a switch.',
          nodes: ['battery', '?', 'bulb', '?'],
          correct: ['wire', 'switch'],
          bank: ['wire', 'switch', 'battery', 'resistor']),
      _CircuitQ(
          description:
              'Add a battery to power this circuit, then a resistor to protect the bulb.',
          nodes: ['?', 'bulb', '?'],
          correct: ['battery', 'resistor'],
          bank: ['battery', 'resistor', 'wire', 'switch']),
      _CircuitQ(
          description: 'This buzzer circuit needs a wire, then a switch to control it.',
          nodes: ['battery', '?', 'buzzer', '?'],
          correct: ['wire', 'switch'],
          bank: ['wire', 'switch', 'battery', 'ammeter']),
      _CircuitQ(
          description:
              'Add a second battery for extra power, then a switch to control the circuit.',
          nodes: ['battery', '?', 'bulb', '?'],
          correct: ['battery', 'switch'],
          bank: ['battery', 'switch', 'wire', 'resistor']),
      _CircuitQ(
          description: 'Place the ammeter to measure current, then close the loop with a wire.',
          nodes: ['battery', 'bulb', '?', '?'],
          correct: ['ammeter', 'wire'],
          bank: ['ammeter', 'wire', 'resistor', 'buzzer']),
    ]),
    _Zone.simple('Safety & Troubleshooting', [
      _SimpleQ(
          prompt: "If a bulb doesn't light up, what should you check first?",
          choices: ['If the circuit is complete (closed)', 'The colour of the wire', 'The time of day']),
      _SimpleQ(
          prompt: 'In a SERIES circuit, if one bulb breaks, what happens to the others?',
          choices: ['They all switch off', 'They get brighter', 'Nothing changes']),
      _SimpleQ(
          prompt: 'In a PARALLEL circuit, if one bulb breaks, what happens to the others?',
          choices: ['They keep working', 'They all switch off', 'They explode']),
      _SimpleQ(
          prompt: 'Why must you never touch a circuit with wet hands?',
          choices: [
            'Water conducts electricity and can shock you',
            'It makes the bulb brighter',
            'It slows down the current'
          ]),
      _SimpleQ(
          prompt: 'What material is usually used for wires because it conducts electricity well?',
          choices: ['Copper', 'Rubber', 'Wood']),
    ]),
  ];

  static const _wrongReactions = [
    'Not quite -- check the connections!',
    'Hmm, that circuit is not complete yet!',
    'Almost -- try tracing the flow again!',
  ];

  static const _bg1 = Color(0xFF10131F);
  static const _bg2 = Color(0xFF1B2440);
  static const _card = Color(0xFF2A3A66);
  static const _spark = Color(0xFFFFC94D);

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

  // Circuit state
  List<String?> _placements = [];
  List<bool> _bankUsed = [];
  int _flowLit = 0; // nodes with index < _flowLit are "lit"
  bool? _lastCircuitCorrect;

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
    final zone = _zones[_zoneIdx];
    if (zone.kind == _Kind.circuit) {
      final q = zone.circuits[_qIdx];
      _placements = List<String?>.filled(q.correct.length, null);
      _bankUsed = List<bool>.filled(q.bank.length, false);
      _flowLit = 0;
      _lastCircuitCorrect = null;
    }
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

  void _onTapBankComponent(int bankIdx) {
    if (_phase != _Phase.playing) return;
    final q = _zones[_zoneIdx].circuits[_qIdx];
    if (_bankUsed[bankIdx]) return;

    final emptySlot = _placements.indexWhere((p) => p == null);
    if (emptySlot == -1) return;

    setState(() {
      _bankUsed[bankIdx] = true;
      _placements[emptySlot] = q.bank[bankIdx];
    });

    if (!_placements.contains(null)) {
      _delayed(300, _evaluateCircuit);
    }
  }

  void _evaluateCircuit() {
    if (!mounted) return;
    final q = _zones[_zoneIdx].circuits[_qIdx];
    var allCorrect = true;
    for (var i = 0; i < q.correct.length; i++) {
      if (_placements[i] != q.correct[i]) {
        allCorrect = false;
        break;
      }
    }
    setState(() => _lastCircuitCorrect = allCorrect);
    _applyAnswerResult(allCorrect);
  }

  void _runFlowAnimation(int nodeCount) {
    _flowLit = 0;
    void step() {
      if (!mounted) return;
      setState(() => _flowLit++);
      if (_flowLit < nodeCount) {
        _delayed(160, step);
      }
    }

    step();
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

    final zone = _zones[_zoneIdx];
    if (isCorrect) {
      _flashCtrl.forward(from: 0);
      if (zone.kind == _Kind.circuit) {
        _runFlowAnimation(zone.circuits[_qIdx].nodes.length);
      }
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
                  CustomPaint(painter: _SparkBgPainter(_ambientAnim.value)),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _CircuitHeader(
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
                      child: zone.kind == _Kind.circuit
                          ? _buildCircuitQuestion(zone.circuits[_qIdx])
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
                  child: Container(color: _spark),
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

  Widget _buildCircuitQuestion(_CircuitQ q) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Text(
          q.description,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 20),
        _CircuitDiagram(nodes: q.nodes, placements: _placements, litCount: _flowLit),
        if (_phase == _Phase.wrong && _lastCircuitCorrect == false)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              '$_wrongReaction Correct: ${q.correct.map((c) => _componentLabel[c]).join(', ')}.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        const SizedBox(height: 24),
        AnimatedBuilder(
          animation: _shakeAnim,
          builder: (context, _) {
            final dx = _phase == _Phase.wrong
                ? math.sin(_shakeAnim.value * math.pi * 6) * 5
                : 0.0;
            return Transform.translate(
              offset: Offset(dx, 0),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  for (var i = 0; i < q.bank.length; i++)
                    _ComponentChip(
                      id: q.bank[i],
                      used: _bankUsed[i],
                      onTap: () => _onTapBankComponent(i),
                    ),
                ],
              ),
            );
          },
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
          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
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
                    _SimpleTile(
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
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ── Circuit diagram ──────────────────────────────────────────────────────────

class _CircuitDiagram extends StatelessWidget {
  final List<String> nodes; // component ids, or '?' placeholders
  final List<String?> placements;
  final int litCount;
  const _CircuitDiagram({required this.nodes, required this.placements, required this.litCount});

  @override
  Widget build(BuildContext context) {
    var blankIdx = 0;
    final children = <Widget>[];
    for (var i = 0; i < nodes.length; i++) {
      final token = nodes[i];
      final isBlank = token == '?';
      final placedId = isBlank ? placements[blankIdx] : token;
      final lit = i < litCount;
      if (isBlank) blankIdx++;

      children.add(_CircuitNode(
        id: placedId,
        isBlank: isBlank && placedId == null,
        lit: lit,
      ));
      if (i < nodes.length - 1) {
        children.add(Container(
          width: 18,
          height: 3,
          color: i < litCount ? _CLState._spark : Colors.white24,
        ));
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF060812),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 2,
        runSpacing: 10,
        children: children,
      ),
    );
  }
}

class _CircuitNode extends StatelessWidget {
  final String? id;
  final bool isBlank;
  final bool lit;
  const _CircuitNode({required this.id, required this.isBlank, required this.lit});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: lit
            ? _CLState._spark.withValues(alpha: 0.25)
            : (isBlank ? Colors.white10 : Colors.white.withValues(alpha: 0.06)),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: lit ? _CLState._spark : (isBlank ? Colors.white38 : Colors.white24),
          width: lit ? 2.5 : 1.5,
        ),
        boxShadow: lit
            ? [BoxShadow(color: _CLState._spark.withValues(alpha: 0.5), blurRadius: 10)]
            : null,
      ),
      alignment: Alignment.center,
      child: Text(
        id != null ? _componentEmoji[id]! : '?',
        style: const TextStyle(fontSize: 20),
      ),
    );
  }
}

// ── Component chip (bank) ────────────────────────────────────────────────────

class _ComponentChip extends StatelessWidget {
  final String id;
  final bool used;
  final VoidCallback onTap;
  const _ComponentChip({required this.id, required this.used, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: used ? null : onTap,
      child: Opacity(
        opacity: used ? 0.35 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _CLState._card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _CLState._spark.withValues(alpha: 0.6), width: 2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_componentEmoji[id]!, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Text(_componentLabel[id]!,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
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
    Color fill = _CLState._card;
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
          border: Border.all(color: _CLState._spark.withValues(alpha: 0.6), width: 2),
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

class _SparkBgPainter extends CustomPainter {
  final double t;
  const _SparkBgPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(11);
    for (var i = 0; i < 22; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final flicker = (math.sin(t * math.pi * 2 + i) + 1) / 2;
      final paint = Paint()
        ..color = _CLState._spark.withValues(alpha: 0.05 + flicker * 0.06);
      canvas.drawCircle(Offset(x, y), 1.4, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparkBgPainter oldDelegate) => oldDelegate.t != t;
}

class _SparkleShowerPainter extends CustomPainter {
  final double t;
  const _SparkleShowerPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(29);
    for (var i = 0; i < 18; i++) {
      final startX = rng.nextDouble() * size.width;
      final speed = 0.5 + rng.nextDouble() * 0.6;
      final y = (t * speed) * (size.height + 40) - 20;
      final x = startX + math.sin((t * 6) + i) * 12;
      final paint = Paint()
        ..color = _CLState._spark.withValues(alpha: (1 - t).clamp(0.0, 1.0));
      canvas.drawCircle(Offset(x, y), 3, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparkleShowerPainter oldDelegate) => oldDelegate.t != t;
}

// ── Header / progress ────────────────────────────────────────────────────────

class _CircuitHeader extends StatelessWidget {
  final String zoneName;
  final int zoneIdx;
  final int totalZones;
  final int completedSteps;
  final int totalSteps;
  const _CircuitHeader({
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
              const Text('⚡', style: TextStyle(fontSize: 22)),
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
          _CircuitTrail(completed: completedSteps, total: totalSteps),
        ],
      ),
    );
  }
}

class _CircuitTrail extends StatelessWidget {
  final int completed;
  final int total;
  const _CircuitTrail({required this.completed, required this.total});

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
                  i < completed ? '🔌' : '·',
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
            color: _CLState._card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _CLState._spark, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('⚡', style: TextStyle(fontSize: 40)),
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
            colors: [_CLState._bg1, _CLState._bg2],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('⚡🔌', style: TextStyle(fontSize: 44)),
                  SizedBox(height: 16),
                  Text(
                    'Circuit Builder',
                    style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Tap the right components to complete each circuit and '
                    'watch the current flow!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  SizedBox(height: 24),
                  CircularProgressIndicator(color: _CLState._spark),
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
            colors: [_CLState._bg1, _CLState._bg2],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🏆⚡', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  const Text('Circuit Master!',
                      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  Text('$correctCount / $total correct ($pct%)',
                      style: const TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('+$totalXP XP',
                      style: const TextStyle(color: _CLState._spark, fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: onReplay,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _CLState._card,
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
