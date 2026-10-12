import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/core/constants/game_catalog.dart';
import 'package:questkids/features/games/core/game_config.dart';
import 'package:questkids/features/games/water_cycle/water_cycle_game.dart';

/// Completion coverage for WaterCycleGame (see
/// addition_adventure_game_test.dart for why this doesn't attempt content
/// verification -- fact-based content, nothing arithmetic to recompute).
/// Zone 1 (drag-to-label) is handled by dragging each term chip onto its
/// matching target by key; every other zone taps the last-rendered
/// GestureDetector. Asserts the full playthrough completes without
/// exceptions.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  testWidgets(
      'WaterCycleGame: full playthrough completes without exceptions '
      'and reaches the victory screen', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final entry = GameCatalog.all.firstWhere((e) => e.engineType == 'waterCycle');
    final config = GameConfig.fromCatalogEntry(entry);

    await tester.pumpWidget(MaterialApp(
      home: WaterCycleGame(config: config, user: null),
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

    const diagramTermIds = ['evaporation', 'condensation', 'precipitation', 'collection'];

    for (var q = 0; q < 30; q++) {
      if (find.textContaining('Water Cycle Master!').evaluate().isNotEmpty) break;

      // Zone 1: drag each remaining term chip onto its matching target.
      if (find.byKey(const ValueKey('wc_chip_evaporation')).evaluate().isNotEmpty ||
          find.byKey(const ValueKey('wc_chip_condensation')).evaluate().isNotEmpty ||
          find.byKey(const ValueKey('wc_chip_precipitation')).evaluate().isNotEmpty ||
          find.byKey(const ValueKey('wc_chip_collection')).evaluate().isNotEmpty) {
        for (final id in diagramTermIds) {
          final chip = find.byKey(ValueKey('wc_chip_$id'));
          if (chip.evaluate().isEmpty) continue; // already placed
          final target = find.byKey(ValueKey('wc_target_$id'));
          final start = tester.getCenter(chip);
          final end = tester.getCenter(target);
          await tester.drag(chip, end - start);
          await tester.pump();
          // Longer budget than an MCQ answer: a correct drop can chain a
          // streak-celebration delay (up to ~1.9s) and, on the 4th/last
          // term, the zoneDone transition overlay (2s) back to back.
          for (var i = 0; i < 45; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          expect(tester.takeException(), isNull,
              reason: 'exception thrown placing diagram term $id');
        }
        continue;
      }

      final detectors = find.byType(GestureDetector);
      final count = detectors.evaluate().length;
      expect(count, greaterThan(0), reason: 'expected a tappable choice at question $q');
      await tester.tap(detectors.last, warnIfMissed: false);
      await tester.pump();
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find.textContaining('Water Cycle Master!').evaluate().isNotEmpty) break;
      }
      expect(tester.takeException(), isNull,
          reason: 'exception thrown answering question $q');
    }

    expect(find.textContaining('Water Cycle Master!'), findsOneWidget,
        reason: 'did not reach the victory screen');
  });
}
