import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/game_session_model.dart';
import '../core/game_config.dart';
import '../core/game_session_persistence.dart';

// ────────────────────────────────────────────────────────────────────────────
// Career Explorer — Grade 4 Life Skills: careers, the skills and tools they
// need, and the work-ethic values behind them
//
// NOTE: this is a DIFFERENT engine from adventure_journey/ (engineType
// 'adventureJourney'), which is a shared generic engine still used by 16
// other catalog entries. This engine (engineType 'careerExplorer') is
// registered ONLY against ls_g4_career.
//
// 4 Zones (5 questions each = 20 total):
//   1. Try On the Career   — read a clue describing a job, tap the matching
//      career; a blank ID badge does a 3D Y-axis flip to reveal the
//      career's title + emoji as an earned badge
//   2. Careers & Skills      — recall MCQ (what skill suits which career)
//   3. Tools of the Trade    — recall MCQ (which tool belongs to which job)
//   4. Work Ethics & Values  — recall MCQ (responsibility, teamwork, growth)
//
// Structurally distinct from every prior engine: Zone 1's 3D card-flip ID
// badge is a new animation primitive -- unlike Idiom Island's lid-shrink
// reveal, Ancient Civilizations' tile-clearing grid, or Democracy Game's
// falling ballot. Architecture: fully self-contained StatefulWidget.
// ────────────────────────────────────────────────────────────────────────────

enum _Phase { intro, playing, correct, wrong, streak, zoneDone, victory }

enum _Kind { badge, simple }

class _BadgeQ {
  final String clue;
  final String emoji;
  final List<String> choices; // [0] correct career name
  const _BadgeQ({required this.clue, required this.emoji, required this.choices});
}

class _SimpleQ {
  final String prompt;
  final List<String> choices; // [0] correct
  const _SimpleQ({required this.prompt, required this.choices});
}

class _Zone {
  final String name;
  final _Kind kind;
  final List<_BadgeQ> badge;
  final List<_SimpleQ> simple;
  const _Zone.badge(this.name, this.badge)
      : kind = _Kind.badge,
        simple = const [];
  const _Zone.simple(this.name, this.simple)
      : kind = _Kind.simple,
        badge = const [];

  int get length => kind == _Kind.badge ? badge.length : simple.length;
}

class CareerExplorerGame extends StatefulWidget {
  final GameConfig config;
  final dynamic user;
  const CareerExplorerGame({super.key, required this.config, this.user});

  @override
  State<CareerExplorerGame> createState() => _CEState();
}

class _CEState extends State<CareerExplorerGame> with TickerProviderStateMixin {
  static const _zones = [
    _Zone.badge('Try On the Career', [
      _BadgeQ(
        clue: 'I look after sick people and help them get better. I often work in a hospital.',
        emoji: '🩺',
        choices: ['Nurse', 'Teacher', 'Farmer'],
      ),
      _BadgeQ(
        clue: 'I teach learners new things every day and help them with their homework.',
        emoji: '📚',
        choices: ['Teacher', 'Chef', 'Pilot'],
      ),
      _BadgeQ(
        clue: 'I grow crops and raise animals to produce food for our country.',
        emoji: '🌾',
        choices: ['Farmer', 'Engineer', 'Artist'],
      ),
      _BadgeQ(
        clue: 'I design and build houses, bridges, and roads using maths and science.',
        emoji: '📐',
        choices: ['Engineer', 'Musician', 'Police Officer'],
      ),
      _BadgeQ(
        clue: 'I keep our communities safe and help enforce the law.',
        emoji: '👮',
        choices: ['Police Officer', 'Baker', 'Scientist'],
      ),
    ]),
    _Zone.simple('Careers & Skills', [
      _SimpleQ(
        prompt: 'Which skill is most important for a firefighter?',
        choices: ['Bravery and quick thinking', 'Painting', 'Singing'],
      ),
      _SimpleQ(
        prompt: 'A chef needs to be skilled at...?',
        choices: ['Cooking and following recipes', 'Fixing cars', 'Building houses'],
      ),
      _SimpleQ(
        prompt: 'An artist mainly uses their...?',
        choices: ['Creativity and imagination', 'Medical knowledge', 'Legal knowledge'],
      ),
      _SimpleQ(
        prompt: 'A good teacher needs to be...?',
        choices: ['Patient and a clear communicator', 'Very tall', 'Good at sport only'],
      ),
      _SimpleQ(
        prompt: 'Scientists mostly rely on...?',
        choices: ['Careful observation and experiments', 'Guessing randomly', 'Copying others'],
      ),
    ]),
    _Zone.simple('Tools of the Trade', [
      _SimpleQ(
        prompt: 'Which tool would a doctor most likely use?',
        choices: ['Stethoscope', 'Hammer', 'Paintbrush'],
      ),
      _SimpleQ(
        prompt: 'A carpenter would most likely use a...?',
        choices: ['Saw', 'Microscope', 'Whisk'],
      ),
      _SimpleQ(
        prompt: 'Which tool does a farmer often use to plough fields?',
        choices: ['Tractor', 'Calculator', 'Camera'],
      ),
      _SimpleQ(
        prompt: 'A hairdresser would most likely use...?',
        choices: ['Scissors and a comb', 'A stethoscope', 'A fire hose'],
      ),
      _SimpleQ(
        prompt: 'Which tool would an accountant use most often?',
        choices: ['Calculator', 'Hammer', 'Paintbrush'],
      ),
    ]),
    _Zone.simple('Work Ethics & Values', [
      _SimpleQ(
        prompt: 'Turning up on time and doing your best work shows...?',
        choices: ['Responsibility', 'Laziness', 'Rudeness'],
      ),
      _SimpleQ(
        prompt: 'Working well with others towards a shared goal is called...?',
        choices: ['Teamwork', 'Competition', 'Isolation'],
      ),
      _SimpleQ(
        prompt: 'Why is it important to keep learning new skills in a career?',
        choices: [
          'Jobs and technology keep changing, so skills need to grow too',
          'It is never important',
          'Only scientists need to keep learning',
        ],
      ),
      _SimpleQ(
        prompt: 'If you make a mistake at work, what should you do?',
        choices: ['Take responsibility and learn from it', 'Blame someone else', "Pretend it didn't happen"],
      ),
      _SimpleQ(
        prompt: 'What does having a strong work ethic mean?',
        choices: ['Being reliable, honest and putting in effort', 'Working as little as possible', 'Only working when watched'],
      ),
    ]),
  ];

  static const _wrongReactions = [
    'Not quite -- read the clue again!',
    'Hmm, think about what that job actually does!',
    'Close -- which career really matches that?',
  ];

  static const _bg1 = Color(0xFF0D2438);
  static const _bg2 = Color(0xFF1B4965);
  static const _card = Color(0xFF19405C);
  static const _gold = Color(0xFFF2B705);

  late AnimationController _ambientCtrl;
  late AnimationController _fadeCtrl;
  late AnimationController _flashCtrl;
  late AnimationController _burstCtrl;
  late AnimationController _shakeCtrl;
  late AnimationController _flipCtrl;

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
    _ambientCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 6))
      ..repeat(reverse: true);
    _ambientAnim = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _ambientCtrl, curve: Curves.easeInOut));

    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);

    _flashCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _flashAnim = CurvedAnimation(parent: _flashCtrl, curve: Curves.easeOut);

    _burstCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
    _burstAnim = CurvedAnimation(parent: _burstCtrl, curve: Curves.easeOut);

    _shakeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
    _shakeAnim = CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut);

    _flipCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
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
    _flipCtrl.dispose();
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
    _flipCtrl.value = 0;
    _fadeCtrl.forward(from: 0);
  }

  void _onBadgeAnswer(int index) {
    if (_phase != _Phase.playing) return;
    final isCorrect = index == 0;
    setState(() => _selectedIndex = index);
    if (isCorrect) _flipCtrl.forward(from: 0);
    _applyAnswerResult(isCorrect);
  }

  void _onSimpleAnswer(int index) {
    if (_phase != _Phase.playing) return;
    final isCorrect = index == 0;
    setState(() => _selectedIndex = index);
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
          _flipCtrl.value = 0;
          _fadeCtrl.forward(from: 0);
        });
      }
    } else {
      setState(() {
        _qIdx = next;
        _selectedIndex = null;
        _phase = _Phase.playing;
      });
      _flipCtrl.value = 0;
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
                  CustomPaint(painter: _GridBgPainter(_ambientAnim.value)),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _FairHeader(
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
                      child: zone.kind == _Kind.badge
                          ? _buildBadgeQuestion(zone.badge[_qIdx], revealed)
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
                  painter: _ConfettiShowerPainter(_burstAnim.value),
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

  Widget _buildBadgeQuestion(_BadgeQ q, bool revealed) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0B1C2C),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _gold.withValues(alpha: 0.5), width: 2),
          ),
          child: Text(
            q.clue,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 16),
        _IdBadge(flipCtrl: _flipCtrl, emoji: q.emoji, title: q.choices[0]),
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
                      onTap: () => _onBadgeAnswer(i),
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

  Widget _buildSimpleQuestion(_SimpleQ q, bool revealed) {
    return Column(
      children: [
        const SizedBox(height: 12),
        Text(
          q.prompt,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
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

// ── ID badge (3D flip reveal) ────────────────────────────────────────────────

class _IdBadge extends StatelessWidget {
  final AnimationController flipCtrl;
  final String emoji;
  final String title;
  const _IdBadge({required this.flipCtrl, required this.emoji, required this.title});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: flipCtrl,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(flipCtrl.value);
        final angle = t * math.pi;
        final showBack = angle > math.pi / 2;
        final displayAngle = showBack ? angle - math.pi : angle;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0012)
            ..rotateY(displayAngle),
          child: Container(
            width: 150,
            height: 100,
            decoration: BoxDecoration(
              color: showBack ? _CEState._gold : _CEState._card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _CEState._gold, width: 2),
            ),
            alignment: Alignment.center,
            child: showBack
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 26)),
                      const SizedBox(height: 4),
                      Text(
                        title,
                        style: const TextStyle(color: Color(0xFF0B1C2C), fontSize: 13, fontWeight: FontWeight.w800),
                      ),
                    ],
                  )
                : const Text('💼', style: TextStyle(fontSize: 30)),
          ),
        );
      },
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
    Color fill = _CEState._card;
    if (revealed && isCorrect) fill = const Color(0xFF4CAF7D);
    if (revealed && selected && !isCorrect) fill = const Color(0xFFE05656);

    return GestureDetector(
      onTap: revealed ? null : onTap,
      child: Container(
        constraints: const BoxConstraints(minWidth: 90, maxWidth: 300),
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _CEState._gold.withValues(alpha: 0.8), width: 2),
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

class _GridBgPainter extends CustomPainter {
  final double t;
  const _GridBgPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _CEState._gold.withValues(alpha: 0.04 + 0.03 * t)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    const step = 40.0;
    for (var x = 0.0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridBgPainter oldDelegate) => oldDelegate.t != t;
}

class _ConfettiShowerPainter extends CustomPainter {
  final double t;
  const _ConfettiShowerPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(513);
    for (var i = 0; i < 18; i++) {
      final startX = rng.nextDouble() * size.width;
      final speed = 0.5 + rng.nextDouble() * 0.6;
      final y = (t * speed) * (size.height + 40) - 20;
      final x = startX + math.sin((t * 6) + i) * 12;
      final paint = Paint()
        ..color = _CEState._gold.withValues(alpha: (1 - t).clamp(0.0, 1.0));
      canvas.drawRect(Rect.fromCenter(center: Offset(x, y), width: 6, height: 6), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiShowerPainter oldDelegate) => oldDelegate.t != t;
}

// ── Header / progress ────────────────────────────────────────────────────────

class _FairHeader extends StatelessWidget {
  final String zoneName;
  final int zoneIdx;
  final int totalZones;
  final int completedSteps;
  final int totalSteps;
  const _FairHeader({
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
              const Text('💼', style: TextStyle(fontSize: 22)),
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
          _FairTrail(completed: completedSteps, total: totalSteps),
        ],
      ),
    );
  }
}

class _FairTrail extends StatelessWidget {
  final int completed;
  final int total;
  const _FairTrail({required this.completed, required this.total});

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
                  i < completed ? '💼' : '·',
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
            color: _CEState._card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _CEState._gold, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('💼', style: TextStyle(fontSize: 40)),
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
            colors: [_CEState._bg1, _CEState._bg2],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('💼🎓', style: TextStyle(fontSize: 44)),
                  SizedBox(height: 16),
                  Text(
                    'Career Explorer',
                    style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Discover different careers and the skills they need!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  SizedBox(height: 24),
                  CircularProgressIndicator(color: _CEState._gold),
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
            colors: [_CEState._bg1, _CEState._bg2],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🏆💼', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  const Text('Career Ready!',
                      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  Text('$correctCount / $total correct ($pct%)',
                      style: const TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('+$totalXP XP',
                      style: const TextStyle(color: _CEState._gold, fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: onReplay,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _CEState._card,
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
