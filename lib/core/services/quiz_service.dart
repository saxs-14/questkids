import '../../data/models/activity_model.dart';
import '../../data/models/progress_model.dart';
import '../../data/models/reward_model.dart';
import '../../data/repositories/activity_repository.dart';
import '../../data/repositories/progress_repository.dart';
import '../../data/repositories/reward_repository.dart';
import '../../data/repositories/user_repository.dart';
import 'offline_service.dart';

class QuizService {
  final ActivityRepository _activityRepo = ActivityRepository();
  final ProgressRepository _progressRepo = ProgressRepository();
  final RewardRepository _rewardRepo = RewardRepository();
  final UserRepository _userRepo = UserRepository();

  Future<void> submitQuiz({
    required String uid,
    required ActivityModel activity,
    required int correctAnswers,
    required int totalQuestions,
    required int timeTakenSeconds,
  }) async {
    final offlineService = OfflineService();
    final score = totalQuestions > 0
        ? ((correctAnswers / totalQuestions) * 100).round()
        : 0;
    final pointsEarned = _calculatePoints(
      score: score,
      basePoints: activity.rewardPoints,
      timeTakenSeconds: timeTakenSeconds,
    );

    final progress = ProgressModel(
      uid: uid,
      activityId: activity.id,
      activityTitle: activity.title,
      subject: activity.subject,
      score: score,
      pointsEarned: pointsEarned,
      completed: true,
      verified: false,
      completedAt: DateTime.now(),
      timeTakenSeconds: timeTakenSeconds,
    );

    final isOnline = await offlineService.isOnline();
    if (isOnline) {
      await _progressRepo.saveProgress(progress);
      await _rewardRepo.addPoints(uid, pointsEarned);
      await _userRepo.addPoints(uid, pointsEarned);
    } else {
      await offlineService.saveProgressOffline(progress);
      // Update local rewards cache
      final cachedRewards =
          await offlineService.getCachedRewards(uid);
      if (cachedRewards != null) {
        final updated = RewardModel(
          uid: uid,
          totalPoints: cachedRewards.totalPoints + pointsEarned,
          level: (cachedRewards.totalPoints + pointsEarned)
                  ~/ 100 +
              1,
          streakDays: cachedRewards.streakDays,
          badges: cachedRewards.badges,
          achievements: cachedRewards.achievements,
          lastActiveDate: DateTime.now(),
        );
        await offlineService.cacheRewards(updated);
      }
    }
  }

  int _calculatePoints({
    required int score,
    required int basePoints,
    required int timeTakenSeconds,
  }) {
    double multiplier = 1.0;
    if (score == 100) {
      multiplier = 2.0;
    } else if (score >= 80) {
      multiplier = 1.5;
    } else if (score >= 60) {
      multiplier = 1.2;
    }
    if (timeTakenSeconds < 30) {
      multiplier += 0.3;
    } else if (timeTakenSeconds < 60) {
      multiplier += 0.1;
    }
    return (basePoints * multiplier * (score / 100)).round();
  }

  Future<void> seedDemoActivities(String grade) async {
    final existing = await _activityRepo.getActivitiesByGrade(grade);
    if (existing.isNotEmpty) return;

    final demos = _getDemoActivities(grade);
    for (final activity in demos) {
      await _activityRepo.createActivity(activity);
    }
  }

  List<ActivityModel> _getDemoActivities(String grade) {
    return [
      ActivityModel(
        id: 'math_001_$grade',
        title: 'Multiplication Tables',
        description: 'Test your multiplication skills!',
        subject: 'Math',
        type: 'quiz',
        difficulty: 'medium',
        rewardPoints: 20,
        grade: grade,
        createdAt: DateTime.now(),
        questions: [
          QuestionModel(
            question: 'What is 6 × 7?',
            options: ['40', '42', '48', '36'],
            correctIndex: 1,
            explanation: '6 × 7 = 42. Count by 7s: 7, 14, 21, 28, 35, 42!',
          ),
          QuestionModel(
            question: 'What is 8 × 9?',
            options: ['63', '72', '81', '64'],
            correctIndex: 1,
            explanation: '8 × 9 = 72. Remember: 8 × 10 = 80, minus 8 = 72!',
          ),
          QuestionModel(
            question: 'What is 4 × 12?',
            options: ['44', '48', '52', '40'],
            correctIndex: 1,
            explanation: '4 × 12 = 48. Think: 4 × 10 = 40, plus 4 × 2 = 8!',
          ),
          QuestionModel(
            question: 'What is 7 × 7?',
            options: ['42', '56', '49', '63'],
            correctIndex: 2,
            explanation: '7 × 7 = 49. The lucky square number!',
          ),
          QuestionModel(
            question: 'What is 9 × 9?',
            options: ['81', '72', '90', '99'],
            correctIndex: 0,
            explanation: '9 × 9 = 81. The biggest single-digit square!',
          ),
        ],
      ),
      ActivityModel(
        id: 'science_001_$grade',
        title: 'The Water Cycle',
        description: 'Learn about evaporation, condensation and precipitation!',
        subject: 'Science',
        type: 'quiz',
        difficulty: 'easy',
        rewardPoints: 10,
        grade: grade,
        createdAt: DateTime.now(),
        questions: [
          QuestionModel(
            question: 'What is the process called when water turns into vapour?',
            options: ['Condensation', 'Precipitation', 'Evaporation', 'Transpiration'],
            correctIndex: 2,
            explanation: 'Evaporation happens when the sun heats water and turns it into water vapour.',
          ),
          QuestionModel(
            question: 'What is it called when water vapour turns back into liquid?',
            options: ['Evaporation', 'Condensation', 'Precipitation', 'Collection'],
            correctIndex: 1,
            explanation: 'Condensation happens when water vapour cools and forms clouds.',
          ),
          QuestionModel(
            question: 'What is precipitation?',
            options: ['Water evaporating', 'Clouds forming', 'Rain or snow falling', 'Water flowing in rivers'],
            correctIndex: 2,
            explanation: 'Precipitation is any form of water falling from clouds - rain, snow, hail!',
          ),
          QuestionModel(
            question: 'Where does most evaporation occur?',
            options: ['Rivers', 'Lakes', 'Oceans', 'Puddles'],
            correctIndex: 2,
            explanation: 'Oceans cover 70% of Earth so most evaporation happens there.',
          ),
          QuestionModel(
            question: 'What powers the water cycle?',
            options: ['Wind', 'The Moon', 'The Sun', 'Gravity'],
            correctIndex: 2,
            explanation: 'The Sun provides the energy that drives the entire water cycle!',
          ),
        ],
      ),
      ActivityModel(
        id: 'english_001_$grade',
        title: 'Parts of Speech',
        description: 'Identify nouns, verbs, adjectives and adverbs!',
        subject: 'English',
        type: 'quiz',
        difficulty: 'hard',
        rewardPoints: 30,
        grade: grade,
        createdAt: DateTime.now(),
        questions: [
          QuestionModel(
            question: 'Which word is a NOUN in: "The dog ran fast"?',
            options: ['The', 'dog', 'ran', 'fast'],
            correctIndex: 1,
            explanation: 'A noun is a person, place or thing. "Dog" is a thing!',
          ),
          QuestionModel(
            question: 'Which word is a VERB in: "She quickly ate the apple"?',
            options: ['She', 'quickly', 'ate', 'apple'],
            correctIndex: 2,
            explanation: 'A verb is an action word. "Ate" is the action happening!',
          ),
          QuestionModel(
            question: 'Which word is an ADJECTIVE in: "The big red ball bounced"?',
            options: ['The', 'big', 'bounced', 'ball'],
            correctIndex: 1,
            explanation: 'Adjectives describe nouns. "Big" describes the ball!',
          ),
          QuestionModel(
            question: 'Which word is an ADVERB in: "He ran quickly to school"?',
            options: ['He', 'ran', 'quickly', 'school'],
            correctIndex: 2,
            explanation: 'Adverbs describe verbs. "Quickly" tells us HOW he ran!',
          ),
          QuestionModel(
            question: 'What part of speech is "beautiful" in: "She wore a beautiful dress"?',
            options: ['Noun', 'Verb', 'Adverb', 'Adjective'],
            correctIndex: 3,
            explanation: '"Beautiful" describes the dress, making it an adjective!',
          ),
        ],
      ),
      ActivityModel(
        id: 'social_001_$grade',
        title: 'SA Provinces',
        description: 'Learn about South Africa\'s 9 provinces!',
        subject: 'Social Sciences',
        type: 'quiz',
        difficulty: 'easy',
        rewardPoints: 10,
        grade: grade,
        createdAt: DateTime.now(),
        questions: [
          QuestionModel(
            question: 'How many provinces does South Africa have?',
            options: ['7', '8', '9', '10'],
            correctIndex: 2,
            explanation: 'South Africa has 9 provinces since the 1994 elections!',
          ),
          QuestionModel(
            question: 'What is the capital city of Gauteng?',
            options: ['Johannesburg', 'Pretoria', 'Soweto', 'Sandton'],
            correctIndex: 1,
            explanation: 'Pretoria (Tshwane) is the administrative capital of Gauteng!',
          ),
          QuestionModel(
            question: 'Which province is the largest by area?',
            options: ['Limpopo', 'Northern Cape', 'North West', 'Gauteng'],
            correctIndex: 1,
            explanation: 'Northern Cape is the largest province covering about 30% of SA!',
          ),
          QuestionModel(
            question: 'Which province is the smallest by area?',
            options: ['Western Cape', 'Mpumalanga', 'Gauteng', 'Free State'],
            correctIndex: 2,
            explanation: 'Gauteng is the smallest but most populated province!',
          ),
          QuestionModel(
            question: 'Cape Town is the capital of which province?',
            options: ['Eastern Cape', 'Northern Cape', 'Western Cape', 'KwaZulu-Natal'],
            correctIndex: 2,
            explanation: 'Cape Town is the capital of the Western Cape province!',
          ),
        ],
      ),
    ];
  }
}
