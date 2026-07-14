import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/quest_boy_mascot.dart';
import '../../../providers/ai_tutor_provider.dart';
import '../core/game_config.dart';
import '../core/numeric_keyboard_mixin.dart';
import 'tug_of_war_session.dart';
import 'widgets/game_result_overlay.dart';
import 'widgets/rope_scene.dart';
import 'widgets/tug_of_war_keypad.dart';

/// Main Tug of War game screen.
///
/// Architecture: TugOfWarGame (UI) → TugOfWarSession (state) → TugOfWarEngine
///
/// Keyboard: physical 0–9 / Enter / Backspace are forwarded via
/// [NumericKeyboardMixin]; the [Focus] node captures them when the
/// widget has focus.
class TugOfWarGame extends StatefulWidget {
  final GameConfig config;
  final dynamic user;

  const TugOfWarGame({super.key, required this.config, required this.user});

  @override
  State<TugOfWarGame> createState() => _TugOfWarGameState();
}

class _TugOfWarGameState extends State<TugOfWarGame>
    with NumericKeyboardMixin<TugOfWarGame> {
  late TugOfWarSession _session;
  bool _hintLoading = false;
  String? _hintText;

  String get _uid => (widget.user?.uid as String?) ?? '';

  @override
  void initState() {
    super.initState();
    _session = TugOfWarSession(widget.config, _uid);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _session.startSession());
  }

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  // ── NumericKeyboardMixin callbacks ─────────────────────────────────────────

  @override
  void handleDigit(String digit) => _session.appendDigit(digit);

  @override
  void handleConfirm() {
    if (_session.currentInput.isNotEmpty) {
      _session.submitAnswer(_session.currentInput);
    }
  }

  @override
  void handleBackspace() => _session.clearInput();

  // ── QuestBot hint ────────────────────────────────────────────────────────

  Future<void> _fetchHint() async {
    final q = _session.currentQuestion;
    if (q == null || _hintLoading) return;
    setState(() => _hintLoading = true);
    final hint = await context.read<AiTutorProvider>().getHint(
          q['display'] as String,
          widget.config.subject,
        );
    if (mounted) {
      setState(() {
        _hintText = hint;
        _hintLoading = false;
      });
    }
  }

  // ── Play-again ─────────────────────────────────────────────────────────────

  void _restart() {
    _session.dispose();
    setState(() {
      _session = TugOfWarSession(widget.config, _uid);
      _hintText = null;
    });
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _session.startSession());
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _session,
      child: Focus(
        focusNode: keyboardFocusNode,
        onKeyEvent: onKeyEvent,
        autofocus: true,
        child: Consumer<TugOfWarSession>(
          builder: (ctx, session, _) {
            if (session.isFinished && session.result != null) {
              return GameResultOverlay(
                result: session.result!,
                playerScore: session.playerScore,
                opponentScore: session.opponentScore,
                opponentName: widget.config.opponentName,
                onPlayAgain: _restart,
                onContinue: () => Navigator.of(ctx).pop(),
              );
            }

            return Scaffold(
              backgroundColor: AppColors.backgroundLight,
              body: SafeArea(
                child: Column(
                  children: [
                    _TitleBar(
                      topicName: widget.config.subtopicId.isEmpty
                          ? widget.config.subject
                          : widget.config.subtopicId
                              .replaceAll('_', ' ')
                              .toUpperCase(),
                      elapsedSeconds: session.elapsedSeconds,
                      onHint: _fetchHint,
                      hintLoading: _hintLoading,
                    ),

                    // Hint bubble
                    if (_hintText != null)
                      _HintBubble(
                        text: _hintText!,
                        onDismiss: () => setState(() => _hintText = null),
                      ),

                    // Main game area
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          // Wide layout: 3-panel split (matches reference video)
                          // Narrow: player + rope stacked vertically
                          if (constraints.maxWidth >= 560) {
                            return _WideLayout(
                              session: session,
                              config: widget.config,
                              user: widget.user,
                              onDigit: (d) => session.appendDigit(d),
                              onClear: session.clearInput,
                              onConfirm: () {
                                if (session.currentInput.isNotEmpty) {
                                  session.submitAnswer(session.currentInput);
                                }
                              },
                            );
                          }
                          return _NarrowLayout(
                            session: session,
                            config: widget.config,
                            user: widget.user,
                            onDigit: (d) => session.appendDigit(d),
                            onClear: session.clearInput,
                            onConfirm: () {
                              if (session.currentInput.isNotEmpty) {
                                session.submitAnswer(session.currentInput);
                              }
                            },
                          );
                        },
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

// ── Title Bar ────────────────────────────────────────────────────────────────

class _TitleBar extends StatelessWidget {
  final String topicName;
  final int elapsedSeconds;
  final VoidCallback onHint;
  final bool hintLoading;

  const _TitleBar({
    required this.topicName,
    required this.elapsedSeconds,
    required this.onHint,
    required this.hintLoading,
  });

  @override
  Widget build(BuildContext context) {
    final mm = (elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final ss = (elapsedSeconds % 60).toString().padLeft(2, '0');
    return Container(
      color: AppColors.primary,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          // Back
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            padding: EdgeInsets.zero,
          ),
          // Title
          Expanded(
            child: Text(
              'TUG OF WAR: $topicName',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
          ),
          // Timer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$mm:$ss',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Hint button
          IconButton(
            onPressed: onHint,
            icon: hintLoading
                ? const QuestBoyMascot(size: 24, state: QuestBoyState.knowledge)
                : const QuestBoyMascot(size: 24, state: QuestBoyState.waving),
            tooltip: 'QuestBot hint',
          ),
        ],
      ),
    );
  }
}

// ── Hint Bubble ───────────────────────────────────────────────────────────────

class _HintBubble extends StatelessWidget {
  final String text;
  final VoidCallback onDismiss;
  const _HintBubble({required this.text, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.gold.withAlpha(40),
        border: Border.all(color: AppColors.gold),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const QuestBoyMascot(size: 22, state: QuestBoyState.waving),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textPrimary)),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.close,
                size: 18, color: AppColors.textSecondary),
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}

// ── Wide Layout (>= 560 px) ───────────────────────────────────────────────────

class _WideLayout extends StatelessWidget {
  final TugOfWarSession session;
  final GameConfig config;
  final dynamic user;
  final ValueChanged<String> onDigit;
  final VoidCallback onClear;
  final VoidCallback onConfirm;

  const _WideLayout({
    required this.session,
    required this.config,
    required this.user,
    required this.onDigit,
    required this.onClear,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Player panel (blue) ──────────────────────────────────────────────
        Expanded(
          flex: 5,
          child: _PlayerPanel(
            session: session,
            user: user,
            onDigit: onDigit,
            onClear: onClear,
            onConfirm: onConfirm,
          ),
        ),

        // ── Center: rope scene ───────────────────────────────────────────────
        Expanded(
          flex: 4,
          child: _CenterPanel(session: session, config: config),
        ),

        // ── Opponent panel (red) ─────────────────────────────────────────────
        Expanded(
          flex: 5,
          child: _OpponentPanel(session: session, config: config),
        ),
      ],
    );
  }
}

// ── Narrow Layout (< 560 px) ──────────────────────────────────────────────────

class _NarrowLayout extends StatelessWidget {
  final TugOfWarSession session;
  final GameConfig config;
  final dynamic user;
  final ValueChanged<String> onDigit;
  final VoidCallback onClear;
  final VoidCallback onConfirm;

  const _NarrowLayout({
    required this.session,
    required this.config,
    required this.user,
    required this.onDigit,
    required this.onClear,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Compact scoreboard
        _NarrowScoreBar(session: session, config: config),
        // Rope (compact height)
        SizedBox(
          height: 100,
          child: RopeScene(
            flagPosition: session.flagPosition,
            opponentName: config.opponentName,
            opponentEmoji: config.opponentEmoji,
          ),
        ),
        // Question + keypad
        Expanded(
          child: _PlayerPanel(
            session: session,
            user: user,
            onDigit: onDigit,
            onClear: onClear,
            onConfirm: onConfirm,
            compact: true,
          ),
        ),
      ],
    );
  }
}

class _NarrowScoreBar extends StatelessWidget {
  final TugOfWarSession session;
  final GameConfig config;
  const _NarrowScoreBar({required this.session, required this.config});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.backgroundLight,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('You: ${session.playerScore}',
              style: const TextStyle(
                  color: AppColors.blue, fontWeight: FontWeight.bold)),
          Text('vs  ${config.opponentEmoji}  ${config.opponentName}',
              style: const TextStyle(color: AppColors.textSecondary)),
          Text('${config.opponentName}: ${session.opponentScore}',
              style: const TextStyle(
                  color: AppColors.accent, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// ── Player Panel ──────────────────────────────────────────────────────────────

class _PlayerPanel extends StatelessWidget {
  final TugOfWarSession session;
  final dynamic user;
  final ValueChanged<String> onDigit;
  final VoidCallback onClear;
  final VoidCallback onConfirm;
  final bool compact;

  const _PlayerPanel({
    required this.session,
    required this.user,
    required this.onDigit,
    required this.onClear,
    required this.onConfirm,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final q = session.currentQuestion;
    final avatarName = (user?.name as String?)?.isNotEmpty == true
        ? (user!.name as String)
        : 'You';
    final initial = avatarName.isNotEmpty ? avatarName[0].toUpperCase() : 'Y';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: session.lastAnswerCorrect == true
            ? AppColors.green.withAlpha(30)
            : session.lastAnswerCorrect == false
                ? AppColors.error.withAlpha(30)
                : AppColors.blue.withAlpha(12),
        border: Border(
          right: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: Column(
          children: [
            // Avatar + score
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: compact ? 16 : 20,
                  backgroundColor: AppColors.blue,
                  child: Text(initial,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      avatarName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: compact ? 12 : 14,
                        color: AppColors.blue,
                      ),
                    ),
                    Text(
                      'Score: ${session.playerScore}',
                      style: TextStyle(
                        fontSize: compact ? 11 : 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Question
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2)),
                ],
              ),
              child: Text(
                q != null ? q['display'] as String : '...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: compact ? 20 : 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Progress
            LinearProgressIndicator(
              value: session.progressFraction,
              backgroundColor: Colors.grey.shade200,
              color: AppColors.blue,
              minHeight: 5,
              borderRadius: BorderRadius.circular(3),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${session.questionIndex + 1} / ${session.totalQuestions}',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary),
              ),
            ),

            const SizedBox(height: 8),

            // Keypad
            Expanded(
              child: TugOfWarKeypad(
                currentInput: session.currentInput,
                lastAnswerCorrect: session.lastAnswerCorrect,
                onDigit: onDigit,
                onClear: onClear,
                onConfirm: onConfirm,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Center Panel (rope scene) ─────────────────────────────────────────────────

class _CenterPanel extends StatelessWidget {
  final TugOfWarSession session;
  final GameConfig config;
  const _CenterPanel({required this.session, required this.config});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: RopeScene(
        flagPosition: session.flagPosition,
        opponentName: config.opponentName,
        opponentEmoji: config.opponentEmoji,
      ),
    );
  }
}

// ── Opponent Panel ────────────────────────────────────────────────────────────

class _OpponentPanel extends StatelessWidget {
  final TugOfWarSession session;
  final GameConfig config;
  const _OpponentPanel({required this.session, required this.config});

  @override
  Widget build(BuildContext context) {
    final oq = session.opponentCurrentQuestion;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.accent.withAlpha(12),
        border: Border(
          left: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(
        children: [
          // Avatar + score
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(config.opponentEmoji, style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    config.opponentName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.accent,
                    ),
                  ),
                  Text(
                    'Score: ${session.opponentScore}',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Opponent question (cosmetic)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              oq != null ? oq['display'] as String : '...',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade400,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Greyed-out keypad (visual parity only — not interactive)
          Expanded(
            child: TugOfWarKeypad(
              currentInput: '???',
              enabled: false,
              onDigit: (_) {},
              onClear: () {},
              onConfirm: () {},
            ),
          ),
        ],
      ),
    );
  }
}
