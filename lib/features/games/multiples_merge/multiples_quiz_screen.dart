import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../core/game_config.dart';
import '../core/game_theme.dart';
import '../tug_of_war/widgets/game_result_overlay.dart';
import 'multiples_quiz.dart';

/// Weekly Quiz — strict, timed times-tables recall. Separate entry point from
/// the everyday Multiples Merge game.
class MultiplesQuizScreen extends StatefulWidget {
  final GameConfig config;
  final dynamic user;

  const MultiplesQuizScreen(
      {super.key, required this.config, required this.user});

  @override
  State<MultiplesQuizScreen> createState() => _MultiplesQuizScreenState();
}

class _MultiplesQuizScreenState extends State<MultiplesQuizScreen> {
  late MultiplesQuizSession _session;

  String get _uid => (widget.user?.uid as String?) ?? '';

  @override
  void initState() {
    super.initState();
    _session = MultiplesQuizSession(widget.config, _uid)..startSession();
  }

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  void _restart() {
    _session.dispose();
    setState(() =>
        _session = MultiplesQuizSession(widget.config, _uid)..startSession());
  }

  @override
  Widget build(BuildContext context) {
    const accent = AppColors.math; // orange identity

    return ChangeNotifierProvider.value(
      value: _session,
      child: Consumer<MultiplesQuizSession>(
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

          final q = session.currentQuestion;
          if (q == null) return const SizedBox.shrink();
          final options = List<int>.from(q['options'] as List);

          return Scaffold(
            backgroundColor: AppColors.backgroundLight,
            body: SafeArea(
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: const Icon(Icons.close),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Text('Weekly Times-Tables Quiz',
                                  style: GameTheme.display(18, color: accent)),
                              Text(
                                'Question ${session.questionIndex + 1} of ${session.totalQuestions}',
                                style: GameTheme.body(13,
                                    color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        _TimerChip(seconds: session.elapsedSeconds),
                      ],
                    ),
                  ),
                  LinearProgressIndicator(
                    value: session.progressFraction,
                    backgroundColor: accent.withValues(alpha: 0.15),
                    color: accent,
                    minHeight: 6,
                  ),
                  const Spacer(),

                  // Prompt
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.symmetric(
                        vertical: 32, horizontal: 24),
                    decoration: BoxDecoration(
                      gradient:
                          const LinearGradient(colors: AppColors.mathGradient),
                      borderRadius:
                          BorderRadius.circular(GameTheme.radiusLarge),
                      boxShadow: GameTheme.softShadow(accent),
                    ),
                    child: Text(
                      q['prompt'] as String,
                      textAlign: TextAlign.center,
                      style: GameTheme.display(40,
                          color: Colors.white, weight: FontWeight.w700),
                    ),
                  ),

                  const Spacer(),

                  // Options
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 2.2,
                      physics: const NeverScrollableScrollPhysics(),
                      children: options.map((opt) {
                        final isAnswer = opt == q['answer'];
                        final isSelected = session.selected == opt;
                        Color bg = Colors.white;
                        Color fg = AppColors.textPrimary;
                        if (session.locked) {
                          if (isAnswer) {
                            bg = GameTheme.positive;
                            fg = Colors.white;
                          } else if (isSelected) {
                            bg = GameTheme.gentleMiss;
                            fg = Colors.white;
                          }
                        }
                        return GestureDetector(
                          onTap: session.locked
                              ? null
                              : () => session.submitAnswer(opt),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            constraints: const BoxConstraints(
                                minHeight: GameTheme.minTapTarget),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: bg,
                              borderRadius: GameTheme.rounded,
                              border: Border.all(
                                  color: accent.withValues(alpha: 0.35),
                                  width: 2),
                              boxShadow: GameTheme.cardShadow,
                            ),
                            child: Text('$opt',
                                style: GameTheme.display(28, color: fg)),
                          ),
                        );
                      }).toList(),
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

class _TimerChip extends StatelessWidget {
  final int seconds;
  const _TimerChip({required this.seconds});

  @override
  Widget build(BuildContext context) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.math.withValues(alpha: 0.12),
        borderRadius: GameTheme.roundedSmall,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_outlined, size: 16, color: AppColors.math),
          const SizedBox(width: 4),
          Text('$m:$s',
              style: GameTheme.body(13,
                  color: AppColors.math, weight: FontWeight.w700)),
        ],
      ),
    );
  }
}
