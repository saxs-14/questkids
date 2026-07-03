import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/providers/mission_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

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
