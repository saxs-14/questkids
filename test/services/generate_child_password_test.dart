import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/core/services/auth_service.dart';

void main() {
  // Regression test: the production Firebase project enforces a password
  // policy (12+ characters, upper/lower/numeric/special) that the local
  // emulator does NOT replicate, so a generated password that satisfies
  // every character-class requirement but is too short still passes
  // local testing while every child-account creation fails in production
  // with PASSWORD_DOES_NOT_MEET_REQUIREMENTS. This asserts the actual
  // policy shape directly, not just "looks like a password", so it would
  // have caught the regression (the previous generator produced exactly
  // 10 characters).
  test('generated child password satisfies the production password policy', () {
    final password = AuthService.generateChildPassword(DateTime(2020, 10, 12));

    expect(password.length, greaterThanOrEqualTo(12));
    expect(password, matches(RegExp(r'[a-z]')), reason: 'needs a lowercase character');
    expect(password, matches(RegExp(r'[A-Z]')), reason: 'needs an uppercase character');
    expect(password, matches(RegExp(r'[0-9]')), reason: 'needs a numeric character');
    expect(password, matches(RegExp(r'[^a-zA-Z0-9]')), reason: 'needs a non-alphanumeric character');
  });

  test('is deterministic for the same birth date', () {
    final date = DateTime(2018, 3, 4);
    expect(
      AuthService.generateChildPassword(date),
      AuthService.generateChildPassword(date),
    );
  });
}
