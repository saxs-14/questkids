import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/game_session_model.dart';
import '../core/game_config.dart';
import '../core/game_session_persistence.dart';

// ────────────────────────────────────────────────────────────────────────────
// Climate Quest — Grade 4 Social Sciences: South Africa's climatic zones,
// rainfall patterns and the factors that shape them
//
// NOTE: this is a DIFFERENT engine from runner_collector/ (engineType
// 'runnerCollector'), which is a shared generic engine still used by 19
// other catalog entries. This engine (engineType 'climateQuest') is
// registered ONLY against ss_g4_climate.
//
// 4 Zones (5 questions each = 20 total):
//   1. Set the Thermometer — tap the correct level on a vertical mercury
//      thermometer to match a described SA climate scenario
//   2. Rainfall Patterns    — recall MCQ (summer vs winter rainfall)
//   3. Climate Zones of SA  — recall MCQ (Mediterranean, subtropical,
//      semi-desert, alpine, bushveld)
//   4. Climate Factors      — recall MCQ (ocean currents, altitude,
//      latitude)
//
// Structurally distinct from every prior engine: Zone 1 is the first
// VERTICAL fill-gauge (a thermometer whose mercury column animates up or
// down to the tapped level), unlike Decimal Dunes' horizontal number line
// or Number Ninja's shrinking countdown bar.
// Architecture: fully self-contained StatefulWidget.
// ────────────────────────────────────────────────────────────────────────────

enum _Phase { intro, playing, correct, wrong, streak, zoneDone, victory }

enum _Kind { thermo, simple }

const _tempLevels = ['Cold', 'Cool', 'Mild', 'Warm', 'Hot'];
const _tempEmoji = ['❄️', '🧊', '🌤️', '☀️', '🔥'];

class _ThermoQ {
  final String prompt;
  final int correctLevel; // 0..4
  const _ThermoQ({required this.prompt, required this.correctLevel});
}

class _SimpleQ {
  final String prompt;
  final List<String> choices; // [0] correct
  const _SimpleQ({required this.prompt, required this.choices});
}

class _Zone {
  final String name;
  final _Kind kind;
  final List<_ThermoQ> thermo;
  final List<_SimpleQ> simple;
  const _Zone.thermo(this.name, this.thermo)
      : kind = _Kind.thermo,
        simple = const [];
  const _Zone.simple(this.name, this.simple)
      : kind = _Kind.simple,
        thermo = const [];

  int get length => kind == _Kind.thermo ? thermo.length : simple.length;
}

class ClimateQuestGame extends StatefulWidget {
  final GameConfig config;
  final dynamic user;
  const ClimateQuestGame({super.key, required this.config, this.user});

  @override
  State<ClimateQuestGame> createState() => _CQState();
}

class _CQState extends State<ClimateQuestGame> with TickerProviderStateMixin {
  static const _zones = [
    _Zone.thermo('Set the Thermometer', [
      _ThermoQ(
          prompt: 'The Drakensberg mountains often get snow in winter. Set the thermometer to...',
          correctLevel: 0),
      _ThermoQ(
          prompt: 'Cape Town has cool, wet winters. Set the thermometer to...',
          correctLevel: 1),
      _ThermoQ(
          prompt:
              'The Highveld (Johannesburg area) has mild, sunny weather for much of the year. Set the thermometer to...',
          correctLevel: 2),
      _ThermoQ(
          prompt: "Durban's coast stays warm and humid most of the year. Set the thermometer to...",
          correctLevel: 3),
      _ThermoQ(
          prompt:
              'The Kalahari Desert in the Northern Cape gets extremely hot in summer. Set the thermometer to...',
          correctLevel: 4),
    ]),
    _Zone.simple('Rainfall Patterns', [
      _SimpleQ(
          prompt: 'The Western Cape mostly receives its rain in...?',
          choices: ['Winter', 'Summer', 'It never rains']),
      _SimpleQ(
          prompt: 'Most of South Africa (like the Highveld) receives its rain mainly in...?',
          choices: ['Summer', 'Winter', 'Autumn']),
      _SimpleQ(
          prompt: 'Which region of South Africa is the driest?',
          choices: ['The Northern Cape (Kalahari)', 'KwaZulu-Natal coast', 'The Drakensberg']),
      _SimpleQ(
          prompt: 'A region with a Mediterranean climate has...?',
          choices: ['Wet winters and dry summers', 'Wet summers and dry winters', 'Rain all year round']),
      _SimpleQ(
          prompt: 'Thunderstorms are common on highveld summer afternoons because...?',
          choices: ['Hot air rises and forms rain clouds', 'The ocean is very close', 'It snows first']),
    ]),
    _Zone.simple('Climate Zones of SA', [
      _SimpleQ(
          prompt: 'Cape Town and the Western Cape coast have a...?',
          choices: ['Mediterranean climate', 'Desert climate', 'Tropical climate']),
      _SimpleQ(
          prompt: 'Durban and the KwaZulu-Natal coast have a...?',
          choices: ['Subtropical (warm and humid) climate', 'Cold polar climate', 'Desert climate']),
      _SimpleQ(
          prompt: 'The Kalahari region in the Northern Cape has a...?',
          choices: ['Semi-desert climate', 'Tropical rainforest climate', 'Mediterranean climate']),
      _SimpleQ(
          prompt: 'The Drakensberg mountains have a...?',
          choices: ['Cold, mountain (alpine) climate', 'Hot desert climate', 'Tropical climate']),
      _SimpleQ(
          prompt: 'The Lowveld (parts of Limpopo and Mpumalanga) has a...?',
          choices: ['Hot, bushveld climate', 'Cold, snowy climate', 'Mediterranean climate']),
    ]),
    _Zone.simple('Climate Factors', [
      _SimpleQ(
          prompt: 'What ocean current warms the KwaZulu-Natal coast?',
          choices: ['The warm Agulhas Current', 'The cold Benguela Current', 'The Gulf Stream']),
      _SimpleQ(
          prompt: "What ocean current cools the Western Cape's west coast?",
          choices: ['The cold Benguela Current', 'The warm Agulhas Current', 'The Pacific Current']),
      _SimpleQ(
          prompt: 'Places at a higher altitude (like mountains) are usually...?',
          choices: ['Colder', 'Hotter', 'The same temperature']),
      _SimpleQ(
          prompt: 'Places closer to the equator are usually...?',
          choices: ['Hotter', 'Colder', 'Wetter only']),
      _SimpleQ(
          prompt: "Being close to the ocean usually makes a place's climate...?",
          choices: ['Milder (less extreme)', 'More extreme', 'Colder in summer']),
    ]),
  ];

  static const _wrongReactions = [
    'Not quite -- think about the season!',
    'Hmm, try a different level!',
    'Almost -- picture the real weather there!',
  ];

  static const _bg1 = Color(0xFF1A2A3A);
  static const _bg2 = Color(0xFF2E4258);
  static const _card = Color(0xFF3D5670);
  static const _amber = Color(0xFFF2A65A);

  late AnimationController _ambientCtrl;
  late AnimationController _fadeCtrl;
  late AnimationController _flashCtrl;
  late AnimationController _burstCtrl;
  late AnimationController _shakeCtrl;
  late AnimationController _mercuryCtrl;

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
  int? _pickedLevel;
  double _mercuryFrom = 0;
  double _mercuryTo = 0;

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

    _mercuryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
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
    _mercuryCtrl.dispose();
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
    _pickedLevel = null;
    _mercuryFrom = 0;
    _mercuryTo = 0;
    _mercuryCtrl.value = 0;
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

  void _onThermoTap(int level) {
    if (_phase != _Phase.playing) return;
    final q = _zones[_zoneIdx].thermo[_qIdx];
    final isCorrect = level == q.correctLevel;

    _mercuryFrom = _pickedLevel?.toDouble() ?? 0;
    _mercuryTo = level.toDouble();

    setState(() => _pickedLevel = level);
    _mercuryCtrl.forward(from: 0);
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
                  CustomPaint(painter: _CloudDriftBgPainter(_ambientAnim.value)),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _ClimateHeader(
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
                      child: zone.kind == _Kind.thermo
                          ? _buildThermoQuestion(zone.thermo[_qIdx])
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
                  child: Container(color: _amber),
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

  Widget _buildThermoQuestion(_ThermoQ q) {
    const tubeHeight = 180.0;
    final revealed = _phase == _Phase.correct || _phase == _Phase.wrong;

    return Column(
      children: [
        const SizedBox(height: 8),
        Text(
          q.prompt,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Thermometer tube
            AnimatedBuilder(
              animation: _mercuryCtrl,
              builder: (context, _) {
                final t = Curves.easeOutCubic.transform(_mercuryCtrl.value);
                final level = _mercuryFrom + (_mercuryTo - _mercuryFrom) * t;
                final fillHeight = (level / 4).clamp(0.0, 1.0) * (tubeHeight - 20) + 20;
                final mercuryColor = _pickedLevel == null
                    ? _amber
                    : (revealed
                        ? (_pickedLevel == q.correctLevel
                            ? const Color(0xFF4CAF7D)
                            : const Color(0xFFE05656))
                        : _amber);
                return Container(
                  width: 34,
                  height: tubeHeight,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0E1A24),
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(color: Colors.white24, width: 2),
                  ),
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    margin: const EdgeInsets.all(4),
                    width: 26,
                    height: fillHeight,
                    decoration: BoxDecoration(
                      color: mercuryColor,
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 16),
            // Level rows (tap targets), Hot at top, Cold at bottom.
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = _tempLevels.length - 1; i >= 0; i--)
                  _ThermoLevelRow(
                    level: i,
                    isCorrectLevel: i == q.correctLevel,
                    isPicked: i == _pickedLevel,
                    revealed: revealed,
                    onTap: () => _onThermoTap(i),
                  ),
              ],
            ),
          ],
        ),
        if (_phase == _Phase.wrong)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text(
              '$_wrongReaction The answer was ${_tempEmoji[q.correctLevel]} ${_tempLevels[q.correctLevel]}.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
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

// ── Thermometer level row ────────────────────────────────────────────────────

class _ThermoLevelRow extends StatelessWidget {
  final int level;
  final bool isCorrectLevel;
  final bool isPicked;
  final bool revealed;
  final VoidCallback onTap;
  const _ThermoLevelRow({
    required this.level,
    required this.isCorrectLevel,
    required this.isPicked,
    required this.revealed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color fill = _CQState._card;
    if (revealed && isCorrectLevel) fill = const Color(0xFF4CAF7D);
    if (revealed && isPicked && !isCorrectLevel) fill = const Color(0xFFE05656);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 130,
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _CQState._amber.withValues(alpha: 0.6), width: 1.5),
          ),
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              Text(_tempEmoji[level], style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(_tempLevels[level],
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
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
    Color fill = _CQState._card;
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
          border: Border.all(color: _CQState._amber.withValues(alpha: 0.7), width: 2),
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

class _CloudDriftBgPainter extends CustomPainter {
  final double t;
  const _CloudDriftBgPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.03 + 0.02 * t);
    for (var i = 0; i < 4; i++) {
      final y = size.height * (0.1 + i * 0.22);
      final x = (size.width * 0.15 * i) + t * 20;
      canvas.drawOval(Rect.fromCenter(center: Offset(x, y), width: 90, height: 26), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CloudDriftBgPainter oldDelegate) => oldDelegate.t != t;
}

class _SparkleShowerPainter extends CustomPainter {
  final double t;
  const _SparkleShowerPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(71);
    for (var i = 0; i < 18; i++) {
      final startX = rng.nextDouble() * size.width;
      final speed = 0.5 + rng.nextDouble() * 0.6;
      final y = (t * speed) * (size.height + 40) - 20;
      final x = startX + math.sin((t * 6) + i) * 12;
      final paint = Paint()
        ..color = _CQState._amber.withValues(alpha: (1 - t).clamp(0.0, 1.0));
      canvas.drawCircle(Offset(x, y), 3, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparkleShowerPainter oldDelegate) => oldDelegate.t != t;
}

// ── Header / progress ────────────────────────────────────────────────────────

class _ClimateHeader extends StatelessWidget {
  final String zoneName;
  final int zoneIdx;
  final int totalZones;
  final int completedSteps;
  final int totalSteps;
  const _ClimateHeader({
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
              const Text('🌡️', style: TextStyle(fontSize: 22)),
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
          _ClimateTrail(completed: completedSteps, total: totalSteps),
        ],
      ),
    );
  }
}

class _ClimateTrail extends StatelessWidget {
  final int completed;
  final int total;
  const _ClimateTrail({required this.completed, required this.total});

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
                  i < completed ? '☀️' : '·',
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
            color: _CQState._card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _CQState._amber, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🌡️', style: TextStyle(fontSize: 40)),
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
            colors: [_CQState._bg1, _CQState._bg2],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🌡️🌍', style: TextStyle(fontSize: 44)),
                  SizedBox(height: 16),
                  Text(
                    'Climate Quest',
                    style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "Set the thermometer and explore South Africa's climate "
                    'zones!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  SizedBox(height: 24),
                  CircularProgressIndicator(color: _CQState._amber),
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
            colors: [_CQState._bg1, _CQState._bg2],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🏆🌡️', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  const Text('Climate Master!',
                      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  Text('$correctCount / $total correct ($pct%)',
                      style: const TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('+$totalXP XP',
                      style: const TextStyle(color: _CQState._amber, fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: onReplay,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _CQState._card,
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
