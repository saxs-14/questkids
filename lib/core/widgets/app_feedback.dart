import 'dart:math';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Wraps [child] with a horizontal shake trigger for wrong-answer feedback.
/// Trigger via a `GlobalKey<AppShakeState>`:
///
/// ```dart
/// final shakeKey = GlobalKey<AppShakeState>();
/// AppShake(key: shakeKey, child: answerTile)
/// // on wrong answer:
/// shakeKey.currentState?.shake();
/// ```
class AppShake extends StatefulWidget {
  final Widget child;
  const AppShake({super.key, required this.child});

  @override
  State<AppShake> createState() => AppShakeState();
}

class AppShakeState extends State<AppShake>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );
  late final Animation<double> _offset = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0, end: -10), weight: 1),
    TweenSequenceItem(tween: Tween(begin: -10, end: 10), weight: 2),
    TweenSequenceItem(tween: Tween(begin: 10, end: -8), weight: 2),
    TweenSequenceItem(tween: Tween(begin: -8, end: 6), weight: 2),
    TweenSequenceItem(tween: Tween(begin: 6, end: 0), weight: 1),
  ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

  void shake() {
    if (MediaQuery.of(context).disableAnimations) return;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _offset,
      builder: (context, child) =>
          Transform.translate(offset: Offset(_offset.value, 0), child: child),
      child: widget.child,
    );
  }
}

/// Shows a transient checkmark-burst overlay for correct-answer feedback,
/// self-removing after its animation finishes. Fire-and-forget: `await`
/// only if the caller needs to wait for it to clear.
Future<void> showCorrectBurst(BuildContext context) async {
  if (MediaQuery.of(context).disableAnimations) return;
  final overlay = Overlay.of(context);
  final entry = OverlayEntry(
    builder: (context) => const _CorrectBurst(),
  );
  overlay.insert(entry);
  await Future.delayed(const Duration(milliseconds: 700));
  entry.remove();
}

class _CorrectBurst extends StatefulWidget {
  const _CorrectBurst();

  @override
  State<_CorrectBurst> createState() => _CorrectBurstState();
}

class _CorrectBurstState extends State<_CorrectBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.3, end: 1.15), weight: 1),
    TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 1),
  ]).animate(CurvedAnimation(
      parent: _controller, curve: const Interval(0, 0.5)));
  late final Animation<double> _opacity = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.6, 1.0),
  ).drive(Tween(begin: 1.0, end: 0.0));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => Opacity(
            opacity: _opacity.value,
            child: Transform.scale(
              scale: _scale.value,
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.success.withValues(alpha: 0.5),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(Icons.check_rounded,
                    color: Colors.white, size: 56),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-screen confetti celebration for level-ups, Trail completion, and
/// Trading Post purchases -- wraps `package:confetti` with a self-managed
/// controller. Place once near the root of a results/celebration screen
/// and trigger via a `GlobalKey<AppConfettiState>`:
///
/// ```dart
/// final confettiKey = GlobalKey<AppConfettiState>();
/// Stack(children: [resultsContent, AppConfetti(key: confettiKey)])
/// // on mount / on level-up:
/// confettiKey.currentState?.play();
/// ```
class AppConfetti extends StatefulWidget {
  const AppConfetti({super.key});

  @override
  State<AppConfetti> createState() => AppConfettiState();
}

class AppConfettiState extends State<AppConfetti> {
  late final ConfettiController _controller =
      ConfettiController(duration: const Duration(seconds: 2));

  void play() {
    if (MediaQuery.of(context).disableAnimations) return;
    _controller.play();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConfettiWidget(
          confettiController: _controller,
          blastDirection: pi / 2,
          blastDirectionality: BlastDirectionality.explosive,
          numberOfParticles: 24,
          gravity: 0.25,
          colors: const [
            AppColors.gold,
            AppColors.primary,
            AppColors.accent,
            AppColors.socialSciences,
            AppColors.xpBlue,
          ],
        ),
      ),
    );
  }
}
