import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/core/constants/game_catalog.dart';
import 'package:questkids/features/games/core/game_config.dart';
import 'package:questkids/features/games/word_builder/word_builder_game.dart';

/// Interaction-survival coverage for WordBuilderGame (see
/// addition_adventure_game_test.dart for why this doesn't attempt content
/// verification). Building a word here is spell-in-order tile taps
/// (_onTapTile), not a single pick-a-choice tap like every other engine
/// in this batch -- a generic "tap the last GestureDetector" doesn't
/// reliably assemble a word (wrong-order taps most likely just get
/// rejected/reset rather than crash), so this stops short of asserting
/// full completion. It still exercises real taps against the live tile
/// board for many rounds and asserts nothing throws -- genuinely more
/// than the existing build-only smoke test, which never taps anything.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  testWidgets(
      'WordBuilderGame: repeated tile taps do not throw', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final entry = GameCatalog.all.firstWhere((e) => e.engineType == 'wordBuilder');
    final config = GameConfig.fromCatalogEntry(entry);

    await tester.pumpWidget(MaterialApp(
      home: WordBuilderGame(config: config, user: null),
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
      if (find.textContaining('Workshop Complete!').evaluate().isNotEmpty) break;
      final detectors = find.byType(GestureDetector);
      if (detectors.evaluate().isEmpty) break;
      await tester.tap(detectors.last, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.takeException(), isNull, reason: 'exception thrown on tap $i');
    }
  });
}
