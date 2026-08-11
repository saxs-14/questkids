import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/game_session_model.dart';
import '../core/game_config.dart';
import '../core/game_session_persistence.dart';

// ────────────────────────────────────────────────────────────────────────────
// Reading Quest — Grade 4 English: reading comprehension
//
// NOTE: this is a DIFFERENT engine from adventure_journey/ (engineType
// 'adventureJourney'), which is a shared generic engine still used by 17
// other catalog entries. This engine (engineType 'readingQuest') is
// registered ONLY against eng_g4_reading.
//
// 4 Zones (5 questions each = 20 total): each zone is ONE short passage
// (a story or an informational text) shown persistently in a storybook
// page card, followed by 5 comprehension questions that all refer back
// to that same passage.
//
// Structurally distinct from every prior engine: this is the first game
// where correctness depends on reading and referring back to a shared
// block of prose that stays on screen, rather than answering from
// general knowledge -- genuinely testing reading comprehension, the
// actual CAPS skill this topic targets.
// Architecture: fully self-contained StatefulWidget.
// ────────────────────────────────────────────────────────────────────────────

enum _Phase { intro, playing, correct, wrong, streak, zoneDone, victory }

class _CompQ {
  final String prompt;
  final List<String> choices; // [0] correct
  const _CompQ({required this.prompt, required this.choices});
}

class _Zone {
  final String name;
  final String passageTitle;
  final String passageText;
  final List<_CompQ> questions;
  const _Zone({
    required this.name,
    required this.passageTitle,
    required this.passageText,
    required this.questions,
  });

  int get length => questions.length;
}

class ReadingQuestGame extends StatefulWidget {
  final GameConfig config;
  final dynamic user;
  const ReadingQuestGame({super.key, required this.config, this.user});

  @override
  State<ReadingQuestGame> createState() => _RQState();
}

class _RQState extends State<ReadingQuestGame> with TickerProviderStateMixin {
  static const _zones = [
    _Zone(
      name: 'The Lost Kite',
      passageTitle: 'The Lost Kite',
      passageText:
          'Thabo loved flying his red kite at the park near his home in Soweto. '
          'One windy Saturday, a strong gust pulled the kite from his hands. It '
          'sailed higher and higher until it got tangled in a tall jacaranda '
          'tree. Thabo felt sad and did not know what to do. His friend Lindiwe '
          'saw him standing under the tree and offered to help. She climbed '
          'carefully, branch by branch, until she reached the kite. Slowly, she '
          'untangled the string and passed the kite back down to Thabo. He was '
          'so happy that he shared his sandwich with Lindiwe to say thank you.',
      questions: [
        _CompQ(prompt: "What colour was Thabo's kite?", choices: ['Red', 'Blue', 'Yellow']),
        _CompQ(
            prompt: 'Where was Thabo flying his kite?',
            choices: ['At the park near his home', 'At school', 'At the beach']),
        _CompQ(
            prompt: 'What got the kite stuck?',
            choices: ['It got tangled in a jacaranda tree', 'It fell in a river', 'A dog caught it']),
        _CompQ(
            prompt: "Who helped Thabo get his kite back?",
            choices: ['Lindiwe', 'His mother', 'A stranger']),
        _CompQ(
            prompt: 'How did Thabo thank Lindiwe?',
            choices: ['He shared his sandwich with her', 'He gave her money', 'He gave her the kite']),
      ],
    ),
    _Zone(
      name: 'The Best Soccer Match',
      passageTitle: 'The Best Soccer Match',
      passageText:
          'Every Saturday, Sipho and his friends played soccer on the dusty '
          "field behind the school. One day, their ball rolled into Mrs. "
          "Naidoo's garden, right next to her prize-winning roses. Sipho was "
          'scared she would be angry, so he knocked on her door to explain and '
          'apologise. Mrs. Naidoo smiled and said accidents happen. She even '
          'brought out cold water for all the tired players. From that day, '
          'Mrs. Naidoo often watched their matches from her porch, cheering '
          'loudly whenever someone scored a goal.',
      questions: [
        _CompQ(
            prompt: 'Where did the friends play soccer?',
            choices: ['On the dusty field behind the school', 'In the street', 'At the beach']),
        _CompQ(
            prompt: "Whose garden did the ball roll into?",
            choices: ["Mrs. Naidoo's garden", 'The school garden', "Sipho's garden"]),
        _CompQ(
            prompt: 'Why was Sipho scared?',
            choices: [
              'He thought Mrs. Naidoo would be angry',
              'He thought he would get hurt',
              'He thought he would lose the ball forever'
            ]),
        _CompQ(
            prompt: 'What did Mrs. Naidoo do instead of getting angry?',
            choices: [
              'She smiled and said accidents happen',
              'She shouted at Sipho',
              'She called his parents'
            ]),
        _CompQ(
            prompt: 'What did Mrs. Naidoo start doing after that day?',
            choices: [
              'Watching and cheering at their matches',
              'Growing more roses',
              'Selling water to the players'
            ]),
      ],
    ),
    _Zone(
      name: 'How Bees Make Honey',
      passageTitle: 'How Bees Make Honey',
      passageText:
          'Bees are amazing insects that work together to make honey. Worker '
          'bees fly from flower to flower, collecting sweet liquid called '
          'nectar. They store the nectar in a special stomach and carry it '
          'back to the hive. Inside the hive, the bees pass the nectar to each '
          'other until it thickens. Then they store it in six-sided wax cells '
          'called honeycombs and fan it with their wings to remove extra '
          'water. Once the honey is ready, the bees seal the cell with wax to '
          'keep it fresh. A single beehive can produce many jars of honey in '
          'one year.',
      questions: [
        _CompQ(
            prompt: 'What do worker bees collect from flowers?',
            choices: ['Nectar', 'Pollen dust', 'Water only']),
        _CompQ(
            prompt: 'Where do bees store honey inside the hive?',
            choices: ['In honeycombs', 'In flower petals', 'In their wings']),
        _CompQ(
            prompt: 'Why do bees fan the nectar with their wings?',
            choices: [
              'To remove extra water and thicken it',
              'To cool down the hive',
              'To scare away other insects'
            ]),
        _CompQ(
            prompt: 'What shape are the wax cells in a honeycomb?',
            choices: ['Six-sided', 'Round', 'Square']),
        _CompQ(
            prompt: 'What do bees do once the honey is ready?',
            choices: ['Seal the cell with wax', 'Eat it all immediately', 'Throw it away']),
      ],
    ),
    _Zone(
      name: 'Recycling',
      passageTitle: 'Recycling: Giving Rubbish a New Life',
      passageText:
          'Every day, people throw away paper, plastic, glass and cans. '
          'Instead of going to a rubbish dump, many of these items can be '
          'recycled. Recycling means turning old materials into new products '
          'instead of throwing them away. Paper can be turned into new paper '
          'or cardboard. Plastic bottles can be melted down and shaped into '
          'new bottles or even clothing. Glass jars can be crushed and melted '
          'to make new glass items. Recycling helps to save natural '
          'resources, reduces pollution, and keeps rubbish dumps from filling '
          'up too quickly. Many schools now have separate bins for paper, '
          'plastic and glass to make recycling easier.',
      questions: [
        _CompQ(
            prompt: 'What does recycling mean?',
            choices: [
              'Turning old materials into new products',
              'Burning all rubbish',
              'Burying rubbish underground'
            ]),
        _CompQ(
            prompt: 'What can plastic bottles be turned into?',
            choices: ['New bottles or even clothing', 'Fresh water', 'Food']),
        _CompQ(
            prompt: 'What happens to glass jars when they are recycled?',
            choices: [
              'They are crushed and melted to make new glass',
              'They are buried in the garden',
              'They are thrown into the ocean'
            ]),
        _CompQ(
            prompt: 'Which of these is NOT mentioned as a benefit of recycling?',
            choices: ['Making people richer', 'Saving natural resources', 'Reducing pollution']),
        _CompQ(
            prompt: 'What do many schools now have to make recycling easier?',
            choices: [
              'Separate bins for paper, plastic and glass',
              'A recycling teacher',
              'A rubbish truck'
            ]),
      ],
    ),
  ];

  static const _wrongReactions = [
    'Not quite -- look back at the passage!',
    'Hmm, try re-reading that part!',
    'Almost -- check the story again!',
  ];

  static const _bg1 = Color(0xFF2A1F14);
  static const _bg2 = Color(0xFF473222);
  static const _card = Color(0xFF5A4130);
  static const _cream = Color(0xFFF3E5C8);
  static const _accent = Color(0xFFD98F3E);

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
    });
    _fadeCtrl.forward(from: 0);
  }

  Object? _cachedQ;
  List<String> _cachedChoices = [];

  List<String> _getShuffledChoices(_CompQ q) {
    if (!identical(_cachedQ, q)) {
      _cachedQ = q;
      _cachedChoices = List<String>.from(q.choices)..shuffle(_rng);
    }
    return _cachedChoices;
  }

  void _onAnswer(int index) {
    if (_phase != _Phase.playing) return;
    final q = _zones[_zoneIdx].questions[_qIdx];
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
                  CustomPaint(painter: _PageGlowBgPainter(_ambientAnim.value)),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _ReadingHeader(
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
                          _PassageCard(title: zone.passageTitle, text: zone.passageText),
                          const SizedBox(height: 16),
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
                  child: Container(color: _accent),
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

  Widget _buildQuestion(_CompQ q, bool revealed) {
    final choices = _getShuffledChoices(q);
    return Column(
      children: [
        Text(
          q.prompt,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 18),
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

// ── Passage card ──────────────────────────────────────────────────────────────

class _PassageCard extends StatelessWidget {
  final String title;
  final String text;
  const _PassageCard({required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _RQState._cream,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _RQState._accent, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('📖', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                      color: Color(0xFF3A2A18), fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            text,
            style: const TextStyle(color: Color(0xFF3A2A18), fontSize: 13, height: 1.5),
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
    Color fill = _RQState._card;
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
          border: Border.all(color: _RQState._accent.withValues(alpha: 0.8), width: 2),
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

class _PageGlowBgPainter extends CustomPainter {
  final double t;
  const _PageGlowBgPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = _RQState._accent.withValues(alpha: 0.04 + 0.03 * t);
    const spacing = 30.0;
    for (var y = 0.0; y < size.height; y += spacing) {
      for (var x = 0.0; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), 1.3, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PageGlowBgPainter oldDelegate) => oldDelegate.t != t;
}

class _SparkleShowerPainter extends CustomPainter {
  final double t;
  const _SparkleShowerPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(157);
    for (var i = 0; i < 18; i++) {
      final startX = rng.nextDouble() * size.width;
      final speed = 0.5 + rng.nextDouble() * 0.6;
      final y = (t * speed) * (size.height + 40) - 20;
      final x = startX + math.sin((t * 6) + i) * 12;
      final paint = Paint()
        ..color = _RQState._accent.withValues(alpha: (1 - t).clamp(0.0, 1.0));
      canvas.drawCircle(Offset(x, y), 3, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparkleShowerPainter oldDelegate) => oldDelegate.t != t;
}

// ── Header / progress ────────────────────────────────────────────────────────

class _ReadingHeader extends StatelessWidget {
  final String zoneName;
  final int zoneIdx;
  final int totalZones;
  final int completedSteps;
  final int totalSteps;
  const _ReadingHeader({
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
              const Text('📚', style: TextStyle(fontSize: 22)),
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
          _ReadingTrail(completed: completedSteps, total: totalSteps),
        ],
      ),
    );
  }
}

class _ReadingTrail extends StatelessWidget {
  final int completed;
  final int total;
  const _ReadingTrail({required this.completed, required this.total});

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
                  i < completed ? '📖' : '·',
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
            color: _RQState._card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _RQState._accent, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('📖', style: TextStyle(fontSize: 40)),
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
            colors: [_RQState._bg1, _RQState._bg2],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('📚🔍', style: TextStyle(fontSize: 44)),
                  SizedBox(height: 16),
                  Text(
                    'Reading Quest',
                    style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Read each passage carefully, then answer questions '
                    'about it!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  SizedBox(height: 24),
                  CircularProgressIndicator(color: _RQState._accent),
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
            colors: [_RQState._bg1, _RQState._bg2],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🏆📚', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  const Text('Reading Champion!',
                      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  Text('$correctCount / $total correct ($pct%)',
                      style: const TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('+$totalXP XP',
                      style: const TextStyle(color: _RQState._accent, fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: onReplay,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _RQState._card,
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
