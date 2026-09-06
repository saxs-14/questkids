import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/core/constants/game_catalog.dart';
import 'package:questkids/features/games/core/game_config.dart';
import 'package:questkids/features/games/measurement_valley/measurement_valley_game.dart';

/// Deep behavioral coverage for MeasurementValleyGame (see
/// fraction_forest_game_test.dart for the general approach).
///
/// "Length Loop"/"Mass Marsh"/"Volume Vale" are all unit-conversion
/// prompts ("100 cm = ? m") -- independently computable via a small
/// base-unit conversion table, 15/20 questions verified. "Time Torrent"
/// is time-arithmetic word problems (different computation per question:
/// add hours, add minutes, count days in weeks) -- not worth a bespoke
/// parser for 5 questions, so it's tapped through like the other
/// unverifiable zones (fraction_forest's shaded-pie, decimal_dunes'
/// number line) without asserting correctness.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  final conversionPattern =
      RegExp(r'^(\d+(?:\.\d+)?) (\w+) = \? (\w+)$');

  // Conversion factor to a base unit per dimension (m, g, l).
  const factors = {
    'mm': 0.001,
    'cm': 0.01,
    'm': 1.0,
    'km': 1000.0,
    'g': 1.0,
    'kg': 1000.0,
    'ml': 0.001,
    'l': 1.0,
  };

  String formatNum(double v) {
    final rounded = double.parse(v.toStringAsFixed(4));
    if (rounded == rounded.roundToDouble()) return rounded.round().toString();
    var s = rounded.toString();
    if (s.contains('.')) {
      s = s.replaceFirst(RegExp(r'0+$'), '');
      s = s.replaceFirst(RegExp(r'\.$'), '');
    }
    return s;
  }

  bool looksLikePrompt(String s) => s.contains(' = ? ') || s.endsWith('?');

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
      if (find.text('Valley Crossed!').evaluate().isNotEmpty) return;
      final prompts = tester
          .widgetList<Text>(find.byType(Text))
          .map((w) => w.data ?? '')
          .where(looksLikePrompt);
      if (prompts.isNotEmpty && !prompts.contains(previousPrompt)) return;
    }
  }

  testWidgets(
      'MeasurementValleyGame: unit-conversion questions accept the '
      'mathematically correct conversion as correct, full 20-question '
      'playthrough completes', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final entry =
        GameCatalog.all.firstWhere((e) => e.engineType == 'measurementValley');
    final config = GameConfig.fromCatalogEntry(entry);

    await tester.pumpWidget(MaterialApp(
      home: MeasurementValleyGame(config: config, user: null),
    ));

    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump();

    var verifiedCount = 0;

    for (var q = 0; q < 20; q++) {
      final prompt = currentPrompt(tester);
      final m = conversionPattern.firstMatch(prompt);

      if (m != null) {
        final value = double.parse(m.group(1)!);
        final fromUnit = m.group(2)!;
        final toUnit = m.group(3)!;
        expect(factors, containsPair(fromUnit, isA<double>()),
            reason: 'unknown unit "$fromUnit" in "$prompt"');
        expect(factors, containsPair(toUnit, isA<double>()),
            reason: 'unknown unit "$toUnit" in "$prompt"');
        final result = value * factors[fromUnit]! / factors[toUnit]!;
        final expected = '${formatNum(result)} $toUnit';

        await tapAndAdvance(tester, expected, prompt);
        expect(find.textContaining('The answer was'), findsNothing,
            reason: 'question "$prompt": expected "$expected" to be correct');
        verifiedCount++;
      } else {
        // Time Torrent -- no single formula to independently verify from
        // rendered text. Tap the first choice found and keep moving.
        final choices = tester
            .widgetList<Text>(find.byType(Text))
            .map((w) => w.data ?? '')
            .where((s) =>
                RegExp(r'^\d+$').hasMatch(s) || RegExp(r'^\d{2}:\d{2}$').hasMatch(s))
            .toList();
        expect(choices, isNotEmpty,
            reason: 'expected time/number choices for "$prompt"');
        await tapAndAdvance(tester, choices.first, prompt);
      }
    }

    expect(find.text('Valley Crossed!'), findsOneWidget,
        reason: 'did not reach the victory screen after 20 questions');
    expect(verifiedCount, 15);
  });
}
