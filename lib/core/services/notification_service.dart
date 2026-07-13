import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import '../widgets/notification_banner.dart';

enum NotificationPermissionState { granted, denied }

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<NotificationPermissionState> init(
      String userId, GlobalKey<NavigatorState> navigatorKey) async {
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      final token = await _fcm.getToken();
      if (token != null) await _saveTokenToDatabase(userId, token);
      _fcm.onTokenRefresh.listen((newToken) => _saveTokenToDatabase(userId, newToken));

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final context = navigatorKey.currentContext;
        final notification = message.notification;
        if (context != null && context.mounted && notification != null) {
          NotificationBanner.show(
            context,
            title: notification.title ?? 'QuestKids',
            body: notification.body ?? '',
          );
        }
      });
      return NotificationPermissionState.granted;
    }
    return NotificationPermissionState.denied;
  }

  /// Re-checks the OS-level permission without re-prompting, so the
  /// Settings screen can refresh its status after the user returns from
  /// the system Settings app.
  Future<NotificationPermissionState> currentStatus() async {
    final settings = await _fcm.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized
        ? NotificationPermissionState.granted
        : NotificationPermissionState.denied;
  }

  Future<void> _saveTokenToDatabase(String userId, String token) async {
    await _firestore.collection('users').doc(userId).update({
      'fcmTokens': FieldValue.arrayUnion([token]),
    });
  }

  Future<void> removeTokenOnSignOut(String userId) async {
    final token = await _fcm.getToken();
    if (token == null) return;
    await _firestore.collection('users').doc(userId).update({
      'fcmTokens': FieldValue.arrayRemove([token]),
    });
  }
}
