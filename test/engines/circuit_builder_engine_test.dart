import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/features/games/circuit_builder/circuit_builder_engine.dart';
import 'package:questkids/features/games/core/game_config.dart';
import 'package:questkids/core/constants/app_constants.dart';

GameConfig _makeConfig({int questionCount = 5}) => GameConfig(
  engineType: AppConstants.engineCircuitBuilder,
  subject: 'Technology',
  grade: 'grade7',
  topicId: 'electric_circuits',
  subtopicId: 'series',
  difficulty: 'easy',
  extras: {'questionCount': questionCount},
);

void main() {
  group('CircuitBuilderEngine', () {
    test('generateQuestions returns correct count', () {
      final engine = CircuitBuilderEngine(_makeConfig(questionCount: 5));
      final questions = engine.generateQuestions();
      expect(questions.length, equals(5));
    });

    test('each question has required fields', () {
      final engine = CircuitBuilderEngine(_makeConfig());
      for (final q in engine.generateQuestions()) {
        expect(q['description'], isA<String>());
        expect(q['blanks'], isA<List>());
        expect(q['bank'], isA<List>());
        expect(q['labels'], isA<Map>());
        expect((q['blanks'] as List).isNotEmpty, isTrue);
      }
    });

    test('checkAnswer returns correct for right answer', () {
      final engine = CircuitBuilderEngine(_makeConfig());
      final q = engine.generateQuestions().first;
      final blanks = (q['blanks'] as List).cast<Map<String, dynamic>>();
      final correctAnswers = blanks.map((b) => b['correctComponent'] as String).toList();
      final result = engine.checkAnswer(q, correctAnswers);
      expect(result.correct, isTrue);
    });

    test('checkAnswer returns incorrect for wrong answer', () {
      final engine = CircuitBuilderEngine(_makeConfig());
      final q = engine.generateQuestions().first;
      final wrongAnswers = List.filled((q['blanks'] as List).length, 'wrongComponent');
      final result = engine.checkAnswer(q, wrongAnswers);
      expect(result.correct, isFalse);
    });

    test('buildResult win when majority correct', () {
      final engine = CircuitBuilderEngine(_makeConfig(questionCount: 5));
      final result = engine.buildResult(correct: 4, total: 5, timeTakenSeconds: 60);
      expect(result.score, equals(80));
      expect(result.xpEarned, greaterThan(0));
    });

    test('buildResult perfect score gives complete result', () {
      final engine = CircuitBuilderEngine(_makeConfig(questionCount: 5));
      final result = engine.buildResult(correct: 5, total: 5, timeTakenSeconds: 45);
      expect(result.result, equals('complete'));
      expect(result.accuracy, closeTo(1.0, 0.01));
    });
  });
}
