import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/core/constants/game_catalog.dart';
import 'package:questkids/features/games/core/game_config.dart';
import 'package:questkids/features/games/subtraction_safari/subtraction_safari_game.dart';

/// Completion coverage for SubtractionSafariGame (see
/// addition_adventure_game_test.dart for why this can't do
/// fraction_forest-style content verification -- same sibling engine,
/// same procedural-generation-plus-dot-counters limitation). Plays a
/// full round tapping whichever choice renders first each time and
/// asserts it completes without exceptions.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  List<String> currentChoices(WidgetTester tester) {
    return tester
        .widgetList<Text>(find.byType(Text))
        .map((w) => w.data ?? '')
        .where((s) => RegExp(r'^\d+$').hasMatch(s))
        .toList();
  }

  testWidgets(
      'SubtractionSafariGame: full 20-question playthrough completes '
      'without exceptions and reaches the victory screen', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final entry =
        GameCatalog.all.firstWhere((e) => e.engineType == 'subtractionSafari');
    final config = GameConfig.fromCatalogEntry(entry);

    await tester.pumpWidget(MaterialApp(
      home: SubtractionSafariGame(config: config, user: null),
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
      final before = currentChoices(tester);
      expect(before, isNotEmpty, reason: 'expected choice buttons at question $q');

      await tester.tap(find.text(before.first).last);
      await tester.pump();
      for (var i = 0; i < 45; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find.textContaining('Party Complete!').evaluate().isNotEmpty) break;
        if (!listEquals(currentChoices(tester), before)) break;
      }
      expect(tester.takeException(), isNull,
          reason: 'exception thrown answering question $q');
    }

    expect(find.textContaining('Party Complete!'), findsOneWidget,
        reason: 'did not reach the victory screen after 20 questions');
  });
}
