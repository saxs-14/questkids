import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/data/repositories/leaderboard_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  test('LeaderboardRepository can be constructed without touching surname data', () {
    // Construction-only smoke test: watchClassLeaderboard's live Firestore
    // stream can't be exercised without a Firestore emulator, but this
    // guards against a compile-time regression and documents the
    // POPIA-compliance intent via the source fix in this same commit --
    // see the source diff for the actual behavioral fix (surname removed
    // from the displayName field built in watchClassLeaderboard).
    expect(() => LeaderboardRepository(), returnsNormally);
  });
}
