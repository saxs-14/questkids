import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/game_session_model.dart';
import '../core/game_config.dart';
import '../core/game_session_persistence.dart';

// ────────────────────────────────────────────────────────────────────────────
// Weather Watcher — Grade 4 Natural Sciences: weather maps, cloud types,
// South African weather patterns
//
// 4 Zones (5 questions each = 20 total):
//   1. Read the Sky      — a hand-drawn cloud-shape diagram (cumulus,
//      stratus, cirrus, cumulonimbus, clear sky) to identify
//   2. Weather Dashboard — THREE instrument readouts shown together
//      (thermometer, wind, condition icon) that must be read as a set
//   3. SA Seasons & Patterns — recall MCQ, South African context
//   4. Weather Instruments   — match instrument to what it measures
//
// Structurally distinct from every prior engine: Weather Dashboard is the
// first question anywhere that shows multiple simultaneous instrument
// readouts (a thermometer, a wind indicator and a condition icon at once)
// that must be read TOGETHER as a set to answer, rather than a single
// diagram or a single data value.
// Architecture: fully self-contained StatefulWidget.
// ────────────────────────────────────────────────────────────────────────────

enum _Phase { intro, playing, correct, wrong, streak, zoneDone, victory }

enum _Kind { cloud, dashboard, simple }

class _CloudQ {
  final String cloudType; // cumulus | stratus | cirrus | cumulonimbus | clear
  final String prompt;
  final List<String> choices; // [0] correct
  const _CloudQ({required this.cloudType, required this.prompt, required this.choices});
}

class _DashboardQ {
  final int tempC;
  final bool windy;
  final String condition; // sunny | rainy | cloudy | snow
  final String prompt;
  final List<String> choices; // [0] correct
  const _DashboardQ({
    required this.tempC,
    required this.windy,
    required this.condition,
    required this.prompt,
    required this.choices,
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
  final List<_CloudQ> clouds;
  final List<_DashboardQ> dashboards;
  final List<_SimpleQ> simple;
  const _Zone.cloud(this.name, this.clouds)
      : kind = _Kind.cloud,
        dashboards = const [],
        simple = const [];
  const _Zone.dashboard(this.name, this.dashboards)
      : kind = _Kind.dashboard,
        clouds = const [],
        simple = const [];
  const _Zone.simple(this.name, this.simple)
      : kind = _Kind.simple,
        clouds = const [],
        dashboards = const [];

  int get length => switch (kind) {
        _Kind.cloud => clouds.length,
        _Kind.dashboard => dashboards.length,
        _Kind.simple => simple.length,
      };
}

class WeatherWatcherGame extends StatefulWidget {
  final GameConfig config;
  final dynamic user;
  const WeatherWatcherGame({super.key, required this.config, this.user});

  @override
  State<WeatherWatcherGame> createState() => _WWState();
}

class _WWState extends State<WeatherWatcherGame> with TickerProviderStateMixin {
  static const _zones = [
    _Zone.cloud('Read the Sky', [
      _CloudQ(
          cloudType: 'cumulus',
          prompt: 'What type of cloud is this -- fluffy, like cotton wool?',
          choices: ['Cumulus', 'Stratus', 'Cirrus']),
      _CloudQ(
          cloudType: 'stratus',
          prompt: 'What type of cloud is this -- a flat, grey layer?',
          choices: ['Stratus', 'Cumulus', 'Cirrus']),
      _CloudQ(
          cloudType: 'cirrus',
          prompt: 'What type of cloud is this -- thin and wispy, high up?',
          choices: ['Cirrus', 'Stratus', 'Cumulus']),
      _CloudQ(
          cloudType: 'cumulonimbus',
          prompt: 'What type of cloud brings thunderstorms?',
          choices: ['Cumulonimbus', 'Cirrus', 'Stratus']),
      _CloudQ(
          cloudType: 'clear',
          prompt: 'What does a clear sky like this usually mean?',
          choices: ['Fine, sunny weather', 'Rain is coming', 'A storm']),
    ]),
    _Zone.dashboard('Weather Dashboard', [
      _DashboardQ(
          tempC: 30,
          windy: false,
          condition: 'sunny',
          prompt: 'What should you wear today?',
          choices: ['Shorts and a hat', 'A raincoat', 'A thick jacket']),
      _DashboardQ(
          tempC: 8,
          windy: true,
          condition: 'cloudy',
          prompt: 'What should you wear today?',
          choices: ['A warm jacket', 'Shorts', 'A swimsuit']),
      _DashboardQ(
          tempC: 18,
          windy: false,
          condition: 'rainy',
          prompt: 'What should you take with you?',
          choices: ['An umbrella', 'Sunglasses', 'A fan']),
      _DashboardQ(
          tempC: 20,
          windy: true,
          condition: 'sunny',
          prompt: 'What weather condition is shown here?',
          choices: ['Windy', 'Calm', 'Foggy']),
      _DashboardQ(
          tempC: -2,
          windy: true,
          condition: 'snow',
          prompt: 'Which South African region might see this in winter?',
          choices: ['The Drakensberg mountains', 'The Kalahari desert', 'The Durban coast']),
    ]),
    _Zone.simple('SA Seasons & Patterns', [
      _SimpleQ(
          prompt: 'In which season does Cape Town get most of its rain?',
          choices: ['Winter', 'Summer', 'Autumn']),
      _SimpleQ(
          prompt: 'In which season does Johannesburg usually get most of its rain?',
          choices: ['Summer', 'Winter', 'Spring']),
      _SimpleQ(
          prompt: 'Which South African region often sees snow in winter?',
          choices: ['The Drakensberg region', 'The Kalahari desert', 'The Durban beachfront']),
      _SimpleQ(
          prompt: 'What is one of the driest regions in South Africa?',
          choices: ['The Kalahari / Northern Cape', 'The Cape coast', 'The Drakensberg']),
      _SimpleQ(
          prompt: 'In which season are South African days usually longest?',
          choices: ['Summer', 'Winter', 'Autumn']),
    ]),
    _Zone.simple('Weather Instruments', [
      _SimpleQ(
          prompt: 'Which instrument measures temperature?',
          choices: ['Thermometer', 'Rain gauge', 'Wind vane']),
      _SimpleQ(
          prompt: 'Which instrument measures rainfall?',
          choices: ['Rain gauge', 'Thermometer', 'Barometer']),
      _SimpleQ(
          prompt: 'Which instrument shows wind direction?',
          choices: ['Wind vane', 'Rain gauge', 'Thermometer']),
      _SimpleQ(
          prompt: 'Which instrument measures air pressure?',
          choices: ['Barometer', 'Thermometer', 'Wind vane']),
      _SimpleQ(
          prompt: 'Which instrument measures wind speed?',
          choices: ['Anemometer', 'Barometer', 'Rain gauge']),
    ]),
  ];

  static const _wrongReactions = [
    'Not quite -- look at the sky again!',
    'Close -- check the readings again!',
    'Try again, weather watcher!',
  ];

  static const _skyTop = Color(0xFF8FB8D6);
  static const _skyBottom = Color(0xFF4C7291);
  static const _card = Color(0xFF33566F);

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
    final total = _totalQuestions;
    final completedSteps =
        _zones.take(_zoneIdx).fold<int>(0, (sum, z) => sum + z.length) + _qIdx;
    final revealed = _phase == _Phase.correct || _phase == _Phase.wrong;

    late final String prompt;
    late final List<String> choices;
    switch (zone.kind) {
      case _Kind.cloud:
        prompt = zone.clouds[_qIdx].prompt;
        choices = zone.clouds[_qIdx].choices;
      case _Kind.dashboard:
        prompt = zone.dashboards[_qIdx].prompt;
        choices = zone.dashboards[_qIdx].choices;
      case _Kind.simple:
        prompt = zone.simple[_qIdx].prompt;
        choices = zone.simple[_qIdx].choices;
    }

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
                  CustomPaint(painter: _DriftCloudPainter(_ambientAnim.value)),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _WeatherHeader(
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
                            prompt,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 18),
                          if (zone.kind == _Kind.cloud)
                            SizedBox(
                              width: 220,
                              height: 130,
                              child: CustomPaint(
                                  painter: _CloudPainter(zone.clouds[_qIdx].cloudType)),
                            ),
                          if (zone.kind == _Kind.dashboard)
                            _DashboardWidget(q: zone.dashboards[_qIdx]),
                          const SizedBox(height: 24),
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
                                      _WeatherTile(
                                        label: choices[i],
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
                          if (_phase == _Phase.wrong)
                            Padding(
                              padding: const EdgeInsets.only(top: 18),
                              child: Text(
                                '$_wrongReaction The answer was ${choices[0]}.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
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
                  painter: _RainShowerPainter(_burstAnim.value),
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
}

// ── Cloud diagram ────────────────────────────────────────────────────────────

class _CloudPainter extends CustomPainter {
  final String cloudType;
  const _CloudPainter(this.cloudType);

  @override
  void paint(Canvas canvas, Size size) {
    final skyPaint = Paint()..color = const Color(0xFF6E9DBF);
    canvas.drawRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(14)), skyPaint);

    switch (cloudType) {
      case 'cumulus':
        final paint = Paint()..color = Colors.white;
        final cx = size.width / 2, cy = size.height / 2 + 10;
        canvas.drawCircle(Offset(cx - 40, cy + 8), 30, paint);
        canvas.drawCircle(Offset(cx - 10, cy - 10), 38, paint);
        canvas.drawCircle(Offset(cx + 30, cy), 32, paint);
        canvas.drawCircle(Offset(cx + 55, cy + 12), 24, paint);
        canvas.drawRect(Rect.fromLTWH(cx - 60, cy + 5, 130, 30), paint);
      case 'stratus':
        final paint = Paint()..color = const Color(0xFFCBD5DC);
        for (var i = 0; i < 3; i++) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(10, size.height * 0.3 + i * 24, size.width - 20, 20),
              const Radius.circular(10),
            ),
            paint,
          );
        }
      case 'cirrus':
        final paint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round;
        for (var i = 0; i < 4; i++) {
          final y = size.height * 0.3 + i * 18.0;
          final path = Path()..moveTo(10, y);
          path.quadraticBezierTo(size.width * 0.5, y - 14, size.width - 10, y);
          canvas.drawPath(path, paint);
        }
      case 'cumulonimbus':
        final darkPaint = Paint()..color = const Color(0xFF4A5563);
        final cx = size.width / 2, cy = size.height / 2;
        canvas.drawCircle(Offset(cx - 35, cy + 10), 28, darkPaint);
        canvas.drawCircle(Offset(cx, cy - 15), 36, darkPaint);
        canvas.drawCircle(Offset(cx + 35, cy + 5), 30, darkPaint);
        canvas.drawRect(Rect.fromLTWH(cx - 55, cy + 5, 115, 35), darkPaint);
        final boltPaint = Paint()
          ..color = const Color(0xFFFFC94A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4;
        final bolt = Path()
          ..moveTo(cx, cy + 40)
          ..lineTo(cx - 10, cy + 65)
          ..lineTo(cx + 4, cy + 65)
          ..lineTo(cx - 8, cy + 95);
        canvas.drawPath(bolt, boltPaint);
      case 'clear':
        final sunPaint = Paint()..color = const Color(0xFFFFC94A);
        final center = Offset(size.width / 2, size.height / 2);
        canvas.drawCircle(center, 26, sunPaint);
        final rayPaint = Paint()
          ..color = const Color(0xFFFFC94A)
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round;
        for (var i = 0; i < 8; i++) {
          final angle = i * math.pi / 4;
          final p1 = center + Offset(math.cos(angle), math.sin(angle)) * 36;
          final p2 = center + Offset(math.cos(angle), math.sin(angle)) * 50;
          canvas.drawLine(p1, p2, rayPaint);
        }
    }
  }

  @override
  bool shouldRepaint(covariant _CloudPainter oldDelegate) =>
      oldDelegate.cloudType != cloudType;
}

// ── Weather dashboard (multi-instrument readout) ────────────────────────────

class _DashboardWidget extends StatelessWidget {
  final _DashboardQ q;
  const _DashboardWidget({required this.q});

  String get _conditionEmoji => switch (q.condition) {
        'sunny' => '☀️',
        'rainy' => '🌧️',
        'cloudy' => '☁️',
        'snow' => '❄️',
        _ => '🌤️',
      };

  @override
  Widget build(BuildContext context) {
    final fill = ((q.tempC + 10) / 50).clamp(0.05, 1.0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Thermometer
          Column(
            children: [
              SizedBox(
                width: 20,
                height: 70,
                child: CustomPaint(painter: _ThermoPainter(fill: fill)),
              ),
              const SizedBox(height: 4),
              Text('${q.tempC}°C',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
            ],
          ),
          // Wind
          Column(
            children: [
              SizedBox(
                width: 50,
                height: 70,
                child: CustomPaint(painter: _WindPainter(windy: q.windy)),
              ),
              const SizedBox(height: 4),
              Text(q.windy ? 'Windy' : 'Calm',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
            ],
          ),
          // Condition
          Column(
            children: [
              SizedBox(
                height: 70,
                child: Center(child: Text(_conditionEmoji, style: const TextStyle(fontSize: 40))),
              ),
              const SizedBox(height: 4),
              Text(q.condition[0].toUpperCase() + q.condition.substring(1),
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ThermoPainter extends CustomPainter {
  final double fill;
  const _ThermoPainter({required this.fill});

  @override
  void paint(Canvas canvas, Size size) {
    final trackPaint = Paint()..color = Colors.white24;
    final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.3, 0, size.width * 0.4, size.height - 12),
        const Radius.circular(6));
    canvas.drawRRect(rrect, trackPaint);

    final fillHeight = (size.height - 12) * fill;
    final fillPaint = Paint()..color = fill > 0.5 ? const Color(0xFFE05656) : const Color(0xFF6EC6E8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.3, size.height - 12 - fillHeight, size.width * 0.4, fillHeight),
        const Radius.circular(6),
      ),
      fillPaint,
    );
    canvas.drawCircle(Offset(size.width / 2, size.height - 6), 8, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _ThermoPainter oldDelegate) => oldDelegate.fill != fill;
}

class _WindPainter extends CustomPainter {
  final bool windy;
  const _WindPainter({required this.windy});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = windy ? 3.5 : 2
      ..strokeCap = StrokeCap.round;
    final lineCount = windy ? 3 : 1;
    for (var i = 0; i < lineCount; i++) {
      final y = size.height * 0.35 + i * 14;
      final len = windy ? size.width * 0.8 : size.width * 0.4;
      canvas.drawLine(Offset(4, y), Offset(4 + len, y), paint);
      canvas.drawLine(
          Offset(4 + len, y), Offset(4 + len - 6, y - 4), paint);
      canvas.drawLine(
          Offset(4 + len, y), Offset(4 + len - 6, y + 4), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WindPainter oldDelegate) => oldDelegate.windy != windy;
}

// ── Weather tile (MCQ) ──────────────────────────────────────────────────────

class _WeatherTile extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isCorrect;
  final bool revealed;
  final VoidCallback onTap;
  const _WeatherTile({
    required this.label,
    required this.selected,
    required this.isCorrect,
    required this.revealed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color fill = _WWState._card;
    if (revealed && isCorrect) fill = const Color(0xFF4CAF7D);
    if (revealed && selected && !isCorrect) fill = const Color(0xFFE05656);

    return GestureDetector(
      onTap: revealed ? null : onTap,
      child: Container(
        constraints: const BoxConstraints(minWidth: 100, maxWidth: 180),
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
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

class _DriftCloudPainter extends CustomPainter {
  final double t;
  const _DriftCloudPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.15);
    for (var i = 0; i < 3; i++) {
      final x = size.width * (0.15 + i * 0.3) + math.sin(t * math.pi * 2 + i) * 12;
      canvas.drawOval(
          Rect.fromCenter(center: Offset(x, size.height * 0.1), width: 50, height: 20), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DriftCloudPainter oldDelegate) => oldDelegate.t != t;
}

class _RainShowerPainter extends CustomPainter {
  final double t;
  const _RainShowerPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(67);
    final paint = Paint()
      ..color = const Color(0xFF6EC6E8).withValues(alpha: (1 - t).clamp(0.0, 1.0))
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 20; i++) {
      final startX = rng.nextDouble() * size.width;
      final speed = 0.6 + rng.nextDouble() * 0.6;
      final y = (t * speed) * (size.height + 40) - 20;
      final x = startX + t * 20;
      canvas.drawLine(Offset(x, y), Offset(x - 6, y + 14), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RainShowerPainter oldDelegate) => oldDelegate.t != t;
}

// ── Header / progress ────────────────────────────────────────────────────────

class _WeatherHeader extends StatelessWidget {
  final String zoneName;
  final int zoneIdx;
  final int totalZones;
  final int completedSteps;
  final int totalSteps;
  const _WeatherHeader({
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
              const Text('🌤️', style: TextStyle(fontSize: 22)),
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
          _WeatherTrail(completed: completedSteps, total: totalSteps),
        ],
      ),
    );
  }
}

class _WeatherTrail extends StatelessWidget {
  final int completed;
  final int total;
  const _WeatherTrail({required this.completed, required this.total});

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
                  i < completed ? '☁️' : '·',
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
        color: Colors.black38,
        alignment: Alignment.center,
        child: Container(
          padding: const EdgeInsets.all(24),
          margin: const EdgeInsets.symmetric(horizontal: 40),
          decoration: BoxDecoration(
            color: _WWState._card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🌦️', style: TextStyle(fontSize: 40)),
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
            colors: [_WWState._skyTop, _WWState._skyBottom],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🌤️☔', style: TextStyle(fontSize: 44)),
                  SizedBox(height: 16),
                  Text(
                    'Weather Watcher',
                    style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Read the clouds, check the dashboard, and discover '
                    "South Africa's weather patterns!",
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
            colors: [_WWState._skyTop, _WWState._skyBottom],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🏆🌤️', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  const Text('Forecast Complete!',
                      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  Text('$correctCount / $total correct ($pct%)',
                      style: const TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('+$totalXP XP',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: onReplay,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _WWState._card,
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
