import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/core/constants/game_catalog.dart';
import 'package:questkids/features/games/core/game_config.dart';
import 'package:questkids/features/games/data_city/data_city_game.dart';

/// Deep behavioral coverage for DataCityGame (see
/// fraction_forest_game_test.dart for the general approach).
///
/// Only "Table Towers" (a plain day→value data table, rendered as
/// literal text rows) is independently verifiable here -- 5/20. The
/// other three zones encode their answer as pixel geometry, not text:
/// "Skyline Bars"/"Compare Corner" show bar height only (the axis
/// numbers are gridline scale marks, not per-bar values), and "Picto
/// Plaza" repeats an icon glyph a number of times rather than printing a
/// count. Reverse-engineering bar heights or counting repeated glyphs
/// pixel-adjacent to unlabeled rows would need to lean on rendering
/// internals fragile enough that it isn't worth it for this engine --
/// those 15 questions are tapped through to keep the playthrough moving,
/// same treatment as the diagram/drag zones in fraction_forest,
/// decimal_dunes, and measurement_valley.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  bool looksLikePrompt(String s) => s.endsWith('?') || s.startsWith('Tap the');

  String currentPrompt(WidgetTester tester) {
    return tester
        .widgetList<Text>(find.byType(Text))
        .map((w) => w.data ?? '')
        .firstWhere(looksLikePrompt);
  }

  Future<void> tapAndAdvance(
      WidgetTester tester, String label, String previousPrompt) async {
    await tester.tap(find.text(label).last);
    await tester.pump();
    for (var i = 0; i < 45; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('City Charted!').evaluate().isNotEmpty) return;
      final prompts = tester
          .widgetList<Text>(find.byType(Text))
          .map((w) => w.data ?? '')
          .where(looksLikePrompt);
      if (prompts.isNotEmpty && !prompts.contains(previousPrompt)) return;
    }
  }

  testWidgets(
      'DataCityGame: Table Towers accepts the mathematically correct '
      'lookup as correct, full 20-question playthrough completes',
      (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final entry = GameCatalog.all.firstWhere((e) => e.engineType == 'dataCity');
    final config = GameConfig.fromCatalogEntry(entry);

    await tester.pumpWidget(MaterialApp(
      home: DataCityGame(config: config, user: null),
    ));

    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump();

    var verifiedCount = 0;

    for (var q = 0; q < 20; q++) {
      final prompt = currentPrompt(tester);
      final dayMatch = RegExp(r'^How much rain fell on (\w+)\?$').firstMatch(prompt);
      final sumMatch = RegExp(r'^How much rain fell on (\w+) and (\w+) together\?$')
          .firstMatch(prompt);
      final isMostRain = prompt == 'Which day had the most rain?';

      if (dayMatch != null || sumMatch != null || isMostRain) {
        // Table Towers: 'Day' / 'Rainfall (mm)' header, then one Text per
        // day name immediately followed by one Text per value, in the
        // same top-to-bottom order -- pair them positionally.
        final texts = tester
            .widgetList<Text>(find.byType(Text))
            .map((w) => w.data ?? '')
            .toList();
        final headerIdx = texts.indexOf('Rainfall (mm)');
        expect(headerIdx, greaterThanOrEqualTo(0),
            reason: 'expected the Table Towers header for "$prompt"');
        final dayPattern = RegExp(r'^(Mon|Tue|Wed|Thu|Fri|Sat|Sun)$');
        final valuePattern = RegExp(r'^\d+$');
        final rows = <String, int>{};
        var i = headerIdx + 1;
        while (i + 1 < texts.length &&
            dayPattern.hasMatch(texts[i]) &&
            valuePattern.hasMatch(texts[i + 1])) {
          rows[texts[i]] = int.parse(texts[i + 1]);
          i += 2;
        }
        expect(rows, isNotEmpty, reason: 'failed to read any table rows for "$prompt"');

        final String expected;
        if (isMostRain) {
          final maxEntry = rows.entries.reduce((a, b) => a.value >= b.value ? a : b);
          final fullNames = {
            'Mon': 'Monday', 'Tue': 'Tuesday', 'Wed': 'Wednesday',
            'Thu': 'Thursday', 'Fri': 'Friday', 'Sat': 'Saturday', 'Sun': 'Sunday',
          };
          expected = fullNames[maxEntry.key]!;
        } else if (sumMatch != null) {
          final day1 = sumMatch.group(1)!.substring(0, 3);
          final day2 = sumMatch.group(2)!.substring(0, 3);
          expect(rows, allOf(contains(day1), contains(day2)),
              reason: '"$day1"/"$day2" not found in table rows $rows');
          expected = '${rows[day1]! + rows[day2]!} mm';
        } else {
          final day = dayMatch!.group(1)!.substring(0, 3);
          expect(rows, contains(day), reason: '"$day" not found in table rows $rows');
          expected = '${rows[day]} mm';
        }

        await tapAndAdvance(tester, expected, prompt);
        expect(find.textContaining('The answer was'), findsNothing,
            reason: 'question "$prompt": expected "$expected" to be correct');
        verifiedCount++;
      } else if (prompt.startsWith('Tap the')) {
        // Compare Corner: the tap target is a bar's label (e.g.
        // "Soccer"), not a choice button -- and the chart also renders
        // Y-axis gridline numbers ("9","6","3","0") that would otherwise
        // look like plausible numeric choices, so this has to route here
        // rather than through the numeric fallback below.
        final labels = tester
            .widgetList<Text>(find.byType(Text))
            .map((w) => w.data ?? '')
            .where((s) => RegExp(r'^[A-Za-z]+\d?$').hasMatch(s) && s != prompt)
            .toList();
        expect(labels, isNotEmpty, reason: 'expected a tappable label for "$prompt"');
        await tapAndAdvance(tester, labels.first, prompt);
      } else {
        // Skyline Bars / Picto Plaza: answer is encoded as pixel
        // geometry (bar height) or a repeated icon glyph, not
        // independently readable text. The chart renders Y-axis
        // gridline numbers before the choice buttons, so .last lands on
        // a real, tappable choice instead of an inert axis label.
        final numeric = tester
            .widgetList<Text>(find.byType(Text))
            .map((w) => w.data ?? '')
            .where((s) => RegExp(r'^\d+$').hasMatch(s) && int.parse(s) < 100)
            .toList();
        expect(numeric, isNotEmpty, reason: 'expected numeric choices for "$prompt"');
        await tapAndAdvance(tester, numeric.last, prompt);
      }
    }

    expect(find.text('City Charted!'), findsOneWidget,
        reason: 'did not reach the victory screen after 20 questions');
    expect(verifiedCount, 5);
  });
}
