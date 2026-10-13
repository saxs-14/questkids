import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import '../widgets/notification_banner.dart';

enum NotificationPermissionState { granted, denied, unavailable }

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  String? _activeUserId;
  NotificationPermissionState? _lastPermissionState;
  bool _isConfigured = false;

  Future<NotificationPermissionState> init(
      String userId, GlobalKey<NavigatorState> navigatorKey) async {
    if (_activeUserId == userId && _isConfigured) {
      return _lastPermissionState!;
    }

    final previousUserId = _activeUserId;
    await _cancelListeners();
    _isConfigured = false;
    if (previousUserId != null && previousUserId != userId) {
      try {
        await _removeCurrentToken(previousUserId);
      } catch (error, stackTrace) {
        debugPrint('Could not remove the previous account FCM token: '
            '$error\n$stackTrace');
      }
    }
    _activeUserId = userId;

    try {
      final settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        _lastPermissionState = NotificationPermissionState.denied;
        return _lastPermissionState!;
      }

      final token = await _fcm.getToken();
      if (token == null || token.isEmpty) {
        throw StateError('Firebase Messaging did not return a device token.');
      }
      await _saveTokenToDatabase(userId, token);
      _listenForTokenRefresh();
      _listenForForegroundMessages(navigatorKey);
      _listenForNotificationOpens(navigatorKey);

      final initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) _openNotifications(navigatorKey);

      _lastPermissionState = NotificationPermissionState.granted;
      _isConfigured = true;
      return _lastPermissionState!;
    } catch (error, stackTrace) {
      debugPrint('Push notification setup failed: $error\n$stackTrace');
      _lastPermissionState = NotificationPermissionState.unavailable;
      return _lastPermissionState!;
    }
  }

  void _listenForTokenRefresh() {
    _tokenSubscription = _fcm.onTokenRefresh.listen(
      (token) async {
        final userId = _activeUserId;
        if (userId == null) return;
        try {
          await _saveTokenToDatabase(userId, token);
        } catch (error, stackTrace) {
          debugPrint('Could not save refreshed FCM token: $error\n$stackTrace');
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('FCM token refresh stream failed: $error\n$stackTrace');
      },
    );
  }

  void _listenForForegroundMessages(
      GlobalKey<NavigatorState> navigatorKey) {
    _foregroundSubscription = FirebaseMessaging.onMessage.listen(
      (message) {
        final context = navigatorKey.currentContext;
        final notification = message.notification;
        if (context == null || !context.mounted || notification == null) return;
        NotificationBanner.show(
          context,
          title: notification.title ?? 'QuestKids',
          body: notification.body ?? '',
          onView: () => _openNotifications(navigatorKey),
        );
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Foreground notification stream failed: $error\n$stackTrace');
      },
    );
  }

  void _listenForNotificationOpens(GlobalKey<NavigatorState> navigatorKey) {
    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      (_) => _openNotifications(navigatorKey),
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Notification-open stream failed: $error\n$stackTrace');
      },
    );
  }

  void _openNotifications(GlobalKey<NavigatorState> navigatorKey) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      navigatorKey.currentState?.pushNamed('/notifications');
    });
  }

  /// Re-checks the OS-level permission without re-prompting.
  Future<NotificationPermissionState> currentStatus() async {
    try {
      final settings = await _fcm.getNotificationSettings();
      final isGranted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
              settings.authorizationStatus == AuthorizationStatus.provisional;
      _lastPermissionState = isGranted
          ? NotificationPermissionState.granted
          : NotificationPermissionState.denied;
    } catch (error, stackTrace) {
      debugPrint('Could not read push notification permission: '
          '$error\n$stackTrace');
      _lastPermissionState = NotificationPermissionState.unavailable;
    }
    return _lastPermissionState!;
  }

  Future<void> _saveTokenToDatabase(String userId, String token) async {
    await _firestore.collection('users').doc(userId).update({
      'fcmTokens': FieldValue.arrayUnion([token]),
    });
  }

  Future<void> removeTokenOnSignOut(String userId) async {
    try {
      await _removeCurrentToken(userId);
    } finally {
      await _cancelListeners();
      _activeUserId = null;
      _lastPermissionState = null;
      _isConfigured = false;
    }
  }

  Future<void> _removeCurrentToken(String userId) async {
    final token = await _fcm.getToken();
    if (token == null || token.isEmpty) return;
    await _firestore.collection('users').doc(userId).update({
      'fcmTokens': FieldValue.arrayRemove([token]),
    });
  }

  Future<void> stopListening() async {
    await _cancelListeners();
    _activeUserId = null;
    _lastPermissionState = null;
    _isConfigured = false;
  }

  Future<void> _cancelListeners() async {
    await _tokenSubscription?.cancel();
    await _foregroundSubscription?.cancel();
    await _openedSubscription?.cancel();
    _tokenSubscription = null;
    _foregroundSubscription = null;
    _openedSubscription = null;
  }
}
