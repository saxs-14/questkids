import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/core/services/permission_service.dart';

void main() {
  group('PermissionService.isPermissionDenied', () {
    test('true for image_picker camera_access_denied', () {
      final e = PlatformException(code: 'camera_access_denied');
      expect(PermissionService.isPermissionDenied(e), isTrue);
    });

    test('true for image_picker photo_access_denied', () {
      final e = PlatformException(code: 'photo_access_denied');
      expect(PermissionService.isPermissionDenied(e), isTrue);
    });

    test('false for an unrelated PlatformException code', () {
      final e = PlatformException(code: 'some_other_error');
      expect(PermissionService.isPermissionDenied(e), isFalse);
    });

    test('false for a non-PlatformException error', () {
      expect(PermissionService.isPermissionDenied(Exception('boom')), isFalse);
    });
  });

  group('PermissionService.friendlyMessage', () {
    test('permission-specific message for a denied camera', () {
      final e = PlatformException(code: 'camera_access_denied');
      expect(
        PermissionService.friendlyMessage(e),
        contains('Settings'),
      );
    });

    test('generic message for an unrelated error', () {
      final message = PermissionService.friendlyMessage(Exception('boom'));
      expect(message, isNot(contains('Settings')));
      expect(message, isNotEmpty);
    });
  });
}
