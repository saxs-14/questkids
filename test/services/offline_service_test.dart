import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/data/models/game_session_model.dart';
import 'package:questkids/data/models/progress_model.dart';
import 'package:questkids/core/services/local_storage_service.dart';
import 'package:questkids/core/services/offline_service.dart';

/// In-memory fake so these tests never touch sqflite/shared_preferences
/// or Firestore -- mirrors the exact subset of LocalStorageService that
/// OfflineService relies on (see local_storage_service.dart doc comment).
class _FakeLocalStorage extends LocalStorageService {
  final Map<String, List<Map<String, dynamic>>> _tables = {};
  int _nextId = 1;
  bool failPendingSyncInsert = false;

  List<Map<String, dynamic>> _rows(String table) =>
      _tables.putIfAbsent(table, () => []);

  @override
  Future<void> insert(String table, Map<String, dynamic> data) async {
    if (table == 'pending_sync' && failPendingSyncInsert) {
      throw StateError('Local queue is unavailable.');
    }
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

    test('saves progress in the durable queue and exposes it offline',
        () async {
      final service = OfflineService();
      final progress = ProgressModel(
        uid: 'learner-1',
        activityId: 'quiz-1',
        activityTitle: 'Number quest',
        subject: 'Mathematics',
        score: 80,
        pointsEarned: 12,
        completed: true,
        completedAt: DateTime.utc(2026, 10, 13),
        timeTakenSeconds: 35,
      );

      await service.saveProgressOffline(progress);

      final pending = await service.getPendingSync();
      expect(pending, hasLength(1));
      expect(pending.single['type'], 'progress');
      expect(
        (await service.getCachedProgress('learner-1')).single.activityId,
        'quiz-1',
      );
      expect(await service.getCachedProgress('another-learner'), isEmpty);
    });

    test('does not report offline progress saved if queue persistence fails',
        () async {
      fake.failPendingSyncInsert = true;
      final service = OfflineService();
      final progress = ProgressModel(
        uid: 'learner-1',
        activityId: 'quiz-1',
        activityTitle: 'Number quest',
        subject: 'Mathematics',
        score: 80,
        pointsEarned: 12,
        completedAt: DateTime.utc(2026, 10, 13),
      );

      await expectLater(
        service.saveProgressOffline(progress),
        throwsA(isA<StateError>()),
      );
      expect(await service.getPendingSync(), isEmpty);
      expect(await service.getCachedProgress('learner-1'), isEmpty);
    });

    test('persists game sessions with the same stable ID used for retries',
        () async {
      final service = OfflineService();
      final session = GameSessionModel(
        id: 'session-stable-1',
        uid: 'learner-1',
        grade: 'Grade 4',
        subject: 'Mathematics',
        engineType: 'multiplesMerge',
        score: 90,
        xpEarned: 20,
        coinsEarned: 2,
        accuracy: 0.9,
        timeTakenSeconds: 45,
        completedAt: DateTime.utc(2026, 10, 13),
        result: 'win',
      );

      await service.saveGameSessionOffline(session);

      final queued = await service.getPendingSync();
      expect(queued.single['type'], 'game_session');
      expect(queued.single['dataJson'], contains('"id":"session-stable-1"'));
    });

    test('keeps quiz submissions bound to the account that created them',
        () async {
      final service = OfflineService();
      await service.saveQuizSubmissionOffline({
        'uid': 'learner-1',
        'submissionId': 'submission-1',
        'activityId': 'activity-1',
        'answers': ['A'],
        'timeTakenSeconds': 20,
      });

      final pending = await service.getPendingSync();
      expect(pending.single['type'], 'quiz_submission');
      expect(pending.single['dataJson'], contains('"uid":"learner-1"'));
      expect(pending.single['dataJson'],
          contains('"submissionId":"submission-1"'));
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
