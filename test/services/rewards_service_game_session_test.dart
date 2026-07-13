import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/core/services/rewards_service.dart';
import 'package:questkids/data/models/game_session_model.dart';
import 'package:questkids/data/models/reward_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  test('grantGameSessionRewards method exists with the expected signature', () {
    // Full behavioral coverage needs a Firestore emulator (this method
    // performs real reads/writes across rewards/, users/, and progress/),
    // which this repo's test suite doesn't use anywhere yet -- matches
    // the existing testing depth for Firestore-backed repository/service
    // methods (see e.g. OfflineService's tests, which only exercise the
    // local-storage seam, not live Firestore calls). This test guards
    // the public signature Task 4's callers depend on.
    final service = RewardsService();
    final session = GameSessionModel(
      id: 'test-session',
      uid: 'test-uid',
      grade: 'Grade 4',
      subject: 'Mathematics',
      engineType: 'tugOfWar',
      score: 80,
      xpEarned: 50,
      coinsEarned: 10,
      accuracy: 0.8,
      timeTakenSeconds: 45,
      completedAt: DateTime.now(),
      result: 'win',
    );
    final future = service.grantGameSessionRewards(session);
    expect(future, isA<Future<List<dynamic>>>());
    // Swallow the expected Firestore-unavailable error in this
    // emulator-free unit-test environment so it doesn't surface as an
    // unhandled async error after the test body completes.
    unawaited(future.catchError((_) => <BadgeModel>[]));
  });
}
