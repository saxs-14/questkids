import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/providers/mission_provider.dart';

void main() {
  group('MissionProvider', () {
    test('initial state has empty missions', () {
      final provider = MissionProvider();
      expect(provider.missions, isEmpty);
      expect(provider.completedCount, equals(0));
      expect(provider.totalCount, equals(0));
      expect(provider.allComplete, isFalse);
      provider.dispose();
    });

    test('allComplete is false when no missions', () {
      final provider = MissionProvider();
      expect(provider.allComplete, isFalse);
      provider.dispose();
    });
  });
}
