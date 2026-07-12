import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/features/ai_tutor/widgets/questy_dialogue.dart';

void main() {
  test('celebrateBadge returns non-empty text mentioning the badge name', () {
    final line = QuestyDialogue.celebrateBadge('Math Wizard');
    expect(line, isNotEmpty);
    expect(line.contains('Math Wizard'), isTrue);
  });

  test('celebrateLevelUp returns non-empty text mentioning the new level', () {
    final line = QuestyDialogue.celebrateLevelUp(5);
    expect(line, isNotEmpty);
    expect(line.contains('5'), isTrue);
  });

  test('encourageAfterMiss and cheerCorrect return varied non-empty lines', () {
    final seen = <String>{};
    for (var i = 0; i < 20; i++) {
      seen.add(QuestyDialogue.encourageAfterMiss());
    }
    expect(seen.every((s) => s.isNotEmpty), isTrue);
    // With >=3 pool variants and 20 draws, expect more than one distinct line.
    expect(seen.length, greaterThan(1));

    final cheer = QuestyDialogue.cheerCorrect();
    expect(cheer, isNotEmpty);
  });
}
