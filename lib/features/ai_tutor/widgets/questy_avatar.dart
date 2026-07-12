import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Questy's emotional states — every widget in the app that shows Questy
/// picks one of these instead of rendering its own ad-hoc emoji/spinner.
enum QuestyExpression { idle, thinking, happy, encouraging, celebrating }

/// Questy's branded avatar — a friendly glowing star character.
/// Replace every 🤖/💡 occurrence in the app with this widget.
class QuestyAvatar extends StatefulWidget {
  final double size;
  final bool glow;
  final QuestyExpression expression;

  const QuestyAvatar({
    super.key,
    this.size = 36,
    this.glow = true,
    this.expression = QuestyExpression.idle,
  });

  @override
  State<QuestyAvatar> createState() => _QuestyAvatarState();
}

class _QuestyAvatarState extends State<QuestyAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _durationFor(widget.expression),
    )..repeat(reverse: _reversesFor(widget.expression));
  }

  @override
  void didUpdateWidget(covariant QuestyAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expression != widget.expression) {
      _controller
        ..duration = _durationFor(widget.expression)
        ..reset()
        ..repeat(reverse: _reversesFor(widget.expression));
    }
  }

  Duration _durationFor(QuestyExpression e) => switch (e) {
        QuestyExpression.thinking => const Duration(milliseconds: 700),
        QuestyExpression.celebrating => const Duration(milliseconds: 500),
        QuestyExpression.happy => const Duration(milliseconds: 900),
        QuestyExpression.encouraging => const Duration(milliseconds: 1100),
        QuestyExpression.idle => const Duration(milliseconds: 1600),
      };

  bool _reversesFor(QuestyExpression e) => e != QuestyExpression.thinking;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        // Gentle vertical bob for idle/happy/encouraging/celebrating;
        // a steady side-to-side tilt for thinking.
        final bob = widget.expression == QuestyExpression.thinking
            ? 0.0
            : math.sin(t * math.pi) * (widget.size * 0.06);
        final tilt = widget.expression == QuestyExpression.thinking
            ? math.sin(t * 2 * math.pi) * 0.12
            : 0.0;
        final scale = widget.expression == QuestyExpression.celebrating
            ? 1.0 + (math.sin(t * math.pi) * 0.08)
            : 1.0;

        return Transform.translate(
          offset: Offset(0, -bob),
          child: Transform.rotate(
            angle: tilt,
            child: Transform.scale(
              scale: scale,
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFE234), Color(0xFFFF9B00)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: widget.glow
                      ? [
                          BoxShadow(
                            color: const Color(0xFFFFB800).withValues(alpha: 0.55),
                            blurRadius: widget.size * 0.35,
                            spreadRadius: widget.size * 0.04,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: CustomPaint(
                    size: Size(widget.size * 0.60, widget.size * 0.60),
                    painter: _StarFacePainter(expression: widget.expression),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Draws a 5-point star with dot-eyes and a smile — Questy's face.
/// The smile/eye shape varies slightly with [expression].
class _StarFacePainter extends CustomPainter {
  final QuestyExpression expression;

  _StarFacePainter({required this.expression});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;
    final innerR = r * 0.42;

    // ── Star body ──────────────────────────────────────────────────────
    final starPath = Path();
    const points = 5;
    const startAngle = -math.pi / 2;
    for (int i = 0; i < points * 2; i++) {
      final radius = i.isEven ? r : innerR;
      final angle = startAngle + (i * math.pi / points);
      final x = cx + radius * math.cos(angle);
      final y = cy + radius * math.sin(angle);
      if (i == 0) {
        starPath.moveTo(x, y);
      } else {
        starPath.lineTo(x, y);
      }
    }
    starPath.close();

    canvas.drawPath(
      starPath,
      Paint()..color = Colors.white.withValues(alpha: 0.92),
    );

    // ── Eyes ──────────────────────────────────────────────────────────
    final eyePaint = Paint()..color = const Color(0xFF5C35F5);
    final isBig = expression == QuestyExpression.encouraging ||
        expression == QuestyExpression.happy ||
        expression == QuestyExpression.celebrating;
    final eyeRadius = r * (isBig ? 0.14 : 0.12);

    if (expression == QuestyExpression.thinking) {
      // One raised eyebrow-like arc instead of dot-eyes, to read as "thinking".
      final browPaint = Paint()
        ..color = const Color(0xFF5C35F5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.08
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCenter(
            center: Offset(cx - r * 0.22, cy - r * 0.12),
            width: r * 0.3,
            height: r * 0.2),
        math.pi,
        math.pi * 0.6,
        false,
        browPaint,
      );
      canvas.drawCircle(
          Offset(cx + r * 0.22, cy - r * 0.08), eyeRadius, eyePaint);
    } else {
      canvas.drawCircle(
          Offset(cx - r * 0.22, cy - r * 0.08), eyeRadius, eyePaint);
      canvas.drawCircle(
          Offset(cx + r * 0.22, cy - r * 0.08), eyeRadius, eyePaint);
    }

    // Tiny eye-shine
    final shinePaint = Paint()..color = Colors.white;
    canvas.drawCircle(
        Offset(cx - r * 0.18, cy - r * 0.12), eyeRadius * 0.4, shinePaint);
    canvas.drawCircle(
        Offset(cx + r * 0.26, cy - r * 0.12), eyeRadius * 0.4, shinePaint);

    // ── Smile ─────────────────────────────────────────────────────────
    final smilePaint = Paint()
      ..color = const Color(0xFF5C35F5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.10
      ..strokeCap = StrokeCap.round;

    if (expression == QuestyExpression.thinking) {
      // A short flat line instead of a smile, while Questy "thinks".
      canvas.drawLine(
        Offset(cx - r * 0.18, cy + r * 0.10),
        Offset(cx + r * 0.18, cy + r * 0.10),
        smilePaint,
      );
      return;
    }

    final wideSmile = expression == QuestyExpression.happy ||
        expression == QuestyExpression.celebrating;
    final smileRect = Rect.fromCenter(
      center: Offset(cx, cy + r * 0.10),
      width: r * (wideSmile ? 0.65 : 0.55),
      height: r * (wideSmile ? 0.34 : 0.28),
    );
    canvas.drawArc(smileRect, 0.15, math.pi - 0.30, false, smilePaint);
  }

  @override
  bool shouldRepaint(covariant _StarFacePainter oldDelegate) =>
      oldDelegate.expression != expression;
}
