import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/game_session_model.dart';
import '../core/game_config.dart';
import '../core/game_session_persistence.dart';

// ────────────────────────────────────────────────────────────────────────────
// Democracy Game — Grade 4 Social Sciences: the 1994 elections and the
// birth of South African democracy
//
// NOTE: this is a DIFFERENT engine from adventure_journey/ (engineType
// 'adventureJourney'), which is a shared generic engine still used by 18
// other catalog entries. This engine (engineType 'democracyGame') is
// registered ONLY against ss_g4_democracy.
//
// 4 Zones (5 questions each = 20 total):
//   1. Cast Your Vote      — for every correct answer, a ballot paper
//      animates falling into a ballot box, and a running vote tally
//      increments
//   2. What Is Democracy?   — recall MCQ (voting, rights, non-racial
//      democracy)
//   3. The 1994 Election    — recall MCQ (Mandela, new flag, queues)
//   4. Rights & Freedom Day — recall MCQ (Constitution, 27 April, Rainbow
//      Nation)
//
// Structurally distinct from every prior engine: Zone 1 is the first
// "object falls into a container" reveal, with a persistent numeric tally
// (not a position on a path, a growing structure, or an unlocking slot).
// Architecture: fully self-contained StatefulWidget.
// ────────────────────────────────────────────────────────────────────────────

enum _Phase { intro, playing, correct, wrong, streak, zoneDone, victory }

class _SimpleQ {
  final String prompt;
  final List<String> choices; // [0] correct
  const _SimpleQ({required this.prompt, required this.choices});
}

class _Zone {
  final String name;
  final bool isBallotZone;
  final List<_SimpleQ> questions;
  const _Zone(this.name, this.questions, {this.isBallotZone = false});

  int get length => questions.length;
}

class DemocracyGame extends StatefulWidget {
  final GameConfig config;
  final dynamic user;
  const DemocracyGame({super.key, required this.config, this.user});

  @override
  State<DemocracyGame> createState() => _DGState();
}

class _DGState extends State<DemocracyGame> with TickerProviderStateMixin {
  static const _zones = [
    _Zone('Cast Your Vote', [
      _SimpleQ(
          prompt: 'In a democracy, who gets to choose the government?',
          choices: ['The citizens, through voting', 'Only the king', 'Only rich people']),
      _SimpleQ(
          prompt: 'What do we call the day people go to vote?',
          choices: ['Election Day', 'Independence Day', 'Heritage Day']),
      _SimpleQ(
          prompt: 'Why is it important that voting is kept secret (a secret ballot)?',
          choices: [
            'So people can vote freely without being pressured',
            'So the government can spy on people',
            'So votes can be changed later'
          ]),
      _SimpleQ(
          prompt: 'What must you show to prove who you are before you vote?',
          choices: ['Your ID document', 'A school report', 'Nothing at all']),
      _SimpleQ(
          prompt: 'After all votes are counted, the party or person with the most votes usually...?',
          choices: ['Wins the election', 'Loses the election', 'Has to vote again']),
    ], isBallotZone: true),
    _Zone('What Is Democracy?', [
      _SimpleQ(
          prompt: "What does the word 'democracy' mean?",
          choices: ['Government by the people', 'Rule by one king', 'Rule by the army']),
      _SimpleQ(
          prompt: 'In a democracy, citizens have the right to...?',
          choices: ['Vote and have their voices heard', 'Only obey orders', 'Never disagree with the government']),
      _SimpleQ(
          prompt: 'Before 1994, which groups of South Africans were NOT allowed to vote?',
          choices: ['Black, Coloured and Indian South Africans', 'No one could vote', 'Only children']),
      _SimpleQ(
          prompt: 'A country where everyone, of any race, can vote is described as having...?',
          choices: ['A non-racial democracy', 'A monarchy', 'A dictatorship']),
      _SimpleQ(
          prompt: 'What is one responsibility that comes with living in a democracy?',
          choices: ['Respecting the rights of others', 'Ignoring the law', 'Avoiding all responsibility']),
    ]),
    _Zone('The 1994 Election', [
      _SimpleQ(
          prompt: "In what year did South Africa hold its first democratic election open to all races?",
          choices: ['1994', '1652', '1806']),
      _SimpleQ(
          prompt: "Who was elected as South Africa's first democratic president in 1994?",
          choices: ['Nelson Mandela', 'Jan van Riebeeck', 'Desmond Tutu']),
      _SimpleQ(
          prompt: 'Many South Africans waited for hours in long lines to...?',
          choices: ['Cast their vote for the first time', 'Buy food', 'Watch a parade']),
      _SimpleQ(
          prompt: 'After 1994, South Africa adopted a new...?',
          choices: ['Flag and national anthem', 'Language only', 'Currency only']),
      _SimpleQ(
          prompt: "South Africa is sometimes called the 'Rainbow Nation' because of its...?",
          choices: ['Diversity of cultures, languages and people', 'Colourful buildings', 'Weather patterns']),
    ]),
    _Zone('Rights & Freedom Day', [
      _SimpleQ(
          prompt: "The document that protects every South African's basic rights is called the...?",
          choices: ['Constitution (Bill of Rights)', 'Freedom Charter only', 'Election Manifesto']),
      _SimpleQ(
          prompt: 'On which date is Freedom Day celebrated in South Africa?',
          choices: ['27 April', '16 December', '1 January']),
      _SimpleQ(
          prompt: 'What does Freedom Day celebrate?',
          choices: [
            'The first democratic election in 1994',
            'The Great Trek',
            'The arrival of the Dutch'
          ]),
      _SimpleQ(
          prompt: "Which of these is a right protected in South Africa's Constitution?",
          choices: ['Freedom of speech', 'The right to break the law', 'The right to ignore others']),
      _SimpleQ(
          prompt: 'As a citizen, one way you can take part in democracy when you are old enough is to...?',
          choices: ['Register and vote in elections', 'Avoid all elections', 'Stop others from voting']),
    ]),
  ];

  static const _wrongReactions = [
    'Not quite -- think about how democracy works!',
    'Hmm, try a different answer!',
    'Almost -- picture the election!',
  ];

  static const _bg1 = Color(0xFF122A1E);
  static const _bg2 = Color(0xFF1F4A34);
  static const _card = Color(0xFF2A5A40);
  static const _gold = Color(0xFFE0B84E);

  late AnimationController _ambientCtrl;
  late AnimationController _fadeCtrl;
  late AnimationController _flashCtrl;
  late AnimationController _burstCtrl;
  late AnimationController _shakeCtrl;
  late AnimationController _ballotCtrl;

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
  int _votesCast = 0;
  bool _ballotFalling = false;

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

    _ballotCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
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
    _ballotCtrl.dispose();
    super.dispose();
  }

  void _startGame() {
    setState(() {
      _zoneIdx = 0;
      _qIdx = 0;
      _correctCount = 0;
      _streak = 0;
      _totalXP = 0;
      _votesCast = 0;
      _ballotFalling = false;
      _phase = _Phase.playing;
      _selectedIndex = null;
    });
    _fadeCtrl.forward(from: 0);
  }

  void _onAnswer(int index) {
    if (_phase != _Phase.playing) return;
    final isCorrect = index == 0;
    setState(() => _selectedIndex = index);
    _applyAnswerResult(isCorrect);
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
      if (zone.isBallotZone) {
        setState(() => _ballotFalling = true);
        _ballotCtrl.forward(from: 0);
        _delayed(600, () {
          if (!mounted) return;
          setState(() {
            _ballotFalling = false;
            _votesCast++;
          });
        });
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
                  CustomPaint(painter: _StarBgPainter(_ambientAnim.value)),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _DemocracyHeader(
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
                          if (zone.isBallotZone) ...[
                            const SizedBox(height: 8),
                            _BallotBox(
                              votesCast: _votesCast,
                              totalInZone: zone.length,
                              falling: _ballotFalling,
                              fallAnim: _ballotCtrl,
                            ),
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

// ── Ballot box ────────────────────────────────────────────────────────────────

class _BallotBox extends StatelessWidget {
  final int votesCast;
  final int totalInZone;
  final bool falling;
  final Animation<double> fallAnim;
  const _BallotBox({
    required this.votesCast,
    required this.totalInZone,
    required this.falling,
    required this.fallAnim,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 100,
          width: 120,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              if (falling)
                AnimatedBuilder(
                  animation: fallAnim,
                  builder: (context, _) {
                    final t = Curves.easeIn.transform(fallAnim.value);
                    return Positioned(
                      top: t * 60,
                      child: Opacity(
                        opacity: (1 - t).clamp(0.2, 1.0),
                        child: const Text('📄', style: TextStyle(fontSize: 26)),
                      ),
                    );
                  },
                ),
              Container(
                width: 90,
                height: 60,
                decoration: BoxDecoration(
                  color: _DGState._card,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _DGState._gold, width: 2),
                ),
                alignment: Alignment.center,
                child: const Text('🗳️', style: TextStyle(fontSize: 28)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text('Votes cast: $votesCast / $totalInZone',
            style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700)),
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
    Color fill = _DGState._card;
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
          border: Border.all(color: _DGState._gold.withValues(alpha: 0.7), width: 2),
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

class _StarBgPainter extends CustomPainter {
  final double t;
  const _StarBgPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(23);
    for (var i = 0; i < 14; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final flicker = (math.sin(t * math.pi * 2 + i) + 1) / 2;
      final paint = Paint()
        ..color = _DGState._gold.withValues(alpha: 0.04 + flicker * 0.05);
      canvas.drawCircle(Offset(x, y), 1.5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StarBgPainter oldDelegate) => oldDelegate.t != t;
}

class _SparkleShowerPainter extends CustomPainter {
  final double t;
  const _SparkleShowerPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(149);
    for (var i = 0; i < 18; i++) {
      final startX = rng.nextDouble() * size.width;
      final speed = 0.5 + rng.nextDouble() * 0.6;
      final y = (t * speed) * (size.height + 40) - 20;
      final x = startX + math.sin((t * 6) + i) * 12;
      final paint = Paint()
        ..color = _DGState._gold.withValues(alpha: (1 - t).clamp(0.0, 1.0));
      canvas.drawCircle(Offset(x, y), 3, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparkleShowerPainter oldDelegate) => oldDelegate.t != t;
}

// ── Header / progress ────────────────────────────────────────────────────────

class _DemocracyHeader extends StatelessWidget {
  final String zoneName;
  final int zoneIdx;
  final int totalZones;
  final int completedSteps;
  final int totalSteps;
  const _DemocracyHeader({
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
              const Text('🗳️', style: TextStyle(fontSize: 22)),
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
          _DemocracyTrail(completed: completedSteps, total: totalSteps),
        ],
      ),
    );
  }
}

class _DemocracyTrail extends StatelessWidget {
  final int completed;
  final int total;
  const _DemocracyTrail({required this.completed, required this.total});

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
                  i < completed ? '🗳️' : '·',
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
            color: _DGState._card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _DGState._gold, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🗳️', style: TextStyle(fontSize: 40)),
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
            colors: [_DGState._bg1, _DGState._bg2],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🗳️🇿🇦', style: TextStyle(fontSize: 44)),
                  SizedBox(height: 16),
                  Text(
                    'Democracy Game',
                    style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Relive the 1994 elections and the birth of South '
                    "African democracy!",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  SizedBox(height: 24),
                  CircularProgressIndicator(color: _DGState._gold),
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
            colors: [_DGState._bg1, _DGState._bg2],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🏆🗳️', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  const Text('Active Citizen!',
                      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  Text('$correctCount / $total correct ($pct%)',
                      style: const TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('+$totalXP XP',
                      style: const TextStyle(color: _DGState._gold, fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: onReplay,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _DGState._card,
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
