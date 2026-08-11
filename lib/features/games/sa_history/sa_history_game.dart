import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/game_session_model.dart';
import '../core/game_config.dart';
import '../core/game_session_persistence.dart';

// ────────────────────────────────────────────────────────────────────────────
// South African History — Grade 4 Social Sciences: the San, Khoikhoi and
// Nguni peoples
//
// NOTE: this is a DIFFERENT engine from adventure_journey/ (engineType
// 'adventureJourney'), which is a shared generic engine still used by 20
// other catalog entries. This engine (engineType 'saHistory') is
// registered ONLY against ss_g4_indigenous.
//
// 4 Zones (5 questions each = 20 total):
//   1. Which People?  — tap San / Khoikhoi / Nguni for a lifestyle clue;
//      the whole backdrop scene crossfades to a themed landscape matching
//      the tapped answer
//   2. The San People       — recall MCQ (rock art, hunting, click language)
//   3. The Khoikhoi People  — recall MCQ (herding, matjieshuise, trade)
//   4. The Nguni People     — recall MCQ (iron age farming, kraals, praise
//      poetry)
//
// Structurally distinct from every prior engine: Zone 1 is the first
// engine where the ENTIRE backdrop scene (not a diagram or character)
// crossfades to a different themed landscape depending on which answer
// you tap, giving instant visual identity to each of the three peoples.
// Architecture: fully self-contained StatefulWidget.
// ────────────────────────────────────────────────────────────────────────────

enum _Phase { intro, playing, correct, wrong, streak, zoneDone, victory }

enum _Kind { people, simple }

enum _Group { san, khoikhoi, nguni }

const _groupLabel = {
  _Group.san: 'San',
  _Group.khoikhoi: 'Khoikhoi',
  _Group.nguni: 'Nguni',
};
const _groupBadgeEmoji = {
  _Group.san: '🏹',
  _Group.khoikhoi: '🐄',
  _Group.nguni: '🏘️',
};
const _groupSceneEmoji = {
  _Group.san: '🏜️🦌',
  _Group.khoikhoi: '🌾🐄',
  _Group.nguni: '🏘️🌽',
};
const _groupSceneColor = {
  _Group.san: Color(0xFF7A5A34),
  _Group.khoikhoi: Color(0xFF4C6B3A),
  _Group.nguni: Color(0xFF6B4A2F),
};

class _PeopleQ {
  final String prompt;
  final _Group correct;
  const _PeopleQ({required this.prompt, required this.correct});
}

class _SimpleQ {
  final String prompt;
  final List<String> choices; // [0] correct
  const _SimpleQ({required this.prompt, required this.choices});
}

class _Zone {
  final String name;
  final _Kind kind;
  final List<_PeopleQ> people;
  final List<_SimpleQ> simple;
  const _Zone.people(this.name, this.people)
      : kind = _Kind.people,
        simple = const [];
  const _Zone.simple(this.name, this.simple)
      : kind = _Kind.simple,
        people = const [];

  int get length => kind == _Kind.people ? people.length : simple.length;
}

class SaHistoryGame extends StatefulWidget {
  final GameConfig config;
  final dynamic user;
  const SaHistoryGame({super.key, required this.config, this.user});

  @override
  State<SaHistoryGame> createState() => _SHState();
}

class _SHState extends State<SaHistoryGame> with TickerProviderStateMixin {
  static const _zones = [
    _Zone.people('Which People?', [
      _PeopleQ(
          prompt:
              'This group were skilled hunter-gatherers who painted detailed scenes on cave walls and rock shelters.',
          correct: _Group.san),
      _PeopleQ(
          prompt:
              'This group herded cattle and sheep, moving to new grazing land, and lived in reed-mat huts called matjieshuise.',
          correct: _Group.khoikhoi),
      _PeopleQ(
          prompt:
              'This group were Iron Age farmers who grew crops, herded cattle, and lived in homesteads called kraals.',
          correct: _Group.nguni),
      _PeopleQ(
          prompt:
              'This group used bows and arrows to hunt and passed down knowledge through storytelling and click languages.',
          correct: _Group.san),
      _PeopleQ(
          prompt:
              'This group used iron tools they made themselves, and passed down history through oral praise poems.',
          correct: _Group.nguni),
    ]),
    _Zone.simple('The San People', [
      _SimpleQ(
          prompt: 'How did the San people mainly get their food?',
          choices: [
            'By hunting animals and gathering wild plants',
            'By farming large fields of crops',
            'By buying food at markets'
          ]),
      _SimpleQ(
          prompt: 'Where are San rock paintings usually found?',
          choices: ['On cave walls and rock shelters', 'On paper scrolls', 'On pottery only']),
      _SimpleQ(
          prompt: 'What weapon did San hunters typically use?',
          choices: ['Bows and poisoned arrows', 'Swords', 'Guns']),
      _SimpleQ(
          prompt: 'San languages are well known for using...?',
          choices: ['Click sounds', 'Only whistling', 'Sign language only']),
      _SimpleQ(
          prompt: 'How did the San pass down their history and knowledge?',
          choices: [
            'Through storytelling and oral tradition',
            'Through written books',
            'Through newspapers'
          ]),
    ]),
    _Zone.simple('The Khoikhoi People', [
      _SimpleQ(
          prompt: 'What animals did the Khoikhoi mainly herd?',
          choices: ['Cattle and sheep', 'Elephants', 'Chickens only']),
      _SimpleQ(
          prompt: 'Why did the Khoikhoi move from place to place?',
          choices: [
            'To find fresh grazing land for their animals',
            'To escape cold weather only',
            'To find gold'
          ]),
      _SimpleQ(
          prompt: 'What were traditional Khoikhoi huts called?',
          choices: ['Matjieshuise (reed mat houses)', 'Skyscrapers', 'Igloos']),
      _SimpleQ(
          prompt: "The word 'Khoikhoi' means...?",
          choices: ['Men of men (or "the real people")', 'People of the sea', 'People of the sky']),
      _SimpleQ(
          prompt: 'The Khoikhoi were known for trading with which other groups?',
          choices: ['The San and later European settlers', 'Only with the Vikings', 'No one at all']),
    ]),
    _Zone.simple('The Nguni People', [
      _SimpleQ(
          prompt: 'What TWO things did Nguni farmers rely on for a living?',
          choices: ['Growing crops and herding cattle', 'Fishing and mining only', 'Trading gold only']),
      _SimpleQ(
          prompt:
              'What is a traditional Nguni homestead, arranged around a central cattle enclosure, called?',
          choices: ['A kraal', 'A castle', 'A pyramid']),
      _SimpleQ(
          prompt: 'What technology did Nguni communities use to make tools and weapons?',
          choices: ['Iron smelting', 'Plastic moulding', 'Stone Age tools only']),
      _SimpleQ(
          prompt: 'How did Nguni communities preserve their history?',
          choices: [
            'Through oral history and praise poetry',
            'Through printed newspapers',
            'They kept no history'
          ]),
      _SimpleQ(
          prompt: 'Which of these is a Nguni group?',
          choices: ['The Zulu', 'The Vikings', 'The Aztecs']),
    ]),
  ];

  static const _wrongReactions = [
    'Not quite -- think about their way of life!',
    'Hmm, try a different group!',
    'Almost -- picture how they lived!',
  ];

  static const _bg1 = Color(0xFF20180F);
  static const _bg2 = Color(0xFF3A2C18);
  static const _card = Color(0xFF4A3A24);
  static const _ochre = Color(0xFFD1893F);

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
  _Group? _pickedGroup;

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
      _pickedGroup = null;
    });
    _fadeCtrl.forward(from: 0);
  }

  void _onPeopleAnswer(_Group group, _PeopleQ q) {
    if (_phase != _Phase.playing) return;
    final isCorrect = group == q.correct;
    setState(() => _pickedGroup = group);
    _applyAnswerResult(isCorrect);
  }

  _SimpleQ? _cachedQ;
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
            _pickedGroup = null;
            _phase = _Phase.playing;
          });
          _fadeCtrl.forward(from: 0);
        });
      }
    } else {
      setState(() {
        _qIdx = next;
        _selectedIndex = null;
        _pickedGroup = null;
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
                  CustomPaint(painter: _EmbersBgPainter(_ambientAnim.value)),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _HistoryHeader(
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
                      child: zone.kind == _Kind.people
                          ? _buildPeopleQuestion(zone.people[_qIdx])
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
                  child: Container(color: _ochre),
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

  Widget _buildPeopleQuestion(_PeopleQ q) {
    final revealed = _phase == _Phase.correct || _phase == _Phase.wrong;

    return Column(
      children: [
        const SizedBox(height: 8),
        Text(
          q.prompt,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 18),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: _pickedGroup == null
              ? Container(
                  key: const ValueKey('empty'),
                  width: double.infinity,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white24),
                  ),
                  alignment: Alignment.center,
                  child: const Text('?', style: TextStyle(color: Colors.white38, fontSize: 32)),
                )
              : Container(
                  key: ValueKey(_pickedGroup),
                  width: double.infinity,
                  height: 120,
                  decoration: BoxDecoration(
                    color: _groupSceneColor[_pickedGroup]!,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: !revealed
                          ? _ochre
                          : (_pickedGroup == q.correct ? const Color(0xFF4CAF7D) : const Color(0xFFE05656)),
                      width: 3,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_groupSceneEmoji[_pickedGroup]!, style: const TextStyle(fontSize: 36)),
                      const SizedBox(height: 6),
                      Text(_groupLabel[_pickedGroup]!,
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
        ),
        if (_phase == _Phase.wrong)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              '$_wrongReaction The answer was ${_groupLabel[q.correct]}.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final g in _Group.values)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _GroupBadge(group: g, onTap: () => _onPeopleAnswer(g, q)),
              ),
          ],
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

// ── Group badge ──────────────────────────────────────────────────────────────

class _GroupBadge extends StatelessWidget {
  final _Group group;
  final VoidCallback onTap;
  const _GroupBadge({required this.group, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 92,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: _SHState._card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _SHState._ochre.withValues(alpha: 0.7), width: 2),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_groupBadgeEmoji[group]!, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 4),
            Text(_groupLabel[group]!,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
          ],
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
    Color fill = _SHState._card;
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
          border: Border.all(color: _SHState._ochre.withValues(alpha: 0.7), width: 2),
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

class _EmbersBgPainter extends CustomPainter {
  final double t;
  const _EmbersBgPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(31);
    for (var i = 0; i < 14; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final flicker = (math.sin(t * math.pi * 2 + i) + 1) / 2;
      final paint = Paint()
        ..color = _SHState._ochre.withValues(alpha: 0.04 + flicker * 0.05);
      canvas.drawCircle(Offset(x, y), 1.6, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _EmbersBgPainter oldDelegate) => oldDelegate.t != t;
}

class _SparkleShowerPainter extends CustomPainter {
  final double t;
  const _SparkleShowerPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(113);
    for (var i = 0; i < 18; i++) {
      final startX = rng.nextDouble() * size.width;
      final speed = 0.5 + rng.nextDouble() * 0.6;
      final y = (t * speed) * (size.height + 40) - 20;
      final x = startX + math.sin((t * 6) + i) * 12;
      final paint = Paint()
        ..color = _SHState._ochre.withValues(alpha: (1 - t).clamp(0.0, 1.0));
      canvas.drawCircle(Offset(x, y), 3, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparkleShowerPainter oldDelegate) => oldDelegate.t != t;
}

// ── Header / progress ────────────────────────────────────────────────────────

class _HistoryHeader extends StatelessWidget {
  final String zoneName;
  final int zoneIdx;
  final int totalZones;
  final int completedSteps;
  final int totalSteps;
  const _HistoryHeader({
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
              const Text('🌿', style: TextStyle(fontSize: 22)),
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
          _HistoryTrail(completed: completedSteps, total: totalSteps),
        ],
      ),
    );
  }
}

class _HistoryTrail extends StatelessWidget {
  final int completed;
  final int total;
  const _HistoryTrail({required this.completed, required this.total});

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
                  i < completed ? '🌿' : '·',
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
            color: _SHState._card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _SHState._ochre, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🌿', style: TextStyle(fontSize: 40)),
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
            colors: [_SHState._bg1, _SHState._bg2],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🌿🏹', style: TextStyle(fontSize: 44)),
                  SizedBox(height: 16),
                  Text(
                    'South African History',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Discover the San, Khoikhoi and Nguni peoples!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  SizedBox(height: 24),
                  CircularProgressIndicator(color: _SHState._ochre),
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
            colors: [_SHState._bg1, _SHState._bg2],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🏆🌿', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  const Text('History Explorer!',
                      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  Text('$correctCount / $total correct ($pct%)',
                      style: const TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('+$totalXP XP',
                      style: const TextStyle(color: _SHState._ochre, fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: onReplay,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _SHState._card,
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
