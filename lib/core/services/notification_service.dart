import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer';

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> init(String userId) async {
    // Request permission (iOS requires this, Android 13+ requires this)
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      log('User granted permission');

      // Get the token
      String? token = await _fcm.getToken();
      if (token != null) {
        await _saveTokenToDatabase(userId, token);
      }

      // Any time the token refreshes, store it in the database too
      _fcm.onTokenRefresh.listen((newToken) {
        _saveTokenToDatabase(userId, newToken);
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        log('Got a message whilst in the foreground!');
        log('Message data: ${message.data}');

        if (message.notification != null) {
          log('Message also contained a notification: ${message.notification}');
          // Note: To show in-app popup for foreground messages,
          // we typically use flutter_local_notifications plugin.
        }
      });
    } else {
      log('User declined or has not accepted permission');
    }
  }

  Future<void> _saveTokenToDatabase(String userId, String token) async {
    await _firestore.collection('users').doc(userId).update({
      'fcmToken': token,
    });
  }
}
