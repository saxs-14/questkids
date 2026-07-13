import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/features/games/core/game_config.dart';
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
}
