import 'dart:math';
import 'package:flutter_tts/flutter_tts.dart';

/// Lightweight, local celebration voice used by games. It does not consume
/// the Gemini quota and works as a fallback even when the network is offline.
class GameCelebrationService {
  GameCelebrationService._();

  static final FlutterTts _tts = FlutterTts();
  static final Random _random = Random();
  static bool _ready = false;

  static const _normal = [
    'Excellent!',
    'Great job!',
    'Amazing!',
    'Super!',
    'You got it!',
  ];

  static const _streak = [
    'Awesome streak!',
    'Fantastic!',
    'Incredible!',
    'Divine!',
    'You are on fire!',
  ];

  static Future<void> _init() async {
    if (_ready) return;
    await _tts.setLanguage('en-ZA');
    await _tts.setSpeechRate(0.55);
    await _tts.setPitch(1.12);
    await _tts.setVolume(1.0);
    _ready = true;
  }

  static Future<void> correct(int streak) async {
    try {
      await _init();
      final lines = streak >= 3 ? _streak : _normal;
      await _tts.stop();
      await _tts.speak(lines[_random.nextInt(lines.length)]);
    } catch (_) {
      // Audio feedback is never allowed to interrupt gameplay.
    }
  }
}
