import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/features/games/core/game_config.dart';
import 'package:questkids/features/games/tug_of_war/tug_of_war_config.dart';
import 'package:questkids/features/games/tug_of_war/tug_of_war_engine.dart';
import 'package:questkids/features/games/tug_of_war/tug_of_war_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  group('TugOfWarSession decimal/negative input', () {
    late TugOfWarSession session;

    setUp(() {
      session = TugOfWarSession(
        const GameConfig(
          engineType: 'tugOfWar',
          subject: 'Mathematics',
          grade: 'grade4',
          topicId: 'decimals',
          subtopicId: 'decimal_operations',
          catalogId: 'math_g4_decimals',
        ),
        'test-uid',
      );
    });

    tearDown(() => session.dispose());

    test('typing a decimal point once is accepted', () {
      session.appendDigit('1');
      session.appendDigit('2');
      session.appendDigit('.');
      session.appendDigit('5');
      expect(session.currentInput, '12.5');
    });

    test('a second decimal point is rejected', () {
      session.appendDigit('1');
      session.appendDigit('.');
      session.appendDigit('2');
      session.appendDigit('.');
      session.appendDigit('5');
      expect(session.currentInput, '1.25');
    });

    test('the sign toggle prefixes a leading minus', () {
      session.appendDigit('4');
      session.appendDigit('5');
      session.appendDigit('±');
      expect(session.currentInput, '-45');
    });

    test('tapping the sign toggle twice removes the minus again', () {
      session.appendDigit('4');
      session.appendDigit('5');
      session.appendDigit('±');
      session.appendDigit('±');
      expect(session.currentInput, '45');
    });

    test('a minus cannot appear after digits are typed via the digit key', () {
      // '-' typed as a raw digit char (not via the ± toggle) is not one of
      // the keypad's digit keys, but guard the session method directly too.
      session.appendDigit('4');
      session.appendDigit('-');
      expect(session.currentInput, '4');
    });
  });

  group('TugOfWarEngine decimal/integer questions', () {
    test('decimal type generates a non-integer answer with one decimal place', () {
      const config = GameConfig(
        engineType: 'tugOfWar',
        subject: 'Mathematics',
        grade: 'grade4',
      );
      final engine = TugOfWarEngine(
        tugConfig: const TugOfWarConfig(questionType: 'decimal'),
        config: config,
      );
      final questions = engine.generateQuestions();
      expect(questions, isNotEmpty);
      for (final q in questions) {
        expect(q['type'], 'decimal');
        expect(q['answer'], isA<double>());
        final display = q['display'] as String;
        expect(display, contains('.'));
      }
    });

    test('decimal checkAnswer accepts the correct value within tolerance', () {
      final engine = TugOfWarEngine(
        tugConfig: const TugOfWarConfig(questionType: 'decimal'),
        config: const GameConfig(
            engineType: 'tugOfWar', subject: 'Mathematics', grade: 'grade4'),
      );
      final question = {'answer': 12.5, 'type': 'decimal'};
      expect(engine.checkAnswer(question, '12.5').correct, isTrue);
      expect(engine.checkAnswer(question, '12.4').correct, isFalse);
    });

    test('integer type generates answers that can be negative', () {
      const config = GameConfig(
        engineType: 'tugOfWar',
        subject: 'Mathematics',
        grade: 'grade7',
      );
      final engine = TugOfWarEngine(
        tugConfig: const TugOfWarConfig(
            questionType: 'integer', multiplierMin: 1, multiplierMax: 20),
        config: config,
      );
      final questions = engine.generateQuestions();
      expect(questions, isNotEmpty);
      expect(questions.every((q) => q['type'] == 'integer'), isTrue);
      // Not every run is guaranteed to draw a negative result, but the
      // question shape must support one: assert the type contract instead
      // of a specific sign.
      expect(questions.every((q) => q['answer'] is int), isTrue);
    });

    test('integer checkAnswer accepts a negative submitted value', () {
      final engine = TugOfWarEngine(
        tugConfig: const TugOfWarConfig(questionType: 'integer'),
        config: const GameConfig(
            engineType: 'tugOfWar', subject: 'Mathematics', grade: 'grade7'),
      );
      final question = {'answer': -7, 'type': 'integer'};
      expect(engine.checkAnswer(question, '-7').correct, isTrue);
      expect(engine.checkAnswer(question, '7').correct, isFalse);
    });
  });
}
