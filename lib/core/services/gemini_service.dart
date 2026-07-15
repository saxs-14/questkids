import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_functions/cloud_functions.dart';

class GeminiService {
  final _functions = FirebaseFunctions.instanceFor(region: 'us-central1');

  // Callable Functions default to a 70s timeout, which leaves a child
  // staring at a spinner far too long if Gemini or the function hangs.
  // Fail fast into the existing friendly fallback message instead.
  static final _callTimeout = HttpsCallableOptions(
    timeout: const Duration(seconds: 20),
  );
  static final _imageCallTimeout = HttpsCallableOptions(
    timeout: const Duration(seconds: 30),
  );

  // preferredLanguage kept for constructor compatibility; language is set server-side.
  // ignore: avoid_unused_constructor_parameters
  GeminiService({String preferredLanguage = 'English'});

  // No-op kept so existing callers (AiTutorProvider) don't need changes.
  void startNewSession({List<dynamic>? history}) {}

  Future<String> sendMessage(
    String message, {
    List<Map<String, String>> history = const [],
  }) async {
    try {
      final result = await _functions
          .httpsCallable('questyChat', options: _callTimeout)
          .call({
        'message': message,
        'history': history,
      });
      return (result.data as Map<dynamic, dynamic>)['text'] as String? ??
          'I did not understand that. Could you rephrase?';
    } catch (_) {
      return 'Oops! I am having trouble connecting right now. Please try again in a moment! 🔄';
    }
  }

  Future<String> analyzeImage({
    required List<int> imageBytes,
    required String prompt,
  }) async {
    try {
      final base64Image = base64Encode(Uint8List.fromList(imageBytes));
      final result = await _functions
          .httpsCallable('analyzeImage', options: _imageCallTimeout)
          .call({
        'imageBase64': base64Image,
        'prompt': prompt,
      });
      return (result.data as Map<dynamic, dynamic>)['text'] as String? ??
          'I could not analyse the image. Please try again.';
    } catch (_) {
      return 'Image analysis failed. Please check your connection and try again.';
    }
  }

  Future<String> getPersonalisedRecommendation({
    required String name,
    required String grade,
    required Map<String, int> subjectScores,
    required int streakDays,
    required int totalPoints,
  }) async {
    try {
      final result = await _functions
          .httpsCallable('getRecommendation', options: _callTimeout)
          .call({
        'name': name,
        'grade': grade,
        'subjectScores': subjectScores,
        'streakDays': streakDays,
        'totalPoints': totalPoints,
      });
      return (result.data as Map<dynamic, dynamic>)['text'] as String? ??
          'Keep up the great work, $name! 🌟';
    } catch (_) {
      return 'You are doing amazing, $name! Keep completing quests every day! 🚀';
    }
  }

  Future<String> explainQuizAnswer({
    required String question,
    required String correctAnswer,
    required String subject,
    required String grade,
  }) async {
    try {
      final result = await _functions
          .httpsCallable('explainAnswer', options: _callTimeout)
          .call({
        'question': question,
        'correctAnswer': correctAnswer,
        'subject': subject,
        'grade': grade,
      });
      return (result.data as Map<dynamic, dynamic>)['text'] as String? ??
          correctAnswer;
    } catch (_) {
      return 'The correct answer is $correctAnswer. Keep practising and you will get it! 💪';
    }
  }

  Future<String> generateQuizHint({
    required String question,
    required String subject,
  }) async {
    try {
      final result = await _functions
          .httpsCallable('generateHint', options: _callTimeout)
          .call({
        'question': question,
        'subject': subject,
      });
      return (result.data as Map<dynamic, dynamic>)['text'] as String? ??
          'Think carefully about what you have learned! 💡';
    } catch (_) {
      return 'You can do it! Think step by step. 💡';
    }
  }
}
