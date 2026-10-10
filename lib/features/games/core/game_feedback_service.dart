import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Optional spoken feedback for game answers.
///
/// Game screens should call [correct] or [incorrect] after validating an
/// answer. The preference is shared across the app and defaults to enabled.
/// TTS failures are intentionally non-fatal so feedback cannot break a game.
class GameFeedbackService {
  GameFeedbackService._();

  static final FlutterTts _tts = FlutterTts();
  static const String _enabledKey = 'game_answer_voice_feedback_enabled';
  static bool _enabled = true;
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_enabledKey) ?? true;
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.43);
      await _tts.setPitch(1.08);
      _initialized = true;
    } catch (_) {
      // Keep the game playable when platform TTS is unavailable.
    }
  }

  static bool get isEnabled => _enabled;

  static Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, enabled);
      if (!enabled) await _tts.stop();
    } catch (_) {
      // In-memory preference still applies for the current app session.
    }
  }

  static Future<void> correct() => _speak('Correct! Great job!');

  static Future<void> incorrect() => _speak('Not quite. Try again!');

  static Future<void> _speak(String message) async {
    if (!_enabled) return;
    try {
      await initialize();
      if (_enabled) await _tts.speak(message);
    } catch (_) {
      // Voice feedback is optional; never interrupt an answer flow.
    }
  }
}
