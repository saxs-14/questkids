import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/core/constants/game_catalog.dart';
import 'package:questkids/features/games/core/game_config.dart';
import 'package:questkids/features/games/sa_provinces_explorer/sa_provinces_explorer_game.dart';

/// Completion coverage for SaProvincesExplorerGame (see
/// addition_adventure_game_test.dart for why this doesn't attempt content
/// verification -- fact-based content, nothing arithmetic to recompute).
///
/// "Find the Province" and "Famous Landmarks" now use real
/// Draggable/DragTarget (dragging a province-name chip onto the map)
/// instead of tapping an already-labelled province button, so this drags
/// from whichever Draggable<String> chip renders first onto whichever
/// DragTarget<String> slot renders first each round -- any drop (right or
/// wrong) advances the game via the same _applyAnswerResult path a tap
/// used to, so this still drives a full playthrough to completion.
/// "Provincial Capitals" and "Province Facts" are untouched multiple
/// choice and still get tapped.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  testWidgets(
      'SaProvincesExplorerGame: full playthrough completes without exceptions '
      'and reaches the victory screen', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final entry = GameCatalog.all.firstWhere((e) => e.engineType == 'saProvincesExplorer');
    final config = GameConfig.fromCatalogEntry(entry);

    await tester.pumpWidget(MaterialApp(
      home: SaProvincesExplorerGame(config: config, user: null),
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
      if (find.textContaining('Provinces Master!').evaluate().isNotEmpty) break;

      final draggables = find.byType(Draggable<String>);
      final targets = find.byType(DragTarget<String>);
      if (draggables.evaluate().isNotEmpty && targets.evaluate().isNotEmpty) {
        final source = tester.getCenter(draggables.first);
        final target = tester.getCenter(targets.first);
        final gesture = await tester.startGesture(source);
        await tester.pump(const Duration(milliseconds: 50));
        await gesture.moveTo(target);
        await tester.pump(const Duration(milliseconds: 50));
        await gesture.up();
        await tester.pump();
      } else {
        final detectors = find.byType(GestureDetector);
        expect(detectors.evaluate().length, greaterThan(0),
            reason: 'expected a tappable choice or draggable chip at question $q');
        await tester.tap(detectors.last, warnIfMissed: false);
        await tester.pump();
      }

      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find.textContaining('Provinces Master!').evaluate().isNotEmpty) break;
      }
      expect(tester.takeException(), isNull,
          reason: 'exception thrown answering question $q');
    }

    expect(find.textContaining('Provinces Master!'), findsOneWidget,
        reason: 'did not reach the victory screen');
  });
}
