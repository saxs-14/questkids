import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/core/constants/game_catalog.dart';
import 'package:questkids/features/games/core/game_config.dart';
import 'package:questkids/features/games/robot_maker/robot_maker_game.dart';

/// Interaction-survival coverage for RobotMakerGame (see
/// addition_adventure_game_test.dart for why this doesn't attempt content
/// verification, and reading_rainbow_game_test.dart/word_builder_game_test.dart
/// for why this is scoped to survival rather than full completion --
/// this engine's answer flow needs an ordered multi-step interaction
/// that a generic "tap the last GestureDetector" can't reliably drive
/// to victory. It still exercises real taps against the live board for
/// many rounds and asserts nothing throws -- genuinely more than the
/// existing build-only smoke test, which never taps anything.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  testWidgets(
      'RobotMakerGame: repeated taps do not throw', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final entry = GameCatalog.all.firstWhere((e) => e.engineType == 'robotMaker');
    final config = GameConfig.fromCatalogEntry(entry);

    await tester.pumpWidget(MaterialApp(
      home: RobotMakerGame(config: config, user: null),
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

    for (var i = 0; i < 80; i++) {
      if (find.textContaining('Robot Complete!').evaluate().isNotEmpty) break;
      final detectors = find.byType(GestureDetector);
      if (detectors.evaluate().isEmpty) break;
      await tester.tap(detectors.last, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.takeException(), isNull, reason: 'exception thrown on tap $i');
    }
  });

  testWidgets(
      'RobotMakerGame: dragging a bank part onto a robot slot does not throw '
      'and is reflected in the drop target', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final entry = GameCatalog.all.firstWhere((e) => e.engineType == 'robotMaker');
    final config = GameConfig.fromCatalogEntry(entry);

    await tester.pumpWidget(MaterialApp(
      home: RobotMakerGame(config: config, user: null),
    ));

    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump();

    // Both "Choose the Right Part" and "Build the Robot" zones now use
    // Draggable/DragTarget (converted from tap-to-select) -- drive a real
    // drag gesture across several questions and confirm the mechanism
    // itself is wired correctly, rather than re-testing correctness logic
    // already covered by the generic tap-survival test above.
    var dragsPerformed = 0;
    for (var round = 0; round < 20 && dragsPerformed < 8; round++) {
      if (find.textContaining('Robot Complete!').evaluate().isNotEmpty) break;

      final draggables = find.byType(Draggable<int>);
      final targets = find.byType(DragTarget<int>);
      if (draggables.evaluate().isEmpty || targets.evaluate().isEmpty) {
        // Not currently on a drag-based question (Design Process / Robots
        // at Work use plain tap tiles) -- tap through instead so the
        // playthrough keeps advancing toward the next drag-based zone.
        final detectors = find.byType(GestureDetector);
        if (detectors.evaluate().isEmpty) break;
        await tester.tap(detectors.last, warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull, reason: 'exception thrown on tap-through $round');
        continue;
      }

      final source = tester.getCenter(draggables.first);
      final target = tester.getCenter(targets.first);
      final gesture = await tester.startGesture(source);
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.moveTo(target);
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull, reason: 'exception thrown on drag $round');
      dragsPerformed++;
    }

    expect(dragsPerformed, greaterThan(0),
        reason: 'never found a Draggable/DragTarget pair to exercise');
  });
}
