import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/core/constants/game_catalog.dart';
import 'package:questkids/features/games/core/game_config.dart';
import 'package:questkids/features/games/decimal_dunes/decimal_dunes_game.dart';

/// Deep behavioral coverage for DecimalDunesGame (see
/// fraction_forest_game_test.dart for the general approach).
///
/// "Oasis Order" (smallest/largest of 3 tiles), "Compare Canyon" (bigger
/// of 2 tiles), and "Sandstorm Sums" (money +/-) are all tap-a-choice
/// zones with the answer computable from what's rendered -- 15/20
/// questions get real verification. "Dune Line" is a drag-to-position
/// number line with no discrete choice text to reason about (same
/// limitation as fraction_forest's shaded-pie zone) -- it's tapped
/// through to keep the playthrough moving but not asserted on.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  final decimalPattern = RegExp(r'^\d+\.\d+$');
  final moneyPattern = RegExp(r'^R(\d+\.\d+)$');
  final moneyPromptPattern =
      RegExp(r'^R(\d+\.\d+) ([+-]) R(\d+\.\d+) = \?$');

  List<String> visibleDecimalTexts(WidgetTester tester) {
    return tester
        .widgetList<Text>(find.byType(Text))
        .map((w) => w.data ?? '')
        .where((s) => decimalPattern.hasMatch(s))
        .toList();
  }

  List<String> visibleMoneyTexts(WidgetTester tester) {
    return tester
        .widgetList<Text>(find.byType(Text))
        .map((w) => w.data ?? '')
        .where((s) => moneyPattern.hasMatch(s))
        .toList();
  }

  bool looksLikePrompt(String s) =>
      s.startsWith('Tap the') || s.startsWith('Drag the') || moneyPromptPattern.hasMatch(s);

  String currentPrompt(WidgetTester tester) {
    return tester
        .widgetList<Text>(find.byType(Text))
        .map((w) => w.data ?? '')
        .firstWhere(looksLikePrompt);
  }

  Future<void> settle(WidgetTester tester, String previousPrompt) async {
    await tester.pump();
    for (var i = 0; i < 45; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.textContaining('Dunes Crossed').evaluate().isNotEmpty) return;
      final prompts = tester
          .widgetList<Text>(find.byType(Text))
          .map((w) => w.data ?? '')
          .where(looksLikePrompt);
      if (prompts.isNotEmpty && !prompts.contains(previousPrompt)) return;
    }
  }

  testWidgets(
      'DecimalDunesGame: Oasis Order/Compare Canyon/Sandstorm Sums accept '
      'the mathematically correct answer, full 20-question playthrough '
      'completes', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final entry =
        GameCatalog.all.firstWhere((e) => e.engineType == 'decimalDunes');
    final config = GameConfig.fromCatalogEntry(entry);

    await tester.pumpWidget(MaterialApp(
      home: DecimalDunesGame(config: config, user: null),
    ));

    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump();

    var verifiedCount = 0;

    for (var q = 0; q < 20; q++) {
      final prompt = currentPrompt(tester);

      if (prompt.startsWith('Drag the')) {
        // Dune Line -- no discrete choice text to verify against. Tap
        // wherever the number-line gesture detector is to submit
        // *some* answer and keep the playthrough moving.
        await tester.tap(find.byType(GestureDetector).last);
        await settle(tester, prompt);
      } else if (prompt.startsWith('Tap the SMALLEST decimal.') ||
          prompt.startsWith('Tap the LARGEST decimal.') ||
          prompt.startsWith('Tap the BIGGER decimal.')) {
        final tiles = visibleDecimalTexts(tester);
        expect(tiles.length, inInclusiveRange(2, 3),
            reason: 'expected 2-3 decimal tiles for "$prompt", got $tiles');
        final values = tiles.map(double.parse).toList();
        final wantMax = prompt.contains('LARGEST') || prompt.contains('BIGGER');
        final targetValue =
            wantMax ? values.reduce((a, b) => a > b ? a : b) : values.reduce((a, b) => a < b ? a : b);
        final expected = tiles[values.indexOf(targetValue)];

        await tester.tap(find.text(expected).last);
        await settle(tester, prompt);
        expect(find.textContaining('The answer was'), findsNothing,
            reason: 'question "$prompt": expected "$expected" to be correct');
        verifiedCount++;
      } else {
        final m = moneyPromptPattern.firstMatch(prompt);
        expect(m, isNotNull, reason: 'unrecognized prompt shape: "$prompt"');
        final a = double.parse(m!.group(1)!);
        final op = m.group(2)!;
        final b = double.parse(m.group(3)!);
        final result = op == '+' ? a + b : a - b;
        final expected = 'R${result.toStringAsFixed(2)}';
        expect(visibleMoneyTexts(tester), contains(expected),
            reason:
                'computed "$expected" for "$prompt" but it is not among the visible choices ${visibleMoneyTexts(tester)}');

        await tester.tap(find.text(expected).last);
        await settle(tester, prompt);
        expect(find.textContaining('The answer was'), findsNothing,
            reason: 'question "$prompt": expected "$expected" to be correct');
        verifiedCount++;
      }
    }

    expect(find.textContaining('Dunes Crossed'), findsWidgets,
        reason: 'did not reach the victory screen after 20 questions');
    expect(verifiedCount, 15);
  });
}
