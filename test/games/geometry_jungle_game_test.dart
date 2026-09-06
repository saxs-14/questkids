import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/core/constants/game_catalog.dart';
import 'package:questkids/features/games/core/game_config.dart';
import 'package:questkids/features/games/geometry_jungle/geometry_jungle_game.dart';

/// Completion coverage for GeometryJungleGame. Unlike every other engine
/// tested this session, this one uses real drag-and-drop
/// (Draggable<int>/DragTarget<int>, not tap) -- see the file's own
/// header comment. It's also fact-based content (shape names, angle
/// types, 3D solids, symmetry) drawn/labelled visually, not arithmetic,
/// so there's nothing in rendered text to independently recompute a
/// correct answer from (same limitation as fraction_forest's
/// shaded-pie zone). This plays a full round by dragging the diagram
/// card onto whichever sign bin renders first each time and asserts it
/// completes without exceptions -- real value beyond the existing
/// build-only smoke test, since it exercises the drag gesture path end
/// to end, which nothing else does.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  testWidgets(
      'GeometryJungleGame: full 20-question playthrough (drag-and-drop) '
      'completes without exceptions and reaches the victory screen',
      (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final entry = GameCatalog.all.firstWhere((e) => e.engineType == 'geometryJungle');
    final config = GameConfig.fromCatalogEntry(entry);

    await tester.pumpWidget(MaterialApp(
      home: GeometryJungleGame(config: config, user: null),
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
      if (find.text('Jungle Explored!').evaluate().isNotEmpty) break;

      final diagramFinder = find.byType(Draggable<int>);
      expect(diagramFinder, findsOneWidget,
          reason: 'expected exactly one draggable diagram at question $q');
      final binFinder = find.byType(DragTarget<int>).first;

      final gesture = await tester.startGesture(tester.getCenter(diagramFinder));
      await gesture.moveTo(tester.getCenter(binFinder));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      for (var i = 0; i < 45; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find.text('Jungle Explored!').evaluate().isNotEmpty) break;
      }
      expect(tester.takeException(), isNull,
          reason: 'exception thrown answering question $q');
    }

    expect(find.text('Jungle Explored!'), findsOneWidget,
        reason: 'did not reach the victory screen after 20 questions');
  });
}
