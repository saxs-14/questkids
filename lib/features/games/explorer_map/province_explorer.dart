import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../core/game_config.dart';
import '../tug_of_war/widgets/game_result_overlay.dart';
import 'explorer_map_config.dart';
import 'explorer_map_session.dart';

/// SA Provinces Explorer — tap the correct province from a multiple-choice list.
///
/// The map pins give spatial context; the answer buttons are accessible chips
/// so the game works on small screens without requiring precise map taps.
class ProvinceExplorer extends StatefulWidget {
  final GameConfig config;
  final dynamic user;

  const ProvinceExplorer({super.key, required this.config, required this.user});

  @override
  State<ProvinceExplorer> createState() => _ProvinceExplorerState();
}

class _ProvinceExplorerState extends State<ProvinceExplorer>
    with SingleTickerProviderStateMixin {
  late ExplorerMapSession _session;
  late AnimationController _pinCtrl;

  @override
  void initState() {
    super.initState();
    final uid = (widget.user?.uid as String?) ?? '';
    _session = ExplorerMapSession(widget.config, uid);
    _pinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _session.startSession();
  }

  @override
  void dispose() {
    _pinCtrl.dispose();
    _session.dispose();
    super.dispose();
  }

  void _restart() {
    _session.dispose();
    final uid = (widget.user?.uid as String?) ?? '';
    setState(() {
      _session = ExplorerMapSession(widget.config, uid);
    });
    _pinCtrl.reset();
    _session.startSession();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _session,
      child: Consumer<ExplorerMapSession>(
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

          final q = session.currentQuestion;
          if (q == null) return const SizedBox.shrink();

          return Scaffold(
            backgroundColor: const Color(0xFF0D47A1),
            body: SafeArea(
              child: Column(
                children: [
                  _TopBar(
                    questionIndex: session.questionIndex,
                    total: session.totalQuestions,
                    elapsed: session.elapsedSeconds,
                    onBack: () => Navigator.of(ctx).pop(),
                  ),
                  Expanded(
                    flex: 5,
                    child: _MapView(
                      provinces: session.mapConfig.provinces,
                      correctId: q['correctId'] as String,
                      selectedId: session.selectedId,
                      lastCorrect: session.lastAnswerCorrect,
                    ),
                  ),
                  if (session.feedbackFact != null)
                    _FeedbackBanner(
                      fact: session.feedbackFact!,
                      correct: session.lastAnswerCorrect ?? false,
                    ),
                  Expanded(
                    flex: 3,
                    child: _AnswerPanel(
                      question: q['question'] as String,
                      options: session.currentOptions,
                      selectedId: session.selectedId,
                      lastCorrect: session.lastAnswerCorrect,
                      enabled: !session.awaitingNext,
                      onTap: session.submitAnswer,
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

// ── Top bar ───────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final int questionIndex;
  final int total;
  final int elapsed;
  final VoidCallback onBack;

  const _TopBar({
    required this.questionIndex,
    required this.total,
    required this.elapsed,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final min = (elapsed ~/ 60).toString().padLeft(2, '0');
    final sec = (elapsed % 60).toString().padLeft(2, '0');
    return Container(
      color: Colors.black26,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.close, color: Colors.white),
            padding: EdgeInsets.zero,
          ),
          Expanded(
            child: LinearProgressIndicator(
              value: total > 0 ? questionIndex / total : 0,
              backgroundColor: Colors.white24,
              color: AppColors.green,
              minHeight: 6,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$min:$sec',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ── Map view with province pins ───────────────────────────────────────────────

class _MapView extends StatelessWidget {
  final List<ProvincePin> provinces;
  final String correctId;
  final String? selectedId;
  final bool? lastCorrect;

  const _MapView({
    required this.provinces,
    required this.correctId,
    required this.selectedId,
    required this.lastCorrect,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;

      return Stack(
        children: [
          // Map background — outline SA map
          Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1565C0),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white24),
            ),
            child: const Center(
              child: Text(
                '🗺️',
                style: TextStyle(fontSize: 80, color: Colors.white30),
              ),
            ),
          ),
          // Province pins
          for (final pin in provinces)
            Positioned(
              left: pin.position.dx * (w - 48) + 12,
              top: pin.position.dy * (h - 48) + 12,
              child: _ProvincePin(
                pin: pin,
                isCorrect: pin.id == correctId,
                isSelected: pin.id == selectedId,
                lastCorrect: lastCorrect,
              ),
            ),
        ],
      );
    });
  }
}

class _ProvincePin extends StatelessWidget {
  final ProvincePin pin;
  final bool isCorrect;
  final bool isSelected;
  final bool? lastCorrect;

  const _ProvincePin({
    required this.pin,
    required this.isCorrect,
    required this.isSelected,
    required this.lastCorrect,
  });

  @override
  Widget build(BuildContext context) {
    Color bg = pin.color.withAlpha(180);
    if (isSelected) {
      bg = (lastCorrect == true) ? AppColors.green : AppColors.error;
    } else if (lastCorrect != null && isCorrect) {
      bg = AppColors.green;
    }

    return Tooltip(
      message: '${pin.name}\n${pin.capital}',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4)],
        ),
        child: Center(
          child: Text(
            pin.id.length <= 2 ? pin.id : pin.id.substring(0, 2),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 7,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Feedback banner ───────────────────────────────────────────────────────────

class _FeedbackBanner extends StatelessWidget {
  final String fact;
  final bool correct;

  const _FeedbackBanner({required this.fact, required this.correct});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: correct ? AppColors.green.withAlpha(230) : AppColors.error.withAlpha(230),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(correct ? '✅' : '❌', style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              fact,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Answer panel ──────────────────────────────────────────────────────────────

class _AnswerPanel extends StatelessWidget {
  final String question;
  final List<ProvincePin> options;
  final String? selectedId;
  final bool? lastCorrect;
  final bool enabled;
  final ValueChanged<String> onTap;

  const _AnswerPanel({
    required this.question,
    required this.options,
    required this.selectedId,
    required this.lastCorrect,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
          Text(
            question,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: options.map((pin) {
              final isSelected = pin.id == selectedId;
              Color chipColor = pin.color;
              if (isSelected) {
                chipColor = (lastCorrect == true) ? AppColors.green : AppColors.error;
              }
              return GestureDetector(
                onTap: enabled ? () => onTap(pin.id) : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: chipColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.white30,
                      width: isSelected ? 2.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(pin.emoji, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 6),
                      Text(
                        pin.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
