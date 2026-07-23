import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/game_session_model.dart';
import '../core/game_config.dart';
import '../core/game_session_persistence.dart';

// ────────────────────────────────────────────────────────────────────────────
// Financial Literacy — Grade 4 Life Skills: needs vs wants, saving, budgeting,
// and smart money habits (South African Rand context)
//
// NOTE: this is a DIFFERENT engine from budget_builder/ (engineType
// 'budgetBuilder'), which is a shared generic engine still used by 5
// other catalog entries. This engine (engineType 'financialLiteracy') is
// registered ONLY against ls_g4_finance.
//
// 4 Zones (5 questions each = 20 total):
//   1. Save or Spend?   — given a money scenario, tap the smarter choice;
//      a Rand coin drops from the top of a glass savings jar and lands
//      stacked on the coins already earned
//   2. Needs vs Wants     — recall MCQ
//   3. Saving & Budgeting — recall MCQ
//   4. Smart Money Habits — recall MCQ
//
// Structurally distinct from every prior engine: Zone 1's falling-coin
// savings jar (individual coin sprites that drop and physically stack)
// is a new combination -- unlike Climate Quest's liquid-fill thermometer,
// Debate Duel's growing star row, or Democracy Game's single falling
// ballot. Architecture: fully self-contained StatefulWidget.
// ────────────────────────────────────────────────────────────────────────────

enum _Phase { intro, playing, correct, wrong, streak, zoneDone, victory }

enum _Kind { jar, simple }

class _JarQ {
  final String scenario;
  final List<String> choices; // [0] correct (smarter money choice)
  const _JarQ({required this.scenario, required this.choices});
}

class _SimpleQ {
  final String prompt;
  final List<String> choices; // [0] correct
  const _SimpleQ({required this.prompt, required this.choices});
}

class _Zone {
  final String name;
  final _Kind kind;
  final List<_JarQ> jar;
  final List<_SimpleQ> simple;
  const _Zone.jar(this.name, this.jar)
      : kind = _Kind.jar,
        simple = const [];
  const _Zone.simple(this.name, this.simple)
      : kind = _Kind.simple,
        jar = const [];

  int get length => kind == _Kind.jar ? jar.length : simple.length;
}

class FinancialLiteracyGame extends StatefulWidget {
  final GameConfig config;
  final dynamic user;
  const FinancialLiteracyGame({super.key, required this.config, this.user});

  @override
  State<FinancialLiteracyGame> createState() => _FLState();
}

class _FLState extends State<FinancialLiteracyGame> with TickerProviderStateMixin {
  static const _zones = [
    _Zone.jar('Save or Spend?', [
      _JarQ(
        scenario: "You get R50 for your birthday. What's the smartest thing to do?",
        choices: [
          'Save some and spend some wisely',
          'Spend it all on sweets immediately',
          'Give it all away without thinking',
        ],
      ),
      _JarQ(
        scenario: "You want a new toy but don't have enough money. What should you do?",
        choices: [
          'Save up part of your allowance each week until you can afford it',
          "Ask to borrow money you can't repay",
          'Take it without paying',
        ],
      ),
      _JarQ(
        scenario: 'Which of these is a NEED, not a want?',
        choices: ['School shoes', 'A new video game', 'Sweets'],
      ),
      _JarQ(
        scenario: 'You have R100. A toy costs R80 but you also want to save. What is the smart choice?',
        choices: [
          'Save at least some money instead of spending it all',
          'Spend all R100 on toys',
          'Spend more than you have',
        ],
      ),
      _JarQ(
        scenario: 'Why is it smart to compare prices before buying something?',
        choices: [
          'It helps you find the best value for your money',
          'Price never matters',
          'It wastes time',
        ],
      ),
    ]),
    _Zone.simple('Needs vs Wants', [
      _SimpleQ(prompt: 'Which of these is a NEED?', choices: ['Food', 'A new phone', 'A toy']),
      _SimpleQ(prompt: 'Which of these is a WANT?', choices: ['The latest sneakers', 'Water', 'A place to live']),
      _SimpleQ(
        prompt: 'Why is it important to know the difference between needs and wants?',
        choices: [
          'It helps you spend money wisely and prioritise what matters most',
          'Needs and wants are always the same thing',
          'It has no real purpose',
        ],
      ),
      _SimpleQ(
        prompt: 'Which is a need for a family?',
        choices: ['A safe place to live', 'A game console', 'Designer clothes'],
      ),
      _SimpleQ(
        prompt: 'Buying something just because your friends have it is an example of...?',
        choices: [
          'Choosing a want without thinking it through',
          'Meeting a basic need',
          'Smart saving',
        ],
      ),
    ]),
    _Zone.simple('Saving & Budgeting', [
      _SimpleQ(
        prompt: 'A budget helps you...?',
        choices: ['Plan how to spend and save your money', 'Spend without any plan', 'Avoid saving completely'],
      ),
      _SimpleQ(
        prompt: 'Putting money aside regularly, even small amounts, is called...?',
        choices: ['Saving', 'Borrowing', 'Wasting'],
      ),
      _SimpleQ(
        prompt: 'Why should you save money for emergencies?',
        choices: [
          'Unexpected costs can come up, and savings help you cope',
          'Emergencies never happen',
          'Saving is only for adults',
        ],
      ),
      _SimpleQ(
        prompt: 'If you spend more money than you earn, you are...?',
        choices: ['In debt', 'Saving well', 'Being smart with money'],
      ),
      _SimpleQ(
        prompt: 'A piggy bank or savings account helps you...?',
        choices: ['Keep your money safe and watch it grow', 'Lose your money', 'Spend it faster'],
      ),
    ]),
    _Zone.simple('Smart Money Habits', [
      _SimpleQ(
        prompt: 'Before buying something, it is smart to ask yourself...?',
        choices: ['Do I really need this, and can I afford it?', 'Does everyone else have one?', 'Will it look cool?'],
      ),
      _SimpleQ(
        prompt: 'Which is an example of a smart money habit?',
        choices: [
          'Comparing prices before you buy',
          'Spending your allowance the moment you get it',
          'Never checking how much things cost',
        ],
      ),
      _SimpleQ(
        prompt: 'Why is it risky to spend all your money as soon as you get it?',
        choices: [
          "You won't have anything left for emergencies or future goals",
          'It is always the smartest choice',
          'It helps you save more',
        ],
      ),
      _SimpleQ(
        prompt: 'Setting a savings goal, like saving for a bicycle, helps you...?',
        choices: ['Stay motivated and track your progress', 'Spend faster', 'Forget about saving'],
      ),
      _SimpleQ(
        prompt: 'What is one way a child can earn extra money?',
        choices: [
          'Doing extra chores or small jobs for family',
          'Taking money without asking',
          'Borrowing from friends and never paying back',
        ],
      ),
    ]),
  ];

  static const _wrongReactions = [
    'Not quite -- think about what a smart saver would do!',
    'Hmm, try the wiser money choice!',
    'Close -- which option protects your money best?',
  ];

  static const _bg1 = Color(0xFF0F281C);
  static const _bg2 = Color(0xFF1E4A34);
  static const _card = Color(0xFF1B3F2C);
  static const _gold = Color(0xFFE0B93C);

  late AnimationController _ambientCtrl;
  late AnimationController _fadeCtrl;
  late AnimationController _flashCtrl;
  late AnimationController _burstCtrl;
  late AnimationController _shakeCtrl;
  late AnimationController _coinCtrl;

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
  int _coinsSaved = 0;

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

    _coinCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 550));
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
    _coinCtrl.dispose();
    super.dispose();
  }

  void _startGame() {
    setState(() {
      _zoneIdx = 0;
      _qIdx = 0;
      _correctCount = 0;
      _streak = 0;
      _totalXP = 0;
      _coinsSaved = 0;
      _phase = _Phase.playing;
      _selectedIndex = null;
    });
    _fadeCtrl.forward(from: 0);
  }

  void _onJarAnswer(int index) {
    if (_phase != _Phase.playing) return;
    final isCorrect = index == 0;
    setState(() => _selectedIndex = index);
    if (isCorrect) {
      setState(() => _coinsSaved++);
      _coinCtrl.forward(from: 0);
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
                  CustomPaint(painter: _CoinSparkleBgPainter(_ambientAnim.value)),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _JarHeader(
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
                      child: zone.kind == _Kind.jar
                          ? _buildJarQuestion(zone.jar[_qIdx], revealed)
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

  Widget _buildJarQuestion(_JarQ q, bool revealed) {
    return Column(
      children: [
        const SizedBox(height: 8),
        _SavingsJar(coins: _coinsSaved, coinCtrl: _coinCtrl),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0B1F15),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _gold.withValues(alpha: 0.5), width: 2),
          ),
          child: Text(
            q.scenario,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 16),
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
                      child: _ChoiceTile(
                        label: q.choices[i],
                        selected: _selectedIndex == i,
                        isCorrect: i == 0,
                        revealed: revealed,
                        onTap: () => _onJarAnswer(i),
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
              '$_wrongReaction The smarter choice was: "${q.choices[0]}"',
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

// ── Savings jar (falling, stacking coins) ───────────────────────────────────

class _SavingsJar extends StatelessWidget {
  final int coins;
  final AnimationController coinCtrl;
  const _SavingsJar({required this.coins, required this.coinCtrl});

  static const _jarWidth = 130.0;
  static const _jarHeight = 130.0;
  static const _coinSize = 26.0;
  static const _coinStep = 20.0;

  double _restBottom(int index) => 10 + index * _coinStep;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: coinCtrl,
      builder: (context, _) {
        final t = Curves.easeIn.transform(coinCtrl.value.clamp(0.0, 1.0));
        return SizedBox(
          width: _jarWidth,
          height: _jarHeight + 30,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              // Glass jar
              Positioned(
                bottom: 0,
                child: Container(
                  width: _jarWidth,
                  height: _jarHeight,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _FLState._gold.withValues(alpha: 0.6), width: 2.5),
                  ),
                ),
              ),
              // Jar neck/lid
              Positioned(
                bottom: _jarHeight - 4,
                child: Container(
                  width: _jarWidth * 0.5,
                  height: 14,
                  decoration: BoxDecoration(
                    color: _FLState._gold.withValues(alpha: 0.7),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                  ),
                ),
              ),
              // Already-stacked coins (all but the newest one, if animating)
              for (var i = 0; i < (coins > 0 ? coins - 1 : 0); i++)
                Positioned(bottom: _restBottom(i), child: const _Coin(size: _coinSize)),
              // Newest coin: falls from the jar's neck down to its resting spot
              if (coins > 0)
                Positioned(
                  bottom: _lerp(_jarHeight + 10, _restBottom(coins - 1), t),
                  child: const _Coin(size: _coinSize),
                ),
              // Coin counter
              Positioned(
                top: 0,
                child: Text('R$coins saved',
                    style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        );
      },
    );
  }
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

class _Coin extends StatelessWidget {
  final double size;
  const _Coin({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _FLState._gold,
        border: Border.all(color: const Color(0xFF8A6D1A), width: 1.5),
      ),
      alignment: Alignment.center,
      child: const Text('R', style: TextStyle(color: Color(0xFF5C4813), fontSize: 13, fontWeight: FontWeight.w900)),
    );
  }
}

// ── Choice tile (scenario answers, full-width) ──────────────────────────────

class _ChoiceTile extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isCorrect;
  final bool revealed;
  final VoidCallback onTap;
  const _ChoiceTile({
    required this.label,
    required this.selected,
    required this.isCorrect,
    required this.revealed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color fill = _FLState._card;
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
          border: Border.all(color: _FLState._gold.withValues(alpha: 0.8), width: 2),
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
    Color fill = _FLState._card;
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
          border: Border.all(color: _FLState._gold.withValues(alpha: 0.8), width: 2),
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

class _CoinSparkleBgPainter extends CustomPainter {
  final double t;
  const _CoinSparkleBgPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _FLState._gold.withValues(alpha: 0.04 + 0.03 * t)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (var i = 0; i < 5; i++) {
      final cx = size.width * (0.1 + i * 0.2);
      final cy = size.height * 0.15 + t * 10;
      canvas.drawCircle(Offset(cx, cy), 10 + t * 3, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CoinSparkleBgPainter oldDelegate) => oldDelegate.t != t;
}

class _ConfettiShowerPainter extends CustomPainter {
  final double t;
  const _ConfettiShowerPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(612);
    for (var i = 0; i < 18; i++) {
      final startX = rng.nextDouble() * size.width;
      final speed = 0.5 + rng.nextDouble() * 0.6;
      final y = (t * speed) * (size.height + 40) - 20;
      final x = startX + math.sin((t * 6) + i) * 12;
      final paint = Paint()
        ..color = _FLState._gold.withValues(alpha: (1 - t).clamp(0.0, 1.0));
      canvas.drawCircle(Offset(x, y), 3, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiShowerPainter oldDelegate) => oldDelegate.t != t;
}

// ── Header / progress ────────────────────────────────────────────────────────

class _JarHeader extends StatelessWidget {
  final String zoneName;
  final int zoneIdx;
  final int totalZones;
  final int completedSteps;
  final int totalSteps;
  const _JarHeader({
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
              const Text('💰', style: TextStyle(fontSize: 22)),
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
          _SavingsTrail(completed: completedSteps, total: totalSteps),
        ],
      ),
    );
  }
}

class _SavingsTrail extends StatelessWidget {
  final int completed;
  final int total;
  const _SavingsTrail({required this.completed, required this.total});

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
                  i < completed ? '💰' : '·',
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
            color: _FLState._card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _FLState._gold, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('💰', style: TextStyle(fontSize: 40)),
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
            colors: [_FLState._bg1, _FLState._bg2],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('💰🐷', style: TextStyle(fontSize: 44)),
                  SizedBox(height: 16),
                  Text(
                    'Financial Literacy',
                    style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Learn to budget, save and make smart money decisions!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  SizedBox(height: 24),
                  CircularProgressIndicator(color: _FLState._gold),
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
            colors: [_FLState._bg1, _FLState._bg2],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🏆💰', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  const Text('Money Smart!',
                      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  Text('$correctCount / $total correct ($pct%)',
                      style: const TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('+$totalXP XP',
                      style: const TextStyle(color: _FLState._gold, fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: onReplay,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _FLState._card,
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
