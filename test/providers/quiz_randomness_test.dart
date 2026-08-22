import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/data/models/activity_model.dart';
import 'package:questkids/providers/quiz_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  test('QuizProvider startQuiz shuffles options and adjusts correctIndex accurately', () {
    final provider = QuizProvider();

    final staticActivity = ActivityModel(
      id: 'test_act_1',
      title: 'Multiplication Test',
      description: 'Test',
      subject: 'Math',
      type: 'quiz',
      difficulty: 'medium',
      rewardPoints: 20,
      grade: 'Grade 4',
      createdAt: DateTime.now(),
      questions: [
        QuestionModel(
          question: 'What is 6 x 7?',
          options: ['40', '42', '48', '36'],
          correctIndex: 1, // '42'
          explanation: '6 x 7 = 42',
        ),
        QuestionModel(
          question: 'What is 8 x 9?',
          options: ['63', '72', '81', '64'],
          correctIndex: 1, // '72'
          explanation: '8 x 9 = 72',
        ),
      ],
    );

    provider.startQuiz(staticActivity);

    final q1 = provider.currentActivity!.questions[0];
    final q2 = provider.currentActivity!.questions[1];

    // Verify correct answers still point to the correct values
    expect(q1.options[q1.correctIndex], '42');
    expect(q2.options[q2.correctIndex], '72');
    expect(provider.state, QuizState.active);
  });
}
