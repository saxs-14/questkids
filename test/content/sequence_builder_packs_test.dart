import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const files = [
    'assets/content/eng_g1_phonics.json',
    'assets/content/eng_g4_spelling.json',
    'assets/content/eng_g4_debate.json',
    'assets/content/eng_g7_debate.json',
    'assets/content/eng_g7_spelling.json',
  ];

  for (final path in files) {
    test('$path is sequenceBuilder-shaped with >= 4 real steps', () {
      final json = jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
      expect(json['engine'], 'sequenceBuilder');
      expect(json['sceneType'], isA<String>());
      final steps = json['steps'] as List;
      expect(steps.length, greaterThanOrEqualTo(4));
      for (final s in steps) {
        final step = s as Map<String, dynamic>;
        expect(step['id'], isA<String>());
        expect((step['label'] as String).isNotEmpty, isTrue);
        expect((step['emoji'] as String).isNotEmpty, isTrue);
        expect((step['description'] as String).length, greaterThan(10));
      }
    });
  }
}
