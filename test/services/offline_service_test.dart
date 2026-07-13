import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/core/services/local_storage_service.dart';
import 'package:questkids/core/services/offline_service.dart';

/// In-memory fake so these tests never touch sqflite/shared_preferences
/// or Firestore -- mirrors the exact subset of LocalStorageService that
/// OfflineService relies on (see local_storage_service.dart doc comment).
class _FakeLocalStorage extends LocalStorageService {
  final Map<String, List<Map<String, dynamic>>> _tables = {};
  int _nextId = 1;

  List<Map<String, dynamic>> _rows(String table) =>
      _tables.putIfAbsent(table, () => []);

  @override
  Future<void> insert(String table, Map<String, dynamic> data) async {
    final row = Map<String, dynamic>.from(data);
    if (table == 'pending_sync' && row['id'] == null) {
      row['id'] = _nextId++;
    }
    _rows(table).add(row);
  }

  @override
  Future<void> update(String table, Map<String, dynamic> data, String where,
      List<dynamic> whereArgs) async {
    final field = RegExp(r'^(\w+)').firstMatch(where)!.group(1)!;
    for (final row in _rows(table)) {
      if (row[field] == whereArgs[0]) row.addAll(data);
    }
  }

  @override
  Future<void> delete(
      String table, String where, List<dynamic> whereArgs) async {
    final field = RegExp(r'^(\w+)').firstMatch(where)!.group(1)!;
    _rows(table).removeWhere((row) => row[field] == whereArgs[0]);
  }

  @override
  Future<List<Map<String, dynamic>>> query(String table,
      {String? where,
      List<dynamic>? whereArgs,
      String? orderBy,
      int? limit}) async {
    var rows = List<Map<String, dynamic>>.from(_rows(table));
    if (where != null) {
      final field = RegExp(r'^(\w+)').firstMatch(where)!.group(1)!;
      rows = rows.where((r) => r[field] == whereArgs![0]).toList();
    }
    return rows;
  }

  @override
  Future<void> clearTable(String table) async => _tables[table] = [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  late _FakeLocalStorage fake;

  setUp(() {
    fake = _FakeLocalStorage();
    LocalStorageService.instance = fake;
  });

  group('OfflineService pending_sync queue', () {
    test(
        'applyPendingSyncItem throws for an unrecognized type instead of silently succeeding',
        () {
      final service = OfflineService();
      expect(
        () => service.applyPendingSyncItem('some_future_type', {}),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('OfflineService.clearAllLocalData', () {
    test('clears app_settings along with the other tables', () async {
      final service = OfflineService();
      await service.saveSetting('theme', 'dark');
      expect(await service.getSetting('theme'), equals('dark'));

      await service.clearAllLocalData();

      expect(await service.getSetting('theme'), isNull);
    });
  });
}
