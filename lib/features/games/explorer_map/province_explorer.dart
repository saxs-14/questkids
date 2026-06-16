import 'dart:math' as math;

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
          // Painted explorer-map backdrop: ocean, landmass, graticule, compass.
          Padding(
            padding: const EdgeInsets.all(12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CustomPaint(
                size: Size(w, h),
                painter: _MapBackdropPainter(),
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

/// Paints a stylised explorer map: ocean gradient, a soft landmass, a
/// latitude/longitude graticule, and a compass rose in the corner.
class _MapBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Ocean gradient
    final ocean = Rect.fromLTWH(0, 0, w, h);
    canvas.drawRect(
      ocean,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1976D2), Color(0xFF0D47A1), Color(0xFF01579B)],
        ).createShader(ocean),
    );

    // Graticule (lat/long grid)
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..strokeWidth = 1;
    for (double x = w * 0.1; x < w; x += w * 0.12) {
      canvas.drawLine(Offset(x, 0), Offset(x, h), grid);
    }
    for (double y = h * 0.1; y < h; y += h * 0.14) {
      canvas.drawLine(Offset(0, y), Offset(w, y), grid);
    }

    // Stylised landmass blob (centre)
    final land = Path();
    land.moveTo(w * 0.30, h * 0.20);
    land.cubicTo(w * 0.55, h * 0.10, w * 0.80, h * 0.22, w * 0.78, h * 0.45);
    land.cubicTo(w * 0.76, h * 0.70, w * 0.58, h * 0.88, w * 0.42, h * 0.80);
    land.cubicTo(w * 0.24, h * 0.72, w * 0.18, h * 0.45, w * 0.22, h * 0.34);
    land.cubicTo(w * 0.24, h * 0.26, w * 0.26, h * 0.22, w * 0.30, h * 0.20);
    land.close();
    canvas.drawPath(
      land,
      Paint()..color = const Color(0xFF66BB6A).withValues(alpha: 0.55),
    );
    canvas.drawPath(
      land,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Compass rose (top-left)
    final cc = Offset(w * 0.12, h * 0.14);
    const r = 16.0;
    final rosePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(cc, r, rosePaint);
    for (int i = 0; i < 4; i++) {
      final a = i * math.pi / 2;
      final p1 = cc + Offset(math.cos(a), math.sin(a)) * r;
      final p2 = cc - Offset(math.cos(a), math.sin(a)) * r;
      canvas.drawLine(p1, p2, rosePaint);
    }
    // North needle
    final needle = Path()
      ..moveTo(cc.dx, cc.dy - r - 4)
      ..lineTo(cc.dx - 4, cc.dy)
      ..lineTo(cc.dx + 4, cc.dy)
      ..close();
    canvas.drawPath(needle, Paint()..color = const Color(0xFFFF5252));
  }

  @override
  bool shouldRepaint(_MapBackdropPainter old) => false;
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
