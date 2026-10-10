import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/core/utils/auth_validation.dart';

void main() {
  group('AuthValidation.emailError', () {
    test('accepts a valid email address', () {
      expect(AuthValidation.emailError('parent@example.co.za'), isNull);
    });

    test('rejects an empty or malformed email address', () {
      expect(AuthValidation.emailError(' '), isNotNull);
      expect(AuthValidation.emailError('not-an-email'), isNotNull);
      expect(AuthValidation.emailError('parent@localhost'), isNotNull);
    });
  });

  group('AuthValidation.passwordError', () {
    test('accepts a strong password without modifying its contents', () {
      expect(AuthValidation.passwordError('Secure Parent#2026'), isNull);
    });

    test('rejects passwords shorter than 12 characters', () {
      expect(AuthValidation.passwordError('Ab#123'), isNotNull);
    });

    test('requires upper, lower, number, and symbol', () {
      expect(AuthValidation.passwordError('alllowercase123!'), isNotNull);
      expect(AuthValidation.passwordError('ALLUPPERCASE123!'), isNotNull);
      expect(AuthValidation.passwordError('NoNumbersHere!!'), isNotNull);
      expect(AuthValidation.passwordError('NoSymbol12345'), isNotNull);
    });
  });
}
