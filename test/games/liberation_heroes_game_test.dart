import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/core/constants/game_catalog.dart';
import 'package:questkids/features/games/core/game_config.dart';
import 'package:questkids/features/games/liberation_heroes/liberation_heroes_game.dart';

/// Completion coverage for LiberationHeroesGame (see
/// addition_adventure_game_test.dart for why this doesn't attempt content
/// verification -- fact-based content, nothing arithmetic to recompute).
/// Taps the last-rendered GestureDetector each round and asserts the
/// full playthrough completes without exceptions.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  testWidgets(
      'LiberationHeroesGame: full playthrough completes without exceptions '
      'and reaches the victory screen', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final entry = GameCatalog.all.firstWhere((e) => e.engineType == 'liberationHeroes');
    final config = GameConfig.fromCatalogEntry(entry);

    await tester.pumpWidget(MaterialApp(
      home: LiberationHeroesGame(config: config, user: null),
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

    for (var q = 0; q < 30; q++) {
      if (find.textContaining('History Champion!').evaluate().isNotEmpty) break;

      final detectors = find.byType(GestureDetector);
      final count = detectors.evaluate().length;
      expect(count, greaterThan(0), reason: 'expected a tappable choice at question $q');
      await tester.tap(detectors.last, warnIfMissed: false);
      await tester.pump();
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find.textContaining('History Champion!').evaluate().isNotEmpty) break;
      }
      expect(tester.takeException(), isNull,
          reason: 'exception thrown answering question $q');
    }

    expect(find.textContaining('History Champion!'), findsOneWidget,
        reason: 'did not reach the victory screen');
  });
}
