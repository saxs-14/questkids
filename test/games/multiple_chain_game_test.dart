import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/core/constants/game_catalog.dart';
import 'package:questkids/features/games/core/game_config.dart';
import 'package:questkids/features/games/multiple_chain/multiple_chain_game.dart';

/// Completion coverage for MultipleChainGame (see
/// addition_adventure_game_test.dart for why this can't do
/// fraction_forest-style content verification -- same sibling engine,
/// same procedural-generation-plus-dot-counters limitation). Plays a
/// full round tapping whichever choice renders first each time and
/// asserts it completes without exceptions.
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

  // "${q.chainSoFar.join(', ')}, ...?" -- the sequence-so-far hint is the
  // one piece of rendered text that's unique per question. The bare
  // numeric choice list is NOT a reliable advancement signal here: the
  // chain display grows by one element the instant an answer is marked
  // correct (before _advance()'s own transition fires), so watching it
  // can false-positive on "the choices changed" while still on the
  // same (now revealed/disabled) question -- the next tap would then
  // hit a disabled button and silently do nothing.
  String currentHint(WidgetTester tester) {
    return tester
        .widgetList<Text>(find.byType(Text))
        .map((w) => w.data ?? '')
        .firstWhere((s) => s.endsWith(', ...?'));
  }

  testWidgets(
      'MultipleChainGame: full 20-question playthrough completes '
      'without exceptions and reaches the victory screen', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final entry = GameCatalog.all.firstWhere((e) => e.engineType == 'multipleChain');
    final config = GameConfig.fromCatalogEntry(entry);

    await tester.pumpWidget(MaterialApp(
      home: MultipleChainGame(config: config, user: null),
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
      final beforeHint = currentHint(tester);
      final before = currentChoices(tester);
      expect(before, isNotEmpty, reason: 'expected choice buttons at question $q');

      // The chain display renders each already-placed correct answer as
      // numeric text too, and it's built before the current question's
      // 3 choice buttons -- take the trailing 3 (always the real,
      // currently-tappable choices) rather than assuming .last alone is
      // never itself a repeated chain value.
      final choiceWindow =
          before.length >= 3 ? before.sublist(before.length - 3) : before;
      await tester.tap(find.text(choiceWindow.first).last);
      await tester.pump();
      for (var i = 0; i < 45; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find.textContaining('Cavern Conquered!').evaluate().isNotEmpty) break;
        final hints =
            tester.widgetList<Text>(find.byType(Text)).map((w) => w.data ?? '').where(
                (s) => s.endsWith(', ...?'));
        if (hints.isNotEmpty && !hints.contains(beforeHint)) break;
      }
      expect(tester.takeException(), isNull,
          reason: 'exception thrown answering question $q');
    }

    expect(find.textContaining('Cavern Conquered!'), findsOneWidget,
        reason: 'did not reach the victory screen after 20 questions');
  });
}
