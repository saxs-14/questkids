# Phase 6: Offline Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make offline mode actually reliable end-to-end: no gameplay XP/coins/leaderboard writes are silently lost when offline, the pending-sync indicator is accurate, sync happens automatically on reconnect, and dead/broken pieces of the existing offline infrastructure are fixed rather than left as traps.

**Architecture:** The app already has a working offline foundation for the *quiz* path (`QuizService` → `OfflineService.saveProgressOffline` → SQLite `pending_sync` table → `ConnectivityProvider.syncNow` → `OfflineService.syncToFirestore`). Phase 6 extends that exact same mechanism to the *game-engine* path (`GameSessionState.finishSession` → `GameRepository.logGameSession`), which today has zero offline handling and swallows failures in a bare `catch (_) {}`. It also fixes several latent bugs found in the existing `ConnectivityProvider`/`OfflineService` plumbing (dead `updatePendingCount()`, `syncNow()` hardcoding the pending count to 0, a silent-drop bug for any pending-sync `type` other than `'progress'`, and no auto-sync-on-reconnect trigger), and wires up Firestore's own offline persistence setting, which currently lives in a completely dead class.

**Tech Stack:** Flutter/Dart, Provider (`ChangeNotifierProxyProvider`), sqflite/sqflite_common_ffi (native) + shared_preferences-backed `LocalStorageService` (web), `connectivity_plus`, `cloud_firestore`.

## Global Constraints

- `flutter analyze` must stay at 0 errors before every commit (warnings only if pre-existing).
- `flutter test` must stay green; add tests for anything this phase touches, per repo `CLAUDE.md` §9.
- Do not touch the `db_bootstrap.dart`/`db_bootstrap_io.dart`/`db_bootstrap_stub.dart` conditional-import pattern (CLAUDE.md §7 — DO NOT TOUCH).
- Do not restructure the game engine layering (`GameRouter → <Engine>Game → <Engine>Session → <Engine>Engine`) — only the offline-write fallback inside the existing `GameSessionState.finishSession` method changes.
- Per Rule 3 (from the standing project instructions): fix broken existing functionality exactly as intended, do not redesign it. Per Rule 5: no placeholder functionality — every fix must be fully functional, not a TODO.
- Fix any other bug encountered while doing this work, even if unrelated to Phase 6, per the standing "fix it for all phases" instruction — add it as a task here if it's in scope of a file already being touched, or note it for the deferred list otherwise.

---

### Task 1: Fix `OfflineService` silent-drop bug in `syncToFirestore` and add game-session queueing

**Files:**
- Modify: `lib/core/services/offline_service.dart`
- Test: `test/services/offline_service_test.dart` (new)

**Interfaces:**
- Consumes: `GameSessionModel` (`lib/data/models/game_session_model.dart`) — `toMap()` (no `id` key), `fromMap(String id, Map<String, dynamic> map)`. `GameRepository.logGameSession(GameSessionModel) → Future<String>` (`lib/data/repositories/game_repository.dart:26`) — uses `batch.set` keyed by `session.id`, so calling it twice with the same `id` is idempotent (safe to retry).
- Produces: `OfflineService.saveGameSessionOffline(GameSessionModel session) → Future<void>` — later tasks (Task 2) call this as the offline fallback for game sessions, mirroring `saveProgressOffline`.

Today, `syncToFirestore`'s `switch (type)` (lines 273-278) only has a `case 'progress'` with no `default`. Because `await removePendingSync(id); syncedCount++;` run *unconditionally* after the switch regardless of whether a case matched, an item with any other `type` is silently marked as synced and deleted without ever being written anywhere — a silent-data-loss bug. This task fixes that bug and, in the same change, adds the new `'game_session'` type this phase needs.

- [ ] **Step 1: Write the failing test for the current silent-drop bug**

Create `test/services/offline_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/core/services/local_storage_service.dart';
import 'package:questkids/core/services/offline_service.dart';

/// In-memory fake so these tests never touch sqflite/shared_preferences
/// or Firestore — mirrors the exact subset of LocalStorageService that
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
  late _FakeLocalStorage fake;

  setUp(() {
    fake = _FakeLocalStorage();
    LocalStorageService.instance = fake;
  });

  group('OfflineService pending_sync queue', () {
    test('applyPendingSyncItem throws for an unrecognized type instead of silently succeeding', () {
      final service = OfflineService();
      expect(
        () => service.applyPendingSyncItem('some_future_type', {}),
        throwsA(isA<StateError>()),
      );
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/offline_service_test.dart`
Expected: FAIL — `applyPendingSyncItem` doesn't exist yet (compile error / method not found).

- [ ] **Step 3: Add the seam this test (and Task 1's real fix) needs**

`syncToFirestore`'s per-item handling (lines 273-278) is inline in a `for` loop and can't be unit-tested in isolation without `isOnline()` returning true, which requires the real `connectivity_plus` plugin (not faked in this repo — no mock-plugin dependency exists for it). Extract the per-item switch into its own method so the silent-drop bug can be tested directly, independent of connectivity. This also directly enables Task 1's `game_session` addition:

```dart
  /// Applies one pending-sync item to Firestore. Throws if [type] is not
  /// a recognized pending-sync type, so callers must not mark an
  /// unhandled item as synced.
  @visibleForTesting
  Future<void> applyPendingSyncItem(String type, Map<String, dynamic> data) async {
    switch (type) {
      case 'progress':
        await _progressRepo.saveProgress(ProgressModel.fromMap(data));
        return;
      case 'game_session':
        await _gameRepo.logGameSession(
          GameSessionModel.fromMap(data['id'] as String, data),
        );
        return;
      default:
        throw StateError('Unknown pending sync type: $type');
    }
  }
```

Add the test (append to the same file, inside `group('OfflineService pending_sync queue', ...)`):

```dart
    test('applyPendingSyncItem throws for an unrecognized type instead of silently succeeding', () {
      final service = OfflineService();
      expect(
        () => service.applyPendingSyncItem('some_future_type', {}),
        throwsA(isA<StateError>()),
      );
    });
```

- [ ] **Step 4: Run test to verify it fails**

Run: `flutter test test/services/offline_service_test.dart`
Expected: FAIL — `applyPendingSyncItem` and the `game_session` case don't exist yet (compile error / method not found).

- [ ] **Step 5: Implement — add `applyPendingSyncItem`, `saveGameSessionOffline`, and rewrite the sync loop to use it**

In `lib/core/services/offline_service.dart`:

Add imports at the top:
```dart
import '../../data/models/game_session_model.dart';
import '../../data/repositories/game_repository.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
```

Add a field alongside the other repos (near line 14-16):
```dart
  final GameRepository _gameRepo = GameRepository();
```

Add a new method in the "Progress caching & sync" section, right after `saveProgressOffline` (after line 138):
```dart
  Future<void> saveGameSessionOffline(GameSessionModel session) async {
    await _addToPendingSync(
      type: 'game_session',
      data: {...session.toMap(), 'id': session.id},
    );
  }
```

Add the `applyPendingSyncItem` method from Step 3 in the "Full sync" section, right before `syncToFirestore` (before line 251).

Replace the `switch` block inside `syncToFirestore`'s for-loop (lines 266-286) with:
```dart
    for (final item in pending) {
      try {
        final id = item['id'] as int;
        final type = item['type'] as String;
        final data =
            jsonDecode(item['dataJson'] as String) as Map<String, dynamic>;

        await applyPendingSyncItem(type, data);

        await removePendingSync(id);
        syncedCount++;
      } catch (e) {
        await incrementRetryCount(item['id'] as int);
        errors.add('Failed to sync item: $e');
      }
    }
```

Note `GameSessionModel.fromMap(id, map)` expects `map['completedAt']` to be a Firestore `Timestamp` (see `game_session_model.dart:46`), but the queued JSON stores it as whatever `Timestamp.fromDate(...).toMap()`... actually `session.toMap()` (line 62) stores `'completedAt': Timestamp.fromDate(completedAt)` — a `Timestamp` object directly, which `jsonEncode` cannot serialize as-is. Fix this in the same step: `saveGameSessionOffline` must store `completedAt` as millis instead, and `applyPendingSyncItem`'s `'game_session'` case must convert it back:

```dart
  Future<void> saveGameSessionOffline(GameSessionModel session) async {
    final map = session.toMap();
    map['completedAt'] = session.completedAt.millisecondsSinceEpoch;
    await _addToPendingSync(type: 'game_session', data: {...map, 'id': session.id});
  }
```

```dart
      case 'game_session':
        final map = Map<String, dynamic>.from(data);
        map['completedAt'] = Timestamp.fromMillisecondsSinceEpoch(
          map['completedAt'] as int,
        );
        await _gameRepo.logGameSession(
          GameSessionModel.fromMap(data['id'] as String, map),
        );
        return;
```

This requires `import 'package:cloud_firestore/cloud_firestore.dart';` at the top of `offline_service.dart` for `Timestamp`.

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/services/offline_service_test.dart`
Expected: PASS (both tests).

- [ ] **Step 7: Run `flutter analyze` and the full test suite**

Run: `flutter analyze && flutter test`
Expected: 0 errors; all tests green.

- [ ] **Step 8: Commit**

```bash
git add lib/core/services/offline_service.dart test/services/offline_service_test.dart
git commit -m "fix(offline): stop silently dropping unrecognized pending-sync items, add game_session sync type"
```

---

### Task 2: Route game-engine writes through the offline queue instead of silently discarding them

**Files:**
- Modify: `lib/features/games/core/game_session_state.dart`
- Test: `test/games/game_session_state_offline_test.dart` (new)

**Interfaces:**
- Consumes: `OfflineService.isOnline() → Future<bool>`, `OfflineService.saveGameSessionOffline(GameSessionModel) → Future<void>` (from Task 1).
- Produces: nothing new consumed elsewhere — this is the fix itself.

This is the most impactful fix in Phase 6. `finishSession` (lines 96-130) currently does `try { await _repo.logGameSession(session); } catch (_) {}` — if offline, or if the write fails for any reason, the player's XP/coins/leaderboard update is silently discarded with zero user-visible indication and zero retry.

- [ ] **Step 1: Write the failing test**

Create `test/games/game_session_state_offline_test.dart`. Because `GameSessionState` is abstract and its concrete subclasses require full engine/question setup, test the extracted logic directly rather than through a concrete session subclass — extract the offline-fallback decision into a small top-level function that's independently testable, which is also what Step 3 needs:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/features/games/core/game_session_persistence.dart';

void main() {
  group('shouldQueueGameSessionOffline', () {
    test('queues when device reports offline', () {
      expect(shouldQueueGameSessionOffline(isOnline: false, writeSucceeded: false), isTrue);
    });

    test('does not queue when the Firestore write already succeeded', () {
      expect(shouldQueueGameSessionOffline(isOnline: true, writeSucceeded: true), isFalse);
    });

    test('queues when online but the write still failed', () {
      expect(shouldQueueGameSessionOffline(isOnline: true, writeSucceeded: false), isTrue);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/games/game_session_state_offline_test.dart`
Expected: FAIL — `game_session_persistence.dart` doesn't exist yet.

- [ ] **Step 3: Implement — new small helper file + wire it into `finishSession`**

Create `lib/features/games/core/game_session_persistence.dart`:
```dart
/// A session should be queued to the local pending-sync table whenever
/// the Firestore write did not succeed, regardless of why (device is
/// offline, or the write threw for some other transient reason).
bool shouldQueueGameSessionOffline({
  required bool isOnline,
  required bool writeSucceeded,
}) =>
    !writeSucceeded;
```

(`isOnline` is accepted for readability at call sites and to keep the signature explicit about the two inputs that matter, even though the logic collapses to `!writeSucceeded` — a failed write must always be queued, whether or not the device *currently* reports online, since a reported-online write can still fail, e.g. a Firestore permission hiccup or a captive-portal wifi false positive.)

In `lib/features/games/core/game_session_state.dart`, add imports:
```dart
import '../../../core/services/offline_service.dart';
import 'game_session_persistence.dart';
```

Replace the `if (uid.isNotEmpty) { ... }` block (lines 109-129) with:
```dart
    if (uid.isNotEmpty) {
      final session = GameSessionModel(
        id: _uuid.v4(),
        uid: uid,
        grade: config.grade,
        subject: config.subject,
        engineType: config.engineType,
        score: _result!.score,
        xpEarned: _result!.xpEarned,
        coinsEarned: _result!.coinsEarned,
        accuracy: _result!.accuracy,
        timeTakenSeconds: _elapsed,
        completedAt: DateTime.now(),
        result: _result!.result,
      );
      final offlineService = OfflineService();
      final online = await offlineService.isOnline();
      var writeSucceeded = false;
      if (online) {
        try {
          await _repo.logGameSession(session);
          writeSucceeded = true;
        } catch (_) {
          writeSucceeded = false;
        }
      }
      if (shouldQueueGameSessionOffline(
          isOnline: online, writeSucceeded: writeSucceeded)) {
        await offlineService.saveGameSessionOffline(session);
      }
    }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/games/game_session_state_offline_test.dart`
Expected: PASS.

- [ ] **Step 5: Run the existing game engine/session test suite to confirm no regression**

Run: `flutter test test/games/ test/engines/`
Expected: all green — `finishSession`'s externally-observable behavior (sets `_result`, `_finished`, calls `notifyListeners()`) is unchanged; only what happens with the Firestore write result changed.

- [ ] **Step 6: Run `flutter analyze` and the full test suite**

Run: `flutter analyze && flutter test`
Expected: 0 errors; all tests green.

- [ ] **Step 7: Commit**

```bash
git add lib/features/games/core/game_session_state.dart lib/features/games/core/game_session_persistence.dart test/games/game_session_state_offline_test.dart
git commit -m "fix(offline): queue game session XP/coins/leaderboard writes instead of silently discarding them when offline"
```

---

### Task 3: Fix `ConnectivityProvider`'s pending-count bugs and wire auto-sync-on-reconnect

**Files:**
- Modify: `lib/providers/connectivity_provider.dart`
- Test: `test/providers/connectivity_provider_test.dart` (new)

**Interfaces:**
- Consumes: `OfflineService.getPendingSync()`, `OfflineService.syncToFirestore(uid)` (unchanged signatures).
- Produces: `ConnectivityProvider.setUid(String? uid)` — consumed by Task 4's `ChangeNotifierProxyProvider` wiring in `main.dart`.

Three bugs to fix in one pass since they're all in the same small file and touch the same state:
1. `updatePendingCount()` (line 67-71) is defined but never called anywhere — the pending badge is stale.
2. `syncNow()` (line 59) unconditionally sets `_pendingSyncCount = 0` even on partial failure, instead of re-querying.
3. Reconnecting sets an aspirational "Back online! Syncing…" message (line 39) but never actually triggers a sync — nothing is automatic.

- [ ] **Step 1: Write the failing test**

Create `test/providers/connectivity_provider_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/providers/connectivity_provider.dart';

void main() {
  group('ConnectivityProvider.setUid', () {
    test('setUid stores the uid without throwing when unset initially', () {
      final provider = ConnectivityProvider();
      expect(() => provider.setUid('learner-123'), returnsNormally);
      provider.dispose();
    });

    test('setUid is idempotent for the same value (no redundant notifyListeners loop)', () {
      final provider = ConnectivityProvider();
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/providers/connectivity_provider_test.dart`
Expected: FAIL — `setUid` doesn't exist yet.

- [ ] **Step 3: Implement**

Rewrite `lib/providers/connectivity_provider.dart`:
```dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../core/services/offline_service.dart';

enum ConnectionStatus { online, offline, syncing }

class ConnectivityProvider extends ChangeNotifier {
  final OfflineService _offlineService = OfflineService();

  ConnectionStatus _status = ConnectionStatus.online;
  bool _isSyncing = false;
  String? _syncMessage;
  int _pendingSyncCount = 0;
  String? _uid;
  StreamSubscription? _subscription;

  ConnectionStatus get status => _status;
  bool get isSyncing => _isSyncing;
  String? get syncMessage => _syncMessage;
  int get pendingSyncCount => _pendingSyncCount;
  bool get isOnline => _status == ConnectionStatus.online;
  bool get isOffline => _status == ConnectionStatus.offline;

  ConnectivityProvider() {
    _init();
  }

  /// Called whenever the signed-in user changes (including sign-out, where
  /// [uid] is null) so reconnect-triggered auto-sync knows whose data to
  /// push. See main.dart's ChangeNotifierProxyProvider<AuthProvider, ...>.
  void setUid(String? uid) {
    if (_uid == uid) return;
    _uid = uid;
  }

  Future<void> _init() async {
    final isOnline = await _offlineService.isOnline();
    _status = isOnline ? ConnectionStatus.online : ConnectionStatus.offline;
    await updatePendingCount();

    _subscription = _offlineService.connectivityStream.listen((online) {
      final newStatus =
          online ? ConnectionStatus.online : ConnectionStatus.offline;
      if (newStatus != _status) {
        _status = newStatus;
        notifyListeners();
        if (online) {
          _syncMessage = 'Back online! Syncing your progress...';
          notifyListeners();
          final uid = _uid;
          if (uid != null && uid.isNotEmpty) {
            syncNow(uid);
          }
        } else {
          updatePendingCount();
        }
      }
    });
  }

  Future<void> syncNow(String uid) async {
    if (_isSyncing) return;
    _isSyncing = true;
    _status = ConnectionStatus.syncing;
    _syncMessage = 'Syncing your progress...';
    notifyListeners();

    final result = await _offlineService.syncToFirestore(uid);

    _isSyncing = false;
    _status =
        result.success ? ConnectionStatus.online : ConnectionStatus.offline;
    _syncMessage = result.message;
    await updatePendingCount();

    await Future.delayed(const Duration(seconds: 3));
    _syncMessage = null;
    notifyListeners();
  }

  Future<void> updatePendingCount() async {
    final pending = await _offlineService.getPendingSync();
    _pendingSyncCount = pending.length;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/providers/connectivity_provider_test.dart`
Expected: PASS.

- [ ] **Step 5: Run `flutter analyze` and the full test suite**

Run: `flutter analyze && flutter test`
Expected: 0 errors; all tests green.

- [ ] **Step 6: Commit**

```bash
git add lib/providers/connectivity_provider.dart test/providers/connectivity_provider_test.dart
git commit -m "fix(offline): fix stale pending-sync count and wire automatic sync on reconnect"
```

---

### Task 4: Wire `ConnectivityProvider` to the signed-in user via `ChangeNotifierProxyProvider`

**Files:**
- Modify: `lib/main.dart`
- Test: manual/live verification only (provider wiring, covered by Task 3's unit test for `setUid` itself; this task is pure DI wiring with no new branchable logic)

**Interfaces:**
- Consumes: `AuthProvider.user` (`lib/providers/auth_provider.dart`, existing `UserModel? get user`), `ConnectivityProvider.setUid(String? uid)` (from Task 3).

`ConnectivityProvider` needs to know the current user's uid to auto-sync on reconnect (Task 3), but providers in this app don't currently reference each other — `main.dart`'s `MultiProvider` list is flat. `ChangeNotifierProxyProvider` is the standard `package:provider` mechanism for this and requires no change to any other provider.

- [ ] **Step 1: Modify `main.dart`'s provider registration**

In `lib/main.dart`, `ConnectivityProvider` is currently registered at line 46 as:
```dart
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
```
`AuthProvider` is registered earlier at line 41, so it is available as an ancestor. Replace line 46 with:
```dart
        ChangeNotifierProxyProvider<AuthProvider, ConnectivityProvider>(
          create: (_) => ConnectivityProvider(),
          update: (_, auth, connectivity) {
            connectivity!.setUid(auth.user?.uid);
            return connectivity;
          },
        ),
```

- [ ] **Step 2: Run `flutter analyze`**

Run: `flutter analyze`
Expected: 0 errors. `ChangeNotifierProxyProvider` is part of `package:provider` (already a dependency), no new import needed beyond the existing `package:provider/provider.dart` import already in `main.dart`.

- [ ] **Step 3: Run the full test suite**

Run: `flutter test`
Expected: all green — no test constructs `ConnectivityProvider` via the widget tree's `MultiProvider` (existing tests instantiate `ConnectivityProvider()` directly where needed), so this DI-only change shouldn't touch anything else. If any widget test *does* pump a tree expecting a plain `ChangeNotifierProvider<ConnectivityProvider>`, update it to wrap with `AuthProvider` above it in the same way `main.dart` now does, or provide a `ConnectivityProvider` directly via `ChangeNotifierProvider.value` (bypassing the proxy) — check via `grep -rn "ConnectivityProvider" test/` before assuming either fix is needed.

- [ ] **Step 4: Commit**

```bash
git add lib/main.dart
git commit -m "feat(offline): wire ConnectivityProvider to the signed-in user so reconnect auto-sync knows whose data to push"
```

---

### Task 5: Fix `clearAllLocalData()` omitting `app_settings`, and delete the dead `FirebaseInitializer`, wiring real Firestore offline persistence in its place

**Files:**
- Modify: `lib/core/services/offline_service.dart`
- Modify: `lib/main.dart`
- Delete: `lib/core/services/firebase_initializer.dart`
- Test: `test/services/offline_service_test.dart` (extend from Task 1)

**Interfaces:**
- Consumes: nothing new.
- Produces: nothing new consumed elsewhere.

Two small, unrelated-but-adjacent bugs bundled into one task because they're both quick, both found during Phase 6 investigation (per the standing "fix any bug you find, even pre-existing" instruction), and both touch code this phase is already reading closely.

**Part A — `clearAllLocalData()` omits `app_settings`:**

- [ ] **Step 1: Write the failing test**

Add to `test/services/offline_service_test.dart` (new `group`):
```dart
  group('OfflineService.clearAllLocalData', () {
    test('clears app_settings along with the other tables', () async {
      final service = OfflineService();
      await service.saveSetting('theme', 'dark');
      expect(await service.getSetting('theme'), equals('dark'));

      await service.clearAllLocalData();

      expect(await service.getSetting('theme'), isNull);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/offline_service_test.dart`
Expected: FAIL — `getSetting('theme')` still returns `'dark'` after clearing.

- [ ] **Step 3: Implement**

In `lib/core/services/offline_service.dart`, add one line to `clearAllLocalData()` (after line 350):
```dart
    await _store.clearTable('app_settings');
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/services/offline_service_test.dart`
Expected: PASS.

**Part B — dead `FirebaseInitializer`, missing real Firestore persistence config:**

- [ ] **Step 5: Confirm `FirebaseInitializer` is genuinely unused before deleting**

Run: `grep -rn "FirebaseInitializer" lib/ test/`
Expected: only matches inside `lib/core/services/firebase_initializer.dart` itself. If any other match turns up, stop and investigate before deleting — do not delete code that's actually wired in.

- [ ] **Step 6: Delete the dead file**

```bash
git rm lib/core/services/firebase_initializer.dart
```

- [ ] **Step 7: Add the one piece of real functionality it contained — Firestore offline persistence — directly where Firebase is actually initialized**

In `lib/main.dart`, add the import:
```dart
import 'package:cloud_firestore/cloud_firestore.dart';
```

Right after `await Firebase.initializeApp(...)` (currently lines 34-36) and before `runApp(...)`, add:
```dart
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
```

This must run before any other `FirebaseFirestore.instance` call in the app (it does — this is the first line of `main()` after `Firebase.initializeApp`, before `runApp` builds any widget that could touch Firestore).

- [ ] **Step 8: Run `flutter analyze`, the full test suite, and both builds**

Run: `flutter analyze && flutter test && flutter build web --release`
Expected: 0 errors; all tests green; web build succeeds (this is the platform where persistence was previously never actually enabled, since it requires this explicit opt-in and the only code that did it was dead).

- [ ] **Step 9: Commit**

```bash
git add lib/core/services/offline_service.dart lib/main.dart test/services/offline_service_test.dart
git rm lib/core/services/firebase_initializer.dart
git commit -m "fix(offline): clear app_settings on clearAllLocalData; delete dead FirebaseInitializer and enable real Firestore offline persistence"
```

---

### Task 6: Extend the Offline banner/status visibility to Parent and Teacher dashboards

**Files:**
- Modify: `lib/features/dashboard/screens/parent_dashboard.dart`
- Modify: `lib/features/dashboard/screens/teacher_dashboard.dart`
- Test: manual/live verification (these are thin widget-composition changes reusing the already-tested `OfflineBanner`)

**Interfaces:**
- Consumes: `OfflineBanner` (`lib/features/offline/widgets/offline_banner.dart`, unchanged — already reads `ConnectivityProvider` via `context.watch`).

Per the investigation, `ConnectivityProvider`/`OfflineBanner` are only ever shown on the Learner dashboard — Parent and Teacher get no indication their device is offline even though `ConnectivityProvider` is a global provider available everywhere (and, after Task 4, correctly tracks whichever role is signed in). Parents/teachers don't have a game/queue-heavy write path the way learners do, but they still read live Firestore data (child progress, class analytics) that silently goes stale offline with no indication today — showing the existing banner is a direct, in-scope fix, not new functionality, since the component already exists and is designed to be reusable (it takes no parameters and works for any signed-in role).

- [ ] **Step 1: Locate the Scaffold body root in `parent_dashboard.dart`**

Read the file's top-level `build()` method to find where the main `Scaffold`/`body` is assembled (same shape as `learner_dashboard.dart:174`, which does `Column(children: [OfflineBanner(), Expanded(child: IndexedStack(...))])` or similar — match whatever structure `parent_dashboard.dart` already uses; do not restructure its layout beyond inserting the banner).

- [ ] **Step 2: Add the import and insert `OfflineBanner` above the body content**

```dart
import '../../offline/widgets/offline_banner.dart';
```
Insert `const OfflineBanner()` as the first child above the existing body content, following the exact same placement pattern used in `learner_dashboard.dart`.

- [ ] **Step 3: Repeat Steps 1-2 for `teacher_dashboard.dart`**

- [ ] **Step 4: Run `flutter analyze` and the full test suite**

Run: `flutter analyze && flutter test`
Expected: 0 errors; all tests green.

- [ ] **Step 5: Live-verify in browser**

Using the existing local test server / test account workflow from prior phases: load the parent dashboard and teacher dashboard, confirm no banner shows while online (matches `OfflineBanner`'s existing `if (conn.isOnline && conn.syncMessage == null) return const SizedBox.shrink();` behavior), then use Chrome DevTools' network-offline emulation to confirm the red "You are offline" banner appears on both dashboards exactly as it already does on the learner dashboard.

- [ ] **Step 6: Commit**

```bash
git add lib/features/dashboard/screens/parent_dashboard.dart lib/features/dashboard/screens/teacher_dashboard.dart
git commit -m "feat(offline): surface the offline status banner on parent and teacher dashboards, not just learner"
```

---

### Task 7: End-of-phase verification + summary

**Files:** none (verification only)

- [ ] **Step 1: Full static + test verification**

Run:
```bash
flutter analyze
flutter test
flutter build web --release
flutter build apk --debug
```
Expected: 0 analyzer errors/new warnings (baseline: 61 pre-existing info lints from Phase 5); all tests green; both builds succeed.

- [ ] **Step 2: Live end-to-end offline verification in browser**

Using the existing local test server + persisted test account:
1. Load the learner dashboard online, confirm no offline banner.
2. Use Chrome DevTools network-offline emulation to go offline.
3. Confirm the red "You are offline. Progress saved locally." banner appears.
4. Play a short game session to completion (any engine) while offline — confirm the result screen still shows correctly (local state, per `finishSession`'s existing behavior), then check the `OfflineScreen` tab shows an incremented "Pending Sync" count reflecting the queued `game_session` item — this is the core Phase 6 fix being verified live, not just via unit test.
5. Go back online via DevTools. Confirm the banner automatically transitions to "Back online! Syncing your progress..." *without* tapping the sync button manually (verifies Task 3's auto-sync-on-reconnect), then to "Synced N items successfully" / "All synced! ✅", and the pending count returns to 0.
6. Repeat steps 2-5 briefly on the Parent dashboard to confirm the banner now appears there too (Task 6).

- [ ] **Step 3: Write the phase completion report**

Summary of work, files created/modified/deleted, bugs fixed (including the silent-drop bug, the pending-count bugs, the dead `FirebaseInitializer`, the `clearAllLocalData` gap), features added (auto-sync-on-reconnect, parent/teacher offline banners), tests performed, any remaining/deferred issues — then stop and wait for "Continue" per the standing phase-gating rule.
