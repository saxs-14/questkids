import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class AdminService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  Stream<QuerySnapshot<Map<String, dynamic>>> watchUsers() {
    return _firestore.collection('users').orderBy('createdAt', descending: true).limit(100).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchAiReports() {
    return _firestore.collection('ai_reports').orderBy('createdAt', descending: true).limit(100).snapshots();
  }

  Future<Map<String, int>> getOverviewCounts() async {
    final results = await Future.wait([
      _firestore.collection('users').count().get(),
      _firestore.collection('users').where('role', isEqualTo: 'parent').count().get(),
      _firestore.collection('users').where('role', isEqualTo: 'learner').count().get(),
      _firestore.collection('users').where('role', isEqualTo: 'admin').count().get(),
      _firestore.collection('activities').count().get(),
      _firestore.collection('ai_reports').count().get(),
    ]);
    return {
      'users': results[0].count ?? 0,
      'parents': results[1].count ?? 0,
      'children': results[2].count ?? 0,
      'admins': results[3].count ?? 0,
      'activities': results[4].count ?? 0,
      'reports': results[5].count ?? 0,
    };
  }

  Future<void> setUserRole({required String uid, required String role}) async {
    await _functions.httpsCallable('setUserRole').call({'uid': uid, 'role': role});
  }

  Future<void> setUserDisabled({required String uid, required bool disabled}) async {
    await _functions.httpsCallable('setUserDisabled').call({'uid': uid, 'disabled': disabled});
  }

  Future<void> resolveAiReport({required String reportId, required String status}) async {
    await _firestore.collection('ai_reports').doc(reportId).update({
      'status': status,
      'resolvedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<Map<String, dynamic>> getPlatformReport() async {
    final result = await _functions
        .httpsCallable('getAdminPlatformReport')
        .call();
    return Map<String, dynamic>.from(result.data as Map);
  }
}
