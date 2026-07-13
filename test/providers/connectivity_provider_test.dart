import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/core/services/local_storage_service.dart';
import 'package:questkids/providers/connectivity_provider.dart';

const _connectivityMethodChannel =
    MethodChannel('dev.fluttercommunity.plus/connectivity');
const _connectivityEventChannel =
    EventChannel('dev.fluttercommunity.plus/connectivity_status');

/// Empty in-memory fake so updatePendingCount() (invoked from _init())
/// doesn't reach for a real sqflite database, which isn't available
/// under flutter_test without the desktop FFI factory being initialized.
class _EmptyLocalStorage extends LocalStorageService {
  @override
  Future<void> insert(String table, Map<String, dynamic> data) async {}

  @override
  Future<void> update(String table, Map<String, dynamic> data, String where,
          List<dynamic> whereArgs) async =>
      {};

  @override
  Future<void> delete(
          String table, String where, List<dynamic> whereArgs) async =>
      {};

  @override
  Future<List<Map<String, dynamic>>> query(String table,
          {String? where,
          List<dynamic>? whereArgs,
          String? orderBy,
          int? limit}) async =>
      [];

  @override
  Future<void> clearTable(String table) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  setUp(() {
    LocalStorageService.instance = _EmptyLocalStorage();
    // ConnectivityProvider's constructor kicks off OfflineService calls
    // into the real connectivity_plus platform channels, which have no
    // native implementation under flutter_test -- mock both so
    // construction doesn't throw MissingPluginException.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_connectivityMethodChannel, (call) async {
      if (call.method == 'check') return <String>['wifi'];
      return null;
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
      _connectivityEventChannel,
      MockStreamHandler.inline(onListen: (arguments, events) {}),
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_connectivityMethodChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(_connectivityEventChannel, null);
  });

  group('ConnectivityProvider.setUid', () {
    test('setUid stores the uid without throwing when unset initially',
        () async {
      final provider = ConnectivityProvider();
      await pumpEventQueue(); // let the unawaited _init() finish first
      expect(() => provider.setUid('learner-123'), returnsNormally);
      provider.dispose();
    });

    test(
        'setUid is idempotent for the same value (no redundant notifyListeners loop)',
        () async {
      final provider = ConnectivityProvider();
      await pumpEventQueue(); // let the unawaited _init() finish first
      var notifyCount = 0;
      provider.addListener(() => notifyCount++);
      provider.setUid('learner-123');
      final afterFirst = notifyCount;
      provider.setUid('learner-123');
      expect(notifyCount, equals(afterFirst));
      provider.dispose();
    });
  });
}
