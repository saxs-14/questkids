import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../data/models/user_model.dart';
import '../../data/models/activity_model.dart';
import '../../core/constants/app_constants.dart';

class TeacherService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Fetch all students in a specific grade
  Future<List<UserModel>> getStudentsByGrade(String grade) async {
    try {
      final snapshot = await _db
          .collection(AppConstants.colUsers)
          .where('role', isEqualTo: 'learner')
          .where('grade', isEqualTo: grade)
          .get();

      return snapshot.docs
          .map((doc) => UserModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      debugPrint('Error fetching students: $e');
      return [];
    }
  }

  /// Upload a new quiz/activity created by the teacher
  Future<bool> uploadActivity(ActivityModel activity) async {
    try {
      // If activity doesn't have an ID (e.g. creating a new one), we generate it
      final docRef = activity.id.isEmpty
          ? _db.collection(AppConstants.colActivities).doc()
          : _db.collection(AppConstants.colActivities).doc(activity.id);

      final activityMap = activity.toMap();
      await docRef.set(activityMap);
      return true;
    } catch (e) {
      debugPrint('Error uploading activity: $e');
      return false;
    }
  }

  /// Delete an activity
  Future<bool> deleteActivity(String activityId) async {
    try {
      await _db.collection(AppConstants.colActivities).doc(activityId).delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting activity: $e');
      return false;
    }
  }
}
