import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/game_session_model.dart';
import '../core/game_config.dart';
import '../core/game_session_persistence.dart';

// ────────────────────────────────────────────────────────────────────────────
// Data City — Grade 4 Mathematics: bar graphs, pictographs, tables
//
// 4 Zones (5 questions each = 20 total):
//   1. Skyline Bars   — read values off a bar-graph skyline (MCQ)
//   2. Picto Plaza    — read a pictograph with an icon-value legend (MCQ)
//   3. Table Towers   — read a data table (MCQ)
//   4. Compare Corner — tap the tallest/shortest building directly to
//      answer "most/fewest" comparison questions
//
// Structurally distinct from every prior engine: this is the first to
// render three different real data representations (bar graph, pictograph,
// table) matching the three CAPS Grade 4 Data Handling formats, and the
// first zone (Compare Corner) where the diagram itself -- not a separate
// button row -- IS the multiple-choice control, echoing but re-imagining
// Fraction Forest's Compare Canopy idea for a genuinely different skill.
// Architecture: fully self-contained StatefulWidget.
// ────────────────────────────────────────────────────────────────────────────

enum _Phase { intro, playing, correct, wrong, streak, zoneDone, victory }

enum _Kind { barRead, pictograph, table, barCompare }

class _BarDatum {
  final String label;
  final int value;
  const _BarDatum(this.label, this.value);
}

class _DataQ {
  final String prompt;
  final List<String> choices; // choices[0] is always correct; empty for barCompare
  final int correctIndex; // MCQ: always 0; barCompare: index into bars
  final List<_BarDatum>? barsOverride;
  const _DataQ({
    required this.prompt,
    this.choices = const [],
    required this.correctIndex,
    this.barsOverride,
  });
}

class _Zone {
  final String name;
  final _Kind kind;
  final List<_BarDatum> bars;
  final String pictoIcon;
  final int pictoPerIcon;
  final List<MapEntry<String, int>> table;
  final List<_DataQ> questions;
  const _Zone({
    required this.name,
    required this.kind,
    this.bars = const [],
    this.pictoIcon = '',
    this.pictoPerIcon = 1,
    this.table = const [],
    required this.questions,
  });
}

class DataCityGame extends StatefulWidget {
  final GameConfig config;
  final dynamic user;
  const DataCityGame({super.key, required this.config, this.user});

  @override
  State<DataCityGame> createState() => _DCState();
}

class _DCState extends State<DataCityGame> with TickerProviderStateMixin {
  static const _zones = [
    _Zone(
      name: 'Skyline Bars',
      kind: _Kind.barRead,
      bars: [
        _BarDatum('Apple', 4),
        _BarDatum('Banana', 7),
        _BarDatum('Grape', 3),
        _BarDatum('Mango', 5),
      ],
      questions: [
        _DataQ(
            prompt: 'How many learners chose Banana?',
            choices: ['7', '4', '5'],
            correctIndex: 0),
        _DataQ(
            prompt: 'How many learners chose Grape?',
            choices: ['3', '5', '7'],
            correctIndex: 0),
        _DataQ(
            prompt: 'How many learners chose Apple?',
            choices: ['4', '3', '7'],
            correctIndex: 0),
        _DataQ(
            prompt: 'How many learners chose Mango?',
            choices: ['5', '4', '3'],
            correctIndex: 0),
        _DataQ(
            prompt: 'How many learners answered in total?',
            choices: ['19', '16', '20'],
            correctIndex: 0),
      ],
    ),
    _Zone(
      name: 'Picto Plaza',
      kind: _Kind.pictograph,
      pictoIcon: '🐾',
      pictoPerIcon: 2,
      bars: [
        _BarDatum('Dog', 3),
        _BarDatum('Cat', 2),
        _BarDatum('Fish', 4),
        _BarDatum('Bird', 1),
      ],
      questions: [
        _DataQ(
            prompt: 'Each 🐾 = 2 pets. How many dogs are there?',
            choices: ['6', '3', '4'],
            correctIndex: 0),
        _DataQ(
            prompt: 'How many fish are there?',
            choices: ['8', '4', '6'],
            correctIndex: 0),
        _DataQ(
            prompt: 'How many cats are there?',
            choices: ['4', '2', '6'],
            correctIndex: 0),
        _DataQ(
            prompt: 'How many birds are there?',
            choices: ['2', '1', '4'],
            correctIndex: 0),
        _DataQ(
            prompt: 'How many pets are there in total?',
            choices: ['20', '16', '18'],
            correctIndex: 0),
      ],
    ),
    _Zone(
      name: 'Table Towers',
      kind: _Kind.table,
      table: [
        MapEntry('Mon', 5),
        MapEntry('Tue', 12),
        MapEntry('Wed', 0),
        MapEntry('Thu', 8),
        MapEntry('Fri', 15),
      ],
      questions: [
        _DataQ(
            prompt: 'How much rain fell on Tuesday?',
            choices: ['12 mm', '5 mm', '8 mm'],
            correctIndex: 0),
        _DataQ(
            prompt: 'How much rain fell on Wednesday?',
            choices: ['0 mm', '5 mm', '8 mm'],
            correctIndex: 0),
        _DataQ(
            prompt: 'Which day had the most rain?',
            choices: ['Friday', 'Tuesday', 'Thursday'],
            correctIndex: 0),
        _DataQ(
            prompt: 'How much rain fell on Friday?',
            choices: ['15 mm', '12 mm', '8 mm'],
            correctIndex: 0),
        _DataQ(
            prompt: 'How much rain fell on Monday and Thursday together?',
            choices: ['13 mm', '12 mm', '15 mm'],
            correctIndex: 0),
      ],
    ),
    _Zone(
      name: 'Compare Corner',
      kind: _Kind.barCompare,
      questions: [
        _DataQ(
          prompt: 'Tap the sport with the MOST players.',
          correctIndex: 0,
          barsOverride: [
            _BarDatum('Soccer', 9),
            _BarDatum('Netball', 6),
            _BarDatum('Cricket', 4),
            _BarDatum('Athletics', 7),
          ],
        ),
        _DataQ(
          prompt: 'Tap the sport with the FEWEST players.',
          correctIndex: 2,
          barsOverride: [
            _BarDatum('Soccer', 9),
            _BarDatum('Netball', 6),
            _BarDatum('Cricket', 4),
            _BarDatum('Athletics', 7),
          ],
        ),
        _DataQ(
          prompt: 'Tap the reader who read the MOST books.',
          correctIndex: 1,
          barsOverride: [
            _BarDatum('Thabo', 3),
            _BarDatum('Lindiwe', 8),
            _BarDatum('Sipho', 5),
            _BarDatum('Aisha', 6),
          ],
        ),
        _DataQ(
          prompt: 'Tap the reader who read the FEWEST books.',
          correctIndex: 0,
          barsOverride: [
            _BarDatum('Thabo', 3),
            _BarDatum('Lindiwe', 8),
            _BarDatum('Sipho', 5),
            _BarDatum('Aisha', 6),
          ],
        ),
        _DataQ(
          prompt: 'Tap the week that saved the MOST money.',
          correctIndex: 1,
          barsOverride: [
            _BarDatum('Wk1', 20),
            _BarDatum('Wk2', 45),
            _BarDatum('Wk3', 30),
            _BarDatum('Wk4', 15),
          ],
        ),
      ],
    ),
  ];

  static const _wrongReactions = [
    'Not quite -- check the chart again!',
    'Close -- look at the data once more!',
    'Try reading it again carefully!',
  ];

  static const _duskTop = Color(0xFF2B1B54);
  static const _duskBottom = Color(0xFFB5436B);
  static const _gold = Color(0xFFFFC94A);
  static const _buildingBlue = Color(0xFF4A6FA5);

  late AnimationController _ambientCtrl;
  late AnimationController _fadeCtrl;
  late AnimationController _flashCtrl;
  late AnimationController _confettiCtrl;
  late AnimationController _shakeCtrl;

  late Animation<double> _ambientAnim;
  late Animation<double> _fadeAnim;
  late Animation<double> _flashAnim;
  late Animation<double> _confettiAnim;
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

    _confettiCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1700));
    _confettiAnim =
        CurvedAnimation(parent: _confettiCtrl, curve: Curves.easeOut);

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
    _confettiCtrl.dispose();
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

  Object? _cachedQ;
  List<String> _cachedChoices = [];

  List<String> _getShuffledChoices(_DataQ q) {
    if (!identical(_cachedQ, q)) {
      _cachedQ = q;
      _cachedChoices = List<String>.from(q.choices)..shuffle(_rng);
    }
    return _cachedChoices;
  }

  void _onAnswer(int tappedIndex) {
    if (_phase != _Phase.playing) return;
    final zone = _zones[_zoneIdx];
    final q = zone.questions[_qIdx];
    final choices = _getShuffledChoices(q);
    final isCorrect = zone.kind == _Kind.barCompare
        ? tappedIndex == q.correctIndex
        : choices[tappedIndex] == q.choices[q.correctIndex];

    setState(() {
      _selectedIndex = tappedIndex;
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
          _confettiCtrl.forward(from: 0);
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
    final bars = q.barsOverride ?? zone.bars;

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_duskTop, _duskBottom],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _ambientAnim,
              builder: (context, _) =>
                  CustomPaint(painter: _CityLightsPainter(_ambientAnim.value)),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _CityHeader(
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
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 20),
                          switch (zone.kind) {
                            _Kind.barRead => _SkylineChart(bars: zone.bars),
                            _Kind.pictograph => _PictoChart(
                                icon: zone.pictoIcon,
                                perIcon: zone.pictoPerIcon,
                                bars: zone.bars,
                              ),
                            _Kind.table => _TableChart(rows: zone.table),
                            _Kind.barCompare => AnimatedBuilder(
                                animation: _shakeAnim,
                                builder: (context, _) {
                                  final dx = _phase == _Phase.wrong
                                      ? math.sin(
                                              _shakeAnim.value * math.pi * 6) *
                                          6
                                      : 0.0;
                                  return Transform.translate(
                                    offset: Offset(dx, 0),
                                    child: _SkylineChart(
                                      bars: bars,
                                      selectedIndex: _selectedIndex,
                                      correctIndex: q.correctIndex,
                                      revealed: revealed,
                                      onTapBuilding: revealed ? null : _onAnswer,
                                    ),
                                  );
                                },
                              ),
                          },
                          if (zone.kind != _Kind.barCompare) ...[
                            const SizedBox(height: 26),
                            AnimatedBuilder(
                              animation: _shakeAnim,
                              builder: (context, _) {
                                final dx = _phase == _Phase.wrong
                                    ? math.sin(_shakeAnim.value * math.pi * 6) *
                                        6
                                    : 0.0;
                                final choices = _getShuffledChoices(q);
                                return Transform.translate(
                                  offset: Offset(dx, 0),
                                  child: Wrap(
                                    spacing: 14,
                                    runSpacing: 14,
                                    alignment: WrapAlignment.center,
                                    children: [
                                      for (var i = 0; i < choices.length; i++)
                                        _SkyscraperButton(
                                          label: choices[i],
                                          selected: _selectedIndex == i,
                                          isCorrect: choices[i] == q.choices[q.correctIndex],
                                          revealed: revealed,
                                          onTap: () => _onAnswer(i),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                          if (_phase == _Phase.wrong)
                            Padding(
                              padding: const EdgeInsets.only(top: 18),
                              child: Text(
                                zone.kind == _Kind.barCompare
                                    ? '$_wrongReaction The answer was ${bars[q.correctIndex].label}.'
                                    : '$_wrongReaction The answer was ${q.choices[0]}.',
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
                  child: Container(color: _gold),
                ),
              ),
            ),
          if (_phase == _Phase.streak)
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _confettiAnim,
                builder: (context, _) => CustomPaint(
                  painter: _ConfettiShowerPainter(_confettiAnim.value),
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

// ── Bar graph skyline ────────────────────────────────────────────────────────

class _SkylineChart extends StatelessWidget {
  final List<_BarDatum> bars;
  final int? selectedIndex;
  final int? correctIndex;
  final bool revealed;
  final ValueChanged<int>? onTapBuilding;
  const _SkylineChart({
    required this.bars,
    this.selectedIndex,
    this.correctIndex,
    this.revealed = false,
    this.onTapBuilding,
  });

  @override
  Widget build(BuildContext context) {
    final maxValue = bars.map((b) => b.value).reduce(math.max);
    const chartHeight = 160.0;
    final gridStep = (maxValue / 3).ceil().clamp(1, 999);

    return SizedBox(
      height: chartHeight + 40,
      child: Stack(
        children: [
          // Gridlines
          Positioned.fill(
            bottom: 40,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var v = gridStep * 3; v >= 0; v -= gridStep)
                  Row(
                    children: [
                      SizedBox(
                          width: 22,
                          child: Text('$v',
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 10))),
                      const Expanded(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border(
                                top: BorderSide(
                                    color: Colors.white24, width: 1)),
                          ),
                          child: SizedBox(height: 1),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          // Buildings
          Positioned(
            left: 26,
            right: 0,
            bottom: 0,
            top: 0,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (var i = 0; i < bars.length; i++) _building(i, maxValue, chartHeight),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _building(int i, int maxValue, double chartHeight) {
    final b = bars[i];
    final h = (b.value / maxValue) * (chartHeight - 10) + 10;
    Color color = _DCState._buildingBlue;
    if (revealed && i == correctIndex) color = const Color(0xFF4CAF7D);
    if (revealed && i == selectedIndex && i != correctIndex) {
      color = const Color(0xFFE05656);
    }

    final tower = Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 46,
          height: h,
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
          child: CustomPaint(painter: _WindowGridPainter()),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 46,
          child: Text(
            b.label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );

    if (onTapBuilding == null) return tower;
    return GestureDetector(onTap: () => onTapBuilding!(i), child: tower);
  }
}

class _WindowGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.35);
    const win = 5.0, gap = 4.0;
    for (double y = 6; y < size.height - win; y += win + gap) {
      for (double x = 6; x < size.width - win; x += win + gap) {
        canvas.drawRect(Rect.fromLTWH(x, y, win, win), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WindowGridPainter oldDelegate) => false;
}

// ── Pictograph ────────────────────────────────────────────────────────────────

class _PictoChart extends StatelessWidget {
  final String icon;
  final int perIcon;
  final List<_BarDatum> bars;
  const _PictoChart({required this.icon, required this.perIcon, required this.bars});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text('$icon = $perIcon pets',
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 10),
          for (final b in bars)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                      width: 44,
                      child: Text(b.label,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13))),
                  Expanded(
                    child: Text(
                      icon * (b.value / perIcon).round(),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Table ─────────────────────────────────────────────────────────────────────

class _TableChart extends StatelessWidget {
  final List<MapEntry<String, int>> rows;
  const _TableChart({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            color: Colors.white.withValues(alpha: 0.15),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: const Row(
              children: [
                Expanded(
                    child: Text('Day',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13))),
                Text('Rainfall (mm)',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
              ],
            ),
          ),
          for (var i = 0; i < rows.length; i++)
            Container(
              color: i.isEven
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.transparent,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                      child: Text(rows[i].key,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13))),
                  Text('${rows[i].value}',
                      style: const TextStyle(color: Colors.white, fontSize: 13)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Skyscraper answer button ───────────────────────────────────────────────────

class _SkyscraperButton extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isCorrect;
  final bool revealed;
  final VoidCallback onTap;
  const _SkyscraperButton({
    required this.label,
    required this.selected,
    required this.isCorrect,
    required this.revealed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color fill = _DCState._buildingBlue;
    if (revealed && isCorrect) fill = const Color(0xFF4CAF7D);
    if (revealed && selected && !isCorrect) fill = const Color(0xFFE05656);

    return GestureDetector(
      onTap: revealed ? null : onTap,
      child: ClipPath(
        clipper: const _SkyscraperClipper(),
        child: Container(
          width: 92,
          height: 80,
          alignment: Alignment.center,
          padding: const EdgeInsets.only(top: 10),
          color: fill,
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
  }
}

class _SkyscraperClipper extends CustomClipper<Path> {
  const _SkyscraperClipper();
  @override
  Path getClip(Size size) {
    final w = size.width, h = size.height;
    final path = Path()
      ..moveTo(w * 0.45, 0)
      ..lineTo(w * 0.55, 0)
      ..lineTo(w * 0.55, h * 0.12)
      ..lineTo(w * 0.9, h * 0.12)
      ..quadraticBezierTo(w, h * 0.12, w, h * 0.3)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..lineTo(0, h * 0.3)
      ..quadraticBezierTo(0, h * 0.12, w * 0.1, h * 0.12)
      ..lineTo(w * 0.45, h * 0.12)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

// ── Painters ─────────────────────────────────────────────────────────────────

class _CityLightsPainter extends CustomPainter {
  final double t;
  const _CityLightsPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(3);
    for (var i = 0; i < 14; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height * 0.5;
      final glow = (math.sin(t * math.pi * 2 + i * 1.3) + 1) / 2;
      canvas.drawCircle(
        Offset(x, y),
        1.5,
        Paint()..color = _DCState._gold.withValues(alpha: 0.2 + glow * 0.5),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CityLightsPainter oldDelegate) =>
      oldDelegate.t != t;
}

class _ConfettiShowerPainter extends CustomPainter {
  final double t;
  const _ConfettiShowerPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(9);
    const colors = [_DCState._gold, Color(0xFFE05656), Color(0xFF4CAF7D), Colors.white];
    for (var i = 0; i < 24; i++) {
      final startX = rng.nextDouble() * size.width;
      final speed = 0.5 + rng.nextDouble() * 0.6;
      final y = (t * speed) * (size.height + 40) - 20;
      final x = startX + math.sin((t * 6) + i) * 14;
      final paint = Paint()
        ..color = colors[i % colors.length]
            .withValues(alpha: (1 - t).clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(t * 8 + i);
      canvas.drawRect(const Rect.fromLTWH(-4, -4, 8, 8), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiShowerPainter oldDelegate) =>
      oldDelegate.t != t;
}

// ── Header / progress ────────────────────────────────────────────────────────

class _CityHeader extends StatelessWidget {
  final String zoneName;
  final int zoneIdx;
  final int totalZones;
  final int completedSteps;
  final int totalSteps;
  const _CityHeader({
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
              const Text('🏙️', style: TextStyle(fontSize: 22)),
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
          _BlockTrail(completed: completedSteps, total: totalSteps),
        ],
      ),
    );
  }
}

class _BlockTrail extends StatelessWidget {
  final int completed;
  final int total;
  const _BlockTrail({required this.completed, required this.total});

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
                  i < completed ? '🏢' : '·',
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
            color: _DCState._duskTop,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _DCState._gold, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🌆', style: TextStyle(fontSize: 40)),
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
            colors: [_DCState._duskTop, _DCState._duskBottom],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🏙️📊', style: TextStyle(fontSize: 44)),
                  SizedBox(height: 16),
                  Text(
                    'Data City',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Read the skyline, plaza and towers -- every chart '
                    'holds the answer!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  SizedBox(height: 24),
                  CircularProgressIndicator(color: _DCState._gold),
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
            colors: [_DCState._duskTop, _DCState._duskBottom],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🏆🏙️', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  const Text('City Charted!',
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
                          color: _DCState._gold,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: onReplay,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _DCState._buildingBlue,
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
