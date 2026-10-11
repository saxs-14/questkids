// Fake Cloud Functions platform, so widgets that call
// FirebaseFunctions.instanceFor(...).httpsCallable(...).call(...) directly
// (no DI seam exists anywhere in this app) can be widget-tested without a
// real platform channel or a running emulator.
//
// No test in this suite mocked cloud_functions before this file existed --
// every screen that calls a Cloud Function directly had zero widget-level
// coverage. This closes that gap by registering a fake implementation at
// the plugin's own extension point (FirebaseFunctionsPlatform.instance),
// the same seam the real native/web plugins register themselves at -- no
// app code changes. Pair with `setupFirebaseCoreMocks()` from
// package:firebase_core_platform_interface/test.dart (already used by 71
// other tests in this suite) for Firebase.initializeApp() itself.
import 'package:cloud_functions_platform_interface/cloud_functions_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';

class _FakeHttpsCallable extends HttpsCallablePlatform {
  _FakeHttpsCallable(
    FirebaseFunctionsPlatform functions,
    String? origin,
    String name,
    HttpsCallableOptions options,
    this._handler,
  ) : super(functions, origin, name, options, null);

  final Future<dynamic> Function(dynamic parameters) _handler;

  @override
  Future<dynamic> call([dynamic parameters]) => _handler(parameters);
}

class FakeFirebaseFunctionsPlatform extends FirebaseFunctionsPlatform {
  FakeFirebaseFunctionsPlatform({FirebaseApp? app, String region = 'us-central1'})
      : callHandlers = {},
        calls = [],
        super(app, region);

  /// Registered per function name. Throw inside a handler to simulate a
  /// FirebaseFunctionsException the same way a real failed call would
  /// surface one to app code.
  final Map<String, Future<dynamic> Function(dynamic parameters)> callHandlers;

  /// Every call made so far, as (functionName, parameters), in order --
  /// so a test can assert on the exact payload a screen sent (e.g. that
  /// the OTP code or the full permissions map was included), not just
  /// that "a call happened".
  final List<(String name, dynamic parameters)> calls;

  @override
  FirebaseFunctionsPlatform delegateFor({FirebaseApp? app, required String region}) {
    return this;
  }

  @override
  HttpsCallablePlatform httpsCallable(
    String? origin,
    String name,
    HttpsCallableOptions options,
  ) {
    return _FakeHttpsCallable(this, origin, name, options, (parameters) async {
      calls.add((name, parameters));
      final handler = callHandlers[name];
      if (handler == null) {
        throw StateError(
          'FakeFirebaseFunctionsPlatform: no handler registered for "$name". '
          'Register one with fakeFunctions.callHandlers["$name"] = (params) async => ...;',
        );
      }
      return handler(parameters);
    });
  }
}

/// Call once per test (or in setUp, after setupFirebaseCoreMocks() and
/// Firebase.initializeApp()) before pumping a widget that calls a Cloud
/// Function. Returns the fake so the test can register handlers via
/// `fake.callHandlers['functionName'] = (params) async => {...};` and
/// later assert on `fake.calls`.
FakeFirebaseFunctionsPlatform setupFakeFirebaseFunctions() {
  final fake = FakeFirebaseFunctionsPlatform();
  FirebaseFunctionsPlatform.instance = fake;
  return fake;
}
