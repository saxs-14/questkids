import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../core/game_config.dart';
import '../tug_of_war/widgets/game_result_overlay.dart';
import 'runner_collector_session.dart';

/// Grammar Hero Run — endless runner word-collection game.
///
/// Touch: tap a lane to move into it.
/// Keyboard: left/right arrow keys.
/// Words scroll from right to left; collect matching part-of-speech words.
class GrammarHeroRun extends StatefulWidget {
  final GameConfig config;
  final dynamic user;

  const GrammarHeroRun({super.key, required this.config, required this.user});

  @override
  State<GrammarHeroRun> createState() => _GrammarHeroRunState();
}

class _GrammarHeroRunState extends State<GrammarHeroRun>
    with SingleTickerProviderStateMixin {
  late RunnerCollectorSession _session;
  late AnimationController _scrollCtrl;
  double _lastTick = 0;

  @override
  void initState() {
    super.initState();
    final uid = (widget.user?.uid as String?) ?? '';
    _session = RunnerCollectorSession(widget.config, uid);

    _scrollCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();

    _scrollCtrl.addListener(_onTick);
    _session.startSession();
  }

  void _onTick() {
    final now = _scrollCtrl.value;
    final delta = now - _lastTick;
    // Handle wrap-around
    final adjustedDelta = delta < 0 ? (1.0 + delta) : delta;
    _lastTick = now;
    if (!_session.isFinished) {
      _session.tickWords(adjustedDelta);
    }
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onTick);
    _scrollCtrl.dispose();
    _session.dispose();
    super.dispose();
  }

  void _restart() {
    _scrollCtrl.removeListener(_onTick);
    _session.dispose();
    final uid = (widget.user?.uid as String?) ?? '';
    setState(() {
      _session = RunnerCollectorSession(widget.config, uid);
    });
    _scrollCtrl.addListener(_onTick);
    _lastTick = 0;
    _session.startSession();
  }

  void _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _session.moveLeft();
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _session.moveRight();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _session,
      child: KeyboardListener(
        focusNode: FocusNode()..requestFocus(),
        onKeyEvent: _handleKey,
        child: Consumer<RunnerCollectorSession>(
          builder: (ctx, session, _) {
            if (session.isFinished && session.result != null) {
              return GameResultOverlay(
                result: session.result!,
                playerScore: session.wordsCollected,
                opponentScore: 0,
                opponentName: '',
                onPlayAgain: _restart,
                onContinue: () => Navigator.of(ctx).pop(),
              );
            }

            return Scaffold(
              backgroundColor: const Color(0xFF1A1A2E),
              body: SafeArea(
                child: Column(
                  children: [
                    _HUD(session: session),
                    Expanded(
                      child: _RunnerCanvas(
                        session: session,
                        onTapLane: session.tapLane,
                      ),
                    ),
                    _LaneButtons(onLeft: session.moveLeft, onRight: session.moveRight),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── HUD ───────────────────────────────────────────────────────────────────────

class _HUD extends StatelessWidget {
  final RunnerCollectorSession session;
  const _HUD({required this.session});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black45,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white),
            padding: EdgeInsets.zero,
          ),
          Expanded(
            child: Text(
              session.missionLabel,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          // Hearts
          Row(
            children: List.generate(3, (i) {
              return Text(
                i < session.hearts ? '❤️' : '🖤',
                style: const TextStyle(fontSize: 18),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ── Runner Canvas ─────────────────────────────────────────────────────────────

class _RunnerCanvas extends StatelessWidget {
  final RunnerCollectorSession session;
  final ValueChanged<int> onTapLane;

  const _RunnerCanvas({required this.session, required this.onTapLane});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;
      final laneH = h / 3;
      final flash = session.lastCollectionCorrect;
      // Continuous scroll phase for the parallax track (time-based, smooth).
      final phase =
          (DateTime.now().millisecondsSinceEpoch % 2000) / 2000.0;

      return Stack(
        children: [
          // Painted scrolling track (sky, road, speed dashes, lane glow).
          Positioned.fill(
            child: CustomPaint(
              painter: _TrackPainter(
                phase: phase,
                activeLane: session.playerLane,
                flash: flash,
              ),
            ),
          ),

          // Tap targets per lane
          for (int i = 0; i < 3; i++)
            Positioned(
              top: i * laneH,
              left: 0,
              right: 0,
              height: laneH,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onTapLane(i),
              ),
            ),

          // Player character with motion trail + glow
          Positioned(
            left: 24,
            top: session.playerLane * laneH + (laneH / 2) - 26,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              child: const _RunnerHero(),
            ),
          ),

          // Scrolling words
          for (final word in session.activeWords)
            if (!word.collected)
              Positioned(
                left: w - (word.xPosition * w) - 80,
                top: word.lane * laneH + (laneH / 2) - 18,
                child: _WordChip(
                  word: word.word,
                  partOfSpeech: word.partOfSpeech,
                  targetPOS: session.currentLevel.targetPOS,
                ),
              ),
        ],
      );
    });
  }
}

/// Paints the endless-runner track: gradient sky, scrolling road with
/// dashed speed lines, and a soft glow on the player's active lane.
class _TrackPainter extends CustomPainter {
  final double phase; // 0..1 scroll loop
  final int activeLane;
  final bool? flash; // true=correct, false=wrong, null=neutral

  _TrackPainter({required this.phase, required this.activeLane, this.flash});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final laneH = h / 3;

    // Sky-to-track vertical gradient
    final bg = Rect.fromLTWH(0, 0, w, h);
    canvas.drawRect(
      bg,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF311B92), Color(0xFF512DA8), Color(0xFF1A1A2E)],
        ).createShader(bg),
    );

    // Distant city skyline silhouette near the horizon
    final skyline = Paint()..color = Colors.black.withValues(alpha: 0.25);
    for (int i = 0; i < 10; i++) {
      final bx = (i * w / 9) - (phase * w / 9);
      final bh = 18.0 + (i % 3) * 14.0;
      canvas.drawRect(Rect.fromLTWH(bx, h * 0.18 - bh, w / 14, bh), skyline);
    }

    // Lane glow on the active lane
    final glowColor = flash == true
        ? AppColors.success
        : flash == false
            ? AppColors.error
            : AppColors.english;
    final glowRect = Rect.fromLTWH(0, activeLane * laneH, w, laneH);
    canvas.drawRect(
      glowRect,
      Paint()..color = glowColor.withValues(alpha: 0.16),
    );

    // Lane separators
    final sep = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..strokeWidth = 2;
    for (int i = 1; i < 3; i++) {
      canvas.drawLine(Offset(0, i * laneH), Offset(w, i * laneH), sep);
    }

    // Scrolling dashed centre lines per lane (sense of speed)
    final dash = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    const dashW = 34.0;
    const gap = 26.0;
    for (int lane = 0; lane < 3; lane++) {
      final y = lane * laneH + laneH / 2;
      double x = -((phase * (dashW + gap)) % (dashW + gap));
      while (x < w) {
        canvas.drawLine(Offset(x, y), Offset(x + dashW, y), dash);
        x += dashW + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_TrackPainter old) =>
      old.phase != phase || old.activeLane != activeLane || old.flash != flash;
}

/// Player avatar with a glow halo and a small speed trail.
class _RunnerHero extends StatelessWidget {
  const _RunnerHero();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // speed trail
          Positioned(
            left: 0,
            child: Row(
              children: List.generate(3, (i) {
                return Container(
                  width: 6 + i * 3.0,
                  height: 3,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: AppColors.english.withValues(alpha: 0.25 + i * 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            ),
          ),
          // glow halo
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                AppColors.english.withValues(alpha: 0.45),
                Colors.transparent,
              ]),
            ),
          ),
          Transform.translate(
            offset: Offset(0, math.sin(DateTime.now().millisecondsSinceEpoch / 120) * 2),
            child: const Text('🏃', style: TextStyle(fontSize: 38)),
          ),
        ],
      ),
    );
  }
}

class _WordChip extends StatelessWidget {
  final String word;
  final String partOfSpeech;
  final String targetPOS;

  const _WordChip({
    required this.word,
    required this.partOfSpeech,
    required this.targetPOS,
  });

  @override
  Widget build(BuildContext context) {
    final isTarget = targetPOS == 'mixed'
        ? partOfSpeech == 'noun' || partOfSpeech == 'verb'
        : partOfSpeech == targetPOS;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isTarget
              ? [AppColors.english, const Color(0xFFFF4081)]
              : [Colors.blueGrey.shade600, Colors.blueGrey.shade800],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: (isTarget ? AppColors.english : Colors.black)
                .withValues(alpha: 0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        word,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 15,
        ),
      ),
    );
  }
}

// ── Lane buttons (mobile helpers) ─────────────────────────────────────────────

class _LaneButtons extends StatelessWidget {
  final VoidCallback onLeft;
  final VoidCallback onRight;

  const _LaneButtons({required this.onLeft, required this.onRight});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black45,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ElevatedButton.icon(
            onPressed: onLeft,
            icon: const Icon(Icons.arrow_upward),
            label: const Text('Up'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.blue),
          ),
          const Text(
            'Move up/down\n← → keys on desktop',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 11),
          ),
          ElevatedButton.icon(
            onPressed: onRight,
            icon: const Icon(Icons.arrow_downward),
            label: const Text('Down'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.blue),
          ),
        ],
      ),
    );
  }
}
