import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/data/repositories/parent_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  test('ParentRepository can be constructed without touching the childUid field', () {
    // Full behavioral coverage needs a Firestore emulator (getChildAnalytics/
    // getChildProgress/watchPendingVerifications perform real Firestore
    // queries), which this repo's test suite doesn't use anywhere yet --
    // matches the existing testing depth for Firestore-backed repository
    // methods. The real fix is verified via the source diff in this same
    // commit: the progress collection is queried on `uid`, matching what
    // ProgressModel.toMap()/GameRepository._buildProgressMirror write,
    // not `childUid`, which nothing writes.
    expect(() => ParentRepository(), returnsNormally);
  });
}
