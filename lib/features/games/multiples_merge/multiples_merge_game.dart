import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../core/content_pack_loader.dart';
import '../core/content_pack_loading_view.dart';
import '../core/game_config.dart';
import '../core/game_theme.dart';
import '../tug_of_war/widgets/game_result_overlay.dart';
import 'multiples_merge_session.dart';
import 'multiples_quiz_screen.dart';

/// Multiples Merge — connect number tiles in multiple-order (8 → 16 → 24 …).
/// Drag a finger (or tap tiles) across adjacent cells, including diagonals.
/// Valid next tiles glow to scaffold learning; the glow fades at higher grades.
class MultiplesMergeGame extends StatefulWidget {
  final GameConfig config;
  final dynamic user;

  const MultiplesMergeGame(
      {super.key, required this.config, required this.user});

  @override
  State<MultiplesMergeGame> createState() => _MultiplesMergeGameState();
}

class _MultiplesMergeGameState extends State<MultiplesMergeGame>
    with TickerProviderStateMixin {
  MultiplesMergeSession? _session;
  Map<String, dynamic>? _pack;
  late AnimationController _pulse;
  late ConfettiController _confetti;
  int _lastQ = 0;

  String get _uid => (widget.user?.uid as String?) ?? '';

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _confetti = ConfettiController(duration: const Duration(milliseconds: 700));
    _initSession();
  }

  Future<void> _initSession() async {
    final pack = await loadContentPack(widget.config);
    if (!mounted) return;
    _pack = pack;
    final session = MultiplesMergeSession(widget.config, _uid, pack: pack)
      ..startSession();
    session.addListener(_onChange);
    setState(() => _session = session);
  }

  void _onChange() {
    final session = _session!;
    if (session.questionIndex != _lastQ) {
      _lastQ = session.questionIndex;
      _confetti.play();
    }
  }

  @override
  void dispose() {
    _session?.removeListener(_onChange);
    _session?.dispose();
    _pulse.dispose();
    _confetti.dispose();
    super.dispose();
  }

  void _restart() {
    _session?.removeListener(_onChange);
    _session?.dispose();
    final session = MultiplesMergeSession(widget.config, _uid, pack: _pack)
      ..startSession();
    setState(() {
      _session = session;
      _lastQ = 0;
    });
    session.addListener(_onChange);
  }

  void _openWeeklyQuiz() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          MultiplesQuizScreen(config: widget.config, user: widget.user),
    ));
  }

  @override
  Widget build(BuildContext context) {
    const accent = AppColors.math;
    final session = _session;
    if (session == null) {
      return const ContentPackLoadingView(color: accent);
    }

    return ChangeNotifierProvider.value(
      value: session,
      child: Consumer<MultiplesMergeSession>(
        builder: (ctx, session, _) {
          if (session.isFinished && session.result != null) {
            return GameResultOverlay(
              result: session.result!,
              playerScore: session.correctCount,
              opponentScore: session.totalQuestions,
              opponentName: '',
              onPlayAgain: _restart,
              onContinue: () => Navigator.of(ctx).pop(),
            );
          }

          final round = session.round;
          if (round == null) return const SizedBox.shrink();

          return Scaffold(
            backgroundColor: AppColors.backgroundLight,
            body: SafeArea(
              child: Stack(
                children: [
                  Column(
                    children: [
                      _Hud(
                        mode: round.mode,
                        table: session.table,
                        chainLen: session.chain.length,
                        target: session.chainLength,
                        round: session.questionIndex + 1,
                        totalRounds: session.totalQuestions,
                        onClose: () => Navigator.of(ctx).pop(),
                        onQuiz: _openWeeklyQuiz,
                      ),
                      _InstructionStrip(
                          mode: round.mode,
                          table: session.table,
                          length: session.chainLength),
                      Expanded(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: AnimatedBuilder(
                              animation: _pulse,
                              builder: (_, __) => _MergeGrid(
                                session: session,
                                pulse: _pulse.value,
                                accent: accent,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Align(
                    alignment: Alignment.topCenter,
                    child: ConfettiWidget(
                      confettiController: _confetti,
                      blastDirectionality: BlastDirectionality.explosive,
                      numberOfParticles: 20,
                      maxBlastForce: 20,
                      minBlastForce: 8,
                      gravity: 0.3,
                      colors: const [
                        accent,
                        AppColors.gold,
                        AppColors.orange,
                        Colors.white
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── HUD ─────────────────────────────────────────────────────────────────────
class _Hud extends StatelessWidget {
  final String mode;
  final int table;
  final int chainLen;
  final int target;
  final int round;
  final int totalRounds;
  final VoidCallback onClose;
  final VoidCallback onQuiz;

  const _Hud({
    required this.mode,
    required this.table,
    required this.chainLen,
    required this.target,
    required this.round,
    required this.totalRounds,
    required this.onClose,
    required this.onQuiz,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Row(
        children: [
          IconButton(onPressed: onClose, icon: const Icon(Icons.close)),
          Expanded(
            child: Column(
              children: [
                Text(mode == 'pairs' ? 'Match the Pairs' : 'Multiples of $table',
                    style: GameTheme.display(20, color: AppColors.math)),
                Text(
                    'Chain $chainLen / $target   •   Round $round/$totalRounds',
                    style: GameTheme.body(12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Weekly Quiz',
            onPressed: onQuiz,
            icon: const Icon(Icons.quiz_outlined, color: AppColors.math),
          ),
        ],
      ),
    );
  }
}

class _InstructionStrip extends StatelessWidget {
  final String mode;
  final int table;
  final int length;
  const _InstructionStrip(
      {required this.mode, required this.table, required this.length});

  @override
  Widget build(BuildContext context) {
    final text = mode == 'pairs'
        ? 'Tap a tile, then tap its matching pair!'
        : 'Connect the multiples in order:  ${[
            for (int i = 1; i <= math.min(4, length); i++) '${table * i}'
          ].join(' → ')} …';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.math.withValues(alpha: 0.10),
        borderRadius: GameTheme.roundedSmall,
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style:
            GameTheme.body(13, color: AppColors.math, weight: FontWeight.w700),
      ),
    );
  }
}

// ── Grid ─────────────────────────────────────────────────────────────────────
class _MergeGrid extends StatelessWidget {
  final MultiplesMergeSession session;
  final double pulse;
  final Color accent;

  const _MergeGrid(
      {required this.session, required this.pulse, required this.accent});

  void _touch(Offset p, double side, int n) {
    if (p.dx < 0 || p.dy < 0 || p.dx > side || p.dy > side) return;
    final tile = side / n;
    final col = (p.dx / tile).floor().clamp(0, n - 1);
    final row = (p.dy / tile).floor().clamp(0, n - 1);
    session.onTileTouched(row * n + col);
  }

  @override
  Widget build(BuildContext context) {
    final n = session.gridSize;
    final round = session.round!;
    return LayoutBuilder(builder: (context, c) {
      final side = math.min(c.maxWidth, c.maxHeight);
      final tile = side / n;

      return GestureDetector(
        onPanStart: (d) => _touch(d.localPosition, side, n),
        onPanUpdate: (d) => _touch(d.localPosition, side, n),
        onPanEnd: (_) => session.endDrag(),
        onTapDown: (d) => _touch(d.localPosition, side, n),
        child: SizedBox(
          width: side,
          height: side,
          child: Stack(
            children: [
              // Connecting path behind the tiles
              Positioned.fill(
                child: CustomPaint(
                  painter: _PathPainter(
                    chain: session.chain,
                    n: n,
                    tile: tile,
                    color: accent,
                  ),
                ),
              ),
              for (int i = 0; i < round.values.length; i++)
                Positioned(
                  left: (i % n) * tile,
                  top: (i ~/ n) * tile,
                  width: tile,
                  height: tile,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: _Tile(
                      value: round.values[i],
                      selected: session.chain.contains(i),
                      glow: session.shouldGlow(i),
                      merged:
                          session.isMerging && session.mergedCells.contains(i),
                      pulse: pulse,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }
}

class _Tile extends StatelessWidget {
  final Object value;
  final bool selected;
  final bool glow;
  final bool merged;
  final double pulse;

  const _Tile({
    required this.value,
    required this.selected,
    required this.glow,
    required this.merged,
    required this.pulse,
  });

  List<Color> _gradient() {
    if (value is! int) {
      // Pairs mode: a single consistent "word tile" palette instead of the
      // magnitude-tiered numeric palette below (which needs an int).
      return const [Color(0xFFBA68C8), Color(0xFF8E24AA)];
    }
    // Warm "maths orange" family; tier varies by magnitude for visual variety.
    const tiers = [
      [Color(0xFFFFB74D), Color(0xFFFF9800)],
      [Color(0xFFFF8A65), Color(0xFFFF6B35)],
      [Color(0xFFFFA726), Color(0xFFF57C00)],
      [Color(0xFFFF7043), Color(0xFFE64A19)],
    ];
    return tiers[(((value as int) - 1) ~/ 8).clamp(0, tiers.length - 1)];
  }

  @override
  Widget build(BuildContext context) {
    final grad = _gradient();
    final glowAlpha = glow ? (0.35 + 0.45 * pulse) : 0.0;
    final isWordTile = value is! int;

    final tile = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      transform: selected
          ? Matrix4.diagonal3Values(1.06, 1.06, 1.0)
          : Matrix4.identity(),
      transformAlignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: grad,
        ),
        borderRadius: BorderRadius.circular(GameTheme.radiusSmall),
        border: Border.all(
          color: selected ? Colors.white : Colors.white.withValues(alpha: 0.4),
          width: selected ? 3 : 1.5,
        ),
        boxShadow: [
          if (glowAlpha > 0)
            BoxShadow(
              color: AppColors.gold.withValues(alpha: glowAlpha),
              blurRadius: 16,
              spreadRadius: 2,
            ),
          BoxShadow(
            color: grad.last.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            maxLines: isWordTile ? 4 : 1,
            style: GameTheme.display(
              isWordTile ? 13 : 26,
              color: Colors.white,
              weight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );

    if (merged) {
      return tile
          .animate()
          .scale(
            duration: 500.ms,
            begin: const Offset(1, 1),
            end: const Offset(1.3, 1.3),
            curve: Curves.easeOut,
          )
          .fadeOut(duration: 500.ms);
    }
    return tile;
  }
}

class _PathPainter extends CustomPainter {
  final List<int> chain;
  final int n;
  final double tile;
  final Color color;

  _PathPainter(
      {required this.chain,
      required this.n,
      required this.tile,
      required this.color});

  Offset _center(int idx) =>
      Offset((idx % n) * tile + tile / 2, (idx ~/ n) * tile + tile / 2);

  @override
  void paint(Canvas canvas, Size size) {
    if (chain.length < 2) return;
    final path = Path()
      ..moveTo(_center(chain.first).dx, _center(chain.first).dy);
    for (int i = 1; i < chain.length; i++) {
      final c = _center(chain[i]);
      path.lineTo(c.dx, c.dy);
    }
    // glow underlay
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.gold.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = tile * 0.34
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    // main line
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = tile * 0.18
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_PathPainter old) =>
      old.chain.length != chain.length || old.tile != tile;
}
