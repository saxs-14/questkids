import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// Thin helper around device permissions used across the avatar picker,
/// the Questy image-attach flow, and CSV import.
///
/// image_picker and file_selector already trigger the native OS
/// permission prompt themselves -- this class does not duplicate that
/// request. It only (a) opens the OS Settings app after a denial, and
/// (b) turns image_picker's PlatformException codes into a short,
/// friendly, child-appropriate message instead of raw exception text.
class PermissionService {
  static const _deniedCodes = {'camera_access_denied', 'photo_access_denied'};

  static Future<bool> openSettings() => openAppSettings();

  static bool isPermissionDenied(Object error) {
    if (error is! PlatformException) return false;
    return _deniedCodes.contains(error.code);
  }

  static String friendlyMessage(Object error) {
    if (isPermissionDenied(error)) {
      return "We can't get to your camera or photos right now. "
          'You can turn this on in Settings.';
    }
    return 'Something went wrong. Please try again.';
  }
}
