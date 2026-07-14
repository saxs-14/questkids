import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const files = [
    'assets/content/ls_g1_habits.json',
    'assets/content/ns_g4_weather.json',
    'assets/content/ls_g7_wellbeing.json',
    'assets/content/sci_g7_health.json',
  ];

  for (final path in files) {
    test('$path is runnerCollector-shaped with >= 2 levels and real buckets', () {
      final json = jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
      expect(json['engine'], 'runnerCollector');
      final levels = json['levels'] as List;
      expect(levels.length, greaterThanOrEqualTo(2));
      for (final l in levels) {
        final level = l as Map<String, dynamic>;
        expect((level['targetClass'] as String).isNotEmpty, isTrue);
        expect((level['missionLabel'] as String).isNotEmpty, isTrue);
        final buckets = level['buckets'] as Map<String, dynamic>;
        expect(buckets.containsKey(level['targetClass']), isTrue);
        for (final words in buckets.values) {
          expect((words as List).length, greaterThanOrEqualTo(4));
        }
      }
    });
  }
}
