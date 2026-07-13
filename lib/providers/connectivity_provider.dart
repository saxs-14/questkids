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
