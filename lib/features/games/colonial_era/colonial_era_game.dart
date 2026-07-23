import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/game_session_model.dart';
import '../core/game_config.dart';
import '../core/game_session_persistence.dart';

// ────────────────────────────────────────────────────────────────────────────
// Colonial Era — Grade 4 Social Sciences: the colonization of Southern
// Africa and its impact
//
// NOTE: this is a DIFFERENT engine from sequence_builder/ (engineType
// 'sequenceBuilder'), which is a shared generic engine still used by 14
// other catalog entries. This engine (engineType 'colonialEra') is
// registered ONLY against ss_g4_colonial.
//
// 4 Zones (5 questions each = 20 total):
//   1. Voyage Through Time     — chronology MCQ; a ship sails one segment
//      further along a horizontal timeline track for every correct answer
//   2. The Dutch at the Cape   — recall MCQ (VOC, van Riebeeck, free
//      burghers, slavery)
//   3. British Rule & the Great Trek — recall MCQ (1806, Great Trek,
//      Boer republics)
//   4. Impact of Colonization  — recall MCQ (land loss, conflict, disease,
//      new trade)
//
// Structurally distinct from every prior engine: Zone 1 is the first
// straight CHRONOLOGICAL timeline a character sails along, as opposed to
// Water Cycle's closed loop or Coding Adventure's open grid -- the ship's
// position is a direct visual analogue of "how far through history" the
// learner has progressed.
// Architecture: fully self-contained StatefulWidget.
// ────────────────────────────────────────────────────────────────────────────

enum _Phase { intro, playing, correct, wrong, streak, zoneDone, victory }

enum _Kind { voyage, simple }

class _SimpleQ {
  final String prompt;
  final List<String> choices; // [0] correct
  const _SimpleQ({required this.prompt, required this.choices});
}

class _Zone {
  final String name;
  final _Kind kind;
  final List<_SimpleQ> questions;
  const _Zone.voyage(this.name, this.questions) : kind = _Kind.voyage;
  const _Zone.simple(this.name, this.questions) : kind = _Kind.simple;

  int get length => questions.length;
}

class ColonialEraGame extends StatefulWidget {
  final GameConfig config;
  final dynamic user;
  const ColonialEraGame({super.key, required this.config, this.user});

  @override
  State<ColonialEraGame> createState() => _CEState();
}

class _CEState extends State<ColonialEraGame> with TickerProviderStateMixin {
  static const _zones = [
    _Zone.voyage('Voyage Through Time', [
      _SimpleQ(
          prompt: 'Which event happened FIRST?',
          choices: [
            'Jan van Riebeeck arrives at the Cape (1652)',
            'The British take over the Cape (1806)',
            'The Great Trek begins (1830s)'
          ]),
      _SimpleQ(
          prompt: 'Which event happened LAST?',
          choices: [
            'The Great Trek begins (1830s)',
            'Jan van Riebeeck arrives at the Cape (1652)',
            'The British first occupy the Cape (1795)'
          ]),
      _SimpleQ(
          prompt: 'What happened just before the Dutch East India Company set up a refreshment station?',
          choices: [
            'Ships needed a stop for fresh food and water on the route to Asia',
            'The Great Trek had already started',
            'South Africa had cars and trains'
          ]),
      _SimpleQ(
          prompt: 'Why did the British take control of the Cape in 1806?',
          choices: [
            'To protect the sea route to their colony in India',
            'Because the Dutch invited them',
            'To find gold'
          ]),
      _SimpleQ(
          prompt: 'Why did some Dutch farmers (Boers) leave the Cape Colony in the Great Trek?',
          choices: [
            'To escape British rule and find new land to farm',
            'To go on holiday',
            'To meet the San people'
          ]),
    ]),
    _Zone.simple('The Dutch at the Cape', [
      _SimpleQ(
          prompt: "Who led the Dutch East India Company's arrival at the Cape in 1652?",
          choices: ['Jan van Riebeeck', 'Cecil John Rhodes', 'Bartholomew Dias']),
      _SimpleQ(
          prompt: 'Why did the Dutch East India Company (VOC) first set up a station at the Cape?',
          choices: [
            'To supply passing ships with fresh food and water',
            'To build a new capital city',
            'To search for gold'
          ]),
      _SimpleQ(
          prompt: 'What were Dutch farmers who settled at the Cape and grew their own crops called?',
          choices: ['Free burghers', 'Pharaohs', 'Vikings']),
      _SimpleQ(
          prompt: 'The VOC brought enslaved people to the Cape from other parts of...?',
          choices: ['Africa and Asia', 'Europe only', 'South America']),
      _SimpleQ(
          prompt: 'As Dutch settlers expanded their farms, what happened to the land of the Khoikhoi?',
          choices: ['They lost much of their grazing land', 'It was given back to them', 'It stayed exactly the same']),
    ]),
    _Zone.simple('British Rule & the Great Trek', [
      _SimpleQ(
          prompt: 'In what year did the British permanently take control of the Cape?',
          choices: ['1806', '1652', '1994']),
      _SimpleQ(
          prompt: 'What language did the British want to make the official language at the Cape?',
          choices: ['English', 'Zulu', 'Portuguese']),
      _SimpleQ(
          prompt: 'What is the name given to the journey of Boer families moving inland away from British rule?',
          choices: ['The Great Trek', 'The Long March', 'The Gold Rush']),
      _SimpleQ(
          prompt: 'What form of transport did the Voortrekkers mainly use on the Great Trek?',
          choices: ['Ox wagons', 'Cars', 'Trains']),
      _SimpleQ(
          prompt: 'After the Great Trek, Boer settlers formed new independent territories, later called...?',
          choices: ['Boer republics', 'Provinces', 'Colonies of Portugal']),
    ]),
    _Zone.simple('Impact of Colonization', [
      _SimpleQ(
          prompt: 'What was one major impact of colonization on indigenous peoples in Southern Africa?',
          choices: ['Loss of land and grazing areas', 'They gained more land', 'Nothing changed']),
      _SimpleQ(
          prompt: 'As colonists expanded their farms and land, this often led to...?',
          choices: ['Conflict and frontier wars', 'Instant peace', 'No contact at all']),
      _SimpleQ(
          prompt: 'What new items did colonists introduce that changed how conflicts were fought?',
          choices: ['Guns and horses', 'Bows and arrows', 'Spears only']),
      _SimpleQ(
          prompt: 'European settlement also introduced new diseases that...?',
          choices: [
            'Made many indigenous people sick, since they had no immunity',
            'Had no effect on anyone',
            'Only affected the settlers'
          ]),
      _SimpleQ(
          prompt: 'Despite the conflict, colonization also led to...?',
          choices: ['New trade, towns and farming methods', 'No change to daily life', 'Less farming than before']),
    ]),
  ];

  static const _wrongReactions = [
    'Not quite -- think about the order of events!',
    'Hmm, try a different answer!',
    'Almost -- picture the timeline!',
  ];

  static const _bg1 = Color(0xFF1A2530);
  static const _bg2 = Color(0xFF2E4356);
  static const _card = Color(0xFF3B5670);
  static const _brass = Color(0xFFC9A05C);

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
  int _voyageProgress = 0; // 0..5, how far the ship has sailed

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
      _voyageProgress = 0;
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
      if (isCorrect && _zones[_zoneIdx].kind == _Kind.voyage) {
        _voyageProgress = math.min(_voyageProgress + 1, 5);
      }
    });
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
                  CustomPaint(painter: _WaveBgPainter(_ambientAnim.value)),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _ColonialHeader(
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
                          if (zone.kind == _Kind.voyage) ...[
                            const SizedBox(height: 8),
                            _VoyageTrack(progress: _voyageProgress),
                            const SizedBox(height: 8),
                          ],
                          _buildQuestion(q, revealed),
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
                  child: Container(color: _brass),
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

  Widget _buildQuestion(_SimpleQ q, bool revealed) {
    return Column(
      children: [
        const SizedBox(height: 8),
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
                      onTap: () => _onAnswer(i),
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

// ── Voyage timeline track ────────────────────────────────────────────────────

class _VoyageTrack extends StatelessWidget {
  final int progress; // 0..5
  const _VoyageTrack({required this.progress});

  @override
  Widget build(BuildContext context) {
    const trackWidth = 280.0;
    final t = progress / 5;
    return SizedBox(
      width: trackWidth,
      height: 56,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          Container(
            height: 4,
            width: trackWidth,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i <= 5; i++)
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i <= progress ? _CEState._brass : Colors.white24,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
            left: t * (trackWidth - 28),
            top: -6,
            child: const Text('⛵', style: TextStyle(fontSize: 28)),
          ),
        ],
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
    Color fill = _CEState._card;
    if (revealed && isCorrect) fill = const Color(0xFF4CAF7D);
    if (revealed && selected && !isCorrect) fill = const Color(0xFFE05656);

    return GestureDetector(
      onTap: revealed ? null : onTap,
      child: Container(
        constraints: const BoxConstraints(minWidth: 110, maxWidth: 300),
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _CEState._brass.withValues(alpha: 0.7), width: 2),
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

class _WaveBgPainter extends CustomPainter {
  final double t;
  const _WaveBgPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _CEState._brass.withValues(alpha: 0.05 + 0.03 * t)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (var i = 0; i < 4; i++) {
      final y = size.height * (0.15 + i * 0.25);
      final path = Path()..moveTo(0, y);
      for (var x = 0.0; x <= size.width; x += 20) {
        path.quadraticBezierTo(x + 10, y + (t * 6 - 3), x + 20, y);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveBgPainter oldDelegate) => oldDelegate.t != t;
}

class _SparkleShowerPainter extends CustomPainter {
  final double t;
  const _SparkleShowerPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(131);
    for (var i = 0; i < 18; i++) {
      final startX = rng.nextDouble() * size.width;
      final speed = 0.5 + rng.nextDouble() * 0.6;
      final y = (t * speed) * (size.height + 40) - 20;
      final x = startX + math.sin((t * 6) + i) * 12;
      final paint = Paint()
        ..color = _CEState._brass.withValues(alpha: (1 - t).clamp(0.0, 1.0));
      canvas.drawCircle(Offset(x, y), 3, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparkleShowerPainter oldDelegate) => oldDelegate.t != t;
}

// ── Header / progress ────────────────────────────────────────────────────────

class _ColonialHeader extends StatelessWidget {
  final String zoneName;
  final int zoneIdx;
  final int totalZones;
  final int completedSteps;
  final int totalSteps;
  const _ColonialHeader({
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
              const Text('⛵', style: TextStyle(fontSize: 22)),
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
          _ColonialTrail(completed: completedSteps, total: totalSteps),
        ],
      ),
    );
  }
}

class _ColonialTrail extends StatelessWidget {
  final int completed;
  final int total;
  const _ColonialTrail({required this.completed, required this.total});

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
                  i < completed ? '🕰️' : '·',
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
            border: Border.all(color: _CEState._brass, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('⛵', style: TextStyle(fontSize: 40)),
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
                  Text('⛵🕰️', style: TextStyle(fontSize: 44)),
                  SizedBox(height: 16),
                  Text(
                    'Colonial Era',
                    style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Sail through history and understand the impact of '
                    'colonization on Southern Africa!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  SizedBox(height: 24),
                  CircularProgressIndicator(color: _CEState._brass),
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
                  const Text('🏆⛵', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  const Text('History Navigator!',
                      style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  Text('$correctCount / $total correct ($pct%)',
                      style: const TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('+$totalXP XP',
                      style: const TextStyle(color: _CEState._brass, fontSize: 18, fontWeight: FontWeight.w700)),
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
