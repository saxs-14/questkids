import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../services/profile_image_service.dart';
import '../theme/app_colors.dart';

/// Reusable circle avatar with camera/gallery upload.
///
/// Reads the current avatar URL from [AuthProvider] so it stays in sync
/// with any provider-level updates (e.g. after upload, after hot-reload).
///
/// Usage (in any profile tab, any role):
///   ProfileAvatarPicker(radius: 60)
class ProfileAvatarPicker extends StatefulWidget {
  final double radius;
  final Color? accentColor;

  const ProfileAvatarPicker({
    super.key,
    this.radius = 55,
    this.accentColor,
  });

  @override
  State<ProfileAvatarPicker> createState() => _ProfileAvatarPickerState();
}

class _ProfileAvatarPickerState extends State<ProfileAvatarPicker> {
  bool _uploading = false;

  Future<void> _pick(ImageSource source) async {
    final auth = context.read<AuthProvider>();
    final uid = auth.user?.uid;
    if (uid == null) return;

    setState(() => _uploading = true);
    try {
      final url = await ProfileImageService.pickAndUpload(
        uid: uid,
        source: source,
      );
      if (url != null && mounted) {
        auth.updateAvatarUrl(url);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture updated!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _showSourcePicker() async {
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Change Profile Picture',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pick(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a Photo'),
              onTap: () {
                Navigator.pop(context);
                _pick(ImageSource.camera);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final avatarUrl = user?.avatarUrl;
    final displayInitial =
        (user?.name.isNotEmpty == true) ? user!.name[0].toUpperCase() : '?';
    final accent = widget.accentColor ?? AppColors.primary;
    final r = widget.radius;

    return GestureDetector(
      onTap: _uploading ? null : _showSourcePicker,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          CircleAvatar(
            radius: r,
            backgroundColor: accent.withAlpha(30),
            backgroundImage: avatarUrl != null
                ? CachedNetworkImageProvider(avatarUrl)
                : null,
            child: avatarUrl == null
                ? Text(
                    displayInitial,
                    style: TextStyle(
                      fontSize: r * 0.7,
                      fontWeight: FontWeight.bold,
                      color: accent,
                    ),
                  )
                : null,
          ),
          // Upload progress ring
          if (_uploading)
            Positioned.fill(
              child: CircularProgressIndicator(
                color: accent,
                strokeWidth: 3,
              ),
            ),
          // Camera icon badge
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: _uploading ? Colors.grey : accent,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: _uploading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.camera_alt, color: Colors.white, size: 14),
            ),
          ),
        ],
      ),
    );
  }
}
