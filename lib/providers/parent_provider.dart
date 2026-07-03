import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../data/models/user_model.dart';
import '../data/repositories/parent_repository.dart';
import '../data/repositories/notification_repository.dart';

class ParentProvider extends ChangeNotifier {
  final ParentRepository _parentRepo = ParentRepository();
  final NotificationRepository _notifRepo = NotificationRepository();

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
    _setLoading(true);
    try {
      // load pending requests
      _parentRepo.watchPendingRequests(uid).listen((list) {
        _pendingRequests = list;
        notifyListeners();
      });

      // outgoing requests
      _parentRepo.watchOutgoingRequests(uid).listen((list) {
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
    _parentRepo.watchUserDoc(uid).listen((data) {
      final children = List<String>.from(data?['linkedChildrenUids'] ?? []);
      // update linkedChildren list
      _parentRepo.getLinkedChildren(children).then((list) {
        _linkedChildren = list;
        notifyListeners();
      });

      // subscribe to pending verifications for these children
      _parentRepo.watchPendingVerifications(children).listen((items) {
        _pendingVerifications = items;
        notifyListeners();
      });
    });
  }

  void selectChild(UserModel child) {
    _selectedChild = child;
    notifyListeners();
  }

  Future<void> sendLinkRequest(
      String childUid,
      String linkMethod,
      String requestingParentUid,
      String requestingParentName,
      String requestingParentEmail,
      String requestingParentRole) async {
    final child = await _parentRepo.findChildByCode(childUid);
    // childUid param here should be real child uid or code; caller should pass childUid
    final data = {
      'requestingParentUid': requestingParentUid,
      'requestingParentName': requestingParentName,
      'requestingParentEmail': requestingParentEmail,
      'requestingParentRole': requestingParentRole,
      'childUid': childUid,
      'childName': child?.name ?? '',
      'primaryParentUid': child?.parentUid ?? '',
      'status': 'pending',
      'linkMethod': linkMethod,
    };
    await _parentRepo.sendLinkRequest(data);
  }

  Future<void> approveLinkRequest(
      String requestId, String childUid, String requestingParentUid) async {
    await _parentRepo.approveLinkRequest(
        requestId, childUid, requestingParentUid);
    // create notification
    await _notifRepo.createNotification({
      'recipientUid': requestingParentUid,
      'title': 'Link approved',
      'body': 'Your link request was approved. You can now monitor the child.',
      'type': 'link_approved',
    });
  }

  Future<void> declineLinkRequest(String requestId) async {
    await _parentRepo.declineLinkRequest(requestId);
  }

  Future<void> unlinkChild(String parentUid, String childUid) async {
    await _parentRepo.unlinkParentFromChild(parentUid, childUid);
  }

  Future<void> addCalendarEvent(Map<String, dynamic> event) async {
    await _parentRepo.addCalendarEvent(event);
  }

  Future<void> deleteCalendarEvent(String eventId) async {
    await _parentRepo.deleteCalendarEvent(eventId);
  }

  Future<void> uploadDocument(Map<String, dynamic> doc) async {
    await _parentRepo.uploadDocument(doc);
  }

  Future<void> logMoodCheckin(
      String childUid, String mood, String emoji, String? note) async {
    await _parentRepo.logMood({
      'childUid': childUid,
      'loggedByUid': '',
      'mood': mood,
      'moodEmoji': emoji,
      'note': note,
    });
  }

  Future<Map<String, dynamic>> getAnalytics(
      String childUid, DateTime from, DateTime to) async {
    return await _parentRepo.getChildAnalytics(childUid, from, to);
  }

  String generateChildLinkCode(String childUid) {
    final code = _parentRepo.generateLinkCode();
    _parentRepo.saveLinkCode(childUid, code);
    return code;
  }
}
