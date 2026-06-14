import 'package:flutter/material.dart';
import '../core/services/auth_service.dart';
import '../data/models/user_model.dart';
import '../data/repositories/user_repository.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final UserRepository _userRepo = UserRepository();

  AuthStatus _status = AuthStatus.unknown;
  UserModel? _user;
  String? _errorMessage;
  bool _isLoading = false;

  AuthStatus get status => _status;
  UserModel? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  AuthProvider() {
    _init();
  }

  void _init() {
    _authService.authStateChanges.listen((firebaseUser) async {
      if (firebaseUser == null) {
        _status = AuthStatus.unauthenticated;
        _user = null;
      } else {
        _user = await _userRepo.getUser(firebaseUser.uid);
        _status = AuthStatus.authenticated;
      }
      notifyListeners();
    });
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

  Future<void> signOut() async {
    await _authService.signOut();
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  String _friendlyError(String error) {
    if (error.contains('user-not-found')) return 'No account found with this email.';
    if (error.contains('wrong-password')) return 'Incorrect password. Try again.';
    if (error.contains('email-already-in-use')) return 'This email is already registered.';
    if (error.contains('weak-password')) return 'Password must be at least 6 characters.';
    if (error.contains('invalid-email')) return 'Please enter a valid email address.';
    if (error.contains('network-request-failed')) return 'No internet connection.';
    return 'Something went wrong. Please try again.';
  }
}
