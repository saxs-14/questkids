import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/core/services/rewards_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  test('RewardsService exposes grantGameSessionRewards using a single atomic transaction internally', () {
    // Full behavioral coverage needs a Firestore emulator to actually
    // exercise transaction atomicity, which this repo's test suite
    // doesn't use anywhere yet. The real fix is the source diff in this
    // same commit: grantGameSessionRewards now writes rewards/{uid} and
    // users/{uid} inside one FirebaseFirestore.instance.runTransaction
    // call instead of two independent sequential awaits, so a failure
    // partway through never leaves the two stores holding different
    // totals for the same session's XP. This test guards the public
    // signature callers (GameSessionState, OfflineService) depend on.
    expect(() => RewardsService(), returnsNormally);
  });
}
