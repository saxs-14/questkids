/// Shared client-side validation for parent account registration.
///
/// Firebase remains the final authority for account creation; these helpers
/// provide early, understandable form feedback and are covered by unit tests.
class AuthValidation {
  AuthValidation._();

  static final RegExp _emailPattern = RegExp(
    r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?(?:\\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$",
  );

  static String? emailError(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Please enter your email address.';
    if (email.length > 254 || !_emailPattern.hasMatch(email)) {
      return 'Please enter a valid email address.';
    }
    return null;
  }

  /// Require 12+ characters and a mix of upper/lowercase, number, and symbol.
  /// Spaces are allowed and callers must not trim the password itself.
  static String? passwordError(String? value) {
    final password = value ?? '';
    if (password.length < 12) {
      return 'Use at least 12 characters.';
    }
    if (!RegExp(r'[A-Z]').hasMatch(password) ||
        !RegExp(r'[a-z]').hasMatch(password) ||
        !RegExp(r'\d').hasMatch(password) ||
        !RegExp(r'[^A-Za-z0-9\s]').hasMatch(password)) {
      return 'Include uppercase, lowercase, a number, and a symbol.';
    }
    return null;
  }
}
