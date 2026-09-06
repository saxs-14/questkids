import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/core/constants/game_catalog.dart';
import 'package:questkids/features/games/core/game_config.dart';
import 'package:questkids/features/games/fraction_forest/fraction_forest_game.dart';

/// Deep behavioral coverage for FractionForestGame, beyond the universal
/// smoke test (game_router_widget_test.dart only checks it builds without
/// exceptions). All question/answer data is private to the widget's
/// library, so this can't assert against the hardcoded source directly
/// without duplicating it (a copy that could drift out of sync and pass
/// even if the real data breaks). Instead it independently recomputes the
/// expected correct answer from what's actually rendered on screen --
/// the prompt states the arithmetic/target fraction directly for the
/// equivalent-fraction, comparison, and addition zones -- so a real math
/// bug in the question data fails this test without the test needing to
/// know the data in advance.
///
/// Zone 1 (shaded-pie "Whole Woods") is the one exception: what's shaded
/// is drawn as CustomPaint pixels, not exposed as text, so there's no way
/// to independently verify it from widget content alone -- those 5
/// questions are answered but not asserted on, same limitation the smoke
/// test already has.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  final fractionPattern = RegExp(r'^\d+/\d+$');
  final equivPattern =
      RegExp(r'^Which fraction is equivalent to (\d+)/(\d+)\?$');
  final addPattern = RegExp(r'^(\d+)/(\d+) \+ (\d+)/(\d+) = \?$');

  List<String> visibleFractionTexts(WidgetTester tester) {
    return tester
        .widgetList<Text>(find.byType(Text))
        .map((w) => w.data ?? '')
        .where((s) => fractionPattern.hasMatch(s))
        .toList();
  }

  List<int> parseFraction(String s) {
    final parts = s.split('/');
    return [int.parse(parts[0]), int.parse(parts[1])];
  }

  bool looksLikePrompt(String s) =>
      s.endsWith('?') || s.startsWith('Tap the bigger fraction');

  String currentPrompt(WidgetTester tester) {
    return tester
        .widgetList<Text>(find.byType(Text))
        .map((w) => w.data ?? '')
        .firstWhere(looksLikePrompt);
  }

  Future<void> tapAndAdvance(
      WidgetTester tester, String label, String previousPrompt) async {
    await tester.tap(find.text(label));
    await tester.pump();
    for (var i = 0; i < 45; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('Forest Complete!').evaluate().isNotEmpty) return;
      final prompts = tester
          .widgetList<Text>(find.byType(Text))
          .map((w) => w.data ?? '')
          .where(looksLikePrompt);
      if (prompts.isNotEmpty && !prompts.contains(previousPrompt)) return;
    }
  }

  testWidgets(
      'FractionForestGame: every equivalent/comparison/addition question '
      'accepts the mathematically correct answer as correct, full 20-question '
      'playthrough reaches Forest Complete!', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final entry = GameCatalog.all.firstWhere((e) => e.id == 'math_g4_fractions');
    final config = GameConfig.fromCatalogEntry(entry);

    await tester.pumpWidget(MaterialApp(
      home: FractionForestGame(config: config, user: null),
    ));

    // initState's _delayed(700, _startGame) — clears the intro screen.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump();

    var verifiedCount = 0;

    for (var q = 0; q < 20; q++) {
      final prompt = currentPrompt(tester);
      final equivMatch = equivPattern.firstMatch(prompt);
      final addMatch = addPattern.firstMatch(prompt);
      final isCompare = prompt.startsWith('Tap the bigger fraction');

      if (equivMatch != null) {
        final targetNum = int.parse(equivMatch.group(1)!);
        final targetDenom = int.parse(equivMatch.group(2)!);
        final choices = visibleFractionTexts(tester);
        final match = choices.firstWhere((c) {
          final f = parseFraction(c);
          return targetNum * f[1] == f[0] * targetDenom;
        }, orElse: () => '');
        expect(match, isNotEmpty,
            reason:
                'no choice equivalent to $targetNum/$targetDenom found among $choices for "$prompt"');
        await tapAndAdvance(tester, match, prompt);
        expect(find.textContaining('The answer was'), findsNothing,
            reason:
                'equivalent-fraction question "$prompt" marked "$match" wrong');
        verifiedCount++;
      } else if (addMatch != null) {
        final n1 = int.parse(addMatch.group(1)!);
        final d1 = int.parse(addMatch.group(2)!);
        final n2 = int.parse(addMatch.group(3)!);
        final d2 = int.parse(addMatch.group(4)!);
        expect(d1, d2,
            reason:
                'Vine Adder question "$prompt" has mismatched denominators -- '
                'the engine only supports same-denominator addition');
        final expectedLabel = '${n1 + n2}/$d1';
        await tapAndAdvance(tester, expectedLabel, prompt);
        expect(find.textContaining('The answer was'), findsNothing,
            reason:
                'addition question "$prompt": expected "$expectedLabel" to be correct');
        verifiedCount++;
      } else if (isCompare) {
        final fracs = visibleFractionTexts(tester);
        expect(fracs.length, 2,
            reason:
                'expected exactly 2 compare-bar fractions visible for "$prompt", got $fracs');
        final f1 = parseFraction(fracs[0]);
        final f2 = parseFraction(fracs[1]);
        final cross1 = f1[0] * f2[1];
        final cross2 = f2[0] * f1[1];
        final String tapLabel;
        if (cross1 == cross2) {
          tapLabel = 'Equal!';
        } else if (cross1 > cross2) {
          tapLabel = fracs[0];
        } else {
          tapLabel = fracs[1];
        }
        await tapAndAdvance(tester, tapLabel, prompt);
        expect(find.textContaining('The answer was'), findsNothing,
            reason:
                'comparison question "$prompt": expected "$tapLabel" to be correct');
        verifiedCount++;
      } else {
        // Whole Woods (shaded-pie) -- can't independently verify which
        // choice is correct without reading CustomPaint pixels. Tap
        // whichever choice renders first and keep moving; the assertion
        // coverage for this zone is "does it complete without crashing",
        // same as the smoke test.
        final choices = visibleFractionTexts(tester);
        expect(choices, isNotEmpty,
            reason: 'expected fraction choices for "$prompt"');
        await tapAndAdvance(tester, choices.first, prompt);
      }
    }

    expect(find.text('Forest Complete!'), findsOneWidget,
        reason: 'did not reach the victory screen after 20 questions');
    // 15 of the 20 questions (equivalent/comparison/addition zones) were
    // answered with an independently-computed correct answer -- if any of
    // those math checks are wrong in the source data, one of the
    // in-loop "answer was marked wrong" expectations above would already
    // have failed before reaching here.
    expect(verifiedCount, 15);
  });
}
