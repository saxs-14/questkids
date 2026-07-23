import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/game_session_model.dart';
import '../core/game_config.dart';
import '../core/game_session_persistence.dart';

// ────────────────────────────────────────────────────────────────────────────
// Energy Quest — Grade 4 Natural Sciences: heat, light, sound, kinetic and
// potential energy
//
// 4 Zones (5 questions each = 20 total):
//   1. Energy Detectives — identify the energy type from a scenario
//   2. Energy Sources    — match an everyday source to its energy type
//   3. Energy in Action  — everyday examples of energy
//   4. Energy Changes    — energy transformations (electrical → heat, etc.)
//
// Structurally distinct from every prior engine: every answer tile plays
// its OWN small looping animation matched to its energy type -- heat tiles
// shimmer, light tiles glow, sound tiles ripple outward, kinetic tiles
// bounce, and potential tiles compress like a coiled spring. No prior
// engine's answer buttons carry per-choice animated identity; here the
// tile itself demonstrates the concept it names.
// Architecture: fully self-contained StatefulWidget.
// ────────────────────────────────────────────────────────────────────────────

enum _Phase { intro, playing, correct, wrong, streak, zoneDone, victory }

class _EnergyQ {
  final String prompt;
  final List<String> choices; // [0] correct; always one of the 5 energy words
  const _EnergyQ({required this.prompt, required this.choices});
}

class _Zone {
  final String name;
  final List<_EnergyQ> questions;
  const _Zone(this.name, this.questions);
}

const _energyIcons = {
  'Heat': '🔥',
  'Light': '💡',
  'Sound': '🔊',
  'Kinetic': '🏃',
  'Potential': '🌀',
};

class EnergyQuestGame extends StatefulWidget {
  final GameConfig config;
  final dynamic user;
  const EnergyQuestGame({super.key, required this.config, this.user});

  @override
  State<EnergyQuestGame> createState() => _EQState();
}

class _EQState extends State<EnergyQuestGame> with TickerProviderStateMixin {
  static const _zones = [
    _Zone('Energy Detectives', [
      _EnergyQ(
          prompt: 'A hot stove plate warms your hand. This is...?',
          choices: ['Heat', 'Light', 'Sound']),
      _EnergyQ(
          prompt: 'A torch shining in the dark gives off...?',
          choices: ['Light', 'Sound', 'Heat']),
      _EnergyQ(
          prompt: 'A drum being hit produces...?',
          choices: ['Sound', 'Light', 'Kinetic']),
      _EnergyQ(
          prompt: 'A rolling ball has...?',
          choices: ['Kinetic', 'Potential', 'Heat']),
      _EnergyQ(
          prompt: 'A stretched rubber band ready to snap has...?',
          choices: ['Potential', 'Kinetic', 'Sound']),
    ]),
    _Zone('Energy Sources', [
      _EnergyQ(
          prompt: 'The Sun gives us light energy and...?',
          choices: ['Heat', 'Sound', 'Kinetic']),
      _EnergyQ(
          prompt: 'A guitar string makes...?',
          choices: ['Sound', 'Light', 'Heat']),
      _EnergyQ(
          prompt: 'A battery stores...?',
          choices: ['Potential', 'Kinetic', 'Sound']),
      _EnergyQ(
          prompt: 'A moving car has...?',
          choices: ['Kinetic', 'Potential', 'Light']),
      _EnergyQ(
          prompt: 'A campfire gives off light and...?',
          choices: ['Heat', 'Sound', 'Kinetic']),
    ]),
    _Zone('Energy in Action', [
      _EnergyQ(
          prompt: 'Riding a bicycle uses...?',
          choices: ['Kinetic', 'Potential', 'Sound']),
      _EnergyQ(
          prompt: 'A ball held up high has...?',
          choices: ['Potential', 'Kinetic', 'Heat']),
      _EnergyQ(
          prompt: 'Clapping your hands makes...?',
          choices: ['Sound', 'Light', 'Heat']),
      _EnergyQ(
          prompt: 'A light bulb turning on gives off...?',
          choices: ['Light', 'Sound', 'Kinetic']),
      _EnergyQ(
          prompt: 'An ice pack feels cold because it has less...?',
          choices: ['Heat', 'Light', 'Sound']),
    ]),
    _Zone('Energy Changes', [
      _EnergyQ(
          prompt: 'A toaster changes electrical energy into...?',
          choices: ['Heat', 'Light', 'Sound']),
      _EnergyQ(
          prompt: 'A light bulb changes electrical energy into...?',
          choices: ['Light', 'Sound', 'Heat']),
      _EnergyQ(
          prompt: 'A speaker changes electrical energy into...?',
          choices: ['Sound', 'Light', 'Kinetic']),
      _EnergyQ(
          prompt: 'A wind-up toy changes stored energy into...?',
          choices: ['Kinetic', 'Potential', 'Heat']),
      _EnergyQ(
          prompt: 'Pulling back a slingshot stores...?',
          choices: ['Potential', 'Kinetic', 'Sound']),
    ]),
  ];

  static const _wrongReactions = [
    'Not quite -- think about the energy type again!',
    'Close -- check what kind of energy that is!',
    'Try again -- look at what is happening!',
  ];

  static const _skyTop = Color(0xFFFF7A3D);
  static const _skyBottom = Color(0xFF5B2B8C);
  static const _card = Color(0xFF3B2A5C);

  late AnimationController _ambientCtrl;
  late AnimationController _fadeCtrl;
  late AnimationController _flashCtrl;
  late AnimationController _burstCtrl;
  late AnimationController _shakeCtrl;
  late AnimationController _iconCtrl;

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
        vsync: this, duration: const Duration(seconds: 7))
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

    _iconCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
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
    _iconCtrl.dispose();
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
          _burstCtrl.forward(from: 0);
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
                  CustomPaint(painter: _SparkBgPainter(_ambientAnim.value)),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _QuestHeader(
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
                          const SizedBox(height: 16),
                          Text(
                            q.prompt,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 28),
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
                                  spacing: 16,
                                  runSpacing: 16,
                                  alignment: WrapAlignment.center,
                                  children: [
                                    for (var i = 0; i < q.choices.length; i++)
                                      AnimatedBuilder(
                                        animation: _iconCtrl,
                                        builder: (context, _) => _EnergyTile(
                                          label: q.choices[i],
                                          t: _iconCtrl.value,
                                          selected: _selectedIndex == i,
                                          isCorrect: i == 0,
                                          revealed: revealed,
                                          onTap: () => _onAnswer(i),
                                        ),
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
                  child: Container(color: const Color(0xFF4CAF7D)),
                ),
              ),
            ),
          if (_phase == _Phase.streak)
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _burstAnim,
                builder: (context, _) => CustomPaint(
                  painter: _SparkBurstPainter(_burstAnim.value),
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

// ── Energy tile (animated per-type) ─────────────────────────────────────────

class _EnergyTile extends StatelessWidget {
  final String label;
  final double t; // 0..1 looping
  final bool selected;
  final bool isCorrect;
  final bool revealed;
  final VoidCallback onTap;
  const _EnergyTile({
    required this.label,
    required this.t,
    required this.selected,
    required this.isCorrect,
    required this.revealed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color fill = _EQState._card;
    if (revealed && isCorrect) fill = const Color(0xFF4CAF7D);
    if (revealed && selected && !isCorrect) fill = const Color(0xFFE05656);

    final icon = _energyIcons[label] ?? '❓';
    final angle = t * 2 * math.pi;

    Widget animatedIcon;
    switch (label) {
      case 'Heat':
        final scale = 1.0 + math.sin(angle * 3) * 0.12;
        animatedIcon = Transform.scale(scale: scale, child: Text(icon, style: const TextStyle(fontSize: 30)));
      case 'Light':
        final glowOpacity = 0.5 + math.sin(angle * 2) * 0.3;
        animatedIcon = Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: glowOpacity.clamp(0.0, 1.0),
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                    shape: BoxShape.circle, color: Colors.yellowAccent),
              ),
            ),
            Text(icon, style: const TextStyle(fontSize: 30)),
          ],
        );
      case 'Sound':
        final ringScale = 0.6 + (angle % (2 * math.pi)) / (2 * math.pi) * 0.8;
        animatedIcon = Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: (1.4 - ringScale).clamp(0.0, 1.0),
              child: Transform.scale(
                scale: ringScale,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ),
            Text(icon, style: const TextStyle(fontSize: 26)),
          ],
        );
      case 'Kinetic':
        final dx = math.sin(angle * 4) * 6;
        animatedIcon = Transform.translate(
            offset: Offset(dx, 0),
            child: Text(icon, style: const TextStyle(fontSize: 30)));
      case 'Potential':
        final scaleY = 1.0 - (math.sin(angle * 3).abs() * 0.25);
        animatedIcon = Transform(
          alignment: Alignment.center,
          transform: Matrix4.diagonal3Values(1.0, scaleY, 1.0),
          child: Text(icon, style: const TextStyle(fontSize: 30)),
        );
      default:
        animatedIcon = Text(icon, style: const TextStyle(fontSize: 30));
    }

    return GestureDetector(
      onTap: revealed ? null : onTap,
      child: Container(
        width: 100,
        height: 92,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 34, child: Center(child: animatedIcon)),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800),
            ),
          ],
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
    final rng = math.Random(43);
    for (var i = 0; i < 12; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height * 0.6;
      final glow = (math.sin(t * math.pi * 2 + i * 1.1) + 1) / 2;
      canvas.drawCircle(
        Offset(x, y),
        1.5,
        Paint()..color = Colors.yellowAccent.withValues(alpha: 0.2 + glow * 0.4),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SparkBgPainter oldDelegate) => oldDelegate.t != t;
}

class _SparkBurstPainter extends CustomPainter {
  final double t;
  const _SparkBurstPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(47);
    final center = Offset(size.width / 2, size.height * 0.4);
    for (var i = 0; i < 18; i++) {
      final angle = (i / 18) * 2 * math.pi;
      final dist = t * (90 + rng.nextDouble() * 130);
      final pos = center + Offset(math.cos(angle), math.sin(angle)) * dist;
      final paint = Paint()
        ..color = Colors.yellowAccent.withValues(alpha: (1 - t).clamp(0.0, 1.0));
      canvas.drawCircle(pos, 4, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparkBurstPainter oldDelegate) => oldDelegate.t != t;
}

// ── Header / progress ────────────────────────────────────────────────────────

class _QuestHeader extends StatelessWidget {
  final String zoneName;
  final int zoneIdx;
  final int totalZones;
  final int completedSteps;
  final int totalSteps;
  const _QuestHeader({
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
          _QuestTrail(completed: completedSteps, total: totalSteps),
        ],
      ),
    );
  }
}

class _QuestTrail extends StatelessWidget {
  final int completed;
  final int total;
  const _QuestTrail({required this.completed, required this.total});

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
                  i < completed ? '⚡' : '·',
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
        color: Colors.black45,
        alignment: Alignment.center,
        child: Container(
          padding: const EdgeInsets.all(24),
          margin: const EdgeInsets.symmetric(horizontal: 40),
          decoration: BoxDecoration(
            color: _EQState._card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.yellowAccent, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('⚡', style: TextStyle(fontSize: 40)),
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
            colors: [_EQState._skyTop, _EQState._skyBottom],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('⚡🔥', style: TextStyle(fontSize: 44)),
                  SizedBox(height: 16),
                  Text(
                    'Energy Quest',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Discover heat, light, sound, kinetic and potential '
                    'energy all around you!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  SizedBox(height: 24),
                  CircularProgressIndicator(color: Colors.yellowAccent),
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
            colors: [_EQState._skyTop, _EQState._skyBottom],
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
                  const Text('Energy Master!',
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
                          color: Colors.yellowAccent,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: onReplay,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _EQState._card,
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
