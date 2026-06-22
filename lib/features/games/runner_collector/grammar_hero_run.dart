import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../core/game_config.dart';
import '../core/game_theme.dart';
import '../tug_of_war/widgets/game_result_overlay.dart';
import 'runner_collector_session.dart';

/// Grammar Hero Run — endless runner word-collection game.
///
/// Movement: **swipe up / down** to change lanes (primary). On-screen Up/Down
/// buttons and the arrow keys are accessibility fallbacks. The hero faces the
/// incoming words. A spawn manager (in the session) guarantees one spaced word
/// per lane, so words never overlap. Collect the round's target part of speech;
/// QuestBot cheers correct grabs and gently encourages misses.
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
  late ConfettiController _confetti;
  final FocusNode _focusNode = FocusNode();
  double _lastTick = 0;
  int _lastLevel = 0;

  @override
  void initState() {
    super.initState();
    _session = RunnerCollectorSession(widget.config, _uid);

    _scrollCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    _confetti = ConfettiController(duration: const Duration(milliseconds: 900));

    _scrollCtrl.addListener(_onTick);
    _session.addListener(_onSessionChange);
    _session.startSession();
  }

  String get _uid => (widget.user?.uid as String?) ?? '';

  void _onTick() {
    final now = _scrollCtrl.value;
    final delta = now - _lastTick;
    final adjustedDelta = delta < 0 ? (1.0 + delta) : delta;
    _lastTick = now;
    if (!_session.isFinished) _session.tickWords(adjustedDelta);
  }

  void _onSessionChange() {
    if (_session.levelIndex != _lastLevel) {
      _lastLevel = _session.levelIndex;
      _confetti.play();
    }
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onTick);
    _scrollCtrl.dispose();
    _confetti.dispose();
    _focusNode.dispose();
    _session.removeListener(_onSessionChange);
    _session.dispose();
    super.dispose();
  }

  void _restart() {
    _scrollCtrl.removeListener(_onTick);
    _session.removeListener(_onSessionChange);
    _session.dispose();
    setState(() {
      _session = RunnerCollectorSession(widget.config, _uid);
      _lastLevel = 0;
      _lastTick = 0;
    });
    _scrollCtrl.addListener(_onTick);
    _session.addListener(_onSessionChange);
    _session.startSession();
  }

  void _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _session.moveLeft(); // lane up
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _session.moveRight(); // lane down
    }
  }

  void _onVerticalSwipe(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    if (v < -50) {
      _session.moveLeft(); // swipe up → move to upper lane
    } else if (v > 50) {
      _session.moveRight(); // swipe down → move to lower lane
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _session,
      child: KeyboardListener(
        focusNode: _focusNode..requestFocus(),
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
                child: Stack(
                  children: [
                    Column(
                      children: [
                        _HUD(session: session),
                        Expanded(
                          child: GestureDetector(
                            onVerticalDragEnd: _onVerticalSwipe,
                            child: _RunnerCanvas(
                              session: session,
                              onTapLane: session.tapLane,
                            ),
                          ),
                        ),
                        _LaneButtons(
                          onUp: session.moveLeft,
                          onDown: session.moveRight,
                        ),
                      ],
                    ),

                    // QuestBot feedback bubble (cheer / encourage)
                    if (session.lastCollectionCorrect != null)
                      Positioned(
                        top: 64,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: MascotBubble(
                            positive: session.lastCollectionCorrect == true,
                            message: session.lastCollectionCorrect == true
                                ? 'Nice catch! ✨'
                                : 'Oops — keep looking!',
                          )
                              .animate()
                              .scale(
                                duration: 220.ms,
                                curve: Curves.elasticOut,
                                begin: const Offset(0.6, 0.6),
                                end: const Offset(1, 1),
                              )
                              .fadeIn(duration: 150.ms),
                        ),
                      ),

                    // Level-up confetti
                    Align(
                      alignment: Alignment.topCenter,
                      child: ConfettiWidget(
                        confettiController: _confetti,
                        blastDirectionality: BlastDirectionality.explosive,
                        numberOfParticles: 18,
                        maxBlastForce: 18,
                        minBlastForce: 6,
                        gravity: 0.25,
                        colors: const [
                          AppColors.english,
                          AppColors.gold,
                          Colors.white,
                          AppColors.xpBlue,
                        ],
                      ),
                    ),
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
      color: Colors.black.withValues(alpha: 0.30),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white),
            tooltip: 'Quit',
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  session.missionLabel,
                  textAlign: TextAlign.center,
                  style: GameTheme.display(16, color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  'Collected: ${session.wordsCollected}',
                  style: GameTheme.body(12, color: Colors.white70),
                ),
              ],
            ),
          ),
          Row(
            children: List.generate(3, (i) {
              final alive = i < session.hearts;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Text(alive ? '❤️' : '🖤',
                    style: const TextStyle(fontSize: 18)),
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
      final phase = (DateTime.now().millisecondsSinceEpoch % 2000) / 2000.0;

      return Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _TrackPainter(
                phase: phase,
                activeLane: session.playerLane,
                flash: flash,
              ),
            ),
          ),

          // Per-lane tap targets (accessibility fallback for swipe)
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

          // Hero — faces the incoming words (to the right)
          Positioned(
            left: 20,
            top: session.playerLane * laneH + (laneH / 2) - 26,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 130),
              curve: Curves.easeOut,
              child: const _RunnerHero(),
            ),
          ),

          // Scrolling words on legible neutral pills (colour never reveals POS)
          for (final word in session.activeWords)
            if (!word.collected)
              Positioned(
                left: w - (word.xPosition * w) - 80,
                top: word.lane * laneH + (laneH / 2) - 20,
                child: _WordPill(word: word.word),
              ),
        ],
      );
    });
  }
}

/// Track backdrop: gradient sky, scrolling road with speed dashes, skyline,
/// and a soft glow on the player's active lane.
class _TrackPainter extends CustomPainter {
  final double phase;
  final int activeLane;
  final bool? flash;

  _TrackPainter({required this.phase, required this.activeLane, this.flash});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final laneH = h / 3;

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

    final skyline = Paint()..color = Colors.black.withValues(alpha: 0.25);
    for (int i = 0; i < 10; i++) {
      final bx = (i * w / 9) - (phase * w / 9);
      final bh = 18.0 + (i % 3) * 14.0;
      canvas.drawRect(Rect.fromLTWH(bx, h * 0.18 - bh, w / 14, bh), skyline);
    }

    final glowColor = flash == true
        ? GameTheme.positive
        : flash == false
            ? GameTheme.gentleMiss
            : AppColors.english;
    canvas.drawRect(
      Rect.fromLTWH(0, activeLane * laneH, w, laneH),
      Paint()..color = glowColor.withValues(alpha: 0.16),
    );

    final sep = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..strokeWidth = 2;
    for (int i = 1; i < 3; i++) {
      canvas.drawLine(Offset(0, i * laneH), Offset(w, i * laneH), sep);
    }

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

/// Player avatar with a glow halo and speed trail, flipped to face the words.
class _RunnerHero extends StatelessWidget {
  const _RunnerHero();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 66,
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
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
          // Flip horizontally so the runner faces the incoming words (right).
          Transform(
            alignment: Alignment.center,
            transform: Matrix4.diagonal3Values(-1, 1, 1),
            child: const Text('🏃', style: TextStyle(fontSize: 38)),
          ),
        ],
      ),
    );
  }
}

/// Neutral word card — bright, legible, high-contrast. Deliberately does NOT
/// encode the part of speech in its colour, so the learner must read & decide.
class _WordPill extends StatelessWidget {
  final String word;
  const _WordPill({required this.word});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: GameTheme.minTapTarget),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE0E0F0), width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      child: Text(
        word,
        style: GameTheme.display(18, color: AppColors.textPrimary),
      ),
    );
  }
}

// ── Lane buttons (accessibility fallback) ─────────────────────────────────────

class _LaneButtons extends StatelessWidget {
  final VoidCallback onUp;
  final VoidCallback onDown;

  const _LaneButtons({required this.onUp, required this.onDown});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.30),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _RoundBtn(icon: Icons.keyboard_arrow_up, label: 'Up', onTap: onUp),
          Flexible(
            child: Text(
              'Swipe up / down to move\n(or use these buttons)',
              textAlign: TextAlign.center,
              style: GameTheme.body(12, color: Colors.white60),
            ),
          ),
          _RoundBtn(
              icon: Icons.keyboard_arrow_down, label: 'Down', onTap: onDown),
        ],
      ),
    );
  }
}

class _RoundBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _RoundBtn(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Move $label',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          width: GameTheme.minTapTarget + 8,
          height: GameTheme.minTapTarget + 8,
          decoration: BoxDecoration(
            color: AppColors.english,
            shape: BoxShape.circle,
            boxShadow: GameTheme.softShadow(AppColors.english),
          ),
          child: Icon(icon, color: Colors.white, size: 34),
        ),
      ),
    );
  }
}
