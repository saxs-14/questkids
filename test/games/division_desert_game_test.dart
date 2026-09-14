import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/core/constants/game_catalog.dart';
import 'package:questkids/features/games/core/game_config.dart';
import 'package:questkids/features/games/division_desert/division_desert_game.dart';

/// Deep behavioral coverage for DivisionDesertGame (see
/// fraction_forest_game_test.dart for the general approach: independently
/// recompute the expected correct answer from rendered content instead of
/// duplicating the private source data).
///
/// All 20 questions are verifiable here, across 4 different answer
/// shapes:
///  - "Even Split" / "Fact Families": plain "A ÷ B = ?" -- tap the
///    computed quotient.
///  - "Leftover Oasis": two-step (quotient, then remainder) -- same
///    "A ÷ B = ?" main prompt supplies both numbers; each step is
///    verified independently via the no-wrong-reveal check before moving
///    to the next step.
///  - "Desert Trek": word problems ("shared among" / "put into
///    bags/baskets of") -- extracts the two numbers in order (total,
///    group size), computes quotient+remainder, and matches the answer
///    template ("N each/bags/baskets, M left over") from whichever
///    choice is currently on screen rather than hardcoding the phrasing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  final mainPromptPattern = RegExp(r'(\d+)\s*÷\s*(\d+)\s*=\s*\?');
  final leftoverChoicePattern =
      RegExp(r'^(\d+) (each|bags|baskets), (\d+) left over$');

  String currentMainPrompt(WidgetTester tester) {
    // The main prompt (q.prompt) always ends with '?', and — for the
    // two-step zone — is built before the "Step N/2: ..." sub-prompt
    // Text (which also ends with '?'), so firstWhere's tree-order scan
    // reliably lands on the main prompt, not the sub-prompt.
    return tester
        .widgetList<Text>(find.byType(Text))
        .map((w) => w.data ?? '')
        .firstWhere((s) => s.endsWith('?'));
  }

  bool isStepOne(WidgetTester tester) {
    return tester
        .widgetList<Text>(find.byType(Text))
        .any((w) => (w.data ?? '').startsWith('Step 1/2:'));
  }

  bool isStepTwo(WidgetTester tester) {
    return tester
        .widgetList<Text>(find.byType(Text))
        .any((w) => (w.data ?? '').startsWith('Step 2/2:'));
  }

  Future<void> tapAndWaitFor(
      WidgetTester tester, String label, bool Function() until) async {
    await tester.tap(find.text(label).last);
    await tester.pump();
    for (var i = 0; i < 45; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('Cookies Shared!').evaluate().isNotEmpty) return;
      if (until()) return;
    }
  }

  testWidgets(
      'DivisionDesertGame: every question (simple, two-step, and word '
      'problem) accepts the mathematically correct division as correct, '
      'full 20-question playthrough completes', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final entry =
        GameCatalog.all.firstWhere((e) => e.engineType == 'divisionDesert');
    final config = GameConfig.fromCatalogEntry(entry);

    await tester.pumpWidget(MaterialApp(
      home: DivisionDesertGame(config: config, user: null),
    ));

    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump();

    for (var q = 0; q < 20; q++) {
      final prompt = currentMainPrompt(tester);
      final divMatch = mainPromptPattern.firstMatch(prompt);

      if (isStepOne(tester)) {
        // Leftover Oasis, step 1: tap the quotient.
        final total = int.parse(divMatch!.group(1)!);
        final divisor = int.parse(divMatch.group(2)!);
        final quotient = total ~/ divisor;
        await tapAndWaitFor(
            tester, '$quotient', () => isStepTwo(tester));
        expect(find.textContaining('The answer was'), findsNothing,
            reason:
                'question "$prompt" step 1: expected quotient $quotient to be correct');

        // Step 2: tap the remainder.
        final remainder = total % divisor;
        await tapAndWaitFor(tester, '$remainder',
            () => currentMainPrompt(tester) != prompt);
        expect(find.textContaining('The answer was'), findsNothing,
            reason:
                'question "$prompt" step 2: expected remainder $remainder to be correct');
      } else if (divMatch != null) {
        // Even Split / Fact Families: plain "A ÷ B = ?".
        final a = int.parse(divMatch.group(1)!);
        final b = int.parse(divMatch.group(2)!);
        final expected = '${a ~/ b}';
        await tapAndWaitFor(
            tester, expected, () => currentMainPrompt(tester) != prompt);
        expect(find.textContaining('The answer was'), findsNothing,
            reason: 'question "$prompt": expected "$expected" to be correct');
      } else {
        // Desert Trek word problems: no "÷" in the prompt text itself.
        final nums = RegExp(r'\d+')
            .allMatches(prompt)
            .map((m) => int.parse(m.group(0)!))
            .toList();
        expect(nums.length, greaterThanOrEqualTo(2),
            reason: 'expected 2 numbers in word problem "$prompt"');
        final total = nums[0];
        final groupSize = nums[1];
        final quotient = total ~/ groupSize;
        final remainder = total % groupSize;

        final sampleChoice = tester
            .widgetList<Text>(find.byType(Text))
            .map((w) => w.data ?? '')
            .firstWhere((s) => leftoverChoicePattern.hasMatch(s));
        final word = leftoverChoicePattern.firstMatch(sampleChoice)!.group(2)!;
        final expected = '$quotient $word, $remainder left over';

        await tapAndWaitFor(
            tester, expected, () => currentMainPrompt(tester) != prompt);
        expect(find.textContaining('The answer was'), findsNothing,
            reason:
                'word problem "$prompt": expected "$expected" to be correct');
      }
    }

    expect(find.textContaining('Cookies Shared'), findsWidgets,
        reason: 'did not reach the victory screen after 20 questions');
  });
}
