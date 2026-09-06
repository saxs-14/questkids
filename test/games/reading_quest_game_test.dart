import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/core/constants/game_catalog.dart';
import 'package:questkids/features/games/core/game_config.dart';
import 'package:questkids/features/games/reading_quest/reading_quest_game.dart';

/// Interaction-survival coverage for ReadingQuestGame (see
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
      'ReadingQuestGame: repeated taps do not throw', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final entry = GameCatalog.all.firstWhere((e) => e.engineType == 'readingQuest');
    final config = GameConfig.fromCatalogEntry(entry);

    await tester.pumpWidget(MaterialApp(
      home: ReadingQuestGame(config: config, user: null),
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
      if (find.textContaining('Reading Champion!').evaluate().isNotEmpty) break;
      final detectors = find.byType(GestureDetector);
      if (detectors.evaluate().isEmpty) break;
      await tester.tap(detectors.last, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.takeException(), isNull, reason: 'exception thrown on tap $i');
    }
  });
}
