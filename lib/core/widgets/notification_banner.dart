import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Shows an in-app banner for a push notification received while the app
/// is in the foreground (FirebaseMessaging.onMessage doesn't show anything
/// on its own on either platform).
class NotificationBanner {
  static void show(BuildContext context, {required String title, required String body}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.notifications_active, color: AppColors.gold),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(body, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 5),
      ),
    );
  }
}
