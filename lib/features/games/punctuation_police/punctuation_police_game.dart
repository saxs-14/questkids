import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/game_session_model.dart';
import '../core/game_config.dart';
import '../core/game_session_persistence.dart';

// ────────────────────────────────────────────────────────────────────────────
// Punctuation Police — Grade 4 English: capital letters, end punctuation,
// commas and apostrophes
//
// NOTE: this is a DIFFERENT engine from runner_collector/ (engineType
// 'runnerCollector'), which is a shared generic engine still used by 16
// other catalog entries. This engine (engineType 'punctuationPolice') is
// registered ONLY against eng_g4_punctuation.
//
// 4 Zones (5 questions each = 20 total):
//   1. Where Does It Go?    — a sentence renders as words with a few
//      tappable GAP markers between them; tap the gap where the comma
//      belongs and watch it appear in the sentence
//   2. Which Mark Fits?      — recall MCQ (choose the correct end
//      punctuation: . ! ?)
//   3. Capital Letters & Commas — recall MCQ
//   4. Apostrophes            — recall MCQ (possessive vs contraction)
//
// Structurally distinct from every prior engine: Zone 1 is the first
// mechanic where the tap target is a POSITION inside a sentence (a gap
// between two words) rather than a whole word (Spelling Bee), a
// highlighted word (Noun Navigator) or a blank (Verb Volcano) -- tapping
// correctly inserts a punctuation mark exactly where it belongs.
// Architecture: fully self-contained StatefulWidget.
// ────────────────────────────────────────────────────────────────────────────

enum _Phase { intro, playing, correct, wrong, streak, zoneDone, victory }

enum _Kind { gap, simple }

class _GapQ {
  final String instruction;
  final List<String> words;
  final List<int> gapOptions; // word indices; gap renders right after that word
  final int correctOptionIdx; // index into gapOptions
  const _GapQ({
    required this.instruction,
    required this.words,
    required this.gapOptions,
    required this.correctOptionIdx,
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
  final List<_GapQ> gaps;
  final List<_SimpleQ> simple;
  const _Zone.gap(this.name, this.gaps)
      : kind = _Kind.gap,
        simple = const [];
  const _Zone.simple(this.name, this.simple)
      : kind = _Kind.simple,
        gaps = const [];

  int get length => kind == _Kind.gap ? gaps.length : simple.length;
}

class PunctuationPoliceGame extends StatefulWidget {
  final GameConfig config;
  final dynamic user;
  const PunctuationPoliceGame({super.key, required this.config, this.user});

  @override
  State<PunctuationPoliceGame> createState() => _PPState();
}

class _PPState extends State<PunctuationPoliceGame> with TickerProviderStateMixin {
  static const _zones = [
    _Zone.gap('Where Does It Go?', [
      _GapQ(
          instruction: 'Tap where the comma belongs.',
          words: ['Yesterday', 'I', 'went', 'to', 'the', 'shops.'],
          gapOptions: [0, 2, 4],
          correctOptionIdx: 0),
      _GapQ(
          instruction: 'Tap where the comma belongs.',
          words: ['Before', 'we', 'start', "let's", 'warm', 'up.'],
          gapOptions: [1, 2, 4],
          correctOptionIdx: 1),
      _GapQ(
          instruction: 'Tap where the comma belongs.',
          words: ['In', 'the', 'morning', 'the', 'birds', 'sing.'],
          gapOptions: [1, 2, 4],
          correctOptionIdx: 1),
      _GapQ(
          instruction: 'Tap where the comma belongs.',
          words: ['After', 'school', 'we', 'play', 'soccer.'],
          gapOptions: [0, 1, 3],
          correctOptionIdx: 1),
      _GapQ(
          instruction: 'Tap where the comma belongs.',
          words: ['Suddenly', 'the', 'lights', 'went', 'out.'],
          gapOptions: [0, 2, 3],
          correctOptionIdx: 0),
    ]),
    _Zone.simple('Which Mark Fits?', [
      _SimpleQ(prompt: 'Watch out for that car___', choices: ['!', '?', '.']),
      _SimpleQ(prompt: 'What time does the movie start___', choices: ['?', '!', '.']),
      _SimpleQ(prompt: 'The sun rises in the east___', choices: ['.', '!', '?']),
      _SimpleQ(prompt: 'Please close the door___', choices: ['.', '?', '!']),
      _SimpleQ(prompt: 'How exciting our trip is going to be___', choices: ['!', '.', '?']),
    ]),
    _Zone.simple('Capital Letters & Commas', [
      _SimpleQ(
          prompt: 'A sentence should always start with a...?',
          choices: ['Capital letter', 'Small letter', 'Number']),
      _SimpleQ(
          prompt: "Which word in this sentence needs a capital letter: 'we visited durban last year.'?",
          choices: ['durban', 'visited', 'last']),
      _SimpleQ(
          prompt: 'A comma is used to...?',
          choices: ['Separate items in a list or add a pause', 'End every sentence', 'Replace a full stop']),
      _SimpleQ(
          prompt: 'Names of people, places and days of the week always start with a...?',
          choices: ['Capital letter', 'Comma', 'Question mark']),
      _SimpleQ(
          prompt: 'Which sentence uses commas correctly?',
          choices: [
            "'I bought apples, bananas and grapes.'",
            "'I bought apples bananas, and, grapes.'",
            "'I, bought apples bananas and grapes.'"
          ]),
    ]),
    _Zone.simple('Apostrophes', [
      _SimpleQ(
          prompt: "What does an apostrophe + 's' usually show, like in 'Thabo's book'?",
          choices: ['That the book belongs to Thabo', 'That there are many Thabos', 'That the book is old']),
      _SimpleQ(
          prompt: "Which word correctly shows a contraction of 'do not'?",
          choices: ["don't", 'dont', "do'nt"]),
      _SimpleQ(
          prompt: "Which word correctly shows a contraction of 'I am'?",
          choices: ["I'm", 'Im', "Ia'm"]),
      _SimpleQ(
          prompt: 'An apostrophe used to show ownership is called a...?',
          choices: ['Possessive apostrophe', 'Question apostrophe', 'Plural apostrophe']),
      _SimpleQ(
          prompt: 'Which sentence uses an apostrophe correctly?',
          choices: [
            "'The cat's tail is fluffy.'",
            "'The cats tail is fluffy.'",
            "'The cat' s tail is fluffy.'"
          ]),
    ]),
  ];

  static const _wrongReactions = [
    'Not quite -- read the sentence again!',
    'Hmm, try a different spot!',
    'Almost -- listen for the pause!',
  ];

  static const _bg1 = Color(0xFF14202E);
  static const _bg2 = Color(0xFF243A50);
  static const _card = Color(0xFF2E4964);
  static const _siren = Color(0xFFE8544A);
  static const _sirenBlue = Color(0xFF4A8FE8);

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
  int? _pickedGapOptionIdx;

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
      _pickedGapOptionIdx = null;
    });
    _fadeCtrl.forward(from: 0);
  }

  void _onGapAnswer(int optionIdx, _GapQ q) {
    if (_phase != _Phase.playing) return;
    final isCorrect = optionIdx == q.correctOptionIdx;
    setState(() => _pickedGapOptionIdx = optionIdx);
    _applyAnswerResult(isCorrect);
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
            _pickedGapOptionIdx = null;
            _phase = _Phase.playing;
          });
          _fadeCtrl.forward(from: 0);
        });
      }
    } else {
      setState(() {
        _qIdx = next;
        _selectedIndex = null;
        _pickedGapOptionIdx = null;
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
                  CustomPaint(painter: _SirenBgPainter(_ambientAnim.value)),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _PoliceHeader(
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
                      child: zone.kind == _Kind.gap
                          ? _buildGapQuestion(zone.gaps[_qIdx], revealed)
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
                  child: Container(color: _sirenBlue),
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

  Widget _buildGapQuestion(_GapQ q, bool revealed) {
    return Column(
      children: [
        const SizedBox(height: 8),
        const Text('❗', style: TextStyle(fontSize: 32)),
        const SizedBox(height: 8),
        Text(
          q.instruction,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 4,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: _buildWordsWithGaps(q, revealed),
        ),
        if (_phase == _Phase.wrong)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text(
              _wrongReaction,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }

  List<Widget> _buildWordsWithGaps(_GapQ q, bool revealed) {
    final widgets = <Widget>[];
    for (var i = 0; i < q.words.length; i++) {
      widgets.add(Text(q.words[i],
          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)));
      final optionIdx = q.gapOptions.indexOf(i);
      if (optionIdx != -1) {
        widgets.add(_GapMarker(
          optionIdx: optionIdx,
          isCorrectGap: optionIdx == q.correctOptionIdx,
          isPicked: optionIdx == _pickedGapOptionIdx,
          revealed: revealed,
          onTap: () => _onGapAnswer(optionIdx, q),
        ));
      }
    }
    return widgets;
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

// ── Gap marker ────────────────────────────────────────────────────────────────

class _GapMarker extends StatelessWidget {
  final int optionIdx;
  final bool isCorrectGap;
  final bool isPicked;
  final bool revealed;
  final VoidCallback onTap;
  const _GapMarker({
    required this.optionIdx,
    required this.isCorrectGap,
    required this.isPicked,
    required this.revealed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final answered = revealed;
    Color color = _PPState._siren;
    if (answered && isCorrectGap) color = const Color(0xFF4CAF7D);
    if (answered && isPicked && !isCorrectGap) color = const Color(0xFFE05656);

    return GestureDetector(
      onTap: answered ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: answered && isCorrectGap ? 20 : 22,
        height: 30,
        alignment: Alignment.center,
        child: answered && isCorrectGap
            ? Text(',', style: TextStyle(color: color, fontSize: 26, fontWeight: FontWeight.w900))
            : Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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
    Color fill = _PPState._card;
    if (revealed && isCorrect) fill = const Color(0xFF4CAF7D);
    if (revealed && selected && !isCorrect) fill = const Color(0xFFE05656);

    return GestureDetector(
      onTap: revealed ? null : onTap,
      child: Container(
        constraints: const BoxConstraints(minWidth: 90, maxWidth: 280),
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _PPState._sirenBlue.withValues(alpha: 0.8), width: 2),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

// ── Painters ─────────────────────────────────────────────────────────────────

class _SirenBgPainter extends CustomPainter {
  final double t;
  const _SirenBgPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final color = t < 0.5 ? _PPState._siren : _PPState._sirenBlue;
    final paint = Paint()..color = color.withValues(alpha: 0.03 + 0.02 * (t < 0.5 ? t * 2 : (1 - t) * 2));
    const spacing = 30.0;
    for (var y = 0.0; y < size.height; y += spacing) {
      for (var x = 0.0; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), 1.3, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SirenBgPainter oldDelegate) => oldDelegate.t != t;
}

class _SparkleShowerPainter extends CustomPainter {
  final double t;
  const _SparkleShowerPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(223);
    for (var i = 0; i < 18; i++) {
      final startX = rng.nextDouble() * size.width;
      final speed = 0.5 + rng.nextDouble() * 0.6;
      final y = (t * speed) * (size.height + 40) - 20;
      final x = startX + math.sin((t * 6) + i) * 12;
      final paint = Paint()
        ..color = _PPState._sirenBlue.withValues(alpha: (1 - t).clamp(0.0, 1.0));
      canvas.drawCircle(Offset(x, y), 3, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparkleShowerPainter oldDelegate) => oldDelegate.t != t;
}

// ── Header / progress ────────────────────────────────────────────────────────

class _PoliceHeader extends StatelessWidget {
  final String zoneName;
  final int zoneIdx;
  final int totalZones;
  final int completedSteps;
  final int totalSteps;
  const _PoliceHeader({
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
              const Text('❗', style: TextStyle(fontSize: 22)),
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
          _PoliceTrail(completed: completedSteps, total: totalSteps),
        ],
      ),
    );
  }
}

class _PoliceTrail extends StatelessWidget {
  final int completed;
  final int total;
  const _PoliceTrail({required this.completed, required this.total});

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
                  i < completed ? '🚨' : '·',
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
            color: _PPState._card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _PPState._sirenBlue, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🚨', style: TextStyle(fontSize: 40)),
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
            colors: [_PPState._bg1, _PPState._bg2],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('❗🚨', style: TextStyle(fontSize: 44)),
                  SizedBox(height: 16),
                  Text(
                    'Punctuation Police',
                    style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Catch missing punctuation and fix sentences correctly!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  SizedBox(height: 24),
                  CircularProgressIndicator(color: _PPState._sirenBlue),
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
            colors: [_PPState._bg1, _PPState._bg2],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🏆❗', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  const Text('Top Officer!',
                      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  Text('$correctCount / $total correct ($pct%)',
                      style: const TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('+$totalXP XP',
                      style: const TextStyle(color: _PPState._sirenBlue, fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: onReplay,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _PPState._card,
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
