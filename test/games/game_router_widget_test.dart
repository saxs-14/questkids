import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/core/constants/game_catalog.dart';
import 'package:questkids/features/games/core/game_config.dart';
import 'package:questkids/features/games/core/game_router.dart';

/// Builds each of the 9 engine widgets (via GameRouter, exactly as the app
/// launches a game) with a representative catalog entry — no exceptions,
/// no red screen. See CLAUDE.md gamegen Phase D §2.
///
/// Uses tester.pump() rather than pumpAndSettle(): several game screens run
/// a repeating ambient AnimationController (..repeat()) that never settles.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  // One representative entry per distinct engineType — first occurrence in
  // catalog order, so this stays in sync automatically as topics.json grows.
  final representatives = <String, GameCatalogEntry>{};
  for (final entry in GameCatalog.all) {
    representatives.putIfAbsent(entry.engineType, () => entry);
  }

  for (final entry in representatives.values) {
    testWidgets(
        'GameRouter builds ${entry.engineType} (${entry.id}) at 360x740 without exceptions or overflow',
        (tester) async {
      // Foundation Phase minimum target: a small Android phone (CLAUDE.md
      // gamegen Phase D §3) — catches RenderFlex overflow that a default
      // 800x600 test surface would hide.
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final config = GameConfig.fromCatalogEntry(entry);

      await tester.pumpWidget(MaterialApp(
        home: GameRouter(config: config, user: null),
      ));

      // Let the async content-pack load (and any post-frame callbacks)
      // resolve, without waiting for repeating animations to "settle".
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(tester.takeException(), isNull);
    });
  }
}
