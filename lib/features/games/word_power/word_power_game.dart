import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/game_session_model.dart';
import '../core/game_config.dart';
import '../core/game_session_persistence.dart';

// ────────────────────────────────────────────────────────────────────────────
// Word Power — Grade 4 English: synonyms, antonyms and context clues
//
// NOTE: this is a DIFFERENT engine from multiples_merge/ (engineType
// 'multiplesMerge'), which is a shared generic engine still used by 7
// other catalog entries. This engine (engineType 'wordPower') is
// registered ONLY against eng_g4_vocabulary.
//
// 4 Zones (5 questions each = 20 total):
//   1. Synonym Match  — tap the word that means the same as the target
//      word; a connecting thread animates drawing between the two word
//      bubbles
//   2. Antonym Match  — same word-web mechanic, opposite-meaning pairs
//   3. Context Clues   — recall MCQ (infer meaning from a sentence)
//   4. Vocabulary in Action — recall MCQ (synonym/antonym/dictionary
//      skills)
//
// Structurally distinct from every prior engine: Zones 1 & 2 are the
// first "word web" -- a line visibly animates growing between two word
// bubbles once connected, rather than a diagram lighting up, a character
// moving, or a slot being filled.
// Architecture: fully self-contained StatefulWidget.
// ────────────────────────────────────────────────────────────────────────────

enum _Phase { intro, playing, correct, wrong, streak, zoneDone, victory }

enum _Kind { web, simple }

class _WebQ {
  final String target;
  final List<String> choices; // [0] correct
  const _WebQ({required this.target, required this.choices});
}

class _SimpleQ {
  final String prompt;
  final List<String> choices; // [0] correct
  const _SimpleQ({required this.prompt, required this.choices});
}

class _Zone {
  final String name;
  final _Kind kind;
  final List<_WebQ> web;
  final List<_SimpleQ> simple;
  const _Zone.web(this.name, this.web)
      : kind = _Kind.web,
        simple = const [];
  const _Zone.simple(this.name, this.simple)
      : kind = _Kind.simple,
        web = const [];

  int get length => kind == _Kind.web ? web.length : simple.length;
}

class WordPowerGame extends StatefulWidget {
  final GameConfig config;
  final dynamic user;
  const WordPowerGame({super.key, required this.config, this.user});

  @override
  State<WordPowerGame> createState() => _WPState();
}

class _WPState extends State<WordPowerGame> with TickerProviderStateMixin {
  static const _zones = [
    _Zone.web('Synonym Match', [
      _WebQ(target: 'happy', choices: ['joyful', 'angry', 'tired']),
      _WebQ(target: 'big', choices: ['huge', 'tiny', 'quiet']),
      _WebQ(target: 'fast', choices: ['quick', 'slow', 'loud']),
      _WebQ(target: 'smart', choices: ['clever', 'lazy', 'sad']),
      _WebQ(target: 'brave', choices: ['courageous', 'fearful', 'weak']),
    ]),
    _Zone.web('Antonym Match', [
      _WebQ(target: 'hot', choices: ['cold', 'warm', 'mild']),
      _WebQ(target: 'day', choices: ['night', 'sun', 'morning']),
      _WebQ(target: 'full', choices: ['empty', 'heavy', 'wide']),
      _WebQ(target: 'begin', choices: ['end', 'start', 'open']),
      _WebQ(target: 'wide', choices: ['narrow', 'tall', 'deep']),
    ]),
    _Zone.simple('Context Clues', [
      _SimpleQ(
          prompt: 'The ravenous lion had not eaten in three days. RAVENOUS means...?',
          choices: ['Extremely hungry', 'Very sleepy', 'Extremely happy']),
      _SimpleQ(
          prompt:
              'The ancient castle was decrepit, with crumbling walls and broken windows. DECREPIT means...?',
          choices: ['Old and falling apart', 'Bright and colourful', 'Brand new']),
      _SimpleQ(
          prompt: 'She felt elated when she won first prize. ELATED means...?',
          choices: ['Extremely happy', 'Very tired', 'Slightly annoyed']),
      _SimpleQ(
          prompt: 'The thick fog made it hard to see, so the driver moved cautiously. CAUTIOUSLY means...?',
          choices: ['Carefully', 'Quickly', 'Loudly']),
      _SimpleQ(
          prompt: 'The stubborn mule refused to move, no matter how hard they pulled. STUBBORN means...?',
          choices: ['Refusing to change your mind', 'Very friendly', 'Extremely fast']),
    ]),
    _Zone.simple('Vocabulary in Action', [
      _SimpleQ(
          prompt: 'A SYNONYM is a word that...?',
          choices: [
            'Means almost the same as another word',
            'Means the opposite of another word',
            'Sounds the same as another word'
          ]),
      _SimpleQ(
          prompt: 'An ANTONYM is a word that...?',
          choices: [
            'Means the opposite of another word',
            'Means almost the same as another word',
            'Rhymes with another word'
          ]),
      _SimpleQ(
          prompt: 'What are CONTEXT CLUES?',
          choices: [
            'Hints in the surrounding words that help you understand a new word',
            'A list of every word in a book',
            'A type of punctuation mark'
          ]),
      _SimpleQ(
          prompt: 'Where can you look up the meaning of an unfamiliar word?',
          choices: ['A dictionary', 'A calendar', 'A map']),
      _SimpleQ(
          prompt: 'Why is it useful to learn new vocabulary?',
          choices: [
            'It helps you understand and express ideas more clearly',
            'It makes books heavier',
            'It has no real use'
          ]),
    ]),
  ];

  static const _wrongReactions = [
    'Not quite -- think about the meaning!',
    'Hmm, try a different word!',
    'Almost -- picture what it means!',
  ];

  static const _bg1 = Color(0xFF1B1530);
  static const _bg2 = Color(0xFF322150);
  static const _card = Color(0xFF433566);
  static const _violet = Color(0xFFB89EF2);

  late AnimationController _ambientCtrl;
  late AnimationController _fadeCtrl;
  late AnimationController _flashCtrl;
  late AnimationController _burstCtrl;
  late AnimationController _shakeCtrl;
  late AnimationController _threadCtrl;

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
  int? _pickedWebIdx;

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

    _threadCtrl = AnimationController(
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
    _threadCtrl.dispose();
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
      _pickedWebIdx = null;
    });
    _fadeCtrl.forward(from: 0);
  }

  void _onWebAnswer(int index) {
    if (_phase != _Phase.playing) return;
    final isCorrect = index == 0;
    setState(() => _pickedWebIdx = index);
    _threadCtrl.forward(from: 0);
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
            _pickedWebIdx = null;
            _phase = _Phase.playing;
          });
          _fadeCtrl.forward(from: 0);
        });
      }
    } else {
      setState(() {
        _qIdx = next;
        _selectedIndex = null;
        _pickedWebIdx = null;
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
                  CustomPaint(painter: _DotBgPainter(_ambientAnim.value)),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _WordPowerHeader(
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
                      child: zone.kind == _Kind.web
                          ? _buildWebQuestion(zone.web[_qIdx], zone.name, revealed)
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
                  child: Container(color: _violet),
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

  Widget _buildWebQuestion(_WebQ q, String zoneName, bool revealed) {
    const boxWidth = 300.0;
    const boxHeight = 220.0;
    final isSynonymZone = zoneName == 'Synonym Match';

    const targetPos = Offset(0.5, 0.18);
    const choicePositions = [Offset(0.15, 0.82), Offset(0.5, 0.82), Offset(0.85, 0.82)];

    return Column(
      children: [
        const SizedBox(height: 8),
        Text(
          isSynonymZone
              ? 'Which word means the SAME as the target word?'
              : 'Which word means the OPPOSITE of the target word?',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: boxWidth,
          height: boxHeight,
          child: Stack(
            children: [
              if (_pickedWebIdx != null)
                AnimatedBuilder(
                  animation: _threadCtrl,
                  builder: (context, _) => CustomPaint(
                    size: const Size(boxWidth, boxHeight),
                    painter: _ThreadPainter(
                      from: targetPos,
                      to: choicePositions[_pickedWebIdx!],
                      progress: Curves.easeOut.transform(_threadCtrl.value),
                      color: !revealed
                          ? _violet
                          : (_pickedWebIdx == 0 ? const Color(0xFF4CAF7D) : const Color(0xFFE05656)),
                    ),
                  ),
                ),
              Positioned(
                left: targetPos.dx * boxWidth - 55,
                top: targetPos.dy * boxHeight - 24,
                child: _WordBubble(text: q.target, isTarget: true, fill: _card, border: _violet),
              ),
              for (var i = 0; i < q.choices.length; i++)
                Positioned(
                  left: choicePositions[i].dx * boxWidth - 55,
                  top: choicePositions[i].dy * boxHeight - 24,
                  child: GestureDetector(
                    onTap: () => _onWebAnswer(i),
                    child: _WordBubble(
                      text: q.choices[i],
                      isTarget: false,
                      fill: _bubbleFill(i, revealed),
                      border: _violet,
                    ),
                  ),
                ),
            ],
          ),
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

  Color _bubbleFill(int i, bool revealed) {
    if (!revealed) return _card;
    if (i == 0) return const Color(0xFF4CAF7D);
    if (_pickedWebIdx == i) return const Color(0xFFE05656);
    return _card;
  }

  Widget _buildSimpleQuestion(_SimpleQ q, bool revealed) {
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

// ── Word bubble ───────────────────────────────────────────────────────────────

class _WordBubble extends StatelessWidget {
  final String text;
  final bool isTarget;
  final Color fill;
  final Color border;
  const _WordBubble({required this.text, required this.isTarget, required this.fill, required this.border});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      height: 48,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isTarget ? Colors.white : border, width: isTarget ? 2.5 : 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: isTarget ? FontWeight.w800 : FontWeight.w700,
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
    Color fill = _WPState._card;
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
          border: Border.all(color: _WPState._violet.withValues(alpha: 0.8), width: 2),
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

class _ThreadPainter extends CustomPainter {
  final Offset from;
  final Offset to;
  final double progress;
  final Color color;
  const _ThreadPainter({required this.from, required this.to, required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final start = Offset(from.dx * size.width, from.dy * size.height);
    final end = Offset(to.dx * size.width, to.dy * size.height);
    final current = Offset.lerp(start, end, progress)!;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(start, current, paint);
  }

  @override
  bool shouldRepaint(covariant _ThreadPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.to != to || oldDelegate.color != color;
}

class _DotBgPainter extends CustomPainter {
  final double t;
  const _DotBgPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = _WPState._violet.withValues(alpha: 0.04 + 0.03 * t);
    const spacing = 30.0;
    for (var y = 0.0; y < size.height; y += spacing) {
      for (var x = 0.0; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), 1.3, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotBgPainter oldDelegate) => oldDelegate.t != t;
}

class _SparkleShowerPainter extends CustomPainter {
  final double t;
  const _SparkleShowerPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(191);
    for (var i = 0; i < 18; i++) {
      final startX = rng.nextDouble() * size.width;
      final speed = 0.5 + rng.nextDouble() * 0.6;
      final y = (t * speed) * (size.height + 40) - 20;
      final x = startX + math.sin((t * 6) + i) * 12;
      final paint = Paint()
        ..color = _WPState._violet.withValues(alpha: (1 - t).clamp(0.0, 1.0));
      canvas.drawCircle(Offset(x, y), 3, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparkleShowerPainter oldDelegate) => oldDelegate.t != t;
}

// ── Header / progress ────────────────────────────────────────────────────────

class _WordPowerHeader extends StatelessWidget {
  final String zoneName;
  final int zoneIdx;
  final int totalZones;
  final int completedSteps;
  final int totalSteps;
  const _WordPowerHeader({
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
              const Text('💬', style: TextStyle(fontSize: 22)),
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
          _WordPowerTrail(completed: completedSteps, total: totalSteps),
        ],
      ),
    );
  }
}

class _WordPowerTrail extends StatelessWidget {
  final int completed;
  final int total;
  const _WordPowerTrail({required this.completed, required this.total});

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
                  i < completed ? '💬' : '·',
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
            color: _WPState._card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _WPState._violet, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('💬', style: TextStyle(fontSize: 40)),
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
            colors: [_WPState._bg1, _WPState._bg2],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('💬🕸️', style: TextStyle(fontSize: 44)),
                  SizedBox(height: 16),
                  Text(
                    'Word Power',
                    style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Build your vocabulary with synonyms, antonyms and '
                    'context clues!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  SizedBox(height: 24),
                  CircularProgressIndicator(color: _WPState._violet),
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
            colors: [_WPState._bg1, _WPState._bg2],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🏆💬', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  const Text('Word Wizard!',
                      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  Text('$correctCount / $total correct ($pct%)',
                      style: const TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('+$totalXP XP',
                      style: const TextStyle(color: _WPState._violet, fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: onReplay,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _WPState._card,
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
