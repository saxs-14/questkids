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
    // Construction-only smoke test: watchGradeLeaderboard's live Firestore
    // stream can't be exercised without a Firestore emulator, but this
    // guards against a compile-time regression. (watchClassLeaderboard was
    // removed with the teacher role -- it queried `users` by
    // linkedTeacherUid, a field nothing could write once
    // teacher_dashboard.dart was deleted, and had no Firestore rule
    // permitting a learner to read classmates' docs that way in the first
    // place, so its StreamBuilder spun forever on a silent
    // permission-denied error.)
    expect(() => LeaderboardRepository(), returnsNormally);
  });
}
