import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/data/models/user_model.dart';

void main() {
  test('a child UserModel built with parentUid set serializes it in toMap', () {
    final child = UserModel(
      uid: 'child-1',
      name: 'Test Child',
      email: 'test@questkids.learn',
      role: 'learner',
      grade: 'grade1',
      parentUid: 'parent-1',
      linkedParentUids: const ['parent-1'],
      createdAt: DateTime(2026, 1, 1),
    );
    expect(child.toMap()['parentUid'], 'parent-1');
  });
}
