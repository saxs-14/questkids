import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/game_session_model.dart';
import '../core/game_config.dart';
import '../core/game_session_persistence.dart';

// ────────────────────────────────────────────────────────────────────────────
// Debate Duel — Grade 4 English: choosing an argument, backing it with the
// strongest evidence, persuasive language, and respectful listening/rebuttal
//
// NOTE: this is a DIFFERENT engine from sequence_builder/ (engineType
// 'sequenceBuilder'), which is a shared generic engine still used by 11
// other catalog entries. This engine (engineType 'debateDuel') is
// registered ONLY against eng_g4_debate.
//
// 4 Zones (5 questions each = 20 total):
//   1. Build Your Case  — given a claim, tap the STRONGEST supporting
//      reason (not just any true statement); a debate podium behind the
//      speaker fills with stars and a spotlight glow intensifies with
//      each correct pick
//   2. Debate Basics       — recall MCQ (claim, fact vs opinion, evidence,
//      rebuttal)
//   3. Persuasive Language — recall MCQ (tone, confidence, persuasive
//      phrasing)
//   4. Listening & Rebuttal — recall MCQ (respectful listening, responding
//      to the other side)
//
// Structurally distinct from every prior engine: Zone 1's podium +
// intensifying spotlight-glow meter is a new combination -- unlike Robot
// Maker's milestone avatar assembly, Times Table Tower's single stack, or
// Liberation Heroes' 1:1 hero unlock, here a single growing "case
// strength" meter brightens continuously behind a fixed podium figure.
// Architecture: fully self-contained StatefulWidget.
// ────────────────────────────────────────────────────────────────────────────

enum _Phase { intro, playing, correct, wrong, streak, zoneDone, victory }

enum _Kind { case_, simple }

class _CaseQ {
  final String claim;
  final List<String> choices; // [0] correct (strongest reason)
  const _CaseQ({required this.claim, required this.choices});
}

class _SimpleQ {
  final String prompt;
  final List<String> choices; // [0] correct
  const _SimpleQ({required this.prompt, required this.choices});
}

class _Zone {
  final String name;
  final _Kind kind;
  final List<_CaseQ> caseQs;
  final List<_SimpleQ> simple;
  const _Zone.caseBuilding(this.name, this.caseQs)
      : kind = _Kind.case_,
        simple = const [];
  const _Zone.simple(this.name, this.simple)
      : kind = _Kind.simple,
        caseQs = const [];

  int get length => kind == _Kind.case_ ? caseQs.length : simple.length;
}

class DebateDuelGame extends StatefulWidget {
  final GameConfig config;
  final dynamic user;
  const DebateDuelGame({super.key, required this.config, this.user});

  @override
  State<DebateDuelGame> createState() => _DDState();
}

class _DDState extends State<DebateDuelGame> with TickerProviderStateMixin {
  static const _zones = [
    _Zone.caseBuilding('Build Your Case', [
      _CaseQ(
        claim: 'Schools should have longer lunch breaks.',
        choices: [
          'Students would have more time to eat properly and relax before afternoon classes',
          'Lunch is my favourite meal of the day',
          'The school cafeteria sells pizza',
        ],
      ),
      _CaseQ(
        claim: 'Every classroom should have a class pet.',
        choices: [
          'Caring for a pet teaches students responsibility',
          'Pets are cute',
          'My friend has a dog at home',
        ],
      ),
      _CaseQ(
        claim: 'Homework should be given less often.',
        choices: [
          'Students need more time to rest and spend time with family',
          'Homework is boring',
          "I don't like writing",
        ],
      ),
      _CaseQ(
        claim: 'Recycling bins should be in every classroom.',
        choices: [
          'It would make it easier for students to reduce waste every day',
          'Bins are useful objects',
          'The bins outside are far away',
        ],
      ),
      _CaseQ(
        claim: 'Students should learn how to swim at school.',
        choices: [
          'Swimming is an important safety skill that could save lives',
          'Swimming is fun in summer',
          'The pool looks nice',
        ],
      ),
    ]),
    _Zone.simple('Debate Basics', [
      _SimpleQ(
        prompt: 'In a debate, your main opinion or position is called your...?',
        choices: ['Claim (or argument)', 'Rebuttal', 'Audience'],
      ),
      _SimpleQ(
        prompt: 'A FACT is something that...?',
        choices: ['Can be proven true', "Is just someone's feeling", 'Is always about the future'],
      ),
      _SimpleQ(
        prompt: 'An OPINION is...?',
        choices: [
          'A personal belief or feeling, not necessarily provable',
          'Always 100% true',
          'A type of fact',
        ],
      ),
      _SimpleQ(
        prompt: 'Evidence in a debate should be...?',
        choices: ['Relevant and support your claim', 'Random and unrelated', 'As long as possible'],
      ),
      _SimpleQ(
        prompt: "Responding to the other side's argument is called a...?",
        choices: ['Rebuttal', 'Claim', 'Opinion'],
      ),
    ]),
    _Zone.simple('Persuasive Language', [
      _SimpleQ(
        prompt: 'Persuasive language tries to...?',
        choices: [
          'Convince someone to agree with your point of view',
          'Confuse the listener',
          'List random facts only',
        ],
      ),
      _SimpleQ(
        prompt: 'Which phrase sounds most persuasive?',
        choices: [
          "'This is clearly the best choice because...'",
          "'Um, maybe, I guess...'",
          "'I don't really know.'",
        ],
      ),
      _SimpleQ(
        prompt: 'Speaking with confidence and clear evidence helps you sound...?',
        choices: ['More convincing', 'Less believable', 'Confusing'],
      ),
      _SimpleQ(
        prompt: 'Why is tone of voice important in a debate?',
        choices: [
          'It shows confidence and helps persuade the listener',
          'It has no effect at all',
          'It only matters when shouting',
        ],
      ),
      _SimpleQ(
        prompt: "Using words like 'because' and 'for example' helps you...?",
        choices: ['Explain and support your point clearly', 'Make your speech longer', 'Confuse your opponent'],
      ),
    ]),
    _Zone.simple('Listening & Rebuttal', [
      _SimpleQ(
        prompt: 'Why is it important to listen carefully to the other side in a debate?',
        choices: [
          'So you can understand and respond to their argument',
          'So you can ignore them completely',
          'It is not important',
        ],
      ),
      _SimpleQ(
        prompt: 'If you disagree with someone in a debate, you should...?',
        choices: ['Respectfully explain why, using evidence', 'Interrupt them loudly', 'Refuse to speak'],
      ),
      _SimpleQ(
        prompt: 'A good debater treats their opponent with...?',
        choices: ['Respect, even when disagreeing', 'Rudeness', 'Silence'],
      ),
      _SimpleQ(
        prompt: 'What should you do if the other side makes a good point?',
        choices: [
          'Acknowledge it and explain your view further',
          'Pretend you did not hear it',
          'Change the subject completely',
        ],
      ),
      _SimpleQ(
        prompt: 'The goal of a friendly classroom debate is to...?',
        choices: [
          'Practise sharing and defending ideas respectfully',
          'Prove the other side is wrong by shouting',
          'Win by talking over everyone else',
        ],
      ),
    ]),
  ];

  static const _wrongReactions = [
    'Not quite -- think about which reason is STRONGEST!',
    'Hmm, try to find the most convincing point!',
    'Close -- but is that really the best evidence?',
  ];

  static const _bg1 = Color(0xFF241733);
  static const _bg2 = Color(0xFF4A2049);
  static const _card = Color(0xFF3A2450);
  static const _gold = Color(0xFFE8B94D);

  late AnimationController _ambientCtrl;
  late AnimationController _fadeCtrl;
  late AnimationController _flashCtrl;
  late AnimationController _burstCtrl;
  late AnimationController _shakeCtrl;
  late AnimationController _starCtrl;

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
  int _caseStars = 0;

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

    _starCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
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
    _starCtrl.dispose();
    super.dispose();
  }

  void _startGame() {
    setState(() {
      _zoneIdx = 0;
      _qIdx = 0;
      _correctCount = 0;
      _streak = 0;
      _totalXP = 0;
      _caseStars = 0;
      _phase = _Phase.playing;
      _selectedIndex = null;
    });
    _fadeCtrl.forward(from: 0);
  }

  void _onCaseAnswer(int index) {
    if (_phase != _Phase.playing) return;
    final isCorrect = index == 0;
    setState(() => _selectedIndex = index);
    if (isCorrect) {
      setState(() => _caseStars++);
      _starCtrl.forward(from: 0);
    }
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
                  CustomPaint(painter: _SpotlightBgPainter(_ambientAnim.value)),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _PodiumHeader(
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
                      child: zone.kind == _Kind.case_
                          ? _buildCaseQuestion(zone.caseQs[_qIdx], revealed)
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

  Widget _buildCaseQuestion(_CaseQ q, bool revealed) {
    return Column(
      children: [
        const SizedBox(height: 8),
        _DebatePodium(stars: _caseStars, starCtrl: _starCtrl),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF190F26),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _gold.withValues(alpha: 0.5), width: 2),
          ),
          child: Column(
            children: [
              const Text('CLAIM', style: TextStyle(color: _gold, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
              const SizedBox(height: 6),
              Text(
                q.claim,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Which is the BEST supporting reason?',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 14),
        AnimatedBuilder(
          animation: _shakeAnim,
          builder: (context, _) {
            final dx = _phase == _Phase.wrong
                ? math.sin(_shakeAnim.value * math.pi * 6) * 6
                : 0.0;
            return Transform.translate(
              offset: Offset(dx, 0),
              child: Column(
                children: [
                  for (var i = 0; i < q.choices.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _EvidenceTile(
                        label: q.choices[i],
                        selected: _selectedIndex == i,
                        isCorrect: i == 0,
                        revealed: revealed,
                        onTap: () => _onCaseAnswer(i),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        if (_phase == _Phase.wrong)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '$_wrongReaction The strongest reason was: "${q.choices[0]}"',
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

// ── Debate podium + spotlight meter ─────────────────────────────────────────

class _DebatePodium extends StatelessWidget {
  final int stars;
  final AnimationController starCtrl;
  const _DebatePodium({required this.stars, required this.starCtrl});

  @override
  Widget build(BuildContext context) {
    final glow = (0.15 + stars * 0.15).clamp(0.0, 0.9);
    return AnimatedBuilder(
      animation: starCtrl,
      builder: (context, _) {
        final pop = Curves.easeOutBack.transform(starCtrl.value);
        return SizedBox(
          height: 116,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              // Spotlight glow, intensifies with each star earned
              Positioned(
                bottom: 0,
                child: Container(
                  width: 140,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _DDState._gold.withValues(alpha: glow),
                        _DDState._gold.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
              // Podium
              Positioned(
                bottom: 0,
                child: Container(
                  width: 90,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFF5B3B26),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                    border: Border.all(color: _DDState._gold, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: const Text('🎤', style: TextStyle(fontSize: 26)),
                ),
              ),
              // Star row above podium — fills as evidence is correctly chosen
              Positioned(
                bottom: 50,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < 5; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Transform.scale(
                          scale: (i == stars - 1) ? 0.7 + pop * 0.3 : 1.0,
                          child: Text(
                            i < stars ? '⭐' : '☆',
                            style: TextStyle(
                              fontSize: 18,
                              color: i < stars ? null : Colors.white24,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Evidence tile (case-strength choices, full-width) ───────────────────────

class _EvidenceTile extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isCorrect;
  final bool revealed;
  final VoidCallback onTap;
  const _EvidenceTile({
    required this.label,
    required this.selected,
    required this.isCorrect,
    required this.revealed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color fill = _DDState._card;
    if (revealed && isCorrect) fill = const Color(0xFF4CAF7D);
    if (revealed && selected && !isCorrect) fill = const Color(0xFFE05656);

    return GestureDetector(
      onTap: revealed ? null : onTap,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 56),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _DDState._gold.withValues(alpha: 0.8), width: 2),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
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
    Color fill = _DDState._card;
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
          border: Border.all(color: _DDState._gold.withValues(alpha: 0.8), width: 2),
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

class _SpotlightBgPainter extends CustomPainter {
  final double t;
  const _SpotlightBgPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _DDState._gold.withValues(alpha: 0.05 + 0.04 * t)
      ..style = PaintingStyle.fill;
    for (var i = 0; i < 3; i++) {
      final cx = size.width * (0.2 + i * 0.3);
      final r = size.width * (0.25 + 0.05 * t);
      canvas.drawCircle(Offset(cx, 0), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SpotlightBgPainter oldDelegate) => oldDelegate.t != t;
}

class _ConfettiShowerPainter extends CustomPainter {
  final double t;
  const _ConfettiShowerPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(414);
    for (var i = 0; i < 18; i++) {
      final startX = rng.nextDouble() * size.width;
      final speed = 0.5 + rng.nextDouble() * 0.6;
      final y = (t * speed) * (size.height + 40) - 20;
      final x = startX + math.sin((t * 6) + i) * 12;
      final paint = Paint()
        ..color = _DDState._gold.withValues(alpha: (1 - t).clamp(0.0, 1.0));
      canvas.drawRect(Rect.fromCenter(center: Offset(x, y), width: 6, height: 6), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiShowerPainter oldDelegate) => oldDelegate.t != t;
}

// ── Header / progress ────────────────────────────────────────────────────────

class _PodiumHeader extends StatelessWidget {
  final String zoneName;
  final int zoneIdx;
  final int totalZones;
  final int completedSteps;
  final int totalSteps;
  const _PodiumHeader({
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
              const Text('🎤', style: TextStyle(fontSize: 22)),
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
          _DebateTrail(completed: completedSteps, total: totalSteps),
        ],
      ),
    );
  }
}

class _DebateTrail extends StatelessWidget {
  final int completed;
  final int total;
  const _DebateTrail({required this.completed, required this.total});

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
                  i < completed ? '🎤' : '·',
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
            color: _DDState._card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _DDState._gold, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🎤', style: TextStyle(fontSize: 40)),
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
            colors: [_DDState._bg1, _DDState._bg2],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🎤⚖️', style: TextStyle(fontSize: 44)),
                  SizedBox(height: 16),
                  Text(
                    'Debate Duel',
                    style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Choose your argument, back it with strong evidence, and win the debate!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  SizedBox(height: 24),
                  CircularProgressIndicator(color: _DDState._gold),
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
            colors: [_DDState._bg1, _DDState._bg2],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🏆🎤', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  const Text('Debate Champion!',
                      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  Text('$correctCount / $total correct ($pct%)',
                      style: const TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('+$totalXP XP',
                      style: const TextStyle(color: _DDState._gold, fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: onReplay,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _DDState._card,
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
