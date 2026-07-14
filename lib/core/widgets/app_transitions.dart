import 'package:flutter/material.dart';

/// Drop-in replacement for `MaterialPageRoute` with a springy scale+fade
/// transition matching the premium-2D feel, e.g.:
///
/// ```dart
/// Navigator.push(context, questPageRoute(const SomeScreen()));
/// ```
///
/// Falls back to a plain, near-instant fade when the platform has
/// reduced-motion enabled.
Route<T> questPageRoute<T>(Widget page, {bool fullscreenDialog = false}) {
  return PageRouteBuilder<T>(
    fullscreenDialog: fullscreenDialog,
    transitionDuration: const Duration(milliseconds: 260),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (MediaQuery.of(context).disableAnimations) {
        return FadeTransition(opacity: animation, child: child);
      }
      final curved =
          CurvedAnimation(parent: animation, curve: Curves.easeOutBack);
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: Tween(begin: 0.94, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}
