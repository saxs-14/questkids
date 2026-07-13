import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import '../widgets/notification_banner.dart';

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> init(String userId, GlobalKey<NavigatorState> navigatorKey) async {
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
    }
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
