import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/game_session_model.dart';
import '../core/game_config.dart';
import '../core/game_session_persistence.dart';

// ────────────────────────────────────────────────────────────────────────────
// Liberation Heroes — Grade 4 Social Sciences: the people who fought for
// freedom in South Africa
//
// NOTE: this is a DIFFERENT engine from adventure_journey/ (engineType
// 'adventureJourney'), which is a shared generic engine still used by 19
// other catalog entries. This engine (engineType 'liberationHeroes') is
// registered ONLY against ss_g4_heroes.
//
// 4 Zones (5 questions each = 20 total):
//   1. Who Is This Hero?      — identify a hero from a clue; a fixed Hall
//      of Fame of 5 medallions unlocks the ONE matching portrait the
//      instant that specific hero is correctly identified
//   2. Nelson Mandela          — recall MCQ (Robben Island, presidency,
//      reconciliation)
//   3. More Freedom Fighters   — recall MCQ (Sisulu, Tutu, Luthuli, Biko)
//   4. Fighting for Freedom    — recall MCQ (apartheid, Freedom Charter,
//      Sharpeville, Soweto, 1994)
//
// Structurally distinct from every prior engine: Zone 1's Hall of Fame
// unlocks are content-specific and 1:1 with named individuals -- unlike
// Robot Maker's generic milestone-threshold body parts, each medallion
// here corresponds to exactly one hero and only appears once THAT hero
// has actually been correctly identified.
// Architecture: fully self-contained StatefulWidget.
// ────────────────────────────────────────────────────────────────────────────

enum _Phase { intro, playing, correct, wrong, streak, zoneDone, victory }

enum _Kind { hero, simple }

const _heroNames = [
  'Nelson Mandela',
  'Albertina Sisulu',
  'Desmond Tutu',
  'Chief Albert Luthuli',
  'Steve Biko',
];

class _HeroQ {
  final String prompt;
  final int correctHeroIdx; // index into _heroNames
  final List<int> decoyIdx; // two other indices into _heroNames
  const _HeroQ({required this.prompt, required this.correctHeroIdx, required this.decoyIdx});
}

class _SimpleQ {
  final String prompt;
  final List<String> choices; // [0] correct
  const _SimpleQ({required this.prompt, required this.choices});
}

class _Zone {
  final String name;
  final _Kind kind;
  final List<_HeroQ> hero;
  final List<_SimpleQ> simple;
  const _Zone.hero(this.name, this.hero)
      : kind = _Kind.hero,
        simple = const [];
  const _Zone.simple(this.name, this.simple)
      : kind = _Kind.simple,
        hero = const [];

  int get length => kind == _Kind.hero ? hero.length : simple.length;
}

class LiberationHeroesGame extends StatefulWidget {
  final GameConfig config;
  final dynamic user;
  const LiberationHeroesGame({super.key, required this.config, this.user});

  @override
  State<LiberationHeroesGame> createState() => _LHState();
}

class _LHState extends State<LiberationHeroesGame> with TickerProviderStateMixin {
  static const _zones = [
    _Zone.hero('Who Is This Hero?', [
      _HeroQ(
          prompt:
              "This man spent 27 years in prison for fighting against apartheid and became South Africa's first democratically elected president.",
          correctHeroIdx: 0,
          decoyIdx: [4, 3]),
      _HeroQ(
          prompt:
              "Known as the 'Mother of the Nation', this woman fought for freedom alongside her husband and was a leader in her own right.",
          correctHeroIdx: 1,
          decoyIdx: [2, 0]),
      _HeroQ(
          prompt:
              'This Archbishop led the Truth and Reconciliation Commission and won the Nobel Peace Prize for his work against apartheid.',
          correctHeroIdx: 2,
          decoyIdx: [3, 1]),
      _HeroQ(
          prompt:
              'This ANC president was the first African to win the Nobel Peace Prize, for his peaceful resistance to apartheid.',
          correctHeroIdx: 3,
          decoyIdx: [0, 4]),
      _HeroQ(
          prompt:
              'This young activist led the Black Consciousness Movement, encouraging Black South Africans to take pride in their identity.',
          correctHeroIdx: 4,
          decoyIdx: [2, 1]),
    ]),
    _Zone.simple('Nelson Mandela', [
      _SimpleQ(
          prompt: 'On which island was Nelson Mandela imprisoned for many years?',
          choices: ['Robben Island', 'Bird Island', 'Table Island']),
      _SimpleQ(
          prompt: 'How many years did Nelson Mandela spend in prison?',
          choices: ['27 years', '5 years', '50 years']),
      _SimpleQ(
          prompt: "In what year did Nelson Mandela become South Africa's president?",
          choices: ['1994', '1990', '1652']),
      _SimpleQ(
          prompt: 'After his release, Mandela became known for promoting...?',
          choices: ['Forgiveness and reconciliation', 'Revenge', 'Isolation']),
      _SimpleQ(
          prompt: 'Nelson Mandela won which international award for his fight against apartheid?',
          choices: ['The Nobel Peace Prize', 'An Olympic medal', 'A Grammy Award']),
    ]),
    _Zone.simple('More Freedom Fighters', [
      _SimpleQ(
          prompt: "Albertina Sisulu was a leader in which organisation's Women's League?",
          choices: ['The ANC', 'The VOC', 'The British Army']),
      _SimpleQ(
          prompt: 'Desmond Tutu led which commission after apartheid ended, to help the country heal?',
          choices: ['The Truth and Reconciliation Commission', 'The United Nations', 'The Olympic Committee']),
      _SimpleQ(
          prompt: 'Chief Albert Luthuli was the president of which liberation movement?',
          choices: ['The ANC (African National Congress)', 'The VOC', 'The British Parliament']),
      _SimpleQ(
          prompt: "Steve Biko's Black Consciousness Movement encouraged Black South Africans to...?",
          choices: [
            'Feel proud of their identity and stand up for their rights',
            'Leave South Africa',
            'Stop going to school'
          ]),
      _SimpleQ(
          prompt: 'Many of these leaders were arrested or banned because they...?',
          choices: [
            'Spoke out and organised against unfair apartheid laws',
            'Broke traffic laws',
            'Refused to pay taxes'
          ]),
    ]),
    _Zone.simple('Fighting for Freedom', [
      _SimpleQ(
          prompt: 'What unfair system were these heroes fighting against?',
          choices: [
            'Apartheid (racial segregation and unequal laws)',
            'High taxes',
            'Bad weather'
          ]),
      _SimpleQ(
          prompt: 'The Freedom Charter, adopted in 1955, called for...?',
          choices: [
            'Equal rights for all people in South Africa',
            'More land for one group only',
            'No schools for children'
          ]),
      _SimpleQ(
          prompt: 'What happened at Sharpeville in 1960?',
          choices: [
            'Police shot and killed peaceful protesters',
            'A new school was opened',
            'A sports tournament was held'
          ]),
      _SimpleQ(
          prompt: 'What happened during the Soweto Uprising in 1976?',
          choices: [
            'Students protested against unfair education and many were hurt',
            'A national holiday was declared',
            'Nothing significant happened'
          ]),
      _SimpleQ(
          prompt: 'When did South Africa hold its first democratic election, open to all races?',
          choices: ['1994', '1652', '1806']),
    ]),
  ];

  static const _wrongReactions = [
    'Not quite -- think about their story!',
    'Hmm, try a different hero!',
    'Almost -- picture what they did!',
  ];

  static const _bg1 = Color(0xFF1C1410);
  static const _bg2 = Color(0xFF3A2418);
  static const _card = Color(0xFF4A3020);
  static const _flame = Color(0xFFE8A33D);

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
  int? _pickedHeroIdx;
  final List<bool> _heroUnlocked = List<bool>.filled(5, false);

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
      _pickedHeroIdx = null;
      for (var i = 0; i < _heroUnlocked.length; i++) {
        _heroUnlocked[i] = false;
      }
    });
    _fadeCtrl.forward(from: 0);
  }

  void _onHeroAnswer(int heroIdx, _HeroQ q) {
    if (_phase != _Phase.playing) return;
    final isCorrect = heroIdx == q.correctHeroIdx;
    setState(() {
      _pickedHeroIdx = heroIdx;
      if (isCorrect) _heroUnlocked[q.correctHeroIdx] = true;
    });
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
            _pickedHeroIdx = null;
            _phase = _Phase.playing;
          });
          _fadeCtrl.forward(from: 0);
        });
      }
    } else {
      setState(() {
        _qIdx = next;
        _selectedIndex = null;
        _pickedHeroIdx = null;
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
                  CustomPaint(painter: _EmberGlowBgPainter(_ambientAnim.value)),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _HeroesHeader(
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
                          if (zone.kind == _Kind.hero) ...[
                            const SizedBox(height: 8),
                            _HallOfFame(unlocked: _heroUnlocked),
                            const SizedBox(height: 8),
                          ],
                          zone.kind == _Kind.hero
                              ? _buildHeroQuestion(zone.hero[_qIdx])
                              : _buildSimpleQuestion(zone.simple[_qIdx], revealed),
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
                  child: Container(color: _flame),
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

  Widget _buildHeroQuestion(_HeroQ q) {
    final revealed = _phase == _Phase.correct || _phase == _Phase.wrong;
    final options = [q.correctHeroIdx, ...q.decoyIdx]..shuffle(math.Random(q.correctHeroIdx));

    return Column(
      children: [
        Text(
          q.prompt,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            for (final heroIdx in options)
              _SimpleTile(
                label: _heroNames[heroIdx],
                selected: _pickedHeroIdx == heroIdx,
                isCorrect: heroIdx == q.correctHeroIdx,
                revealed: revealed,
                onTap: () => _onHeroAnswer(heroIdx, q),
              ),
          ],
        ),
        if (_phase == _Phase.wrong)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text(
              '$_wrongReaction The answer was ${_heroNames[q.correctHeroIdx]}.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            ),
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

// ── Hall of Fame ──────────────────────────────────────────────────────────────

class _HallOfFame extends StatelessWidget {
  final List<bool> unlocked;
  const _HallOfFame({required this.unlocked});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        for (var i = 0; i < _heroNames.length; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 60,
            height: 66,
            decoration: BoxDecoration(
              color: unlocked[i] ? _LHState._card : Colors.white10,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: unlocked[i] ? _LHState._flame : Colors.white24, width: 1.5),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(unlocked[i] ? '⭐' : '?',
                    style: TextStyle(fontSize: 18, color: unlocked[i] ? null : Colors.white38)),
                const SizedBox(height: 2),
                Text(
                  unlocked[i] ? _heroNames[i] : '',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
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
    Color fill = _LHState._card;
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
          border: Border.all(color: _LHState._flame.withValues(alpha: 0.7), width: 2),
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

class _EmberGlowBgPainter extends CustomPainter {
  final double t;
  const _EmberGlowBgPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(19);
    for (var i = 0; i < 14; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final flicker = (math.sin(t * math.pi * 2 + i) + 1) / 2;
      final paint = Paint()
        ..color = _LHState._flame.withValues(alpha: 0.04 + flicker * 0.05);
      canvas.drawCircle(Offset(x, y), 1.6, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _EmberGlowBgPainter oldDelegate) => oldDelegate.t != t;
}

class _SparkleShowerPainter extends CustomPainter {
  final double t;
  const _SparkleShowerPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(139);
    for (var i = 0; i < 18; i++) {
      final startX = rng.nextDouble() * size.width;
      final speed = 0.5 + rng.nextDouble() * 0.6;
      final y = (t * speed) * (size.height + 40) - 20;
      final x = startX + math.sin((t * 6) + i) * 12;
      final paint = Paint()
        ..color = _LHState._flame.withValues(alpha: (1 - t).clamp(0.0, 1.0));
      canvas.drawCircle(Offset(x, y), 3, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparkleShowerPainter oldDelegate) => oldDelegate.t != t;
}

// ── Header / progress ────────────────────────────────────────────────────────

class _HeroesHeader extends StatelessWidget {
  final String zoneName;
  final int zoneIdx;
  final int totalZones;
  final int completedSteps;
  final int totalSteps;
  const _HeroesHeader({
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
              const Text('✊', style: TextStyle(fontSize: 22)),
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
          _HeroesTrail(completed: completedSteps, total: totalSteps),
        ],
      ),
    );
  }
}

class _HeroesTrail extends StatelessWidget {
  final int completed;
  final int total;
  const _HeroesTrail({required this.completed, required this.total});

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
                  i < completed ? '✊' : '·',
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
            color: _LHState._card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _LHState._flame, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('✊', style: TextStyle(fontSize: 40)),
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
            colors: [_LHState._bg1, _LHState._bg2],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('✊⭐', style: TextStyle(fontSize: 44)),
                  SizedBox(height: 16),
                  Text(
                    'Liberation Heroes',
                    style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Meet the heroes who fought for freedom in South Africa!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  SizedBox(height: 24),
                  CircularProgressIndicator(color: _LHState._flame),
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
            colors: [_LHState._bg1, _LHState._bg2],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🏆✊', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  const Text('History Champion!',
                      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  Text('$correctCount / $total correct ($pct%)',
                      style: const TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('+$totalXP XP',
                      style: const TextStyle(color: _LHState._flame, fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: onReplay,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _LHState._card,
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
