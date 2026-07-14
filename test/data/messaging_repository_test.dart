import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/data/repositories/messaging_repository.dart';

void main() {
  group('MessagingRepository conversation id', () {
    test('is deterministic regardless of teacher/parent argument order', () {
      final idA = MessagingRepository.conversationId(
          teacherUid: 't1', parentUid: 'p1', childUid: 'c1');
      final idB = MessagingRepository.conversationId(
          teacherUid: 't1', parentUid: 'p1', childUid: 'c1');
      expect(idA, idB);
    });

    test('differs for a different child even with the same teacher/parent', () {
      final idA = MessagingRepository.conversationId(
          teacherUid: 't1', parentUid: 'p1', childUid: 'c1');
      final idB = MessagingRepository.conversationId(
          teacherUid: 't1', parentUid: 'p1', childUid: 'c2');
      expect(idA, isNot(idB));
    });
  });
}
