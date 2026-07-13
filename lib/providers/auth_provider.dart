import 'dart:async';

import 'package:flutter/material.dart';
import '../core/services/auth_service.dart';
import '../core/services/notification_service.dart';
import '../core/services/rewards_service.dart';
import '../data/models/user_model.dart';
import '../data/repositories/user_repository.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final UserRepository _userRepo = UserRepository();
  final NotificationService _notificationService = NotificationService();
  final RewardsService _rewardsService = RewardsService();
  final GlobalKey<NavigatorState> navigatorKey;

  AuthStatus _status = AuthStatus.unknown;
  UserModel? _user;
  String? _errorMessage;
  bool _isLoading = false;
  NotificationPermissionState? _notificationPermission;
  StreamSubscription<UserModel?>? _userSubscription;

  AuthStatus get status => _status;
  UserModel? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  NotificationPermissionState? get notificationPermission => _notificationPermission;

  AuthProvider({required this.navigatorKey}) {
    _init();
  }

  void _init() {
    _authService.authStateChanges.listen((firebaseUser) async {
      await _userSubscription?.cancel();
      _userSubscription = null;

      if (firebaseUser == null) {
        _status = AuthStatus.unauthenticated;
        _user = null;
      } else {
        _user = await _userRepo.getUser(firebaseUser.uid);
        _status = AuthStatus.authenticated;
        _notificationPermission =
            await _notificationService.init(firebaseUser.uid, navigatorKey);
        try {
          await _rewardsService.updateStreak(firebaseUser.uid);
        } catch (_) {
          // Non-fatal: streak update failing must never block login.
        }
        // Live-stream the user doc rather than relying solely on the
        // one-time fetch above, so fields written elsewhere (e.g.
        // totalPoints/streakDays from RewardsService.grantGameSessionRewards)
        // reflect on screens reading AuthProvider.user (the dashboard's
        // XP header) without requiring a sign-out/sign-in cycle --
        // UserRepository.watchUser already existed for this but had no
        // caller anywhere in the app.
        _userSubscription = _userRepo.watchUser(firebaseUser.uid).listen((user) {
          if (user != null) {
            _user = user;
            notifyListeners();
          }
        });
      }
      notifyListeners();
    });
  }

  Future<void> refreshNotificationPermission() async {
    _notificationPermission = await _notificationService.currentStatus();
    notifyListeners();
  }

  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }

  void _setError(String? msg) {
    _errorMessage = msg;
    notifyListeners();
  }

  Future<bool> registerTeacher({
    required String email,
    required String password,
    required String name,
    required String surname,
    required String title,
    required String gender,
    required String grade,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      _user = await _authService.registerWithEmail(
        email: email,
        password: password,
        name: name,
        surname: surname,
        title: title,
        gender: gender,
        role: 'teacher',
        grade: grade,
      );
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _setError(_friendlyError(e.toString()));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> registerParent({
    required String parentEmail,
    required String parentPassword,
    required String parentName,
    required String parentSurname,
    required String parentTitle,
    required String parentGender,
    required String relationToChild,
    String? childName,
    String? childGender,
    DateTime? childBirthDate,
    String? childGrade,
    bool childConsentGiven = false,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      _user = await _authService.registerWithEmail(
        email: parentEmail,
        password: parentPassword,
        name: parentName,
        surname: parentSurname,
        title: parentTitle,
        gender: parentGender,
        role: 'parent',
        grade: childGrade ?? 'Grade 1',
        // optional child data
        childName: childName,
        childGender: childGender,
        childBirthDate: childBirthDate,
        childGrade: childGrade,
        childConsentGiven: childConsentGiven,
      );
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _setError(_friendlyError(e.toString()));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      _user = await _authService.loginWithEmail(
        email: email,
        password: password,
      );
      if (_user == null) {
        _setError(
            'Account found but profile data is missing. Please re-register or contact support.');
        _status = AuthStatus.unauthenticated;
        return false;
      }
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _setError(_friendlyError(e.toString()));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> loginChild({
    required String name,
    required DateTime birthDate,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      _user = await _authService.loginChild(
        name: name,
        birthDate: birthDate,
      );
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _setError(_friendlyError(e.toString()));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> signInWithGoogle({
    required String role,
    required String grade,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      _user = await _authService.signInWithGoogle(
        role: role,
        grade: grade,
      );
      if (_user != null) {
        _status = AuthStatus.authenticated;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _setError(_friendlyError(e.toString()));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> createChildForParent({
    required String parentUid,
    required String childName,
    required String childGender,
    required DateTime childBirthDate,
    required String childGrade,
    required bool consentGiven,
    required String consentGivenBy,
    required String consentEmail,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final child = await _authService.createChildForParent(
        parentUid: parentUid,
        childName: childName,
        childGender: childGender,
        childBirthDate: childBirthDate,
        childGrade: childGrade,
        consentGiven: consentGiven,
        consentGivenBy: consentGivenBy,
        consentEmail: consentEmail,
      );
      return child != null;
    } catch (e) {
      _setError(_friendlyError(e.toString()));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> resetPassword(String email) async {
    _setLoading(true);
    try {
      await _authService.resetPassword(email);
    } catch (e) {
      _setError(_friendlyError(e.toString()));
    } finally {
      _setLoading(false);
    }
  }

  /// Update the local user's avatarUrl after a successful upload so all
  /// avatars in the UI refresh without requiring a sign-out/sign-in cycle.
  void updateAvatarUrl(String url) {
    if (_user != null) {
      _user = _user!.copyWith(avatarUrl: url);
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    if (_user != null) {
      await _notificationService.removeTokenOnSignOut(_user!.uid);
    }
    await _userSubscription?.cancel();
    _userSubscription = null;
    await _authService.signOut();
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }

  String _friendlyError(String error) {
    // Firebase Auth v5+ merges wrong-password + user-not-found into invalid-credential
    if (error.contains('invalid-credential') ||
        error.contains('invalid-login-credentials')) {
      return 'Incorrect email or password. Please check and try again.';
    }
    if (error.contains('user-not-found'))
      return 'No account found with this email.';
    if (error.contains('wrong-password'))
      return 'Incorrect password. Try again.';
    if (error.contains('email-already-in-use'))
      return 'This email is already registered.';
    if (error.contains('weak-password'))
      return 'Password must be at least 6 characters.';
    if (error.contains('invalid-email'))
      return 'Please enter a valid email address.';
    if (error.contains('network-request-failed'))
      return 'No internet connection.';
    if (error.contains('too-many-requests'))
      return 'Too many failed attempts. Please wait a moment and try again.';
    if (error.contains('user-disabled'))
      return 'This account has been disabled. Contact support.';
    if (error.contains('operation-not-allowed'))
      return 'Email/password sign-in is not enabled. Contact support.';
    return 'Something went wrong. Please try again.';
  }
}
