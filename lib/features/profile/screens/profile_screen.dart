import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/services/storage_service.dart';
import '../../../data/repositories/user_repository.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final StorageService _storageService = StorageService();
  final UserRepository _userRepo = UserRepository();
  bool _isUploading = false;
  
  final List<String> _saLanguages = [
    'English', 'Afrikaans', 'isiZulu', 'isiXhosa', 
    'siSwati', 'isiNdebele', 'Sesotho', 'Northern Sotho', 
    'Setswana', 'Tshivenda', 'Xitsonga'
  ];

  Future<void> _pickAndUploadImage() async {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) return;

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    setState(() => _isUploading = true);

    try {
      final file = File(pickedFile.path);
      // Since kIsWeb could be true, you might need pickedFile.readAsBytes() for web
      // But standard ImagePicker usually returns a path for mobile. For simplicity on mobile:
      final extension = pickedFile.name.split('.').last;
      
      final downloadUrl = await _storageService.uploadAvatar(
        uid: user.uid,
        imageFile: file,
        extension: extension,
      );

      if (downloadUrl != null) {
        await _userRepo.updateUser(user.uid, {'avatarUrl': downloadUrl});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile picture updated successfully!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading image: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

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
          GestureDetector(
            onTap: _isUploading ? null : _pickAndUploadImage,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  backgroundImage: user.avatarUrl != null
                      ? CachedNetworkImageProvider(user.avatarUrl!)
                      : null,
                  child: user.avatarUrl == null
                      ? Text(
                          user.displayName.isNotEmpty
                              ? user.displayName[0].toUpperCase()
                              : '?',
                          style: AppTextStyles.h1.copyWith(color: AppColors.primary),
                        )
                      : null,
                ),
                if (_isUploading)
                  const Positioned.fill(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(user.displayName, style: AppTextStyles.h2),
          Text('${user.role[0].toUpperCase()}${user.role.substring(1)} Account',
              style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 32),
          ListTile(
            leading: const Icon(Icons.email_outlined, color: AppColors.primary),
            title: Text('Email', style: AppTextStyles.bodySmall),
            subtitle: Text(user.email.isNotEmpty ? user.email : 'N/A',
                style: AppTextStyles.bodyMedium),
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
            items: _saLanguages.map((String lang) {
              return DropdownMenuItem<String>(
                value: lang,
                child: Text(lang),
              );
            }).toList(),
            onChanged: (String? newValue) async {
              if (newValue != null) {
                await _userRepo.updateUser(user.uid, {'preferredLanguage': newValue});
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
            label: const Text('Sign Out', style: TextStyle(color: AppColors.error)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}
