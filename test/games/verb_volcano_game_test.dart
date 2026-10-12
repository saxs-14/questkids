import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/core/constants/game_catalog.dart';
import 'package:questkids/features/games/core/game_config.dart';
import 'package:questkids/features/games/verb_volcano/verb_volcano_game.dart';

/// Completion and answer-feedback coverage for VerbVolcanoGame.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  testWidgets('choosing the correct missing-verb option is marked correct',
      (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final entry =
        GameCatalog.all.firstWhere((e) => e.engineType == 'verbVolcano');
    await tester.pumpWidget(MaterialApp(
      home: VerbVolcanoGame(
        config: GameConfig.fromCatalogEntry(entry),
        user: null,
      ),
    ));
    await tester.pump(const Duration(milliseconds: 800));

    final sentence = tester
        .widgetList<Text>(find.byWidgetPredicate(
          (widget) => widget is Text && widget.textSpan != null,
        ))
        .map((text) => text.textSpan!.toPlainText())
        .firstWhere((text) => text.contains('_____'));
    final correctAnswer = switch (sentence) {
      final text when text.contains('Yesterday') => 'walked',
      final text when text.contains('Every morning') => 'drinks',
      final text when text.contains('Tomorrow') => 'will visit',
      final text when text.contains('Right now') => 'is barking',
      final text when text.contains('Last year') => 'moved',
      _ => fail('Unexpected missing-verb question: $sentence'),
    };

    expect(find.text('Read question'), findsOneWidget);
    expect(find.text('Hint'), findsOneWidget);
    await tester.tap(find.text('Hint'));
    await tester.pump();
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text && widget.style?.color == const Color(0xFFFFD180),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text(correctAnswer));
    await tester.pump();
    expect(
        find.text('Correct! You chose the right verb tense.'), findsOneWidget);
    expect(find.textContaining('Hint:'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'VerbVolcanoGame: full playthrough completes without exceptions '
      'and reaches the victory screen', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final entry =
        GameCatalog.all.firstWhere((e) => e.engineType == 'verbVolcano');
    final config = GameConfig.fromCatalogEntry(entry);

    await tester.pumpWidget(MaterialApp(
      home: VerbVolcanoGame(config: config, user: null),
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
      if (find.textContaining('Volcano Conqueror!').evaluate().isNotEmpty) {
        break;
      }

      final detectors = find.byType(GestureDetector);
      final count = detectors.evaluate().length;
      expect(count, greaterThan(0),
          reason: 'expected a tappable choice at question $q');
      await tester.tap(detectors.last, warnIfMissed: false);
      await tester.pump();
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find.textContaining('Volcano Conqueror!').evaluate().isNotEmpty) {
          break;
        }
      }
      expect(tester.takeException(), isNull,
          reason: 'exception thrown answering question $q');
    }

    expect(find.textContaining('Volcano Conqueror!'), findsOneWidget,
        reason: 'did not reach the victory screen');
  });
}
