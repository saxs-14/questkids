import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../../providers/auth_provider.dart';
import 'app_button.dart';
import 'app_dialog.dart';

/// Settings entry + confirmed sign-out, shared by all three role profile
/// tabs (learner/parent/teacher) instead of each dashboard re-implementing
/// its own (previously inconsistent) version.
class ProfileSettingsTile extends StatelessWidget {
  const ProfileSettingsTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.settings_outlined, color: AppColors.primary),
          title: Text('Settings', style: AppTextStyles.bodyMedium),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.pushNamed(context, '/settings'),
        ),
        const SizedBox(height: 12),
        AppButton(
          label: 'Sign Out',
          icon: Icons.logout,
          variant: AppButtonVariant.danger,
          onPressed: () async {
            final confirmed = await AppDialog.confirm(
              context,
              title: 'Sign Out',
              message: 'Are you sure you want to sign out?',
              confirmLabel: 'Sign Out',
              isDanger: true,
            );
            if (confirmed && context.mounted) {
              await context.read<AuthProvider>().signOut();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
              }
            }
          },
        ),
      ],
    );
  }
}
