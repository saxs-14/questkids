import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/features/games/budget_builder/budget_builder_engine.dart';
import 'package:questkids/features/games/core/game_config.dart';
import 'package:questkids/core/constants/app_constants.dart';

GameConfig _makeConfig({int questionCount = 4}) => GameConfig(
      engineType: AppConstants.engineBudgetBuilder,
      subject: 'EMS',
      grade: 'grade7',
      topicId: 'personal_finance',
      subtopicId: 'needs_wants',
      difficulty: 'easy',
      questionCount: questionCount,
    );

void main() {
  group('BudgetBuilderEngine', () {
    test('generateQuestions returns correct count', () {
      final engine = BudgetBuilderEngine(_makeConfig(questionCount: 4));
      final questions = engine.generateQuestions();
      expect(questions.length, equals(4));
    });

    test('each question has budget, scenario, and items', () {
      final engine = BudgetBuilderEngine(_makeConfig());
      for (final q in engine.generateQuestions()) {
        expect(q['budget'], isA<int>());
        expect(q['scenario'], isA<String>());
        expect(q['items'], isA<List>());
        expect((q['items'] as List).isNotEmpty, isTrue);
      }
    });

    test('each item has name, cost, category, emoji', () {
      final engine = BudgetBuilderEngine(_makeConfig());
      final q = engine.generateQuestions().first;
      for (final item in (q['items'] as List).cast<Map<String, dynamic>>()) {
        expect(item['name'], isA<String>());
        expect(item['cost'], isA<int>());
        expect(['need', 'want', 'skip'], contains(item['category']));
        expect(item['emoji'], isA<String>());
      }
    });

    test('checkAnswer all correct returns correct=true', () {
      final engine = BudgetBuilderEngine(_makeConfig());
      final q = engine.generateQuestions().first;
      final items = (q['items'] as List).cast<Map<String, dynamic>>();
      final answers = {
        for (final item in items)
          item['name'] as String: item['category'] as String
      };
      final result = engine.checkAnswer(q, answers);
      expect(result.correct, isTrue);
    });

    test('checkAnswer all wrong returns correct=false', () {
      final engine = BudgetBuilderEngine(_makeConfig());
      final q = engine.generateQuestions().first;
      final items = (q['items'] as List).cast<Map<String, dynamic>>();
      final wrongAnswers = {
        for (final item in items) item['name'] as String: 'wrongCategory',
      };
      final result = engine.checkAnswer(q, wrongAnswers);
      expect(result.correct, isFalse);
    });

    test('buildResult loss when fewer than half correct', () {
      final engine = BudgetBuilderEngine(_makeConfig(questionCount: 6));
      final result = engine.buildResult(
          correct: 2, total: 6, timeTakenSeconds: 90, xpFromAnswers: 40);
      expect(result.result, equals('loss'));
      expect(result.score, equals(33));
    });

    test('generateQuestions returns unique scenarios', () {
      final engine = BudgetBuilderEngine(_makeConfig(questionCount: 4));
      final questions = engine.generateQuestions();
      final scenarios = questions.map((q) => q['scenario']).toSet();
      expect(scenarios.length, equals(4));
    });
  });
}
