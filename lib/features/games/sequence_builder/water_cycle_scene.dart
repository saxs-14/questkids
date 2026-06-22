import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Animated water-cycle backdrop. [revealed] (0..4) controls how much of the
/// cycle is shown; [t] (0..1, looping) drives ambient motion. Pure CustomPaint
/// — original art, no bundled assets, works on web + mobile.
class WaterCycleScene extends StatelessWidget {
  final int revealed;
  final double t;
  const WaterCycleScene({super.key, required this.revealed, required this.t});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _WaterCyclePainter(revealed: revealed, t: t),
      size: Size.infinite,
    );
  }
}

class _WaterCyclePainter extends CustomPainter {
  final int revealed;
  final double t;
  _WaterCyclePainter({required this.revealed, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final seaY = h * 0.74;

    // Sky
    final sky = Rect.fromLTWH(0, 0, w, seaY);
    canvas.drawRect(
      sky,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF4FC3F7), Color(0xFFB3E5FC), Color(0xFFE1F5FE)],
        ).createShader(sky),
    );

    // Sun with rotating rays (top-left so it doesn't fight the clouds)
    final sun = Offset(w * 0.16, h * 0.18);
    final rayPaint = Paint()
      ..color = const Color(0xFFFFE082).withValues(alpha: 0.55)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 12; i++) {
      final a = i / 12 * 2 * math.pi + t * 0.8;
      canvas.drawLine(sun + Offset(math.cos(a), math.sin(a)) * 22,
          sun + Offset(math.cos(a), math.sin(a)) * 34, rayPaint);
    }
    canvas.drawCircle(sun, 20, Paint()..color = const Color(0xFFFFD54F));

    // Sea
    final sea = Rect.fromLTWH(0, seaY, w, h - seaY);
    canvas.drawRect(
      sea,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF29B6F6), Color(0xFF0277BD)],
        ).createShader(sea),
    );
    // Wave line
    final wave = Path()..moveTo(0, seaY);
    for (double x = 0; x <= w; x += 20) {
      wave.lineTo(x, seaY + math.sin((x / 40) + t * 2 * math.pi) * 3);
    }
    wave.lineTo(w, seaY);
    canvas.drawPath(
      wave,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // 1 — Evaporation: vapour rising from the sea
    if (revealed >= 1) {
      final vap = Paint()..color = Colors.white.withValues(alpha: 0.5);
      for (int i = 0; i < 8; i++) {
        final baseX = w * (0.2 + 0.07 * i);
        final prog = (t + i * 0.13) % 1.0;
        final y = seaY - prog * (seaY - h * 0.34);
        final r = 4 + 4 * (1 - prog);
        canvas.drawCircle(
          Offset(baseX + math.sin(prog * 6 + i) * 8, y),
          r,
          vap..color = Colors.white.withValues(alpha: 0.45 * (1 - prog)),
        );
      }
    }

    // 2 — Condensation: clouds
    if (revealed >= 2) {
      _cloud(canvas, Offset(w * 0.6, h * 0.26), 1.1);
      _cloud(canvas, Offset(w * 0.78, h * 0.36), 0.8);
    }

    // 3 — Precipitation: rain falling from clouds
    if (revealed >= 3) {
      final rain = Paint()
        ..color = const Color(0xFF4FC3F7)
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;
      for (int i = 0; i < 14; i++) {
        final x = w * (0.5 + 0.03 * i);
        final prog = (t * 1.6 + i * 0.1) % 1.0;
        final y = h * 0.34 + prog * (seaY - h * 0.34);
        canvas.drawLine(Offset(x, y), Offset(x - 2, y + 10), rain);
      }
    }

    // 4 — Collection: river flowing back + cycle arrow
    if (revealed >= 4) {
      final river = Path()
        ..moveTo(w * 0.55, seaY)
        ..quadraticBezierTo(w * 0.4, seaY - 24, w * 0.2, seaY - 6);
      canvas.drawPath(
        river,
        Paint()
          ..color = const Color(0xFF4FC3F7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round,
      );
      // big circular cycle arrow
      final c = Offset(w * 0.5, h * 0.45);
      final arc = Rect.fromCircle(center: c, radius: w * 0.26);
      canvas.drawArc(
        arc,
        -math.pi / 2,
        math.pi * 1.5,
        false,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
      // arrow head
      final ahx = c.dx + w * 0.26 * math.cos(math.pi);
      final ahy = c.dy + w * 0.26 * math.sin(math.pi);
      final head = Path()
        ..moveTo(ahx, ahy - 8)
        ..lineTo(ahx - 10, ahy)
        ..lineTo(ahx, ahy + 8)
        ..close();
      canvas.drawPath(head, Paint()..color = Colors.white.withValues(alpha: 0.6));
    }
  }

  void _cloud(Canvas canvas, Offset c, double s) {
    final p = Paint()..color = Colors.white.withValues(alpha: 0.92);
    canvas.drawCircle(c, 18 * s, p);
    canvas.drawCircle(c + Offset(20 * s, 4 * s), 14 * s, p);
    canvas.drawCircle(c + Offset(-18 * s, 5 * s), 13 * s, p);
    canvas.drawOval(
      Rect.fromCenter(
          center: c + Offset(0, 11 * s), width: 64 * s, height: 20 * s),
      p,
    );
  }

  @override
  bool shouldRepaint(_WaterCyclePainter old) =>
      old.revealed != revealed || old.t != t;
}
