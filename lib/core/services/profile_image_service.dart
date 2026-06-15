import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/repositories/user_repository.dart';
import 'storage_service.dart';

/// Handles the full pick → compress → upload → Firestore-update pipeline
/// for profile avatars, across all roles (learner, parent, teacher).
class ProfileImageService {
  static final _picker = ImagePicker();
  static final _storage = StorageService();
  static final _userRepo = UserRepository();

  /// Pick an image from [source], compress it (native only), upload to
  /// Firebase Storage, update Firestore `avatarUrl`, and return the URL.
  /// Returns null if the user cancelled or an error occurred.
  static Future<String?> pickAndUpload({
    required String uid,
    ImageSource source = ImageSource.gallery,
  }) async {
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (picked == null) return null;

    Uint8List bytes;
    if (kIsWeb) {
      // flutter_image_compress doesn't support web — use raw bytes.
      bytes = await picked.readAsBytes();
    } else {
      final original = await picked.readAsBytes();
      bytes = await FlutterImageCompress.compressWithList(
        original,
        minWidth: 512,
        minHeight: 512,
        quality: 75,
        format: CompressFormat.jpeg,
      );
    }

    final url = await _storage.uploadAvatarBytes(uid: uid, bytes: bytes);
    if (url != null) {
      await _userRepo.updateUser(uid, {'avatarUrl': url});
    }
    return url;
  }
}
