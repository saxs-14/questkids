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

      return Stack(
        children: [
          // Lane backgrounds
          for (int i = 0; i < 3; i++)
            Positioned(
              top: i * laneH,
              left: 0,
              right: 0,
              height: laneH,
              child: GestureDetector(
                onTap: () => onTapLane(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  color: session.playerLane == i
                      ? (flash == true
                          ? AppColors.green.withAlpha(80)
                          : flash == false
                              ? AppColors.error.withAlpha(80)
                              : Colors.white12)
                      : Colors.transparent,
                  child: const Divider(color: Colors.white10, thickness: 1),
                ),
              ),
            ),

          // Player character
          Positioned(
            left: 24,
            top: session.playerLane * laneH + (laneH / 2) - 20,
            child: const Text('🏃', style: TextStyle(fontSize: 36)),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isTarget ? AppColors.blue : Colors.grey.shade700,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        word,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
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
