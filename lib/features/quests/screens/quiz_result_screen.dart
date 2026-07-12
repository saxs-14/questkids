import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../providers/quiz_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/rewards_provider.dart';
import '../../../providers/ai_tutor_provider.dart';
import '../../ai_tutor/widgets/questy_avatar.dart';
import '../../ai_tutor/widgets/questy_dialogue.dart';
import '../../rewards/widgets/badge_earned_dialog.dart';

class QuizResultScreen extends StatefulWidget {
  const QuizResultScreen({super.key});

  @override
  State<QuizResultScreen> createState() => _QuizResultScreenState();
}

class _QuizResultScreenState extends State<QuizResultScreen>
    with TickerProviderStateMixin {
  late final ConfettiController _confettiCtrl;

  // Animated score counter
  late final AnimationController _scoreCtrl;
  late final Animation<int> _scoreCount;

  // Emoji bounce
  late final AnimationController _emojiCtrl;
  late final Animation<double> _emojiScale;

  // Staggered stats row
  late final AnimationController _statsCtrl;
  late final Animation<Offset> _stat0Slide;
  late final Animation<double> _stat0Fade;
  late final Animation<Offset> _stat1Slide;
  late final Animation<double> _stat1Fade;
  late final Animation<Offset> _stat2Slide;
  late final Animation<double> _stat2Fade;

  @override
  void initState() {
    super.initState();

    final quiz = context.read<QuizProvider>();
    final finalScore = quiz.finalScore;
    final passed = finalScore >= 60;

    _confettiCtrl = ConfettiController(duration: const Duration(seconds: 3));

    _scoreCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _scoreCount = IntTween(begin: 0, end: finalScore)
        .animate(CurvedAnimation(parent: _scoreCtrl, curve: Curves.easeOut));

    _emojiCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _emojiScale = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _emojiCtrl, curve: Curves.elasticOut));

    _statsCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _stat0Slide = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _statsCtrl,
            curve: const Interval(0.0, 0.6, curve: Curves.easeOut)));
    _stat0Fade =
        CurvedAnimation(parent: _statsCtrl, curve: const Interval(0.0, 0.4));
    _stat1Slide = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _statsCtrl,
            curve: const Interval(0.2, 0.8, curve: Curves.easeOut)));
    _stat1Fade =
        CurvedAnimation(parent: _statsCtrl, curve: const Interval(0.2, 0.6));
    _stat2Slide = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _statsCtrl,
            curve: const Interval(0.4, 1.0, curve: Curves.easeOut)));
    _stat2Fade =
        CurvedAnimation(parent: _statsCtrl, curve: const Interval(0.4, 0.8));

    // Sequence: emoji → score → stats → confetti
    _emojiCtrl.forward().then((_) {
      _scoreCtrl.forward().then((_) {
        _statsCtrl.forward();
        if (passed) _confettiCtrl.play();
      });
    });
  }

  @override
  void dispose() {
    _confettiCtrl.dispose();
    _scoreCtrl.dispose();
    _emojiCtrl.dispose();
    _statsCtrl.dispose();
    super.dispose();
  }

  Color _scoreColor(int score) {
    if (score == 100) return AppColors.gold;
    if (score >= 80) return AppColors.green;
    if (score >= 60) return AppColors.primary;
    if (score >= 40) return AppColors.orange;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    final quiz = context.watch<QuizProvider>();
    final passed = quiz.finalScore >= 60;

    return Scaffold(
      body: Stack(
        children: [
          // Confetti cannon — centered at top
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiCtrl,
              blastDirectionality: BlastDirectionality.explosive,
              numberOfParticles: 30,
              gravity: 0.2,
              colors: const [
                AppColors.gold,
                AppColors.primary,
                AppColors.green,
                AppColors.accent,
                Colors.cyan,
              ],
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 24),

                  // Animated emoji
                  ScaleTransition(
                    scale: _emojiScale,
                    child: Text(
                      quiz.scoreEmoji,
                      style: const TextStyle(fontSize: 80),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Text(
                    passed ? '⚔️ Quest Complete! ⚔️' : 'Quest Failed',
                    style: AppTextStyles.h2.copyWith(
                      color: passed ? AppColors.primary : AppColors.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    quiz.scoreMessage,
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Animated score circle
                  AnimatedBuilder(
                    animation: _scoreCount,
                    builder: (_, __) {
                      final displayed = _scoreCount.value;
                      return Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              _scoreColor(displayed),
                              _scoreColor(displayed).withValues(alpha: 0.55),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _scoreColor(displayed)
                                  .withValues(alpha: 0.35),
                              blurRadius: 28,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$displayed%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 42,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const Text(
                                'Score',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 32),

                  // Staggered stats row
                  Row(
                    children: [
                      _AnimatedStat(
                        slide: _stat0Slide,
                        fade: _stat0Fade,
                        label: 'Challenges Won',
                        value: '${quiz.correctCount}/${quiz.totalQuestions}',
                        emoji: '⚔️',
                        color: AppColors.green,
                      ),
                      const SizedBox(width: 12),
                      _AnimatedStat(
                        slide: _stat1Slide,
                        fade: _stat1Fade,
                        label: 'XP Earned',
                        value: '+${quiz.pointsEarned}',
                        emoji: '⭐',
                        color: AppColors.gold,
                      ),
                      const SizedBox(width: 12),
                      _AnimatedStat(
                        slide: _stat2Slide,
                        fade: _stat2Fade,
                        label: 'Accuracy',
                        value: '${quiz.finalScore}%',
                        emoji: '🎯',
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Answer review
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Quest Review', style: AppTextStyles.h3),
                  ),
                  const SizedBox(height: 12),
                  if (quiz.currentActivity != null)
                    ...List.generate(quiz.currentActivity!.questions.length,
                        (i) {
                      final q = quiz.currentActivity!.questions[i];
                      final userAnswer = quiz.userAnswers.length > i
                          ? quiz.userAnswers[i]
                          : null;
                      final isCorrect = userAnswer == q.correctIndex;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isCorrect
                              ? AppColors.green.withValues(alpha: 0.1)
                              : AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isCorrect
                                ? AppColors.green.withValues(alpha: 0.3)
                                : AppColors.error.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(isCorrect ? '✅' : '❌',
                                style: const TextStyle(fontSize: 20)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    q.question,
                                    style: AppTextStyles.bodyMedium
                                        .copyWith(fontWeight: FontWeight.w600),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (!isCorrect) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Correct: ${q.options[q.correctIndex]}',
                                      style: AppTextStyles.bodySmall.copyWith(
                                        color: AppColors.green,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  const SizedBox(height: 32),

                  // Action buttons
                  ElevatedButton(
                    onPressed: () async {
                      final uid = context.read<AuthProvider>().user?.uid ?? '';
                      final rewardsProvider = context.read<RewardsProvider>();
                      final lastQuizTimeSeconds =
                          context.read<QuizProvider>().currentActivity != null
                              ? 60
                              : 0;
                      await rewardsProvider.loadRewards(uid);
                      if (!context.mounted) return;
                      await rewardsProvider.checkForNewBadges(
                        uid: uid,
                        lastQuizTimeSeconds: lastQuizTimeSeconds,
                      );
                      if (rewardsProvider.newlyEarnedBadges.isNotEmpty &&
                          context.mounted) {
                        for (final badge in rewardsProvider.newlyEarnedBadges) {
                          await showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (_) => BadgeEarnedDialog(
                              badge: badge,
                              onDismiss: () => Navigator.pop(context),
                            ),
                          );
                        }
                        rewardsProvider.clearNewBadges();
                      }
                      if (rewardsProvider.leveledUpTo != null &&
                          context.mounted) {
                        final line = QuestyDialogue.celebrateLevelUp(
                            rewardsProvider.leveledUpTo!);
                        context.read<AiTutorProvider>().speak(line);
                        await showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (dialogContext) => AlertDialog(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20)),
                            content: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const QuestyAvatar(
                                    size: 40,
                                    expression: QuestyExpression.celebrating),
                                const SizedBox(width: 16),
                                Expanded(child: Text(line)),
                              ],
                            ),
                            actions: [
                              ElevatedButton(
                                onPressed: () => Navigator.pop(dialogContext),
                                child: const Text('Yay! 🚀'),
                              ),
                            ],
                          ),
                        );
                        rewardsProvider.clearLevelUp();
                      }
                      if (context.mounted) {
                        context.read<QuizProvider>().resetQuiz();
                        Navigator.popUntil(context, (r) => r.isFirst);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 54),
                    ),
                    child: const Text('Back to Quests 🏠'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () {
                      final activity = quiz.currentActivity;
                      if (activity != null) {
                        quiz.startQuiz(activity);
                        Navigator.pop(context);
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 54),
                    ),
                    child: const Text('Quest Replay ↺'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedStat extends StatelessWidget {
  final Animation<Offset> slide;
  final Animation<double> fade;
  final String label;
  final String value;
  final String emoji;
  final Color color;

  const _AnimatedStat({
    required this.slide,
    required this.fade,
    required this.label,
    required this.value,
    required this.emoji,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SlideTransition(
        position: slide,
        child: FadeTransition(
          opacity: fade,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(height: 6),
                Text(value, style: AppTextStyles.h4.copyWith(color: color)),
                Text(label,
                    style: AppTextStyles.bodySmall,
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
