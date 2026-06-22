import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Questy's branded avatar — a friendly glowing star character.
/// Replace every 🤖 occurrence in the AI-tutor flow with this widget.
class QuestyAvatar extends StatelessWidget {
  final double size;
  final bool glow;

  const QuestyAvatar({super.key, this.size = 36, this.glow = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFE234), Color(0xFFFF9B00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: glow
            ? [
                BoxShadow(
                  color: const Color(0xFFFFB800).withValues(alpha: 0.55),
                  blurRadius: size * 0.35,
                  spreadRadius: size * 0.04,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Center(
        child: CustomPaint(
          size: Size(size * 0.60, size * 0.60),
          painter: _StarFacePainter(),
        ),
      ),
    );
  }
}

/// Draws a 5-point star with cute dot-eyes and a smile — Questy's face.
class _StarFacePainter extends CustomPainter {
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
    final eyeRadius = r * 0.12;
    canvas.drawCircle(Offset(cx - r * 0.22, cy - r * 0.08), eyeRadius, eyePaint);
    canvas.drawCircle(Offset(cx + r * 0.22, cy - r * 0.08), eyeRadius, eyePaint);

    // Tiny eye-shine
    final shinePaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(cx - r * 0.18, cy - r * 0.12), eyeRadius * 0.4, shinePaint);
    canvas.drawCircle(Offset(cx + r * 0.26, cy - r * 0.12), eyeRadius * 0.4, shinePaint);

    // ── Smile ─────────────────────────────────────────────────────────
    final smilePaint = Paint()
      ..color = const Color(0xFF5C35F5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.10
      ..strokeCap = StrokeCap.round;

    final smileRect = Rect.fromCenter(
      center: Offset(cx, cy + r * 0.10),
      width: r * 0.55,
      height: r * 0.28,
    );
    canvas.drawArc(smileRect, 0.15, math.pi - 0.30, false, smilePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
