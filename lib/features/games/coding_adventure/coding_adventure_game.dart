import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/game_session_model.dart';
import '../core/game_config.dart';
import '../core/game_session_persistence.dart';

// ────────────────────────────────────────────────────────────────────────────
// Coding Adventure — Grade 4 Technology: sequencing instructions, debugging,
// beginner coding
//
// 4 Zones (5 questions each = 20 total):
//   1. Maze Runner       — tap movement-command blocks IN ORDER; the robot
//      physically moves across a grid live, one cell per correct tap
//   2. Debug It           — recall MCQ about finding and fixing bugs
//   3. Sequencing Basics  — recall MCQ about order/algorithms
//   4. Coding Vocabulary  — recall MCQ, coding terms
//
// Structurally distinct from every prior engine: Maze Runner is the first
// engine where tapping a tile causes a character to visibly move through a
// spatial grid in real time -- the learner is literally programming the
// robot's path one instruction at a time and watching it execute, rather
// than building a static sequence or picking an MCQ answer.
// Architecture: fully self-contained StatefulWidget.
// ────────────────────────────────────────────────────────────────────────────

enum _Phase { intro, playing, correct, wrong, streak, zoneDone, victory }

enum _Kind { maze, simple }

enum _Dir { up, down, left, right }

const _dirEmoji = {_Dir.up: '⬆️', _Dir.down: '⬇️', _Dir.left: '⬅️', _Dir.right: '➡️'};
const _dirDelta = {
  _Dir.up: Offset(0, -1),
  _Dir.down: Offset(0, 1),
  _Dir.left: Offset(-1, 0),
  _Dir.right: Offset(1, 0),
};

class _MazeQ {
  final int startCol, startRow;
  final int goalCol, goalRow;
  final List<_Dir> correctSeq;
  final List<_Dir> palette; // scrambled, includes decoys
  const _MazeQ({
    required this.startCol,
    required this.startRow,
    required this.goalCol,
    required this.goalRow,
    required this.correctSeq,
    required this.palette,
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
  final List<_MazeQ> mazes;
  final List<_SimpleQ> simple;
  const _Zone.maze(this.name, this.mazes)
      : kind = _Kind.maze,
        simple = const [];
  const _Zone.simple(this.name, this.simple)
      : kind = _Kind.simple,
        mazes = const [];

  int get length => kind == _Kind.maze ? mazes.length : simple.length;
}

class CodingAdventureGame extends StatefulWidget {
  final GameConfig config;
  final dynamic user;
  const CodingAdventureGame({super.key, required this.config, this.user});

  @override
  State<CodingAdventureGame> createState() => _CAState();
}

class _CAState extends State<CodingAdventureGame> with TickerProviderStateMixin {
  static const _gridSize = 3;

  static const _zones = [
    _Zone.maze('Maze Runner', [
      _MazeQ(
          startCol: 0, startRow: 0, goalCol: 2, goalRow: 0,
          correctSeq: [_Dir.right, _Dir.right],
          palette: [_Dir.right, _Dir.down, _Dir.right]),
      _MazeQ(
          startCol: 0, startRow: 0, goalCol: 0, goalRow: 2,
          correctSeq: [_Dir.down, _Dir.down],
          palette: [_Dir.down, _Dir.right, _Dir.down]),
      _MazeQ(
          startCol: 0, startRow: 0, goalCol: 2, goalRow: 1,
          correctSeq: [_Dir.right, _Dir.right, _Dir.down],
          palette: [_Dir.down, _Dir.right, _Dir.right, _Dir.up]),
      _MazeQ(
          startCol: 2, startRow: 0, goalCol: 0, goalRow: 2,
          correctSeq: [_Dir.left, _Dir.left, _Dir.down, _Dir.down],
          palette: [_Dir.down, _Dir.left, _Dir.down, _Dir.left, _Dir.right]),
      _MazeQ(
          startCol: 0, startRow: 2, goalCol: 2, goalRow: 0,
          correctSeq: [_Dir.right, _Dir.right, _Dir.up, _Dir.up],
          palette: [_Dir.up, _Dir.right, _Dir.up, _Dir.right, _Dir.down]),
    ]),
    _Zone.simple('Debug It', [
      _SimpleQ(
          prompt: 'A program tells the robot to go RIGHT twice to reach a '
              'goal that is actually one step LEFT. What is the bug?',
          choices: ['The direction is wrong', 'The robot is broken', 'There are too many blocks']),
      _SimpleQ(
          prompt: 'Finding and fixing a mistake in a program is called...?',
          choices: ['Debugging', 'Coding', 'Looping']),
      _SimpleQ(
          prompt: 'A program moves the robot UP but the goal is DOWN. '
              'To fix it, you should...?',
          choices: ['Change UP to DOWN', 'Add more UP blocks', 'Delete the whole program']),
      _SimpleQ(
          prompt: 'If a program has the wrong number of steps, the robot will...?',
          choices: ['Stop in the wrong place', 'Go faster', 'Turn a different colour']),
      _SimpleQ(
          prompt: 'Testing your program to see if it works is an important step called...?',
          choices: ['Testing', 'Guessing', 'Ignoring']),
    ]),
    _Zone.simple('Sequencing Basics', [
      _SimpleQ(
          prompt: 'A list of steps followed in order is called a...?',
          choices: ['Sequence', 'Colour', 'Picture']),
      _SimpleQ(
          prompt: 'In coding, the ORDER of steps...?',
          choices: ['Matters a lot', 'Never matters', 'Only matters sometimes']),
      _SimpleQ(
          prompt: 'A set of step-by-step instructions to solve a problem is called an...?',
          choices: ['Algorithm', 'Alphabet', 'Animation']),
      _SimpleQ(
          prompt: 'Before you code, it helps to first...?',
          choices: ['Plan the steps', 'Skip planning', 'Guess randomly']),
      _SimpleQ(
          prompt: 'If you do the steps in the wrong order, the result will usually be...?',
          choices: ['Wrong', 'The same', 'Faster']),
    ]),
    _Zone.simple('Coding Vocabulary', [
      _SimpleQ(
          prompt: 'What is a LOOP in coding?',
          choices: ['Repeating steps', 'A single step', 'A broken program']),
      _SimpleQ(
          prompt: 'What is INPUT?',
          choices: ['Information given to a program', 'The final answer', 'A bug']),
      _SimpleQ(
          prompt: 'What is OUTPUT?',
          choices: ['What the program produces', 'A mistake', 'The starting point']),
      _SimpleQ(
          prompt: 'What does it mean to RUN a program?',
          choices: ['To carry out its instructions', 'To delete it', 'To write it']),
      _SimpleQ(
          prompt: 'What is a COMMAND?',
          choices: ['A single instruction', 'A whole program', 'A type of robot']),
    ]),
  ];

  static const _wrongReactions = [
    'Not that block! Try another.',
    'Hmm, try a different block!',
    'Almost -- pick another block!',
  ];

  static const _bg1 = Color(0xFF0E1B2E);
  static const _bg2 = Color(0xFF1C3A5E);
  static const _card = Color(0xFF2E7D6B);
  static const _neon = Color(0xFF4DE8C0);

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

  // Maze state
  List<_Tile> _tiles = [];
  int _placedCount = 0;
  bool _hadWrongTap = false;
  int? _wobbleTileId;
  int _robotCol = 0, _robotRow = 0;

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
    _setupCurrentQuestion();
    _fadeCtrl.forward(from: 0);
  }

  void _setupCurrentQuestion() {
    final zone = _zones[_zoneIdx];
    if (zone.kind == _Kind.maze) {
      final maze = zone.mazes[_qIdx];
      _tiles = [for (var i = 0; i < maze.palette.length; i++) _Tile(i, maze.palette[i])];
      _placedCount = 0;
      _hadWrongTap = false;
      _wobbleTileId = null;
      _robotCol = maze.startCol;
      _robotRow = maze.startRow;
    }
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

  void _onTapTile(int tileId) {
    if (_phase != _Phase.playing) return;
    final maze = _zones[_zoneIdx].mazes[_qIdx];
    final tile = _tiles.firstWhere((t) => t.id == tileId);
    if (tile.consumed) return;

    final expected = maze.correctSeq[_placedCount];
    if (tile.dir == expected) {
      setState(() {
        tile.consumed = true;
        final delta = _dirDelta[tile.dir]!;
        _robotCol += delta.dx.toInt();
        _robotRow += delta.dy.toInt();
        _placedCount++;
      });
      if (_placedCount == maze.correctSeq.length) {
        _delayed(300, () => _applyAnswerResult(!_hadWrongTap));
      }
    } else {
      setState(() {
        _hadWrongTap = true;
        _wobbleTileId = tileId;
        _wrongReaction = _wrongReactions[_rng.nextInt(_wrongReactions.length)];
      });
      _shakeCtrl.forward(from: 0);
      _delayed(400, () {
        if (mounted) setState(() => _wobbleTileId = null);
      });
    }
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
        _delayed(1000, _advance);
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
          _setupCurrentQuestion();
          _fadeCtrl.forward(from: 0);
        });
      }
    } else {
      setState(() {
        _qIdx = next;
        _selectedIndex = null;
        _phase = _Phase.playing;
      });
      _setupCurrentQuestion();
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
                  CustomPaint(painter: _CircuitBgPainter(_ambientAnim.value)),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _CodeHeader(
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
                      child: zone.kind == _Kind.maze
                          ? _buildMazeQuestion(zone.mazes[_qIdx])
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
                  child: Container(color: _neon),
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

  Widget _buildMazeQuestion(_MazeQ maze) {
    const cellSize = 64.0;
    return Column(
      children: [
        const SizedBox(height: 8),
        const Text(
          'Tap the blocks in order to guide the robot to the flag!',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: cellSize * _gridSize,
          height: cellSize * _gridSize,
          child: Stack(
            children: [
              for (var r = 0; r < _gridSize; r++)
                for (var c = 0; c < _gridSize; c++)
                  Positioned(
                    left: c * cellSize,
                    top: r * cellSize,
                    child: Container(
                      width: cellSize,
                      height: cellSize,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white24),
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                      alignment: Alignment.center,
                      child: (c == maze.goalCol && r == maze.goalRow)
                          ? const Text('🚩', style: TextStyle(fontSize: 26))
                          : null,
                    ),
                  ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOut,
                left: _robotCol * cellSize,
                top: _robotRow * cellSize,
                child: const SizedBox(
                  width: cellSize,
                  height: cellSize,
                  child: Center(child: Text('🤖', style: TextStyle(fontSize: 30))),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        AnimatedBuilder(
          animation: _shakeAnim,
          builder: (context, _) => Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              for (final tile in _tiles)
                if (!tile.consumed)
                  _CodeBlockTile(
                    dir: tile.dir,
                    wobble: _wobbleTileId == tile.id,
                    shakeAnim: _shakeAnim,
                    onTap: () => _onTapTile(tile.id),
                  ),
            ],
          ),
        ),
        if (_hadWrongTap && _wobbleTileId != null)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text(
              _wrongReaction,
              style: const TextStyle(color: _neon, fontSize: 13, fontWeight: FontWeight.w600),
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
        const SizedBox(height: 16),
        Text(
          q.prompt,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 26),
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
            padding: const EdgeInsets.only(top: 18),
            child: Text(
              '$_wrongReaction The answer was ${q.choices[0]}.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _Tile {
  final int id;
  final _Dir dir;
  bool consumed = false;
  _Tile(this.id, this.dir);
}

// ── Code block tile ──────────────────────────────────────────────────────────

class _CodeBlockTile extends StatelessWidget {
  final _Dir dir;
  final bool wobble;
  final Animation<double> shakeAnim;
  final VoidCallback onTap;
  const _CodeBlockTile({
    required this.dir,
    required this.wobble,
    required this.shakeAnim,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: shakeAnim,
      builder: (context, _) {
        final dx = wobble ? math.sin(shakeAnim.value * math.pi * 6) * 5 : 0.0;
        return Transform.translate(
          offset: Offset(dx, 0),
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: _CAState._card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _CAState._neon, width: 2),
              ),
              alignment: Alignment.center,
              child: Text(_dirEmoji[dir]!, style: const TextStyle(fontSize: 26)),
            ),
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
    Color fill = _CAState._card;
    if (revealed && isCorrect) fill = const Color(0xFF4CAF7D);
    if (revealed && selected && !isCorrect) fill = const Color(0xFFE05656);

    return GestureDetector(
      onTap: revealed ? null : onTap,
      child: Container(
        constraints: const BoxConstraints(minWidth: 110, maxWidth: 220),
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _CAState._neon.withValues(alpha: 0.6), width: 2),
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

class _CircuitBgPainter extends CustomPainter {
  final double t;
  const _CircuitBgPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _CAState._neon.withValues(alpha: 0.08 + 0.06 * t)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (var i = 0; i < 4; i++) {
      final y = size.height * (0.05 + i * 0.03);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CircuitBgPainter oldDelegate) => oldDelegate.t != t;
}

class _SparkleShowerPainter extends CustomPainter {
  final double t;
  const _SparkleShowerPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(73);
    for (var i = 0; i < 18; i++) {
      final startX = rng.nextDouble() * size.width;
      final speed = 0.5 + rng.nextDouble() * 0.6;
      final y = (t * speed) * (size.height + 40) - 20;
      final x = startX + math.sin((t * 6) + i) * 12;
      final paint = Paint()
        ..color = _CAState._neon.withValues(alpha: (1 - t).clamp(0.0, 1.0));
      canvas.drawCircle(Offset(x, y), 3, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparkleShowerPainter oldDelegate) => oldDelegate.t != t;
}

// ── Header / progress ────────────────────────────────────────────────────────

class _CodeHeader extends StatelessWidget {
  final String zoneName;
  final int zoneIdx;
  final int totalZones;
  final int completedSteps;
  final int totalSteps;
  const _CodeHeader({
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
              const Text('🤖', style: TextStyle(fontSize: 22)),
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
          _CodeTrail(completed: completedSteps, total: totalSteps),
        ],
      ),
    );
  }
}

class _CodeTrail extends StatelessWidget {
  final int completed;
  final int total;
  const _CodeTrail({required this.completed, required this.total});

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
                  i < completed ? '💾' : '·',
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
            color: _CAState._card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _CAState._neon, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🤖', style: TextStyle(fontSize: 40)),
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
            colors: [_CAState._bg1, _CAState._bg2],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🤖💻', style: TextStyle(fontSize: 44)),
                  SizedBox(height: 16),
                  Text(
                    'Coding Adventure',
                    style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Program the robot one block at a time and watch it '
                    'move to reach the flag!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  SizedBox(height: 24),
                  CircularProgressIndicator(color: _CAState._neon),
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
            colors: [_CAState._bg1, _CAState._bg2],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🏆🤖', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  const Text('Program Complete!',
                      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  Text('$correctCount / $total correct ($pct%)',
                      style: const TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('+$totalXP XP',
                      style: const TextStyle(color: _CAState._neon, fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: onReplay,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _CAState._card,
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
