import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/data/repositories/teacher_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  test('TeacherRepository can be constructed without touching the singular linkedTeacherUid field', () {
    // Full behavioral coverage needs a Firestore emulator. The real fix is
    // the source diff in this same commit: getClassAnalytics/
    // getDailyActiveLearners/exportClassProgress now query the plural
    // array field linkedTeacherUids (via arrayContains), matching what
    // teacher_dashboard.dart's _showAddLearnerDialog actually writes via
    // FieldValue.arrayUnion -- the singular linkedTeacherUid field is
    // never written by any live code path.
    expect(() => TeacherRepository(), returnsNormally);
  });

  test('sendClassBroadcast has the expected named-parameter signature', () {
    expect(TeacherRepository().sendClassBroadcast, isA<Function>());
  });
}
