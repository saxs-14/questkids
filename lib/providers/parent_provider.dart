import 'dart:async' show StreamSubscription;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../data/models/user_model.dart';
import '../data/repositories/parent_repository.dart';

class ParentProvider extends ChangeNotifier {
  final ParentRepository _parentRepo = ParentRepository();

  List<UserModel> _linkedChildren = [];
  UserModel? _selectedChild;
  List<Map<String, dynamic>> _pendingRequests = [];
  List<Map<String, dynamic>> _pendingVerifications = [];
  List<Map<String, dynamic>> _outgoingRequests = [];
  final List<Map<String, dynamic>> _calendarEvents = [];
  final List<Map<String, dynamic>> _documents = [];
  final List<Map<String, dynamic>> _moodHistory = [];
  bool _isLoading = false;
  String? _errorMessage;

  // ParentProvider is a single app-lifetime instance (see main.dart's
  // MultiProvider) that outlives sign-out/sign-in. Without tracking and
  // cancelling these, loadParentData() on a second account layers a new
  // set of listeners on top of the previous account's -- the old
  // listeners keep firing and the old data (_linkedChildren,
  // _selectedChild, etc.) stays visible until the new account's own
  // listeners happen to overwrite it, leaking one family's child data
  // into another parent's freshly-created session.
  StreamSubscription? _pendingRequestsSub;
  StreamSubscription? _outgoingRequestsSub;
  StreamSubscription? _linkedChildrenDocSub;
  StreamSubscription? _pendingVerificationsSub;

  // Getters
  List<UserModel> get linkedChildren => _linkedChildren;
  UserModel? get selectedChild => _selectedChild;
  List<Map<String, dynamic>> get pendingRequests => _pendingRequests;
  List<Map<String, dynamic>> get pendingVerifications => _pendingVerifications;
  List<Map<String, dynamic>> get outgoingRequests => _outgoingRequests;
  List<Map<String, dynamic>> get calendarEvents => _calendarEvents;
  List<Map<String, dynamic>> get documents => _documents;
  List<Map<String, dynamic>> get moodHistory => _moodHistory;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  Future<void> loadParentData(String uid) async {
    reset();
    _setLoading(true);
    try {
      // load pending requests
      _pendingRequestsSub = _parentRepo.watchPendingRequests(uid).listen((list) {
        _pendingRequests = list;
        notifyListeners();
      });

      // outgoing requests
      _outgoingRequestsSub = _parentRepo.watchOutgoingRequests(uid).listen((list) {
        _outgoingRequests = list;
        notifyListeners();
      });

      // pending verifications (for linked children)
      // once we have linkedChildren, subscribe
      watchLinkedChildrenStream(uid);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  void watchLinkedChildrenStream(String uid) {
    // watch user's document to get linked children uids
    _linkedChildrenDocSub = _parentRepo.watchUserDoc(uid).listen((data) {
      final children = List<String>.from(data?['linkedChildrenUids'] ?? []);
      // update linkedChildren list
      _parentRepo.getLinkedChildren(children).then((list) {
        _linkedChildren = list;
        notifyListeners();
      });

      // subscribe to pending verifications for these children
      _pendingVerificationsSub?.cancel();
      _pendingVerificationsSub =
          _parentRepo.watchPendingVerifications(children).listen((items) {
        _pendingVerifications = items;
        notifyListeners();
      });
    });
  }

  /// Cancels every live Firestore listener and clears all cached state.
  /// Must run before loading a different account's data (loadParentData
  /// already does this) and on sign-out, so no linked-children/requests
  /// data from one account is ever visible to the next account that signs
  /// in on this device.
  void reset() {
    _pendingRequestsSub?.cancel();
    _outgoingRequestsSub?.cancel();
    _linkedChildrenDocSub?.cancel();
    _pendingVerificationsSub?.cancel();
    _pendingRequestsSub = null;
    _outgoingRequestsSub = null;
    _linkedChildrenDocSub = null;
    _pendingVerificationsSub = null;

    _linkedChildren = [];
    _selectedChild = null;
    _pendingRequests = [];
    _pendingVerifications = [];
    _outgoingRequests = [];
    _calendarEvents.clear();
    _documents.clear();
    _moodHistory.clear();
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _pendingRequestsSub?.cancel();
    _outgoingRequestsSub?.cancel();
    _linkedChildrenDocSub?.cancel();
    _pendingVerificationsSub?.cancel();
    super.dispose();
  }

  void selectChild(UserModel child) {
    _selectedChild = child;
    notifyListeners();
  }

  Future<void> approveLinkRequest(String requestId) async {
    await _parentRepo.approveLinkRequest(requestId);
  }

  Future<void> declineLinkRequest(String requestId) async {
    await _parentRepo.declineLinkRequest(requestId);
  }

  Future<void> cancelLinkRequest(String requestId) async {
    await _parentRepo.cancelLinkRequest(requestId);
  }

  Future<void> unlinkChild(
    String parentUid,
    String childUid,
    String otpCode,
  ) async {
    await _parentRepo.unlinkParentFromChild(parentUid, childUid, otpCode);
  }

  Future<void> addCalendarEvent(Map<String, dynamic> event) async {
    await _parentRepo.addCalendarEvent(event);
  }

  Future<void> deleteCalendarEvent(String eventId) async {
    await _parentRepo.deleteCalendarEvent(eventId);
  }

  Future<void> logMoodCheckin(String childUid, String loggedByUid,
      String mood, String emoji, String? note) async {
    await _parentRepo.logMood({
      'childUid': childUid,
      'loggedByUid': loggedByUid,
      'mood': mood,
      'moodEmoji': emoji,
      'note': note,
    });
  }

  Future<Map<String, dynamic>> getAnalytics(
      String childUid, DateTime from, DateTime to) async {
    return await _parentRepo.getChildAnalytics(childUid, from, to);
  }

}
