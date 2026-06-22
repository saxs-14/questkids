import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../config/app_config.dart';

class GeminiService {
  static const String _apiKey = AppConfig.geminiApiKey;

  late final GenerativeModel _model;
  late final GenerativeModel _visionModel;
  ChatSession? _chatSession;

  GeminiService({String preferredLanguage = 'English'}) {
    _model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.7,
        topK: 40,
        topP: 0.95,
        maxOutputTokens: 1024,
      ),
      systemInstruction: Content.system(
        '''You are QuestBot, a friendly and encouraging AI tutor
        for South African primary school children (Grades 1-7).
        Your role is to:
        - Explain concepts in simple, age-appropriate language
        - Use fun examples, emojis and analogies children relate to
        - Encourage learners when they struggle
        - Reference South African context (rand, braai, provinces etc)
        - Cover: Math, Science, English, Social Sciences
        - Keep responses concise (max 3-4 short paragraphs)
        - Never give direct quiz answers, guide them to think
        - Celebrate correct answers enthusiastically
        - Use encouraging phrases: "Great question!", "You are doing
          amazing!", "Let us figure this out together!"
        
        CRITICAL RULES:
        1. Always respond in the user's preferred language: $preferredLanguage.
        2. You MUST ONLY answer questions relevant to a primary school child (Grade 1 to 7 level). If a question is outside this educational scope or inappropriate, you must politely reject answering it by saying you are an AI tutor for kids and can only help with school-related topics.
        
        Always respond in a warm, child-friendly tone.''',
      ),
    );

    _visionModel = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.7,
        maxOutputTokens: 1024,
      ),
    );
  }

  void startNewSession({List<Content>? history}) {
    _chatSession = _model.startChat(history: history);
  }

  Future<String> sendMessage(String message) async {
    _chatSession ??= _model.startChat();
    try {
      final response =
          await _chatSession!.sendMessage(Content.text(message));
      return response.text ?? 'I did not understand that. '
          'Could you rephrase?';
    } catch (e) {
      return 'Oops! I am having trouble connecting right now. '
          'Please try again in a moment! 🔄';
    }
  }

  Future<String> analyzeImage({
    required List<int> imageBytes,
    required String prompt,
  }) async {
    try {
      final content = [
        Content.multi([
          TextPart(prompt),
          DataPart('image/jpeg', Uint8List.fromList(imageBytes)),
        ])
      ];
      final response =
          await _visionModel.generateContent(content);
      return response.text ??
          'I could not analyse the image. Please try again.';
    } catch (e) {
      return 'Image analysis failed. '
          'Please check your connection and try again.';
    }
  }

  Future<String> getPersonalisedRecommendation({
    required String name,
    required String grade,
    required Map<String, int> subjectScores,
    required int streakDays,
    required int totalPoints,
  }) async {
    final weakSubjects = subjectScores.entries
        .where((e) => e.value < 60)
        .map((e) => e.key)
        .toList();
    final strongSubjects = subjectScores.entries
        .where((e) => e.value >= 80)
        .map((e) => e.key)
        .toList();

    final prompt = '''
Give a short personalised learning recommendation for:
- Name: $name
- Grade: $grade
- Streak: $streakDays days
- Total Points: $totalPoints
- Strong subjects: ${strongSubjects.join(', ')}
- Needs improvement: ${weakSubjects.join(', ')}

Keep it encouraging, 2-3 sentences max, use their name,
end with a motivational tip. Use 1-2 emojis.
''';
    try {
      final response =
          await _model.generateContent([Content.text(prompt)]);
      return response.text ??
          'Keep up the great work, $name! 🌟';
    } catch (e) {
      return 'You are doing amazing, $name! '
          'Keep completing quests every day! 🚀';
    }
  }

  Future<String> explainQuizAnswer({
    required String question,
    required String correctAnswer,
    required String subject,
    required String grade,
  }) async {
    final prompt = '''
A $grade learner just answered this $subject question wrong:
Question: $question
Correct answer: $correctAnswer

Explain WHY this is the correct answer in a simple,
fun way a child would understand. Use an analogy or
real-world example. Keep it to 2-3 sentences.
Use 1 emoji.
''';
    try {
      final response =
          await _model.generateContent([Content.text(prompt)]);
      return response.text ?? correctAnswer;
    } catch (e) {
      return 'The correct answer is $correctAnswer. '
          'Keep practising and you will get it! 💪';
    }
  }

  Future<String> generateQuizHint({
    required String question,
    required String subject,
  }) async {
    final prompt = '''
A learner is stuck on this $subject question:
"$question"

Give ONE helpful hint that guides them toward the answer
WITHOUT giving the answer away. Keep it to 1-2 sentences.
Be encouraging. Use 1 emoji.
''';
    try {
      final response =
          await _model.generateContent([Content.text(prompt)]);
      return response.text ??
          'Think carefully about what you have learned! 💡';
    } catch (e) {
      return 'You can do it! Think step by step. 💡';
    }
  }
}
