import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/profile_avatar_picker.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../providers/auth_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static const _saLanguages = [
    'English',
    'Afrikaans',
    'isiZulu',
    'isiXhosa',
    'siSwati',
    'isiNdebele',
    'Sesotho',
    'Northern Sotho',
    'Setswana',
    'Tshivenda',
    'Xitsonga',
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          const ProfileAvatarPicker(radius: 60),
          const SizedBox(height: 16),
          Text(user.displayName, style: AppTextStyles.h2),
          Text(
            '${user.role[0].toUpperCase()}${user.role.substring(1)} Account',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 32),
          ListTile(
            leading: const Icon(Icons.email_outlined, color: AppColors.primary),
            title: Text('Email', style: AppTextStyles.bodySmall),
            subtitle: Text(
              user.email.isNotEmpty ? user.email : 'N/A',
              style: AppTextStyles.bodyMedium,
            ),
          ),
          const Divider(),
          if (user.role == 'learner') ...[
            ListTile(
              leading: const Icon(Icons.star_outline, color: AppColors.gold),
              title: Text('Total Points', style: AppTextStyles.bodySmall),
              subtitle: Text('${user.totalPoints} pts',
                  style: AppTextStyles.bodyMedium),
            ),
            const Divider(),
          ],
          const SizedBox(height: 24),
          Text('Preferences', style: AppTextStyles.h3),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: user.preferredLanguage,
            decoration: InputDecoration(
              labelText: 'Preferred Language',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.language, color: AppColors.primary),
            ),
            items: _saLanguages.map((lang) {
              return DropdownMenuItem<String>(
                value: lang,
                child: Text(lang),
              );
            }).toList(),
            onChanged: (newValue) async {
              if (newValue != null) {
                await UserRepository()
                    .updateUser(user.uid, {'preferredLanguage': newValue});
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Language updated to $newValue')),
                  );
                }
              }
            },
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => auth.signOut(),
            icon: const Icon(Icons.logout, color: AppColors.error),
            label: const Text('Sign Out',
                style: TextStyle(color: AppColors.error)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}
