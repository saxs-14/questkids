import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Rich animated tug-of-war arena.
///
/// [flagPosition] in [-1.0, 1.0]:
///   -1.0 = flag fully pulled to opponent's side
///    0.0 = center (tied)
///   +1.0 = flag fully pulled to player's side
///
/// The scene draws a full game backdrop (sky, sun, drifting clouds, rolling
/// hills, grassy pitch), a sagging rope that tilts toward whoever is winning,
/// a waving centre flag, and two characters that lean/strain. A looping
/// [AnimationController] drives ambient motion (clouds, sun rays, flag wave)
/// while a second controller eases the flag between positions.
class RopeScene extends StatefulWidget {
  final double flagPosition;
  final String playerEmoji;
  final String opponentEmoji;
  final String opponentName;

  const RopeScene({
    super.key,
    required this.flagPosition,
    this.playerEmoji = '🧑',
    this.opponentEmoji = '👾',
    this.opponentName = 'Opponent',
  });

  @override
  State<RopeScene> createState() => _RopeSceneState();
}

class _RopeSceneState extends State<RopeScene> with TickerProviderStateMixin {
  late final AnimationController _moveCtrl;   // eases flag between positions
  late final AnimationController _ambientCtrl; // never-ending background motion
  late Animation<double> _flagAnim;
  double _prevFlag = 0.0;

  @override
  void initState() {
    super.initState();
    _moveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _ambientCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _flagAnim = AlwaysStoppedAnimation(widget.flagPosition);
    _prevFlag = widget.flagPosition;
  }

  @override
  void didUpdateWidget(RopeScene old) {
    super.didUpdateWidget(old);
    if (old.flagPosition != widget.flagPosition) {
      final from = _flagAnim.value;
      _flagAnim = Tween<double>(begin: from, end: widget.flagPosition).animate(
        CurvedAnimation(parent: _moveCtrl, curve: Curves.easeOutBack),
      );
      _prevFlag = old.flagPosition;
      _moveCtrl.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _moveCtrl.dispose();
    _ambientCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: AnimatedBuilder(
        animation: Listenable.merge([_moveCtrl, _ambientCtrl]),
        builder: (context, _) {
          final pos = _flagAnim.value.clamp(-1.0, 1.0);
          final t = _ambientCtrl.value; // 0..1 looping
          final playerPulling = pos > _prevFlag || pos > 0.05;
          final opponentPulling = pos < _prevFlag || pos < -0.05;

          return LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final h = constraints.maxHeight;

              return SizedBox(
                width: w,
                height: h,
                child: Stack(
                  children: [
                    // Painted arena: sky, sun, clouds, hills, grass, rope, flag.
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _ArenaPainter(pos: pos, t: t),
                      ),
                    ),

                    // Player character (left side)
                    Positioned(
                      left: w * 0.04,
                      top: h * 0.30,
                      child: _CharacterWidget(
                        emoji: widget.playerEmoji,
                        isPulling: playerPulling,
                        isLosing: pos < -0.35,
                        facingRight: true,
                        wobble: t,
                      ),
                    ),

                    // Opponent character (right side)
                    Positioned(
                      right: w * 0.04,
                      top: h * 0.30,
                      child: _CharacterWidget(
                        emoji: widget.opponentEmoji,
                        isPulling: opponentPulling,
                        isLosing: pos > 0.35,
                        facingRight: false,
                        wobble: t + 0.5,
                      ),
                    ),

                    // Score zones label (subtle)
                    const Positioned(
                      left: 10,
                      bottom: 8,
                      child: _ZoneTag(label: 'YOU', color: AppColors.blue),
                    ),
                    Positioned(
                      right: 10,
                      bottom: 8,
                      child: _ZoneTag(
                        label: widget.opponentName.toUpperCase(),
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Paints the full arena backdrop plus the rope and centre flag.
class _ArenaPainter extends CustomPainter {
  final double pos; // -1..1 flag position
  final double t;   // 0..1 ambient loop

  _ArenaPainter({required this.pos, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final groundY = h * 0.72;

    // ── Sky gradient ──────────────────────────────────────────────────────
    final skyRect = Rect.fromLTWH(0, 0, w, groundY);
    canvas.drawRect(
      skyRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF4FC3F7), Color(0xFFB3E5FC), Color(0xFFE1F5FE)],
        ).createShader(skyRect),
    );

    // ── Sun with soft pulsing rays ────────────────────────────────────────
    final sunCenter = Offset(w * 0.82, h * 0.16);
    final raysPaint = Paint()
      ..color = const Color(0xFFFFE082).withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final rayLen = 16 + 4 * math.sin(t * 2 * math.pi);
    for (int i = 0; i < 12; i++) {
      final a = (i / 12) * 2 * math.pi + t * 0.6;
      final inner = sunCenter + Offset(math.cos(a), math.sin(a)) * 22;
      final outer = sunCenter + Offset(math.cos(a), math.sin(a)) * (22 + rayLen);
      canvas.drawLine(inner, outer, raysPaint);
    }
    canvas.drawCircle(sunCenter, 18, Paint()..color = const Color(0xFFFFD54F));
    canvas.drawCircle(
      sunCenter,
      18,
      Paint()
        ..color = const Color(0xFFFFF59D)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );

    // ── Drifting clouds ───────────────────────────────────────────────────
    final cloudPaint = Paint()..color = Colors.white.withValues(alpha: 0.85);
    _drawCloud(canvas, Offset((w * (0.15 + t)) % (w + 80) - 40, h * 0.18), 1.0, cloudPaint);
    _drawCloud(canvas, Offset((w * (0.55 + t * 0.6)) % (w + 100) - 50, h * 0.30), 0.7, cloudPaint);

    // ── Rolling hills ─────────────────────────────────────────────────────
    final hill1 = Path()..moveTo(0, groundY);
    hill1.quadraticBezierTo(w * 0.25, groundY - h * 0.18, w * 0.5, groundY - h * 0.04);
    hill1.quadraticBezierTo(w * 0.78, groundY + h * 0.10, w, groundY - h * 0.10);
    hill1.lineTo(w, groundY);
    hill1.close();
    canvas.drawPath(hill1, Paint()..color = const Color(0xFF81C784).withValues(alpha: 0.7));

    // ── Grassy pitch ──────────────────────────────────────────────────────
    final groundRect = Rect.fromLTWH(0, groundY, w, h - groundY);
    canvas.drawRect(
      groundRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF66BB6A), Color(0xFF43A047)],
        ).createShader(groundRect),
    );
    // Mud pit beneath the rope centre
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w / 2, groundY + 6), width: w * 0.3, height: 18),
      Paint()..color = const Color(0xFF5D4037).withValues(alpha: 0.55),
    );

    // ── Side tint showing who is winning ──────────────────────────────────
    if (pos.abs() > 0.02) {
      final winColor = pos > 0 ? AppColors.blue : AppColors.accent;
      final glowRect = pos > 0
          ? Rect.fromLTWH(0, 0, w * 0.5, groundY)
          : Rect.fromLTWH(w * 0.5, 0, w * 0.5, groundY);
      canvas.drawRect(
        glowRect,
        Paint()..color = winColor.withValues(alpha: 0.08 * pos.abs()),
      );
    }

    // ── The rope (sags + tilts toward the winner) ─────────────────────────
    final ropeY = h * 0.52;
    final centerX = w / 2;
    final maxOffset = (centerX - 36).clamp(40.0, 260.0);
    final flagX = centerX + pos * maxOffset;

    final leftAnchor = Offset(w * 0.12, ropeY);
    final rightAnchor = Offset(w * 0.88, ropeY);
    final knot = Offset(flagX, ropeY + 14 + 6 * math.sin(t * 2 * math.pi)); // sag + jitter

    final ropePath = Path()..moveTo(leftAnchor.dx, leftAnchor.dy);
    ropePath.quadraticBezierTo(
      (leftAnchor.dx + knot.dx) / 2, knot.dy + 8, knot.dx, knot.dy);
    ropePath.quadraticBezierTo(
      (rightAnchor.dx + knot.dx) / 2, knot.dy + 8, rightAnchor.dx, rightAnchor.dy);

    // rope shadow
    canvas.drawPath(
      ropePath.shift(const Offset(0, 4)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round,
    );
    // rope body
    canvas.drawPath(
      ropePath,
      Paint()
        ..color = const Color(0xFF8D6E63)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round,
    );
    // rope highlight (braided look)
    canvas.drawPath(
      ropePath,
      Paint()
        ..color = const Color(0xFFD7B49E).withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );

    // ── Centre line (fair start marker) ───────────────────────────────────
    canvas.drawLine(
      Offset(centerX, ropeY - 30),
      Offset(centerX, groundY),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.6)
        ..strokeWidth = 2,
    );

    // ── The knot + waving flag ────────────────────────────────────────────
    canvas.drawCircle(knot, 9, Paint()..color = const Color(0xFF5D4037));
    canvas.drawCircle(knot, 9,
        Paint()..color = const Color(0xFFD7B49E)..style = PaintingStyle.stroke..strokeWidth = 2);

    // pole
    final poleTop = Offset(knot.dx, knot.dy - 46);
    canvas.drawLine(
      knot, poleTop,
      Paint()
        ..color = const Color(0xFF455A64)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    // waving flag triangle
    final wave = 6 * math.sin(t * 2 * math.pi * 2);
    final flagColor = pos > 0.05
        ? AppColors.blue
        : pos < -0.05
            ? AppColors.accent
            : AppColors.gold;
    final flag = Path()
      ..moveTo(poleTop.dx, poleTop.dy)
      ..quadraticBezierTo(
          poleTop.dx + 16, poleTop.dy + 6 + wave, poleTop.dx + 30, poleTop.dy + 2)
      ..lineTo(poleTop.dx, poleTop.dy + 16)
      ..close();
    canvas.drawPath(flag, Paint()..color = flagColor);
    canvas.drawPath(
      flag,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // ── Tension sparks at the knot when not tied ──────────────────────────
    if (pos.abs() > 0.15) {
      final sparkPaint = Paint()..color = AppColors.gold.withValues(alpha: 0.9);
      for (int i = 0; i < 4; i++) {
        final a = (i / 4) * 2 * math.pi + t * 4 * math.pi;
        final r = 12 + 4 * math.sin(t * 6 * math.pi + i);
        canvas.drawCircle(knot + Offset(math.cos(a), math.sin(a)) * r, 1.8, sparkPaint);
      }
    }
  }

  void _drawCloud(Canvas canvas, Offset c, double scale, Paint paint) {
    canvas.drawCircle(c, 16 * scale, paint);
    canvas.drawCircle(c + Offset(18 * scale, 4 * scale), 13 * scale, paint);
    canvas.drawCircle(c + Offset(-16 * scale, 5 * scale), 12 * scale, paint);
    canvas.drawOval(
      Rect.fromCenter(
          center: c + Offset(0, 10 * scale), width: 56 * scale, height: 18 * scale),
      paint,
    );
  }

  @override
  bool shouldRepaint(_ArenaPainter old) => old.pos != pos || old.t != t;
}

class _CharacterWidget extends StatelessWidget {
  final String emoji;
  final bool isPulling;
  final bool isLosing;
  final bool facingRight;
  final double wobble;

  const _CharacterWidget({
    required this.emoji,
    required this.isPulling,
    required this.isLosing,
    required this.facingRight,
    required this.wobble,
  });

  @override
  Widget build(BuildContext context) {
    // Winning side leans forward; losing side stumbles back; idle sways gently.
    final strain = 0.05 * math.sin(wobble * 2 * math.pi);
    final angle = isLosing
        ? (facingRight ? 0.32 : -0.32)
        : (isPulling ? (facingRight ? -0.22 : 0.22) : strain);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.rotate(
          angle: angle,
          child: Text(
            emoji,
            style: TextStyle(
              fontSize: 44,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 2),
        // ground shadow
        Container(
          width: 34,
          height: 7,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }
}

class _ZoneTag extends StatelessWidget {
  final String label;
  final Color color;
  const _ZoneTag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
