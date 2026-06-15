import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../core/game_config.dart';
import '../tug_of_war/widgets/game_result_overlay.dart';
import 'adventure_journey_session.dart';

/// Adventure Journey game screen — e.g. Water Cycle Quest.
///
/// Architecture: AdventureJourneyGame (UI)
///                  → AdventureJourneySession (state)
///                  → AdventureJourneyEngine (rules)
class AdventureJourneyGame extends StatefulWidget {
  final GameConfig config;
  final dynamic user;

  const AdventureJourneyGame({
    super.key,
    required this.config,
    required this.user,
  });

  @override
  State<AdventureJourneyGame> createState() => _AdventureJourneyGameState();
}

class _AdventureJourneyGameState extends State<AdventureJourneyGame>
    with SingleTickerProviderStateMixin {
  late AdventureJourneySession _session;
  late AnimationController _dropletCtrl;
  late Animation<double> _dropletAnim;

  @override
  void initState() {
    super.initState();
    final uid = (widget.user?.uid as String?) ?? '';
    _session = AdventureJourneySession(widget.config, uid);
    _dropletCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _dropletAnim = Tween<double>(begin: 0, end: 0)
        .animate(CurvedAnimation(parent: _dropletCtrl, curve: Curves.easeOut));
    _session.addListener(_onSessionChange);
    _session.startSession();
  }

  void _onSessionChange() {
    switch (_session.dropletState) {
      case DropletState.advancing:
        _dropletAnim = Tween<double>(begin: 0, end: 40)
            .animate(CurvedAnimation(parent: _dropletCtrl, curve: Curves.easeOut));
        _dropletCtrl.forward(from: 0);
      case DropletState.bouncing:
        _dropletAnim = Tween<double>(begin: -20, end: 0)
            .animate(CurvedAnimation(parent: _dropletCtrl, curve: Curves.elasticOut));
        _dropletCtrl.forward(from: 0);
      case DropletState.idle:
        break;
    }
  }

  @override
  void dispose() {
    _session.removeListener(_onSessionChange);
    _session.dispose();
    _dropletCtrl.dispose();
    super.dispose();
  }

  void _restart() {
    _session.removeListener(_onSessionChange);
    _session.dispose();
    final uid = (widget.user?.uid as String?) ?? '';
    setState(() {
      _session = AdventureJourneySession(widget.config, uid);
    });
    _session.addListener(_onSessionChange);
    _session.startSession();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _session,
      child: Consumer<AdventureJourneySession>(
        builder: (ctx, session, _) {
          if (session.isFinished && session.result != null) {
            return GameResultOverlay(
              result: session.result!,
              playerScore: session.correctCount,
              opponentScore: 0,
              opponentName: '',
              onPlayAgain: _restart,
              onContinue: () => Navigator.of(ctx).pop(),
            );
          }

          final stage = session.currentStage;
          final q = session.currentQuestion;

          return Scaffold(
            body: AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    stage.themeColor,
                    stage.themeColor.withAlpha(180),
                    Colors.white,
                  ],
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    // Top bar
                    _TopBar(
                      stageName: stage.name,
                      stageIndex: session.questionIndex,
                      totalStages: session.totalQuestions,
                      onBack: () => Navigator.of(ctx).pop(),
                    ),

                    // Stage progress dots
                    _StageDots(
                      total: session.totalQuestions,
                      current: session.questionIndex,
                    ),

                    const SizedBox(height: 8),

                    // Droplet character with animation
                    AnimatedBuilder(
                      animation: _dropletAnim,
                      builder: (_, __) => Transform.translate(
                        offset: Offset(0, -_dropletAnim.value),
                        child: Text(
                          session.journeyConfig.characterEmoji,
                          style: const TextStyle(fontSize: 48),
                        ),
                      ),
                    ),

                    const SizedBox(height: 4),

                    // Stage theme emoji
                    Text(stage.emoji, style: const TextStyle(fontSize: 28)),

                    const SizedBox(height: 6),

                    // Feedback banner
                    if (session.feedbackText != null)
                      _FeedbackBanner(
                        text: session.feedbackText!,
                        isCorrect: session.feedbackIsCorrect,
                      ),

                    const Spacer(),

                    // Question card + options
                    if (q != null)
                      _QuestionCard(
                        question: q['question'] as String,
                        options:
                            List<String>.from(q['options'] as List),
                        onAnswer: (opt) => session.submitAnswer(opt),
                        enabled: session.dropletState == DropletState.idle,
                      ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final String stageName;
  final int stageIndex;
  final int totalStages;
  final VoidCallback onBack;
  const _TopBar({
    required this.stageName,
    required this.stageIndex,
    required this.totalStages,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          Expanded(
            child: Text(
              'Stage ${stageIndex + 1}/$totalStages  •  $stageName',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _StageDots extends StatelessWidget {
  final int total;
  final int current;
  const _StageDots({required this.total, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final done = i < current;
        final active = i == current;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 20 : 10,
          height: 10,
          decoration: BoxDecoration(
            color: done
                ? AppColors.green
                : active
                    ? Colors.white
                    : Colors.white38,
            borderRadius: BorderRadius.circular(5),
          ),
        );
      }),
    );
  }
}

class _FeedbackBanner extends StatelessWidget {
  final String text;
  final bool isCorrect;
  const _FeedbackBanner({required this.text, required this.isCorrect});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color:
            isCorrect ? AppColors.green.withAlpha(220) : AppColors.error.withAlpha(220),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final String question;
  final List<String> options;
  final ValueChanged<String> onAnswer;
  final bool enabled;

  const _QuestionCard({
    required this.question,
    required this.options,
    required this.onAnswer,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          Text(
            question,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 3,
            physics: const NeverScrollableScrollPhysics(),
            children: options
                .map(
                  (opt) => ElevatedButton(
                    onPressed: enabled ? () => onAnswer(opt) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    child: Text(
                      opt,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}
