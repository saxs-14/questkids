import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/core/constants/game_catalog.dart';
import 'package:questkids/features/games/core/game_config.dart';
import 'package:questkids/features/games/times_table_tower/times_table_tower_game.dart';

/// Deep behavioral coverage for TimesTableTowerGame (see
/// fraction_forest_game_test.dart for the general approach). Every prompt
/// is a plain "A × B = ?" with no diagram rendering digit text, so all 20
/// questions get independently-computed verification with no tap-target
/// ambiguity to work around.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  final promptPattern = RegExp(r'^(\d+)\s*×\s*(\d+)\s*=\s*\?$');

  String currentPrompt(WidgetTester tester) {
    return tester
        .widgetList<Text>(find.byType(Text))
        .map((w) => w.data ?? '')
        .firstWhere((s) => promptPattern.hasMatch(s));
  }

  Future<void> tapAndAdvance(
      WidgetTester tester, String label, String previousPrompt) async {
    await tester.tap(find.text(label).last);
    await tester.pump();
    for (var i = 0; i < 45; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('Tower Complete!').evaluate().isNotEmpty) return;
      final prompts = tester
          .widgetList<Text>(find.byType(Text))
          .map((w) => w.data ?? '')
          .where((s) => promptPattern.hasMatch(s));
      if (prompts.isNotEmpty && !prompts.contains(previousPrompt)) return;
    }
  }

  testWidgets(
      'TimesTableTowerGame: every question accepts the mathematically '
      'correct product as correct, full 20-question playthrough completes',
      (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final entry =
        GameCatalog.all.firstWhere((e) => e.engineType == 'timesTableTower');
    final config = GameConfig.fromCatalogEntry(entry);

    await tester.pumpWidget(MaterialApp(
      home: TimesTableTowerGame(config: config, user: null),
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

    expect(find.text('Tower Complete!'), findsOneWidget,
        reason: 'did not reach the victory screen after 20 questions');
  });
}
