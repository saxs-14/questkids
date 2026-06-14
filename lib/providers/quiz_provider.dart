import 'package:flutter/material.dart';
import '../data/models/activity_model.dart';
import '../data/repositories/activity_repository.dart';
import '../core/services/quiz_service.dart';
import '../core/services/offline_service.dart';

enum QuizState { idle, loading, active, reviewing, complete, error }

class QuizProvider extends ChangeNotifier {
  final ActivityRepository _activityRepo = ActivityRepository();
  final QuizService _quizService = QuizService();

  QuizState _state = QuizState.idle;
  List<ActivityModel> _activities = [];
  ActivityModel? _currentActivity;
  int _currentQuestionIndex = 0;
  int? _selectedAnswerIndex;
  bool _isAnswerRevealed = false;
  List<int?> _userAnswers = [];
  int _correctCount = 0;
  int _startTime = 0;
  String? _errorMessage;
  String _selectedSubject = 'All';

  QuizState get state => _state;
  List<ActivityModel> get activities => _activities;
  ActivityModel? get currentActivity => _currentActivity;
  int get currentQuestionIndex => _currentQuestionIndex;
  int? get selectedAnswerIndex => _selectedAnswerIndex;
  bool get isAnswerRevealed => _isAnswerRevealed;
  List<int?> get userAnswers => _userAnswers;
  int get correctCount => _correctCount;
  String? get errorMessage => _errorMessage;
  String get selectedSubject => _selectedSubject;

  QuestionModel? get currentQuestion =>
      _currentActivity != null &&
              _currentQuestionIndex < _currentActivity!.questions.length
          ? _currentActivity!.questions[_currentQuestionIndex]
          : null;

  int get totalQuestions => _currentActivity?.questions.length ?? 0;
  bool get isLastQuestion =>
      _currentQuestionIndex == totalQuestions - 1;
  double get progress =>
      totalQuestions > 0 ? (_currentQuestionIndex + 1) / totalQuestions : 0;

  Future<void> loadActivities(String grade) async {
    _state = QuizState.loading;
    _errorMessage = null;
    notifyListeners();
    final offlineService = OfflineService();
    try {
      final isOnline = await offlineService.isOnline();
      if (isOnline) {
        await _quizService.seedDemoActivities(grade);
        _activities =
            await _activityRepo.getActivitiesByGrade(grade);
        await offlineService.cacheActivities(_activities);
      } else {
        _activities =
            await offlineService.getCachedActivities(grade);
        if (_activities.isEmpty) {
          _state = QuizState.error;
          _errorMessage =
              'No cached quests available offline. '
              'Please connect to the internet first.';
          notifyListeners();
          return;
        }
      }
      _state = QuizState.idle;
    } catch (e) {
      _activities =
          await offlineService.getCachedActivities(grade);
      if (_activities.isNotEmpty) {
        _state = QuizState.idle;
      } else {
        _state = QuizState.error;
        _errorMessage =
            'Failed to load quests. Check your connection.';
      }
    }
    notifyListeners();
  }

  List<ActivityModel> get filteredActivities {
    if (_selectedSubject == 'All') return _activities;
    return _activities
        .where((a) => a.subject == _selectedSubject)
        .toList();
  }

  void setSubjectFilter(String subject) {
    _selectedSubject = subject;
    notifyListeners();
  }

  void startQuiz(ActivityModel activity) {
    _currentActivity = activity;
    _currentQuestionIndex = 0;
    _selectedAnswerIndex = null;
    _isAnswerRevealed = false;
    _userAnswers = List.filled(activity.questions.length, null);
    _correctCount = 0;
    _startTime = DateTime.now().millisecondsSinceEpoch;
    _state = QuizState.active;
    notifyListeners();
  }

  void selectAnswer(int index) {
    if (_isAnswerRevealed) return;
    _selectedAnswerIndex = index;
    notifyListeners();
  }

  void revealAnswer() {
    if (_selectedAnswerIndex == null) return;
    _isAnswerRevealed = true;
    _userAnswers[_currentQuestionIndex] = _selectedAnswerIndex;
    if (_selectedAnswerIndex == currentQuestion?.correctIndex) {
      _correctCount++;
    }
    notifyListeners();
  }

  void nextQuestion() {
    if (_currentQuestionIndex < totalQuestions - 1) {
      _currentQuestionIndex++;
      _selectedAnswerIndex = null;
      _isAnswerRevealed = false;
      notifyListeners();
    } else {
      _state = QuizState.reviewing;
      notifyListeners();
    }
  }

  Future<void> submitQuiz(String uid) async {
    if (_currentActivity == null) return;
    _state = QuizState.loading;
    notifyListeners();
    try {
      final timeTaken =
          (DateTime.now().millisecondsSinceEpoch - _startTime) ~/ 1000;
      await _quizService.submitQuiz(
        uid: uid,
        activity: _currentActivity!,
        correctAnswers: _correctCount,
        totalQuestions: totalQuestions,
        timeTakenSeconds: timeTaken,
      );
      _state = QuizState.complete;
    } catch (e) {
      _state = QuizState.error;
      _errorMessage = 'Failed to save results.';
    }
    notifyListeners();
  }

  void resetQuiz() {
    _state = QuizState.idle;
    _currentActivity = null;
    _currentQuestionIndex = 0;
    _selectedAnswerIndex = null;
    _isAnswerRevealed = false;
    _userAnswers = [];
    _correctCount = 0;
    notifyListeners();
  }

  int get finalScore => totalQuestions > 0
      ? ((_correctCount / totalQuestions) * 100).round()
      : 0;

  int get pointsEarned {
    if (_currentActivity == null) return 0;
    double multiplier = 1.0;
    if (finalScore == 100) {
      multiplier = 2.0;
    } else if (finalScore >= 80) {
      multiplier = 1.5;
    } else if (finalScore >= 60) {
      multiplier = 1.2;
    }
    return (_currentActivity!.rewardPoints * multiplier *
            (finalScore / 100))
        .round();
  }

  String get scoreEmoji {
    if (finalScore == 100) return '🏆';
    if (finalScore >= 80) return '⭐';
    if (finalScore >= 60) return '👍';
    if (finalScore >= 40) return '💪';
    return '😅';
  }

  String get scoreMessage {
    if (finalScore == 100) return 'Perfect Score! Amazing!';
    if (finalScore >= 80) return 'Great Job! Keep it up!';
    if (finalScore >= 60) return 'Good effort! Try again!';
    if (finalScore >= 40) return 'Keep practising!';
    return 'Don\'t give up! Try again!';
  }
}
