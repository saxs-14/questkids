import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/providers/auth_provider.dart';

void main() {
  group('Child login error handling', () {
    test('reports incorrect name only', () {
      expect(
        friendlyAuthError('[firebase_auth/child-incorrect-name]'),
        'Incorrect name. Please check your name and try again.',
      );
    });

    test('reports incorrect date of birth only', () {
      expect(
        friendlyAuthError('[firebase_auth/child-incorrect-dob]'),
        'Incorrect date of birth. Please check the date and try again.',
      );
    });

    test('does not turn child name errors into password errors', () {
      final message =
          friendlyAuthError('[firebase_auth/child-incorrect-name]');
      expect(message, isNot(contains('password')));
      expect(message, isNot(contains('email')));
    });

    test('does not turn child DOB errors into password errors', () {
      final message = friendlyAuthError('[firebase_auth/child-incorrect-dob]');
      expect(message, isNot(contains('password')));
      expect(message, isNot(contains('email')));
    });

    test('keeps parent invalid credentials mapped to email or password', () {
      expect(
        friendlyAuthError('[firebase_auth/invalid-credential]'),
        'Incorrect email or password. Please check and try again.',
      );
    });
  });
}
