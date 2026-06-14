import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/connectivity_provider.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final conn = context.watch<ConnectivityProvider>();

    if (conn.isOnline && conn.syncMessage == null) {
      return const SizedBox.shrink();
    }

    Color bannerColor;
    IconData bannerIcon;
    String bannerText;

    switch (conn.status) {
      case ConnectionStatus.offline:
        bannerColor = AppColors.error;
        bannerIcon = Icons.wifi_off;
        bannerText =
            'You are offline. Progress saved locally.';
        break;
      case ConnectionStatus.syncing:
        bannerColor = AppColors.orange;
        bannerIcon = Icons.sync;
        bannerText = conn.syncMessage ??
            'Syncing your progress...';
        break;
      case ConnectionStatus.online:
        bannerColor = AppColors.green;
        bannerIcon = Icons.cloud_done;
        bannerText =
            conn.syncMessage ?? 'All synced! ✅';
        break;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      color: bannerColor,
      padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 8),
      child: Row(
        children: [
          conn.status == ConnectionStatus.syncing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Icon(bannerIcon,
                  color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              bannerText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (conn.pendingSyncCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${conn.pendingSyncCount} pending',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
