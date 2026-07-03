import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/notification_model.dart';
import '../../../data/repositories/notification_repository.dart';
import '../../../providers/auth_provider.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthProvider>().user?.uid;
    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notifications')),
        body: const Center(child: Text('Not logged in')),
      );
    }

    final repo = NotificationRepository();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: StreamBuilder<List<NotificationModel>>(
        stream: repo.getUserNotifications(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final notifications = snapshot.data ?? [];

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('s📭', style: TextStyle(fontSize: 64)),
                  const SizedBox(height: 16),
                  Text('No new notifications', style: AppTextStyles.h3),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final notif = notifications[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: notif.isRead
                      ? Colors.grey.withValues(alpha: 0.2)
                      : AppColors.primary.withValues(alpha: 0.2),
                  child: Icon(
                    Icons.notifications,
                    color: notif.isRead ? Colors.grey : AppColors.primary,
                  ),
                ),
                title: Text(
                  notif.title,
                  style: TextStyle(
                    fontWeight:
                        notif.isRead ? FontWeight.normal : FontWeight.bold,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(notif.body),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('MMM d, yyyy - h:mm a')
                          .format(notif.createdAt),
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
                onTap: () {
                  if (!notif.isRead) {
                    repo.markAsRead(notif.id);
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}
