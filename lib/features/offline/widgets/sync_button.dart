import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/connectivity_provider.dart';

class SyncButton extends StatelessWidget {
  const SyncButton({super.key});

  @override
  Widget build(BuildContext context) {
    final conn = context.watch<ConnectivityProvider>();
    final uid = context.read<AuthProvider>().user?.uid ?? '';

    return IconButton(
      tooltip: conn.pendingSyncCount > 0
          ? '${conn.pendingSyncCount} items to sync'
          : 'All synced',
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedRotation(
            turns: conn.isSyncing ? 1 : 0,
            duration: const Duration(seconds: 1),
            child: Icon(
              conn.isOffline ? Icons.cloud_off : Icons.cloud_sync,
              color: conn.isOffline ? AppColors.error : Colors.white,
            ),
          ),
          if (conn.pendingSyncCount > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${conn.pendingSyncCount}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      onPressed:
          conn.isSyncing || conn.isOffline ? null : () => conn.syncNow(uid),
    );
  }
}
