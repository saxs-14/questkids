import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
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
  bool _disposed = false;

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
    unawaited(_refreshPendingCountSafely());
  }

  Future<void> _init() async {
    try {
      final isOnline = await _offlineService.isOnline();
      _status = isOnline ? ConnectionStatus.online : ConnectionStatus.offline;
      await updatePendingCount();
    } catch (error, stackTrace) {
      debugPrint('Could not initialize offline status: $error\n$stackTrace');
      _status = ConnectionStatus.offline;
      _syncMessage = 'Offline status could not be checked.';
    }
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
          unawaited(_refreshPendingCountSafely());
        }
      }
    }, onError: (Object error, StackTrace stackTrace) {
      debugPrint('Connectivity updates failed: $error\n$stackTrace');
      _status = ConnectionStatus.offline;
      _syncMessage = 'Connection status could not be checked.';
      if (!_disposed) notifyListeners();
    });
    if (!_disposed) notifyListeners();
  }

  Future<void> syncNow(String uid) async {
    if (_isSyncing) return;
    _isSyncing = true;
    _status = ConnectionStatus.syncing;
    _syncMessage = 'Syncing your progress...';
    notifyListeners();

    var success = false;
    try {
      final result = await _offlineService.syncToFirestore(uid);
      success = result.success;
      _syncMessage = result.message;
    } catch (error, stackTrace) {
      debugPrint('Offline data sync failed: $error\n$stackTrace');
      _syncMessage = 'Sync failed. Your saved work is still queued. Please retry.';
    } finally {
      _isSyncing = false;
      _status = success ? ConnectionStatus.online : ConnectionStatus.offline;
      try {
        await updatePendingCount();
      } catch (error, stackTrace) {
        debugPrint('Could not refresh pending sync count: $error\n$stackTrace');
      }
      if (!_disposed) notifyListeners();
    }

    await Future.delayed(const Duration(seconds: 3));
    _syncMessage = null;
    if (!_disposed) notifyListeners();
  }

  Future<void> updatePendingCount() async {
    final pending = await _offlineService.getPendingSync();
    final uid = _uid;
    _pendingSyncCount = pending.where((item) {
      if (uid == null || uid.isEmpty) return false;
      final data = jsonDecode(item['dataJson'] as String) as Map<String, dynamic>;
      return (data['uid'] ?? data['userId']) == uid;
    }).length;
    if (!_disposed) notifyListeners();
  }

  Future<void> _refreshPendingCountSafely() async {
    try {
      await updatePendingCount();
    } catch (error, stackTrace) {
      debugPrint('Could not count pending offline work: $error\n$stackTrace');
      _syncMessage = 'Saved work status could not be loaded.';
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    super.dispose();
  }
}
