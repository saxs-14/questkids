import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../core/services/gemini_service.dart';
import '../data/models/chat_message_model.dart';
import '../data/models/user_model.dart';
import '../data/repositories/chat_repository.dart';

class AiTutorProvider extends ChangeNotifier {
  GeminiService _gemini = GeminiService();
  final FlutterTts _flutterTts = FlutterTts();
  final ChatRepository _chatRepo = ChatRepository();

  List<ChatMessageModel> _messages = [];
  bool _isTyping = false;
  String? _recommendation;
  bool _recommendationLoading = false;
  List<ChatMessageModel> get messages => _messages;
  bool get isTyping => _isTyping;
  String? get recommendation => _recommendation;
  bool get recommendationLoading => _recommendationLoading;

  AiTutorProvider() {
    _initTts();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-ZA");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  Future<void> speak(String text) async {
    // Remove emojis for better TTS experience
    final cleanText = text.replaceAll(
        RegExp(
            r'[\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}\u{1F700}-\u{1F77F}\u{1F780}-\u{1F7FF}\u{1F800}-\u{1F8FF}\u{1F900}-\u{1F9FF}\u{1FA00}-\u{1FA6F}\u{1FA70}-\u{1FAFF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]',
            unicode: true),
        '');
    await _flutterTts.speak(cleanText);
  }

  void stopSpeaking() async {
    await _flutterTts.stop();
  }

  static const List<String> quickPrompts = [
    '🔢 Help me with maths',
    '🔬 Explain the water cycle',
    '📖 What is a noun?',
    '🌍 Tell me about SA provinces',
    '💡 Give me a study tip',
    '🎯 How do I improve my score?',
  ];

  UserModel? _currentUser;

  Future<void> initSession(UserModel user) async {
    _currentUser = user;
    _gemini = GeminiService(preferredLanguage: user.preferredLanguage);

    // Fetch chat history
    _messages = await _chatRepo.fetchChatHistory(user.uid);

    // Convert to Gemini Content for history
    final history = _messages.map((m) {
      return m.isUser
          ? Content.text(m.text)
          : Content.model([TextPart(m.text)]);
    }).toList();

    _gemini.startNewSession(history: history);

    if (_messages.isEmpty) {
      final text = 'Hi ${user.name.split(' ').first}! 👋 I am Questy, '
          'your personal AI tutor! I am here to help you with '
          '${user.grade} work.\n\n'
          'You can ask me anything about Maths, Science, English '
          'or Social Sciences. What would you like to learn today? 🚀';
      final botMessage = ChatMessageModel.bot(text);
      _messages.add(botMessage);
      _chatRepo.saveMessage(user.uid, botMessage);
      speak(text);
      notifyListeners();
    } else {
      notifyListeners();
    }
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty || _currentUser == null) return;

    final userMessage = ChatMessageModel.user(text);
    _messages.add(userMessage);
    _chatRepo.saveMessage(_currentUser!.uid, userMessage);

    _messages.add(ChatMessageModel.loading());
    _isTyping = true;
    notifyListeners();

    final response = await _gemini.sendMessage(text);

    _messages.removeLast();
    final botMessage = ChatMessageModel.bot(response);
    _messages.add(botMessage);
    _chatRepo.saveMessage(_currentUser!.uid, botMessage);

    _isTyping = false;
    speak(response);
    notifyListeners();
  }

  Future<void> sendImageMessage({
    required List<int> imageBytes,
    required String prompt,
  }) async {
    if (_currentUser == null) return;

    final userMessage = ChatMessageModel.user('📸 $prompt');
    _messages.add(userMessage);
    _chatRepo.saveMessage(_currentUser!.uid, userMessage);

    _messages.add(ChatMessageModel.loading());
    _isTyping = true;
    notifyListeners();

    final response = await _gemini.analyzeImage(
      imageBytes: imageBytes,
      prompt: prompt,
    );

    _messages.removeLast();
    final botMessage = ChatMessageModel.bot(response);
    _messages.add(botMessage);
    _chatRepo.saveMessage(_currentUser!.uid, botMessage);

    _isTyping = false;
    speak(response);
    notifyListeners();
  }

  Future<void> loadRecommendation({
    required String name,
    required String grade,
    required Map<String, int> subjectScores,
    required int streakDays,
    required int totalPoints,
  }) async {
    _recommendationLoading = true;
    notifyListeners();
    _recommendation = await _gemini.getPersonalisedRecommendation(
      name: name,
      grade: grade,
      subjectScores: subjectScores,
      streakDays: streakDays,
      totalPoints: totalPoints,
    );
    _recommendationLoading = false;
    notifyListeners();
  }

  Future<String> getHint(String question, String subject) async {
    final hint = await _gemini.generateQuizHint(
      question: question,
      subject: subject,
    );
    if (_currentUser != null) {
      await _chatRepo.saveMessage(
        _currentUser!.uid,
        ChatMessageModel.bot(hint, intent: 'hint'),
      );
    }
    return hint;
  }

  Future<String> explainAnswer({
    required String question,
    required String correctAnswer,
    required String subject,
    required String grade,
  }) async {
    final explanation = await _gemini.explainQuizAnswer(
      question: question,
      correctAnswer: correctAnswer,
      subject: subject,
      grade: grade,
    );
    if (_currentUser != null) {
      await _chatRepo.saveMessage(
        _currentUser!.uid,
        ChatMessageModel.bot(explanation, intent: 'explain'),
      );
    }
    return explanation;
  }

  void clearMessages() {
    _messages.clear();
    _gemini.startNewSession();
    notifyListeners();
  }
}
