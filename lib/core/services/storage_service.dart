import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Uploads an avatar image to Firebase Storage and returns the download URL
  Future<String?> uploadAvatar({
    required String uid,
    required dynamic imageFile, // File on mobile, Uint8List on Web
    required String extension,
  }) async {
    try {
      final String path = 'users/$uid/avatar.$extension';
      final ref = _storage.ref().child(path);

      UploadTask uploadTask;

      if (kIsWeb) {
        // Web uses bytes
        uploadTask = ref.putData(
          imageFile as Uint8List,
          SettableMetadata(contentType: 'image/$extension'),
        );
      } else {
        // Mobile/Desktop uses File
        uploadTask = ref.putFile(
          imageFile as File,
          SettableMetadata(contentType: 'image/$extension'),
        );
      }

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading avatar: $e');
      return null;
    }
  }

  /// Deletes a user's avatar from Storage
  Future<void> deleteAvatar(String uid, String extension) async {
    try {
      final String path = 'users/$uid/avatar.$extension';
      final ref = _storage.ref().child(path);
      await ref.delete();
    } catch (e) {
      debugPrint('Error deleting avatar: $e');
    }
  }
}
