import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/permission_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/theme_toggle.dart';
import '../../../providers/auth_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Appearance', style: AppTextStyles.label),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: Icon(
                theme.isDark ? Icons.nightlight_round : Icons.wb_sunny,
                color: AppColors.primary,
              ),
              title: Text('Dark Mode', style: AppTextStyles.bodyMedium),
              subtitle: Text(
                theme.isDark ? 'On' : 'Off',
                style: AppTextStyles.bodySmall,
              ),
              trailing: const ThemeToggle(),
            ),
          ),
          const SizedBox(height: 20),
          Text('Notifications', style: AppTextStyles.label),
          const SizedBox(height: 8),
          Consumer<AuthProvider>(
            builder: (context, auth, _) {
              final granted = auth.notificationPermission ==
                  NotificationPermissionState.granted;
              final unavailable = auth.notificationPermission ==
                  NotificationPermissionState.unavailable;
              return Card(
                child: ListTile(
                  leading: Icon(
                    granted
                        ? Icons.notifications_active
                        : Icons.notifications_off,
                    color: AppColors.primary,
                  ),
                  title:
                      Text('Push Notifications', style: AppTextStyles.bodyMedium),
                  subtitle: Text(
                    granted
                        ? 'On'
                        : unavailable
                            ? 'Setup could not finish. Check your connection '
                                'and retry.'
                            : 'Off — turn this on in Settings to get badge '
                                'and quest reminders',
                    style: AppTextStyles.bodySmall,
                  ),
                  trailing: granted
                      ? null
                      : TextButton(
                          onPressed: () async {
                            if (unavailable) {
                              await auth.retryNotificationSetup();
                            } else {
                              try {
                                await PermissionService.openSettings();
                              } catch (_) {
                                // Web has no OS settings page; refresh the
                                // browser's current notification permission.
                              }
                              if (context.mounted) {
                                await auth.refreshNotificationPermission();
                              }
                            }
                          },
                          child: Text(unavailable ? 'Retry' : 'Open Settings'),
                        ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
