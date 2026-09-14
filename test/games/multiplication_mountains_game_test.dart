import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/core/constants/game_catalog.dart';
import 'package:questkids/features/games/core/game_config.dart';
import 'package:questkids/features/games/multiplication_mountains/multiplication_mountains_game.dart';

/// Deep behavioral coverage for MultiplicationMountainsGame (see
/// fraction_forest_game_test.dart for why this independently recomputes
/// answers from rendered content instead of duplicating the private
/// source data). Every one of the 20 prompts leads with a plain "A × B"
/// expression -- even "Break-Down Bluff"'s decomposition prompts
/// ("32 × 3 = (30×3) + (2×3) = ?") -- so all 20 get real verification,
/// unlike fraction_forest where one zone's diagram-only content couldn't
/// be checked independently.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  final promptPattern = RegExp(r'^(\d+)\s*×\s*(\d+)');

  bool looksLikePrompt(String s) => promptPattern.hasMatch(s);

  String currentPrompt(WidgetTester tester) {
    return tester
        .widgetList<Text>(find.byType(Text))
        .map((w) => w.data ?? '')
        .firstWhere(looksLikePrompt);
  }

  Future<void> tapAndAdvance(
      WidgetTester tester, String label, String previousPrompt) async {
    // Grid/doubling-chain diagrams can render the same digits as an
    // answer choice (e.g. a "60" step in the doubling chain vs. a "60"
    // choice button) -- the choice buttons are always the last matching
    // Text in tree order (diagram is built before the choice Wrap).
    await tester.tap(find.text(label).last);
    await tester.pump();
    for (var i = 0; i < 45; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('Pond Crossed!').evaluate().isNotEmpty) return;
      final prompts = tester
          .widgetList<Text>(find.byType(Text))
          .map((w) => w.data ?? '')
          .where(looksLikePrompt);
      if (prompts.isNotEmpty && !prompts.contains(previousPrompt)) return;
    }
  }

  testWidgets(
      'MultiplicationMountainsGame: every question accepts the '
      'mathematically correct product as correct, full 20-question '
      'playthrough completes', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final entry =
        GameCatalog.all.firstWhere((e) => e.engineType == 'multiplicationMountains');
    final config = GameConfig.fromCatalogEntry(entry);

    await tester.pumpWidget(MaterialApp(
      home: MultiplicationMountainsGame(config: config, user: null),
    ));

    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump();

    for (var q = 0; q < 20; q++) {
      final prompt = currentPrompt(tester);
      final m = promptPattern.firstMatch(prompt)!;
      final a = int.parse(m.group(1)!);
      final b = int.parse(m.group(2)!);
      final expectedLabel = '${a * b}';

      await tapAndAdvance(tester, expectedLabel, prompt);
      expect(find.textContaining('The answer was'), findsNothing,
          reason: 'question "$prompt": expected "$expectedLabel" ($a×$b) to be correct');
    }

    expect(find.textContaining('Pond Crossed'), findsWidgets,
        reason: 'did not reach the victory screen after 20 questions');
  });
}
