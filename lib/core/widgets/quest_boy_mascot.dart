import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Quest Boy — the app's mascot, replacing "Questy". The old
/// `QuestyAvatar` widget (previously at
/// lib/features/ai_tutor/widgets/questy_avatar.dart) has been removed;
/// every call site now uses this widget instead.
///
/// **Provenance note:** drawn with [CustomPainter] primitives (composed
/// simple shapes, not traced bezier art), matching the style precedent
/// already established by the old `QuestyAvatar`'s `_StarFacePainter` in
/// this codebase. Trued up against the user-supplied "Quest for
/// Knowledge" reference art: tan pith helmet with a blue compass-rose
/// emblem, brown hair fringe, orange hoodie, navy vest with belt-level
/// utility pouches, cuffed denim shorts, visible white socks, white
/// sneakers with brown trim, and a glowing purple book with a gold star
/// for the knowledge pose (the reference's exact pose/prop). Geometry
/// still can't be visually previewed in this environment -- if it's off,
/// adjust the shape constants in [_QuestBoyPainter], which is independent
/// of the state-machine below.
///
/// **Rive swap point:** `rive` is not currently a project dependency (it
/// was removed in a prior cleanup for having zero usage). Once real Rive
/// `.riv` art exists, add the dependency and replace only [build] below
/// with a `RiveAnimation.asset(...)` driven by [state] -- the public API
/// ([QuestBoyMascot] constructor: `size`/`state`/`glow`) is deliberately
/// stable so no call site needs to change when that swap happens.
enum QuestBoyState {
  /// Idle/greeting pose — used on loading screens, home, transitions,
  /// empty states.
  waving,

  /// Holding a glowing book — used at Challenge intros and QuestBot hints.
  knowledge,

  /// Trophy + star medal raised — used on win/results screens and badge
  /// unlocks.
  achievement,

  /// Holding a game controller, leaning in — used at Challenge/arcade
  /// entry screens.
  gaming,
}

class QuestBoyMascot extends StatefulWidget {
  final double size;
  final QuestBoyState state;
  final bool glow;

  const QuestBoyMascot({
    super.key,
    this.size = 96,
    this.state = QuestBoyState.waving,
    this.glow = false,
  });

  @override
  State<QuestBoyMascot> createState() => _QuestBoyMascotState();
}

class _QuestBoyMascotState extends State<QuestBoyMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _durationFor(widget.state),
  );

  // Deliberately no initState() call to _maybeRepeat(): MediaQuery.of
  // (which it reads) can't be called until the widget's dependencies are
  // established, which happens in didChangeDependencies -- calling it
  // from initState throws in debug/test mode. didChangeDependencies is
  // always invoked once right after initState on the same initial build,
  // so nothing is lost by only calling it there.

  void _maybeRepeat() {
    _controller.stop();
    if (MediaQuery.of(context).disableAnimations) return;
    _controller.repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeRepeat();
  }

  @override
  void didUpdateWidget(covariant QuestBoyMascot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _controller.duration = _durationFor(widget.state);
      _controller.reset();
      _maybeRepeat();
    }
  }

  Duration _durationFor(QuestBoyState s) => switch (s) {
        QuestBoyState.waving => const Duration(milliseconds: 900),
        QuestBoyState.knowledge => const Duration(milliseconds: 1400),
        QuestBoyState.achievement => const Duration(milliseconds: 500),
        QuestBoyState.gaming => const Duration(milliseconds: 1100),
      };

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
        // Idle bob for waving/knowledge/gaming; a bouncier hop for
        // achievement (the "cheering" moment).
        final bobStrength = widget.state == QuestBoyState.achievement
            ? widget.size * 0.05
            : widget.size * 0.025;
        final bob = math.sin(t * math.pi) * bobStrength;
        // A slight wave-arm swing, most visible in the waving state.
        final armSwing = widget.state == QuestBoyState.waving
            ? math.sin(t * math.pi) * 0.35
            : 0.0;

        return Transform.translate(
          offset: Offset(0, -bob),
          child: SizedBox(
            width: widget.size,
            height: widget.size * 1.3,
            child: CustomPaint(
              painter: _QuestBoyPainter(
                state: widget.state,
                armSwing: armSwing,
                glow: widget.glow,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _QuestBoyPainter extends CustomPainter {
  final QuestBoyState state;
  final double armSwing;
  final bool glow;

  _QuestBoyPainter({
    required this.state,
    required this.armSwing,
    required this.glow,
  });

  // Palette trued up against the "Quest for Knowledge" reference art.
  static const _skin = Color(0xFFF4C79E);
  static const _hair = Color(0xFF6B4326);
  static const _helmetBrown = Color(0xFFC7A05C);
  static const _helmetBrownDark = Color(0xFFA9843F);
  static const _compassBlue = Color(0xFF3E6FA6);
  static const _hoodieOrange = Color(0xFFFF8A34);
  static const _hoodieOrangeDark = Color(0xFFE6701C);
  static const _vestNavy = Color(0xFF2C3E63);
  static const _vestNavyDark = Color(0xFF1F2C48);
  static const _pouchBrown = Color(0xFF8A5A32);
  static const _denim = Color(0xFF4C6FA5);
  static const _denimDark = Color(0xFF3C5885);
  static const _sockWhite = Color(0xFFFAFAF6);
  static const _shoeWhite = Color(0xFFF5F1E8);
  static const _shoeBrown = Color(0xFF9A6B3E);
  static const _ink = Color(0xFF2A2340);

  @override
  void paint(Canvas canvas, Size size) {
    // Internal canvas is 100 wide x 130 tall; scale to the actual box.
    final sx = size.width / 100;
    final sy = size.height / 130;
    canvas.save();
    canvas.scale(sx, sy);

    if (glow) {
      final glowPaint = Paint()
        ..color = _hoodieOrange.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
      canvas.drawCircle(const Offset(50, 55), 42, glowPaint);
    }

    _paintBackArm(canvas);
    _paintLegsAndShoes(canvas);
    _paintShorts(canvas);
    _paintTorso(canvas);
    _paintVest(canvas);
    _paintFrontArm(canvas);
    _paintHead(canvas);
    _paintHelmet(canvas);
    _paintProp(canvas);

    canvas.restore();
  }

  void _paintLegsAndShoes(Canvas canvas) {
    final skin = Paint()..color = _skin;
    final sock = Paint()..color = _sockWhite;
    final shoeBody = Paint()..color = _shoeWhite;
    final shoeTrim = Paint()..color = _shoeBrown;
    final leanX = state == QuestBoyState.gaming ? 2.0 : 0.0;
    for (final dx in [-9.0, 9.0]) {
      final legRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(50 + dx - 5 + leanX, 92, 10, 16),
        const Radius.circular(5),
      );
      canvas.drawRRect(legRect, skin);

      // Sock band, visible between the shorts hem and the shoe.
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(50 + dx - 5 + leanX, 106, 10, 6),
          const Radius.circular(3),
        ),
        sock,
      );

      // White shoe body with a brown toe/heel trim (reference: mostly
      // white sneaker, brown accent, not the reverse).
      final shoeRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(50 + dx - 7 + leanX, 111, 14, 8),
        const Radius.circular(4),
      );
      canvas.drawRRect(shoeRect, shoeBody);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(50 + dx - 7 + leanX, 111, 14, 3),
          const Radius.circular(3),
        ),
        shoeTrim,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(50 + dx - 7 + leanX, 117, 14, 2.5),
          const Radius.circular(1.5),
        ),
        shoeTrim,
      );
    }
  }

  void _paintShorts(Canvas canvas) {
    final denim = Paint()..color = _denim;
    final trim = Paint()
      ..color = _denimDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final rect = RRect.fromRectAndCorners(
      const Rect.fromLTWH(30, 78, 40, 20),
      topLeft: const Radius.circular(10),
      topRight: const Radius.circular(10),
      bottomLeft: const Radius.circular(4),
      bottomRight: const Radius.circular(4),
    );
    canvas.drawRRect(rect, denim);
    canvas.drawRRect(rect, trim);
  }

  void _paintBackArm(Canvas canvas) {
    // The far arm, drawn behind the torso; stays relaxed at the side
    // regardless of state so the front arm can hold props/wave alone.
    final sleeve = Paint()..color = _hoodieOrangeDark;
    canvas.save();
    canvas.translate(28, 52);
    canvas.rotate(0.18);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(-5, 0, 10, 26), const Radius.circular(5)),
      sleeve,
    );
    canvas.restore();
    canvas.drawCircle(const Offset(24, 79), 4.5, Paint()..color = _skin);
  }

  void _paintTorso(Canvas canvas) {
    final body = Paint()..color = _hoodieOrange;
    // Hood peeking from behind the neck.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(38, 30, 24, 16), const Radius.circular(10)),
      Paint()..color = _hoodieOrangeDark,
    );
    final torsoRect = RRect.fromRectAndCorners(
      const Rect.fromLTWH(28, 42, 44, 38),
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: const Radius.circular(10),
      bottomRight: const Radius.circular(10),
    );
    canvas.drawRRect(torsoRect, body);
  }

  void _paintVest(Canvas canvas) {
    final vest = Paint()..color = _vestNavy;
    final belt = Paint()..color = _vestNavyDark;
    final pouch = Paint()..color = _pouchBrown;
    // Two open-vest panels either side of the hoodie's zip line.
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        const Rect.fromLTWH(30, 46, 15, 30),
        topLeft: const Radius.circular(8),
        bottomLeft: const Radius.circular(6),
      ),
      vest,
    );
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        const Rect.fromLTWH(55, 46, 15, 30),
        topRight: const Radius.circular(8),
        bottomRight: const Radius.circular(6),
      ),
      vest,
    );
    // Belt with two utility pouches, sitting at the waist/hip line just
    // above the shorts (reference art has the pouches here, not on the
    // chest).
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(29, 74, 42, 5), const Radius.circular(2.5)),
      belt,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(26, 74, 9, 10), const Radius.circular(2.5)),
      pouch,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(65, 74, 9, 10), const Radius.circular(2.5)),
      pouch,
    );
  }

  void _paintFrontArm(Canvas canvas) {
    final sleeve = Paint()..color = _hoodieOrange;
    final hand = Paint()..color = _skin;
    canvas.save();
    canvas.translate(72, 52);

    final angle = switch (state) {
      QuestBoyState.waving => -0.9 - armSwing,
      QuestBoyState.knowledge => -0.55,
      QuestBoyState.achievement => -1.5,
      QuestBoyState.gaming => -0.35,
    };
    canvas.rotate(angle);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(-5, 0, 10, 26), const Radius.circular(5)),
      sleeve,
    );
    canvas.drawCircle(const Offset(0, 28), 5, hand);
    canvas.restore();
  }

  void _paintHead(Canvas canvas) {
    final skin = Paint()..color = _skin;
    canvas.drawCircle(const Offset(50, 26), 16, skin);

    // Brown hair fringe peeking out from under the helmet brim.
    final hair = Paint()..color = _hair;
    canvas.drawArc(
      const Rect.fromLTWH(35, 12, 30, 14),
      math.pi * 0.15,
      math.pi * 0.7,
      false,
      hair
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );

    // Cheeks
    final blush = Paint()..color = const Color(0x33FF8A65);
    canvas.drawCircle(const Offset(41, 30), 3.2, blush);
    canvas.drawCircle(const Offset(59, 30), 3.2, blush);

    // Eyes + smile — a simple friendly face, echoing the excited,
    // wide-open grin in the reference art.
    final ink = Paint()..color = _ink;
    canvas.drawCircle(const Offset(44, 25), 2.0, ink);
    canvas.drawCircle(const Offset(56, 25), 2.0, ink);
    final shine = Paint()..color = Colors.white;
    canvas.drawCircle(const Offset(44.8, 24.2), 0.7, shine);
    canvas.drawCircle(const Offset(56.8, 24.2), 0.7, shine);

    final smile = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      const Rect.fromLTWH(41, 26, 18, 11),
      0.15,
      math.pi - 0.3,
      false,
      smile,
    );
  }

  void _paintHelmet(Canvas canvas) {
    final dome = Paint()..color = _helmetBrown;
    final brimPaint = Paint()..color = _helmetBrownDark;

    // Brim (a flattened oval sitting just above the eyeline).
    canvas.drawOval(
      const Rect.fromLTWH(29, 14, 42, 8),
      brimPaint,
    );
    // Dome.
    canvas.drawArc(
      const Rect.fromLTWH(32, 2, 36, 26),
      math.pi,
      math.pi,
      true,
      dome,
    );
    // Compass emblem: blue disc with a white cross-needle, matching the
    // reference's compass-rose badge on the helmet band.
    final emblemBg = Paint()..color = _compassBlue;
    final emblemRing = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    final needle = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(const Offset(50, 12), 4.2, emblemBg);
    canvas.drawCircle(const Offset(50, 12), 4.2, emblemRing);
    canvas.drawLine(
        const Offset(50, 8.5), const Offset(50, 15.5), needle);
    canvas.drawLine(
        const Offset(46.5, 12), const Offset(53.5, 12), needle);
  }

  void _paintProp(Canvas canvas) {
    switch (state) {
      case QuestBoyState.waving:
        return; // No prop -- the raised, waving hand is the whole beat.
      case QuestBoyState.knowledge:
        _paintBook(canvas);
        return;
      case QuestBoyState.achievement:
        _paintTrophy(canvas);
        return;
      case QuestBoyState.gaming:
        _paintController(canvas);
        return;
    }
  }

  void _paintBook(Canvas canvas) {
    // Glowing purple book with a gold star on the cover -- the reference
    // art's exact knowledge-pose prop.
    final glowPaint = Paint()
      ..color = const Color(0xFFC79BFF).withValues(alpha: 0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(const Offset(76, 60), 13, glowPaint);

    final cover = Paint()..color = const Color(0xFF7A3FC9);
    final page = Paint()..color = Colors.white;
    canvas.save();
    canvas.translate(76, 60);
    canvas.rotate(-0.25);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(-9, -7, 18, 14), const Radius.circular(2.5)),
      cover,
    );
    canvas.drawRect(const Rect.fromLTWH(-6, -4, 12, 8), page);
    final lines = Paint()
      ..color = const Color(0xFFDCC7F5)
      ..strokeWidth = 0.8;
    canvas.drawLine(
        const Offset(-4, -1), const Offset(4, -1), lines);
    canvas.drawLine(
        const Offset(-4, 1.5), const Offset(4, 1.5), lines);
    canvas.restore();

    // Small gold star sparkle above the book, echoing the reference's
    // sparkle burst around the glowing pages.
    _drawStar(canvas, const Offset(84, 48), 3.2, const Color(0xFFFFD54A));
  }

  void _paintTrophy(Canvas canvas) {
    final gold = Paint()..color = const Color(0xFFFFC93C);
    final goldDark = Paint()..color = const Color(0xFFE6A11B);
    canvas.save();
    canvas.translate(76, 20);

    // Cup bowl.
    canvas.drawArc(
      const Rect.fromLTWH(-8, -6, 16, 16),
      0,
      math.pi,
      true,
      gold,
    );
    // Handles.
    canvas.drawArc(const Rect.fromLTWH(-13, -4, 8, 10), -1.4, 2.6, false,
        Paint()
          ..color = const Color(0xFFE6A11B)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6);
    canvas.drawArc(const Rect.fromLTWH(5, -4, 8, 10), 0.5, 2.6, false,
        Paint()
          ..color = const Color(0xFFE6A11B)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6);
    // Stem + base.
    canvas.drawRect(const Rect.fromLTWH(-1.5, 10, 3, 5), goldDark);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(-6, 15, 12, 4), const Radius.circular(1.5)),
      goldDark,
    );
    canvas.restore();

    // Star medal on a ribbon, near the chest.
    final ribbon = Paint()..color = const Color(0xFFD8433C);
    canvas.drawRect(const Rect.fromLTWH(63, 50, 6, 10), ribbon);
    _drawStar(canvas, const Offset(66, 63), 6, const Color(0xFFFFD54A));
  }

  void _paintController(Canvas canvas) {
    final body = Paint()..color = const Color(0xFF4CAF50);
    final dark = Paint()..color = const Color(0xFF357A38);
    canvas.save();
    canvas.translate(58, 62);
    canvas.rotate(0.05);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(-16, -7, 32, 14), const Radius.circular(7)),
      body,
    );
    // D-pad.
    canvas.drawRect(const Rect.fromLTWH(-12, -1.5, 6, 3), dark);
    canvas.drawRect(const Rect.fromLTWH(-10.5, -3, 3, 6), dark);
    // Face buttons.
    canvas.drawCircle(const Offset(9, -2), 1.6, dark);
    canvas.drawCircle(const Offset(12, 1), 1.6, dark);
    canvas.restore();
  }

  void _drawStar(Canvas canvas, Offset center, double r, Color color) {
    final path = Path();
    const points = 5;
    const startAngle = -math.pi / 2;
    final innerR = r * 0.45;
    for (int i = 0; i < points * 2; i++) {
      final radius = i.isEven ? r : innerR;
      final angle = startAngle + (i * math.pi / points);
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _QuestBoyPainter oldDelegate) =>
      oldDelegate.state != state ||
      oldDelegate.armSwing != armSwing ||
      oldDelegate.glow != glow;
}
