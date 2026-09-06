import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/core/constants/game_catalog.dart';
import 'package:questkids/features/games/core/game_config.dart';
import 'package:questkids/features/games/problem_solver/problem_solver_game.dart';

/// Completion coverage for ProblemSolverGame. This is the most
/// structurally complex engine tested this session: every one of the 20
/// questions is answered in two steps -- first pick which operation
/// (+, −, ×, ÷) solves the word problem, then pick the numeric answer --
/// and unlike division_desert's two-step zone (where both numbers came
/// straight from "A ÷ B = ?"), the operation here has to be inferred from
/// free-form, uniquely-phrased detective-narrative text with no shared
/// structure across questions ("A detective drove 18 km, then 25 km
/// more" vs "45 stolen jewels were split equally among 5 suspects" vs
/// "The stakeout van has 3 rows of 6 seats"). Reliably classifying which
/// operation each of the 20 distinct narratives implies would need a
/// real per-question judgment call, not a reusable parsing rule -- so
/// this doesn't attempt correctness verification (same call as
/// geometry_jungle/addition_adventure). It always taps the first
/// operator badge for step 1 (both steps have their own independent
/// correct/wrong reveal per _onOperatorTap/_onAnswerTap, and the flow
/// advances to step 2 either way -- confirmed by reading the source) and
/// the first numeric tile for step 2, and asserts the full 20-question,
/// 2-step-each playthrough completes without exceptions.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  bool onStep2(WidgetTester tester) {
    return tester
        .widgetList<Text>(find.byType(Text))
        .map((w) => w.data ?? '')
        .any((s) => RegExp(r'^\d+$').hasMatch(s));
  }

  testWidgets(
      'ProblemSolverGame: full 20-question, 2-step-each playthrough '
      'completes without exceptions and reaches the victory screen',
      (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final entry = GameCatalog.all.firstWhere((e) => e.engineType == 'problemSolver');
    final config = GameConfig.fromCatalogEntry(entry);

    await tester.pumpWidget(MaterialApp(
      home: ProblemSolverGame(config: config, user: null),
    ));

    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump();

    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      // ignore: avoid_print
      print('=== FULL FLUTTER ERROR ===\n$details');
      originalOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = originalOnError);

    for (var q = 0; q < 20; q++) {
      if (find.text('Case Closed!').evaluate().isNotEmpty) break;

      // Step 1: tap the first operator badge ('+').
      expect(find.text('+'), findsOneWidget,
          reason: 'expected the addition operator badge at question $q');
      await tester.tap(find.text('+'));
      await tester.pump();
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (onStep2(tester)) break;
      }
      expect(tester.takeException(), isNull,
          reason: 'exception thrown picking the operator at question $q');

      // Step 2: tap the first numeric case-file tile.
      final choices = tester
          .widgetList<Text>(find.byType(Text))
          .map((w) => w.data ?? '')
          .where((s) => RegExp(r'^\d+$').hasMatch(s))
          .toList();
      expect(choices, isNotEmpty,
          reason: 'expected numeric answer tiles at question $q step 2');
      await tester.tap(find.text(choices.first).last);
      await tester.pump();
      for (var i = 0; i < 45; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find.text('Case Closed!').evaluate().isNotEmpty) break;
        if (find.text('+').evaluate().isNotEmpty) break; // back to step 1
      }
      expect(tester.takeException(), isNull,
          reason: 'exception thrown answering question $q step 2');
    }

    expect(find.text('Case Closed!'), findsOneWidget,
        reason: 'did not reach the victory screen after 20 questions');
  });
}
