import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/core/constants/game_catalog.dart';
import 'package:questkids/features/games/core/game_config.dart';
import 'package:questkids/features/games/number_ninja/number_ninja_game.dart';

/// Deep behavioral coverage for NumberNinjaGame (see
/// fraction_forest_game_test.dart for the general approach). All 20
/// questions are verifiable: "Skip Counting"/"Counting Down"/"Multiples"
/// are arithmetic sequences (constant difference between terms,
/// extrapolated for the next one), and "Rule Master" states its
/// transformation rule directly in the prompt ("Rule: ×2, then +1").
///
/// Each question has a 6-second on-screen timer (_questionSeconds) that
/// auto-submits a wrong answer on expiry -- this test always computes and
/// taps immediately after reading the prompt, well inside that window.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  String currentPrompt(WidgetTester tester) {
    return tester
        .widgetList<Text>(find.byType(Text))
        .map((w) => w.data ?? '')
        .firstWhere((s) => s.endsWith('?'));
  }

  Future<void> tapAndAdvance(
      WidgetTester tester, String label, String previousPrompt) async {
    await tester.tap(find.text(label).last);
    await tester.pump();
    for (var i = 0; i < 45; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('Dojo Mastered!').evaluate().isNotEmpty) return;
      final prompts = tester
          .widgetList<Text>(find.byType(Text))
          .map((w) => w.data ?? '')
          .where((s) => s.endsWith('?'));
      if (prompts.isNotEmpty && !prompts.contains(previousPrompt)) return;
    }
  }

  int applyRule(String ruleText, int input) {
    var value = input;
    for (final step in ruleText.split(', then ')) {
      final op = step[0];
      final n = int.parse(step.substring(1));
      value = switch (op) {
        '×' => value * n,
        '+' => value + n,
        '-' => value - n,
        '÷' => value ~/ n,
        _ => throw StateError('unknown rule operator "$op" in "$ruleText"'),
      };
    }
    return value;
  }

  testWidgets(
      'NumberNinjaGame: every sequence/rule question accepts the '
      'mathematically correct next value as correct, full 20-question '
      'playthrough completes', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final entry = GameCatalog.all.firstWhere((e) => e.engineType == 'numberNinja');
    final config = GameConfig.fromCatalogEntry(entry);

    await tester.pumpWidget(MaterialApp(
      home: NumberNinjaGame(config: config, user: null),
    ));

    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump();

    for (var q = 0; q < 20; q++) {
      final prompt = currentPrompt(tester);
      final String expected;

      final ruleMatch = RegExp(r'Rule: (.+)').firstMatch(prompt);
      if (ruleMatch != null) {
        final inputMatch = RegExp(r'Input (\d+)').firstMatch(prompt);
        expect(inputMatch, isNotNull,
            reason: 'no "Input N" found in rule prompt "$prompt"');
        final input = int.parse(inputMatch!.group(1)!);
        expected = '${applyRule(ruleMatch.group(1)!, input)}';
      } else {
        final terms = RegExp(r'-?\d+')
            .allMatches(prompt.substring(0, prompt.indexOf('?')))
            .map((m) => int.parse(m.group(0)!))
            .toList();
        expect(terms.length, greaterThanOrEqualTo(2),
            reason: 'expected at least 2 sequence terms in "$prompt"');
        final diff = terms[1] - terms[0];
        for (var i = 1; i < terms.length - 1; i++) {
          expect(terms[i + 1] - terms[i], diff,
              reason:
                  'sequence "$prompt" is not a constant-difference progression');
        }
        expected = '${terms.last + diff}';
      }

      await tapAndAdvance(tester, expected, prompt);
      expect(find.textContaining('The answer was'), findsNothing,
          reason: 'question "$prompt": expected "$expected" to be correct');
    }

    expect(find.text('Dojo Mastered!'), findsOneWidget,
        reason: 'did not reach the victory screen after 20 questions');
  });
}
