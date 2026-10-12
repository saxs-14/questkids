import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/game_session_model.dart';
import '../core/game_config.dart';
import '../core/game_feedback_service.dart';
import '../core/game_session_persistence.dart';

// ────────────────────────────────────────────────────────────────────────────
// Multiples Grid — Grade 4 Mathematics: 5x5 Number Cube Chain Engine
//
// Connect sequential multiples of a base number across a 5x5 matrix of 25
// glowing cubes (e.g. 3 -> 6 -> 9 -> 12 -> 15 -> 18 -> 21 -> 24 -> 27 -> 30).
// ────────────────────────────────────────────────────────────────────────────

enum _Phase { intro, playing, streak, roundDone, victory }

// Shared geometry for the 5x5 cube grid -- used both to hit-test which cube
// a drag position is currently over, and by _LaserPathPainter to find each
// cube's center. Must stay in sync with the GridView.builder's own
// crossAxisCount/crossAxisSpacing/mainAxisSpacing below: a
// SliverGridDelegateWithFixedCrossAxisCount with no explicit
// childAspectRatio defaults to 1.0, so each cell is a square of
// (totalSize - (gridSize-1)*spacing) / gridSize on a side.
const int kMultiplesGridSize = 5;
const double kMultiplesGridSpacing = 8.0;

double gridCellExtentFor(double totalSize) =>
    (totalSize - (kMultiplesGridSize - 1) * kMultiplesGridSpacing) /
    kMultiplesGridSize;

Offset gridCubeCenter(int index, Size size) {
  final cell = gridCellExtentFor(size.width);
  final stride = cell + kMultiplesGridSpacing;
  final col = index % kMultiplesGridSize;
  final row = index ~/ kMultiplesGridSize;
  return Offset(col * stride + cell / 2, row * stride + cell / 2);
}

/// Returns the cube index under [local], or null if the point falls
/// outside the grid or in the gap between cubes (a gap is deliberately
/// not a hit -- passing through it shouldn't count as entering any cube).
int? hitTestGridCubeIndex(Offset local, Size size) {
  final cell = gridCellExtentFor(size.width);
  final stride = cell + kMultiplesGridSpacing;
  if (local.dx < 0 ||
      local.dy < 0 ||
      local.dx >= size.width ||
      local.dy >= size.height) {
    return null;
  }
  final col = (local.dx / stride).floor();
  final row = (local.dy / stride).floor();
  if (col < 0 ||
      col >= kMultiplesGridSize ||
      row < 0 ||
      row >= kMultiplesGridSize) {
    return null;
  }
  final cellLeft = col * stride;
  final cellTop = row * stride;
  if (local.dx - cellLeft > cell || local.dy - cellTop > cell) return null;
  return row * kMultiplesGridSize + col;
}

class _CubeItem {
  final int index;
  final int number;
  final bool isMultiple;
  final int stepIndex; // 1 for 3*1, 2 for 3*2, etc. (or -1 if distractor)

  _CubeItem({
    required this.index,
    required this.number,
    required this.isMultiple,
    required this.stepIndex,
  });
}

class MultiplesGridGame extends StatefulWidget {
  final GameConfig config;
  final dynamic user;

  const MultiplesGridGame({
    super.key,
    required this.config,
    this.user,
  });

  @override
  State<MultiplesGridGame> createState() => _MultiplesGridGameState();
}

class _MultiplesGridGameState extends State<MultiplesGridGame>
    with TickerProviderStateMixin {
  static const List<int> _baseMultipliers = [3, 4, 6, 7, 8, 9, 12];

  late AnimationController _ambientGlowCtrl;
  late AnimationController _shakeCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _victoryCtrl;

  late Animation<double> _ambientGlowAnim;
  late Animation<double> _shakeAnim;
  late Animation<double> _pulseAnim;

  int _roundIndex = 0;
  int _currentStep = 1; // Needs base * 1 next, then base * 2, etc.
  final int _targetChainLength = 10; // Connect 1 to 10 multiples
  int _streak = 0;
  int _totalXP = 0;
  int _correctHits = 0;
  int _totalTaps = 0;

  _Phase _phase = _Phase.intro;
  List<_CubeItem> _gridCubes = [];
  final List<int> _connectedIndices = [];
  int? _lastTappedIndex;
  String _hintMessage = '';

  // Drag-to-connect state: the player draws one continuous line across the
  // grid, in a single drag, through the multiples in ascending order.
  bool _isDragging = false;
  int? _activePointer;
  Offset? _pointerDownPosition;
  Offset? _dragPosition;
  int? _lastHoverIndex;
  Size? _gridRenderSize;

  final math.Random _rng = math.Random();
  final List<Timer> _pendingTimers = [];

  String get _uid => (widget.user?.uid as String?) ?? '';

  int get _currentBase =>
      _baseMultipliers[_roundIndex % _baseMultipliers.length];

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
    _initAnimations();
    _delayed(500, _startNewGame);
  }

  void _initAnimations() {
    _ambientGlowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _ambientGlowAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _ambientGlowCtrl, curve: Curves.easeInOut),
    );

    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn),
    );

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOutBack),
    );

    _victoryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
  }

  @override
  void dispose() {
    for (final t in _pendingTimers) {
      t.cancel();
    }
    _pendingTimers.clear();
    _ambientGlowCtrl.dispose();
    _shakeCtrl.dispose();
    _pulseCtrl.dispose();
    _victoryCtrl.dispose();
    super.dispose();
  }

  void _startNewGame() {
    setState(() {
      _roundIndex = 0;
      _totalXP = 0;
      _correctHits = 0;
      _totalTaps = 0;
      _streak = 0;
    });
    _generateRound();
  }

  void _generateRound() {
    final base = _currentBase;
    _currentStep = 1;
    _connectedIndices.clear();
    _lastTappedIndex = null;
    _hintMessage =
        'Find the smallest multiple of $base, then count on by $base.';

    final validMultiples = <int, int>{}; // stepIndex -> multiple
    for (int step = 1; step <= _targetChainLength; step++) {
      validMultiples[step] = base * step;
    }

    // Distribute the 10 target multiples across 25 grid slots so
    // consecutive steps in the chain land near each other, not scattered
    // at random across the whole grid -- see _proximitySlotIndices.
    final targetSlotIndices = _proximitySlotIndices();

    final cubes = List<_CubeItem?>.filled(25, null);

    // Place correct multiples
    for (int step = 1; step <= _targetChainLength; step++) {
      final slotIndex = targetSlotIndices[step - 1];
      cubes[slotIndex] = _CubeItem(
        index: slotIndex,
        number: base * step,
        isMultiple: true,
        stepIndex: step,
      );
    }

    // Fill distractors
    final usedNumbers = Set<int>.from(validMultiples.values);
    for (int i = 0; i < 25; i++) {
      if (cubes[i] == null) {
        int distractor;
        do {
          final nearMissBase = base * (1 + _rng.nextInt(12));
          final offset = (_rng.nextBool() ? 1 : -1) * (1 + _rng.nextInt(3));
          distractor = (nearMissBase + offset).clamp(1, 150);
        } while (usedNumbers.contains(distractor));
        usedNumbers.add(distractor);

        cubes[i] = _CubeItem(
          index: i,
          number: distractor,
          isMultiple: false,
          stepIndex: -1,
        );
      }
    }

    setState(() {
      _gridCubes = cubes.cast<_CubeItem>();
      _phase = _Phase.playing;
    });
  }

  /// Finds a randomized, non-repeating orthogonal path so every next multiple
  /// is in a cube directly beside the previous one. Backtracking avoids a
  /// random walk dead end that would otherwise force a long jump.
  List<int> _proximitySlotIndices() {
    List<int>? findPath(List<int> path, Set<int> used) {
      if (path.length == _targetChainLength) return List<int>.from(path);

      final current = path.last;
      final row = current ~/ kMultiplesGridSize;
      final col = current % kMultiplesGridSize;
      final candidates = <int>[
        if (row > 0) current - kMultiplesGridSize,
        if (row < kMultiplesGridSize - 1) current + kMultiplesGridSize,
        if (col > 0) current - 1,
        if (col < kMultiplesGridSize - 1) current + 1,
      ]..shuffle(_rng);

      for (final next in candidates) {
        if (!used.add(next)) continue;
        path.add(next);
        final result = findPath(path, used);
        if (result != null) return result;
        path.removeLast();
        used.remove(next);
      }
      return null;
    }

    final startingSlots = List<int>.generate(25, (index) => index)
      ..shuffle(_rng);
    for (final start in startingSlots) {
      final path = findPath([start], {start});
      if (path != null) return path;
    }
    throw StateError(
        'Could not generate a $kMultiplesGridSize×$kMultiplesGridSize multiple path.');
  }

  /// Evaluates a cube the drag path has just newly entered (called once per
  /// distinct cube the pointer moves onto -- see _lastHoverIndex dedup in
  /// the pointer handlers below, so sitting still or wiggling within one cube
  /// doesn't re-fire this repeatedly). Correct/incorrect handling is
  /// unchanged from the original tap-based version: a wrong cube (including
  /// re-entering an already-connected one) resets the streak and shows a
  /// shake + hint, but never clears already-confirmed progress -- the
  /// player can keep dragging (or start a fresh drag) from where they are.
  void _evaluateCubeEntry(int index) {
    if (_phase != _Phase.playing) return;
    _totalTaps++;

    final cube = _gridCubes[index];
    final expectedMultiple = _currentBase * _currentStep;

    if (cube.number == expectedMultiple && !_connectedIndices.contains(index)) {
      // Correct sequential multiple!
      unawaited(GameFeedbackService.correct());
      _correctHits++;
      _streak++;
      _totalXP += 15 + (_streak ~/ 3) * 5;
      _connectedIndices.add(index);
      _lastTappedIndex = index;
      _currentStep++;

      _pulseCtrl.forward(from: 0);

      if (_streak > 0 && _streak % 4 == 0) {
        _phase = _Phase.streak;
        _delayed(700, () {
          if (mounted && _phase == _Phase.streak) {
            setState(() => _phase = _Phase.playing);
          }
        });
      }

      // Check if round complete
      if (_currentStep > _targetChainLength) {
        _onRoundCompleted();
      } else {
        setState(() {
          _hintMessage =
              'Great! Keep adding $_currentBase and follow the connected path.';
        });
      }
    } else {
      // Wrong cube crossed by the drag
      unawaited(GameFeedbackService.incorrect());
      _streak = 0;
      _shakeCtrl.forward(from: 0);
      setState(() {
        if (_connectedIndices.contains(index)) {
          _hintMessage =
              'That cube is already in your path. Keep moving to a new cube.';
        } else if (cube.isMultiple && cube.stepIndex > _currentStep) {
          _hintMessage =
              'Good spot, but connect the multiples in order. Find the next step first.';
        } else {
          _hintMessage =
              'Not the next step. Count on by $_currentBase and try another cube.';
        }
      });
    }
  }

  /// Gives a strategy clue without identifying the answer cube or number.
  void _showHint() {
    if (_phase != _Phase.playing) return;
    setState(() {
      _hintMessage = _connectedIndices.isEmpty
          ? 'Hint: start with the smallest multiple in the matrix.'
          : 'Hint: count on by $_currentBase from the last cube in your path.';
    });
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (_activePointer != null) return;
    _activePointer = event.pointer;
    _pointerDownPosition = event.localPosition;
    _lastHoverIndex = null;
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (event.pointer != _activePointer) return;
    final downPosition = _pointerDownPosition;
    if (downPosition == null) return;

    if (!_isDragging) {
      if ((event.localPosition - downPosition).distance < 12) return;
      _isDragging = true;
      _updateDragPosition(downPosition);
    }
    _updateDragPosition(event.localPosition);
  }

  void _handlePointerEnd(PointerEvent event) {
    if (event.pointer != _activePointer) return;
    if (_isDragging) {
      setState(() {
        _isDragging = false;
        _dragPosition = null;
      });
    }
    _activePointer = null;
    _pointerDownPosition = null;
    _lastHoverIndex = null;
  }

  void _updateDragPosition(Offset local) {
    final size = _gridRenderSize;
    if (size != null && _phase == _Phase.playing) {
      final start = _dragPosition ?? _pointerDownPosition ?? local;
      final delta = local - start;
      final sampleSpacing = math.max(1.0, gridCellExtentFor(size.width) / 2);
      final sampleCount = math.max(1, (delta.distance / sampleSpacing).ceil());

      for (var sample = 1; sample <= sampleCount; sample++) {
        final point = start + delta * (sample / sampleCount);
        final hit = hitTestGridCubeIndex(point, size);
        if (hit == _lastHoverIndex) continue;
        _lastHoverIndex = hit;
        if (hit != null) _evaluateCubeEntry(hit);
      }
    }
    setState(() => _dragPosition = local);
  }

  void _onRoundCompleted() {
    setState(() {
      _phase = _Phase.roundDone;
      _totalXP += 50;
    });

    _delayed(1800, () {
      if (!mounted) return;
      if (_roundIndex + 1 < _baseMultipliers.length) {
        setState(() {
          _roundIndex++;
        });
        _generateRound();
      } else {
        _onVictory();
      }
    });
  }

  void _onVictory() {
    _victoryCtrl.forward(from: 0);
    _persistSession();
    setState(() => _phase = _Phase.victory);
  }

  void _persistSession() {
    final accuracy =
        _totalTaps > 0 ? (_correctHits / _totalTaps).clamp(0.0, 1.0) : 1.0;
    final isWin = accuracy >= 0.6;
    final totalQuestions = _targetChainLength * _baseMultipliers.length;

    final session = GameSessionModel(
      id: const Uuid().v4(),
      uid: _uid,
      grade: widget.config.grade.isNotEmpty ? widget.config.grade : 'Grade 4',
      subject: 'Mathematics',
      engineType: widget.config.engineType.isNotEmpty
          ? widget.config.engineType
          : 'multiplesGrid',
      score: (accuracy * 100).round(),
      xpEarned: _totalXP,
      coinsEarned: _totalXP ~/ 5,
      accuracy: accuracy,
      timeTakenSeconds: 0,
      completedAt: DateTime.now(),
      result: isWin ? 'win' : 'complete',
      metadata: {
        'totalRounds': _baseMultipliers.length,
        'correctHits': _correctHits,
        'totalTaps': _totalTaps,
        'totalQuestions': totalQuestions,
      },
    );
    persistGameSession(session);
  }

  @override
  Widget build(BuildContext context) {
    if (_phase == _Phase.victory) {
      return _buildVictoryScreen();
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final gridMaxWidth = isTablet ? 540.0 : math.min(screenWidth - 32, 420.0);

    return Scaffold(
      backgroundColor: const Color(0xFF1E102E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Multiples of $_currentBase',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 17,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Get a hint',
            icon: const Icon(Icons.lightbulb, color: Color(0xFFFFD54F)),
            onPressed: _showHint,
          ),
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF9800), Color(0xFFFF5722)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withValues(alpha: 0.4),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bolt, color: Colors.yellow, size: 16),
                const SizedBox(width: 3),
                Text(
                  '$_totalXP XP',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Status bar with chain progress & round tracker
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Chain ${_connectedIndices.length} / $_targetChainLength',
                      style: const TextStyle(
                        color: Color(0xFFFFD54F),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Round ${_roundIndex + 1} / ${_baseMultipliers.length}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Instructional subtitle with glowing guidance
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Text(
                _hintMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _streak > 2
                      ? const Color(0xFFFFCA28)
                      : Colors.white.withValues(alpha: 0.85),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            // Main 5x5 Interactive Cube Grid
            Expanded(
              child: Center(
                child: Container(
                  constraints: BoxConstraints(maxWidth: gridMaxWidth),
                  padding: const EdgeInsets.all(12),
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // Cached for hit-testing in the pointer handlers below --
                        // reading layout size during build and stashing it
                        // for later event handling is safe; this never
                        // triggers a rebuild itself.
                        _gridRenderSize = constraints.biggest;
                        return Stack(
                          children: [
                            // Custom painter for connecting laser energy paths
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _LaserPathPainter(
                                  connectedIndices: _connectedIndices,
                                  glowPhase: _ambientGlowAnim.value,
                                  liveEndpoint:
                                      _isDragging ? _dragPosition : null,
                                ),
                              ),
                            ),

                            // 5x5 Matrix of cubes (visuals only -- all
                            // gesture handling is the transparent overlay
                            // below, not a per-cube GestureDetector)
                            GridView.builder(
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: kMultiplesGridSize,
                                crossAxisSpacing: kMultiplesGridSpacing,
                                mainAxisSpacing: kMultiplesGridSpacing,
                              ),
                              itemCount: _gridCubes.length,
                              itemBuilder: (context, index) {
                                final cube = _gridCubes[index];
                                final isConnected =
                                    _connectedIndices.contains(index);
                                final isLatest = _lastTappedIndex == index;

                                return _buildCubeTile(
                                  cube: cube,
                                  isConnected: isConnected,
                                  isLatest: isLatest,
                                );
                              },
                            ),

                            // Transparent overlay on top so the whole grid
                            // is one continuous drag surface -- sits above
                            // GridView in the Stack so it receives pointer
                            // events first, instead of competing with
                            // GridView's own (scroll-disabled but still
                            // present) gesture recognizer.
                            Positioned.fill(
                              child: Listener(
                                behavior: HitTestBehavior.opaque,
                                onPointerDown: _handlePointerDown,
                                onPointerMove: _handlePointerMove,
                                onPointerUp: _handlePointerEnd,
                                onPointerCancel: _handlePointerEnd,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),

            // Streak indicator banner
            if (_streak >= 2)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF5252), Color(0xFFFF7A00)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withValues(alpha: 0.4),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Text(
                  '🔥 $_streak Multiplier Combo! +${_streak * 5} Bonus XP',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCubeTile({
    required _CubeItem cube,
    required bool isConnected,
    required bool isLatest,
  }) {
    final isTablet = MediaQuery.of(context).size.width > 600;
    return AnimatedBuilder(
      key: ValueKey('multiples_grid_cube_${cube.number}'),
      animation: Listenable.merge([_ambientGlowAnim, _shakeAnim, _pulseAnim]),
      builder: (context, child) {
        final double scale = isLatest ? _pulseAnim.value : 1.0;
        final double shakeOffset = (_shakeCtrl.isAnimating && !isConnected)
            ? math.sin(_shakeAnim.value * math.pi * 8) * 4
            : 0.0;

        return Transform.translate(
          offset: Offset(shakeOffset, 0),
          child: Transform.scale(
            scale: scale,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isConnected
                      ? [
                          const Color(0xFFFFD54F),
                          const Color(0xFFFF8F00),
                          const Color(0xFFE65100),
                        ]
                      : [
                          const Color(0xFFFF7043),
                          const Color(0xFFE64A19),
                          const Color(0xFFBF360C),
                        ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: isConnected
                        ? const Color(0xFFFFB300)
                            .withValues(alpha: 0.8 * _ambientGlowAnim.value)
                        : const Color(0xFFD84315).withValues(alpha: 0.4),
                    blurRadius: isConnected ? 16 : 6,
                    spreadRadius: isConnected ? 2 : 0,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: isConnected
                      ? Colors.white.withValues(alpha: 0.9)
                      : Colors.white.withValues(alpha: 0.2),
                  width: isConnected ? 2.5 : 1.0,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${cube.number}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isTablet ? 22 : 18,
                        fontWeight: FontWeight.w900,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    if (isConnected)
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVictoryScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF1E102E),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🌟', style: TextStyle(fontSize: 72)),
              const SizedBox(height: 16),
              const Text(
                'Multiples Master!',
                style: TextStyle(
                  color: Color(0xFFFFD54F),
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You connected all multiple chains across all rounds!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem('🪙 Coins', '${_totalXP ~/ 5}'),
                    _buildStatItem('⚡ Total XP', '+$_totalXP'),
                    _buildStatItem(
                      '🎯 Accuracy',
                      '${_totalTaps > 0 ? ((_correctHits / _totalTaps) * 100).round() : 100}%',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 36),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white54),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.dashboard),
                    label: const Text('Exit to Hub'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF9800),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: _startNewGame,
                    icon: const Icon(Icons.replay),
                    label: const Text('Play Again'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Custom Painter for Laser Connections between grid cubes
// ────────────────────────────────────────────────────────────────────────────
class _LaserPathPainter extends CustomPainter {
  final List<int> connectedIndices;
  final double glowPhase;

  /// The live drag position, in the same local coordinate space as the
  /// cube grid. When set, the laser extends one extra segment from the
  /// last confirmed cube to this point, so the line visibly follows the
  /// finger/cursor while a drag is in progress, not just once a cube is
  /// confirmed.
  final Offset? liveEndpoint;

  _LaserPathPainter({
    required this.connectedIndices,
    required this.glowPhase,
    this.liveEndpoint,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final points = <Offset>[
      for (final index in connectedIndices) gridCubeCenter(index, size),
      if (liveEndpoint != null) liveEndpoint!,
    ];
    if (points.length < 2) return;

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }

    // Outer glow
    final glowPaint = Paint()
      ..color = const Color(0xFFFFB300).withValues(alpha: 0.5 * glowPhase)
      ..strokeWidth = 10.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    // Inner bright beam
    final beamPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, beamPaint);
  }

  @override
  bool shouldRepaint(covariant _LaserPathPainter oldDelegate) {
    return oldDelegate.connectedIndices != connectedIndices ||
        oldDelegate.glowPhase != glowPhase ||
        oldDelegate.liveEndpoint != liveEndpoint;
  }
}
