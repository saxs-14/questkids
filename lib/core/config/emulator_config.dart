import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Whether `flutter run`/`flutter build` was invoked with
/// `--dart-define=USE_EMULATORS=true` (see docs/ENVIRONMENT_SETUP.md §7).
const bool _useEmulatorsFlag = bool.fromEnvironment('USE_EMULATORS');

/// `kDebugMode &&` is a hard safety net on top of the dart-define -- a
/// release/profile build can never connect to emulators even if the flag
/// were somehow set, since kDebugMode is pinned false by the compiler in
/// those modes regardless of any dart-define.
bool get emulatorsEnabled => _useEmulatorsFlag && kDebugMode;

/// Connects every Firebase service on [app] to the local emulator suite
/// (ports match firebase.json's `emulators` block). No-op unless
/// [emulatorsEnabled].
///
/// Emulator connection is per-[FirebaseApp]-instance, not global -- call
/// this for the default app in main() AND for any secondary named
/// FirebaseApp created later (e.g. the temp apps auth_service.dart spins up
/// for child-account registration during parent signup). A secondary app
/// that skips this call silently talks to production even while the
/// default app is correctly emulated, which is exactly what happened
/// before this file existed: two dev-test accounts landed in production
/// Auth via a temp app during local emulator testing.
Future<void> connectToEmulatorsIfEnabled(FirebaseApp app) async {
  if (!emulatorsEnabled) return;
  const host = 'localhost';
  await FirebaseAuth.instanceFor(app: app).useAuthEmulator(host, 9099);
  FirebaseFirestore.instanceFor(app: app).useFirestoreEmulator(host, 8080);
  FirebaseFunctions.instanceFor(app: app).useFunctionsEmulator(host, 5001);
  await FirebaseStorage.instanceFor(app: app).useStorageEmulator(host, 9199);
}
