import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/activity_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/quiz_provider.dart';
import '../../../providers/ai_tutor_provider.dart';
import '../widgets/question_card.dart';
import '../widgets/quest_start_overlay.dart';
import 'quiz_result_screen.dart';

class QuizScreen extends StatefulWidget {
  final ActivityModel activity;
  const QuizScreen({super.key, required this.activity});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen>
    with TickerProviderStateMixin {
  // Question slide-in / fade
  late final AnimationController _transCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  // Wrong-answer shake
  late final AnimationController _shakeCtrl;
  late final Animation<double> _shakeAnim;

  // Floating "+pts" badge on correct answer
  late final AnimationController _pointsCtrl;
  late final Animation<double> _pointsFade;
  late final Animation<Offset> _pointsSlide;

  bool _showStartOverlay = true;
  bool _showPointsPopup = false;

  @override
  void initState() {
    super.initState();

    _transCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim  = CurvedAnimation(parent: _transCtrl, curve: Curves.easeIn);
    _slideAnim = Tween<Offset>(
            begin: const Offset(0.25, 0), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _transCtrl, curve: Curves.easeOutCubic));

    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _shakeAnim =
        Tween<double>(begin: 0, end: 1).animate(_shakeCtrl);

    _pointsCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _pointsFade = Tween<double>(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(
            parent: _pointsCtrl,
            curve: const Interval(0.45, 1.0, curve: Curves.easeIn)));
    _pointsSlide = Tween<Offset>(
            begin: Offset.zero, end: const Offset(0, -2.0))
        .animate(CurvedAnimation(parent: _pointsCtrl, curve: Curves.easeOut));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<QuizProvider>().startQuiz(widget.activity);
    });
  }

  @override
  void dispose() {
    _transCtrl.dispose();
    _shakeCtrl.dispose();
    _pointsCtrl.dispose();
    super.dispose();
  }

  void _onOverlayComplete() {
    setState(() => _showStartOverlay = false);
    _transCtrl.forward();
  }

  void _onNext(QuizProvider quiz, String uid) async {
    if (!quiz.isAnswerRevealed) {
      quiz.revealAnswer();

      final tutor = context.read<AiTutorProvider>();
      final question = quiz.currentQuestion;

      if (question != null) {
        final isCorrect = quiz.selectedAnswerIndex == question.correctIndex;
        if (isCorrect) {
          tutor.speak('Correct! Outstanding, brave adventurer!');
          setState(() => _showPointsPopup = true);
          _pointsCtrl.forward(from: 0).then((_) {
            if (mounted) setState(() => _showPointsPopup = false);
          });
        } else {
          _shakeCtrl.forward(from: 0);
          final user = context.read<AuthProvider>().user;
          tutor.speak('Not quite. Let me guide you...');
          final explanation = await tutor.explainAnswer(
            question: question.question,
            correctAnswer: question.options[question.correctIndex],
            subject: widget.activity.subject,
            grade: user?.grade ?? 'Grade 1',
          );
          tutor.speak('The answer is: $explanation');
        }
      }
    } else if (quiz.isLastQuestion) {
      quiz.submitQuiz(uid).then((_) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ChangeNotifierProvider.value(
                value: quiz,
                child: const QuizResultScreen(),
              ),
            ),
          );
        }
      });
    } else {
      _transCtrl.reverse().then((_) {
        quiz.nextQuestion();
        _transCtrl.forward();
      });
    }
  }

  double get _shakeOffset => sin(_shakeAnim.value * pi * 6) * 10.0;

  @override
  Widget build(BuildContext context) {
    final quiz = context.watch<QuizProvider>();
    final uid = context.read<AuthProvider>().user?.uid ?? '';

    if (quiz.state == QuizState.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final question = quiz.currentQuestion;
    if (question == null) return const SizedBox();

    return Scaffold(
      appBar: AppBar(
        title: Text('⚔️ ${widget.activity.title}',
            overflow: TextOverflow.ellipsis),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Abandon Quest?'),
                content: const Text('Your progress on this quest will be lost.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Keep Fighting!'),
                  ),
                  TextButton(
                    onPressed: () {
                      quiz.resetQuiz();
                      Navigator.pop(context);
                      Navigator.pop(context);
                    },
                    child: const Text('Abandon',
                        style: TextStyle(color: AppColors.error)),
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.lightbulb_outline),
            tooltip: 'Ask QuestBot for a hint',
            onPressed: () async {
              final tutor = context.read<AiTutorProvider>();
              final hint = await tutor.getHint(
                question.question,
                widget.activity.subject,
              );
              if (!context.mounted) return;
              showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                builder: (_) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('💡', style: TextStyle(fontSize: 24)),
                          const SizedBox(width: 12),
                          Text('QuestBot Hint', style: AppTextStyles.h3),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(hint, style: AppTextStyles.bodyMedium),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Got it! Onward! ⚔️'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Quest progress dots + correct counter
              _QuestProgressBar(
                currentIndex: quiz.currentQuestionIndex,
                total: quiz.totalQuestions,
                correctCount: quiz.correctCount,
              ),

              // Question card — shake on wrong, slide+fade on transition
              Expanded(
                child: AnimatedBuilder(
                  animation: _shakeAnim,
                  builder: (_, child) => Transform.translate(
                    offset: Offset(_shakeOffset, 0),
                    child: child,
                  ),
                  child: SlideTransition(
                    position: _slideAnim,
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: QuestionCard(
                          question: question,
                          selectedIndex: quiz.selectedAnswerIndex,
                          isRevealed: quiz.isAnswerRevealed,
                          onOptionSelected: quiz.selectAnswer,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Action button
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: ElevatedButton(
                  onPressed: quiz.selectedAnswerIndex == null &&
                          !quiz.isAnswerRevealed
                      ? null
                      : () => _onNext(quiz, uid),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 54),
                    backgroundColor: quiz.isAnswerRevealed
                        ? (quiz.isLastQuestion
                            ? AppColors.green
                            : AppColors.primary)
                        : AppColors.primary,
                  ),
                  child: Text(
                    quiz.isAnswerRevealed
                        ? (quiz.isLastQuestion
                            ? '🏆 Complete Quest!'
                            : 'Next Challenge →')
                        : 'Reveal! ⚔️',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),

          // Floating "+pts" badge
          if (_showPointsPopup)
            Positioned(
              left: 0,
              right: 0,
              top: MediaQuery.of(context).size.height * 0.38,
              child: IgnorePointer(
                child: SlideTransition(
                  position: _pointsSlide,
                  child: FadeTransition(
                    opacity: _pointsFade,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                              color: AppColors.gold, width: 1.5),
                        ),
                        child: Text(
                          '✨ +10 pts',
                          style: TextStyle(
                            color: AppColors.gold,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            shadows: [
                              Shadow(
                                color: AppColors.gold.withValues(alpha: 0.5),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Full-screen intro overlay
          if (_showStartOverlay)
            Positioned.fill(
              child: QuestStartOverlay(
                questTitle: widget.activity.title,
                subject: widget.activity.subject,
                difficulty: widget.activity.difficulty,
                onComplete: _onOverlayComplete,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Quest progress bar with animated dots ────────────────────────────────────

class _QuestProgressBar extends StatelessWidget {
  final int currentIndex;
  final int total;
  final int correctCount;

  const _QuestProgressBar({
    required this.currentIndex,
    required this.total,
    required this.correctCount,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Challenge ${currentIndex + 1} of $total',
                style: AppTextStyles.bodySmall
                    .copyWith(fontWeight: FontWeight.w600),
              ),
              Row(
                children: [
                  const Text('⚔️', style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 4),
                  Text(
                    '$correctCount conquered',
                    style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.green,
                        fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(total, (i) {
              final isDone    = i < currentIndex;
              final isCurrent = i == currentIndex;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: isCurrent ? 26 : 10,
                height: 10,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  color: isDone
                      ? AppColors.green
                      : isCurrent
                          ? AppColors.primary
                          : AppColors.primary.withValues(alpha: 0.18),
                  boxShadow: isCurrent
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.4),
                            blurRadius: 6,
                          )
                        ]
                      : null,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
