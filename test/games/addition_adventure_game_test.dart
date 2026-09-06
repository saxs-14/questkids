import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/core/constants/game_catalog.dart';
import 'package:questkids/features/games/addition_adventure/addition_adventure_game.dart';
import 'package:questkids/features/games/core/game_config.dart';

/// Completion coverage for AdditionAdventureGame -- one step down from the
/// deep behavioral tests for the other math engines (see
/// fraction_forest_game_test.dart), because this one can't get that
/// treatment: questions are generated procedurally at runtime
/// (Random(), not a fixed bank) and the addends are shown as loose dot
/// piles (Container circles), not printed digits or an equation in the
/// prompt -- there's nothing in the rendered text to independently
/// recompute the sum from. This plays a full 4-island, 20-question round
/// (tapping whichever choice renders first each time, right or wrong)
/// and asserts it completes cleanly -- still real value beyond the
/// existing build-only smoke test, since it exercises the entire
/// question-generation/scoring/island-transition loop end to end.
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
      'AdditionAdventureGame: full 20-question playthrough completes '
      'without exceptions and reaches the victory screen', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final entry =
        GameCatalog.all.firstWhere((e) => e.engineType == 'additionAdventure');
    final config = GameConfig.fromCatalogEntry(entry);

    await tester.pumpWidget(MaterialApp(
      home: AdditionAdventureGame(config: config, user: null),
    ));

    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump();

    // The default tester.takeException() summary (e.g. "A RenderFlex
    // overflowed by 14 pixels on the right") doesn't say which widget --
    // surface the full FlutterErrorDetails (widget ownership chain
    // included) so a future failure here is diagnosable without having
    // to re-add this by hand.
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
        if (find.textContaining('Treasure Found!').evaluate().isNotEmpty) break;
        if (!listEquals(currentChoices(tester), before)) break;
      }
      expect(tester.takeException(), isNull,
          reason: 'exception thrown answering question $q');
    }

    expect(find.textContaining('Treasure Found!'), findsOneWidget,
        reason: 'did not reach the victory screen after 20 questions');
  });
}
