import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/activity_model.dart';
import '../../core/constants/app_constants.dart';

class ActivityRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference get _activities =>
      _db.collection(AppConstants.colActivities);

  Future<void> createActivity(ActivityModel activity) async {
    await _activities.doc(activity.id).set(activity.toMap());
  }

  Future<List<ActivityModel>> getActivitiesBySubject(
      String subject, String grade) async {
    final query = await _activities
        .where('subject', isEqualTo: subject)
        .where('grade', isEqualTo: grade)
        .get();
    return query.docs
        .map((doc) =>
            ActivityModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }

  Future<List<ActivityModel>> getActivitiesByGrade(String grade) async {
    final query = await _activities.where('grade', isEqualTo: grade).get();
    return query.docs
        .map((doc) =>
            ActivityModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }

  Stream<List<ActivityModel>> watchActivities(String grade) {
    return _activities.where('grade', isEqualTo: grade).snapshots().map(
        (snap) => snap.docs
            .map((doc) => ActivityModel.fromMap(
                doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  Future<ActivityModel?> getActivity(String id) async {
    final doc = await _activities.doc(id).get();
    if (!doc.exists) return null;
    return ActivityModel.fromMap(doc.data() as Map<String, dynamic>, id);
  }
}
