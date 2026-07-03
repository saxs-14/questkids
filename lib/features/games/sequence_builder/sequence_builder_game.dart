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
import 'sequence_builder_session.dart';
import 'water_cycle_scene.dart';

/// Water Cycle Adventure — a guided, visual drag-to-order sequencing game.
class SequenceBuilderGame extends StatefulWidget {
  final GameConfig config;
  final dynamic user;

  const SequenceBuilderGame(
      {super.key, required this.config, required this.user});

  @override
  State<SequenceBuilderGame> createState() => _SequenceBuilderGameState();
}

class _SequenceBuilderGameState extends State<SequenceBuilderGame>
    with TickerProviderStateMixin {
  SequenceBuilderSession? _session;
  Map<String, dynamic>? _pack;
  late AnimationController _ambient;
  late ConfettiController _confetti;
  bool _wasComplete = false;

  static const _teal = AppColors.science;

  String get _uid => (widget.user?.uid as String?) ?? '';

  @override
  void initState() {
    super.initState();
    _ambient =
        AnimationController(vsync: this, duration: const Duration(seconds: 6))
          ..repeat();
    _confetti = ConfettiController(duration: const Duration(milliseconds: 800));
    _initSession();
  }

  Future<void> _initSession() async {
    final pack = await loadContentPack(widget.config);
    if (!mounted) return;
    _pack = pack;
    final session = SequenceBuilderSession(widget.config, _uid, pack: pack)
      ..startSession();
    session.addListener(_onChange);
    setState(() => _session = session);
  }

  void _onChange() {
    final session = _session!;
    if (session.roundComplete && !_wasComplete) _confetti.play();
    _wasComplete = session.roundComplete;
  }

  @override
  void dispose() {
    _session?.removeListener(_onChange);
    _session?.dispose();
    _ambient.dispose();
    _confetti.dispose();
    super.dispose();
  }

  void _restart() {
    _session?.removeListener(_onChange);
    _session?.dispose();
    final session = SequenceBuilderSession(widget.config, _uid, pack: _pack)
      ..startSession();
    setState(() {
      _session = session;
      _wasComplete = false;
    });
    session.addListener(_onChange);
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    if (session == null) {
      return const ContentPackLoadingView(color: _teal);
    }
    return ChangeNotifierProvider.value(
      value: session,
      child: Consumer<SequenceBuilderSession>(
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

          return Scaffold(
            backgroundColor: const Color(0xFFE1F5FE),
            body: SafeArea(
              child: Stack(
                children: [
                  Column(
                    children: [
                      // Header
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            icon: const Icon(Icons.close),
                          ),
                          Expanded(
                            child: Text(session.seqConfig.title,
                                textAlign: TextAlign.center,
                                style: GameTheme.display(18, color: _teal)),
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),

                      // Animated scene
                      Expanded(
                        flex: 5,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(GameTheme.radius),
                          child: AnimatedBuilder(
                            animation: _ambient,
                            builder: (_, __) => WaterCycleScene(
                              revealed: session.revealed,
                              t: _ambient.value,
                            ),
                          ),
                        ),
                      ),

                      // Bottom panel
                      Expanded(
                        flex: 5,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(12),
                          child: session.phase == SequencePhase.learn
                              ? _LearnPanel(
                                  session: session,
                                  onStart: session.startChallenge,
                                )
                              : _OrderPanel(session: session),
                        ),
                      ),
                    ],
                  ),
                  Align(
                    alignment: Alignment.topCenter,
                    child: ConfettiWidget(
                      confettiController: _confetti,
                      blastDirectionality: BlastDirectionality.explosive,
                      numberOfParticles: 18,
                      gravity: 0.3,
                      colors: const [
                        _teal,
                        AppColors.xpBlue,
                        Colors.white,
                        AppColors.gold
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

// ── Learn phase ────────────────────────────────────────────────────────────────
class _LearnPanel extends StatelessWidget {
  final SequenceBuilderSession session;
  final VoidCallback onStart;
  const _LearnPanel({required this.session, required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const MascotBubble(
          message: 'Watch how water travels — then put the steps in order!',
        ),
        const SizedBox(height: 12),
        ...List.generate(session.stages.length, (i) {
          final s = session.stages[i];
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: GameTheme.rounded,
              boxShadow: GameTheme.cardShadow,
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.science.withValues(alpha: 0.15),
                  child: Text('${i + 1}',
                      style: GameTheme.display(16, color: AppColors.science)),
                ),
                const SizedBox(width: 10),
                Text(s.emoji, style: const TextStyle(fontSize: 26)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.label,
                          style: GameTheme.display(16,
                              color: AppColors.textPrimary)),
                      Text(s.description,
                          style: GameTheme.body(12,
                              color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: (120 * i).ms).slideX(begin: 0.15, end: 0);
        }),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onStart,
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text('Start Challenge!',
                style: GameTheme.display(16, color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.science,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: GameTheme.rounded),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Ordering phase ───────────────────────────────────────────────────────────────
class _OrderPanel extends StatelessWidget {
  final SequenceBuilderSession session;
  const _OrderPanel({required this.session});

  @override
  Widget build(BuildContext context) {
    final stages = session.stages;
    final placed = session.placed;
    final correct = session.lastPlaceCorrect;

    final narration = correct == false
        ? 'Not that one yet — which step comes next?'
        : placed.isEmpty
            ? 'Which step comes first?'
            : '${stages[placed.last].label}: ${stages[placed.last].description}';

    return Column(
      children: [
        MascotBubble(positive: correct != false, message: narration),
        const SizedBox(height: 12),

        // Ordered slots
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(stages.length, (i) {
            final filled = i < placed.length;
            final active = i == placed.length;
            Widget slot = Container(
              width: 66,
              constraints: const BoxConstraints(minHeight: 66),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: filled
                    ? GameTheme.positive.withValues(alpha: 0.15)
                    : Colors.white,
                borderRadius: GameTheme.roundedSmall,
                border: Border.all(
                  color: active
                      ? AppColors.science
                      : filled
                          ? GameTheme.positive
                          : Colors.black12,
                  width: active ? 3 : 1.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${i + 1}',
                      style:
                          GameTheme.body(11, color: AppColors.textSecondary)),
                  if (filled) ...[
                    Text(stages[placed[i]].emoji,
                        style: const TextStyle(fontSize: 22)),
                    Text(stages[placed[i]].label,
                        textAlign: TextAlign.center,
                        style: GameTheme.body(9, color: AppColors.textPrimary)),
                  ] else
                    const Icon(Icons.add, color: Colors.black26),
                ],
              ),
            );
            if (active && correct == false) {
              slot = slot.animate().shake(hz: 4, duration: 400.ms);
            }
            if (active) {
              return DragTarget<int>(
                onWillAcceptWithDetails: (_) => true,
                onAcceptWithDetails: (d) => session.placeStage(d.data),
                builder: (_, __, ___) => slot,
              );
            }
            return slot;
          }),
        ),

        const SizedBox(height: 16),
        Text('Drag (or tap) the steps into the right order',
            style: GameTheme.body(12, color: AppColors.textSecondary)),
        const SizedBox(height: 8),

        // Tray of shuffled stages
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: session.tray.map((idx) {
            final s = stages[idx];
            final chip = _TrayChip(emoji: s.emoji, label: s.label);
            return Draggable<int>(
              data: idx,
              feedback: Material(
                color: Colors.transparent,
                child:
                    _TrayChip(emoji: s.emoji, label: s.label, dragging: true),
              ),
              childWhenDragging: Opacity(opacity: 0.3, child: chip),
              child: GestureDetector(
                onTap: () => session.placeStage(idx),
                child: chip,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _TrayChip extends StatelessWidget {
  final String emoji;
  final String label;
  final bool dragging;
  const _TrayChip(
      {required this.emoji, required this.label, this.dragging = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: GameTheme.minTapTarget),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: AppColors.sciGradient),
        borderRadius: BorderRadius.circular(24),
        boxShadow: GameTheme.softShadow(AppColors.science),
        border: Border.all(
            color: Colors.white.withValues(alpha: dragging ? 0.9 : 0.4),
            width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 6),
          Text(label, style: GameTheme.display(15, color: Colors.white)),
        ],
      ),
    );
  }
}
