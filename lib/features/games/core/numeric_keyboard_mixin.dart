import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Mixin for [State] classes that host a numeric-keypad game UI.
///
/// Provides keyboard-to-keypad bridging so the same game works on
/// mobile (tap), web (mouse + physical keyboard), and desktop.
///
/// Usage:
///   class _TugOfWarGameState extends State<TugOfWarGame>
///       with NumericKeyboardMixin {
///
///     @override void handleDigit(String d) => session.appendDigit(d);
///     @override void handleConfirm()       => session.submitCurrentInput();
///     @override void handleBackspace()     => session.clearLastDigit();
///
///     @override
///     Widget build(BuildContext context) {
///       return Focus(
///         focusNode: keyboardFocusNode,
///         onKeyEvent: onKeyEvent,
///         autofocus: true,
///         child: ...,
///       );
///     }
///   }
mixin NumericKeyboardMixin<T extends StatefulWidget> on State<T> {
  late final FocusNode keyboardFocusNode;

  // ── Abstract callbacks ────────────────────────────────────────────────────

  /// Called when a digit key (0–9) is pressed.
  void handleDigit(String digit);

  /// Called when Enter or numpad Enter is pressed.
  void handleConfirm();

  /// Called when Backspace or Delete is pressed.
  void handleBackspace();

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    keyboardFocusNode = FocusNode();
  }

  @override
  void dispose() {
    keyboardFocusNode.dispose();
    super.dispose();
  }

  // ── Key event handler — pass to Focus.onKeyEvent ──────────────────────────

  KeyEventResult onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      handleConfirm();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.backspace ||
        key == LogicalKeyboardKey.delete) {
      handleBackspace();
      return KeyEventResult.handled;
    }

    final digit = _digitFromKey(key);
    if (digit != null) {
      handleDigit(digit);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  static final _keyToDigit = <LogicalKeyboardKey, String>{
    LogicalKeyboardKey.digit0: '0',
    LogicalKeyboardKey.digit1: '1',
    LogicalKeyboardKey.digit2: '2',
    LogicalKeyboardKey.digit3: '3',
    LogicalKeyboardKey.digit4: '4',
    LogicalKeyboardKey.digit5: '5',
    LogicalKeyboardKey.digit6: '6',
    LogicalKeyboardKey.digit7: '7',
    LogicalKeyboardKey.digit8: '8',
    LogicalKeyboardKey.digit9: '9',
    LogicalKeyboardKey.numpad0: '0',
    LogicalKeyboardKey.numpad1: '1',
    LogicalKeyboardKey.numpad2: '2',
    LogicalKeyboardKey.numpad3: '3',
    LogicalKeyboardKey.numpad4: '4',
    LogicalKeyboardKey.numpad5: '5',
    LogicalKeyboardKey.numpad6: '6',
    LogicalKeyboardKey.numpad7: '7',
    LogicalKeyboardKey.numpad8: '8',
    LogicalKeyboardKey.numpad9: '9',
  };

  String? _digitFromKey(LogicalKeyboardKey key) => _keyToDigit[key];
}
