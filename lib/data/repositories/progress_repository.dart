import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/progress_model.dart';
import '../../core/constants/app_constants.dart';

class ProgressRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference get _progress => _db.collection(AppConstants.colProgress);

  Future<void> saveProgress(ProgressModel progress) async {
    await _progress.add(progress.toMap());
  }

  Future<List<ProgressModel>> getUserProgress(String uid) async {
    final query = await _progress
        .where('uid', isEqualTo: uid)
        .orderBy('completedAt', descending: true)
        .get();
    return query.docs
        .map((doc) => ProgressModel.fromMap(doc.data() as Map<String, dynamic>))
        .toList();
  }

  Stream<List<ProgressModel>> watchUserProgress(String uid) {
    return _progress
        .where('uid', isEqualTo: uid)
        .orderBy('completedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) =>
                ProgressModel.fromMap(doc.data() as Map<String, dynamic>))
            .toList());
  }

  Future<List<ProgressModel>> getPendingVerification(
      List<String> childUids) async {
    if (childUids.isEmpty) return [];
    final query = await _progress
        .where('uid', whereIn: childUids)
        .where('verified', isEqualTo: false)
        .where('completed', isEqualTo: true)
        .get();
    return query.docs
        .map((doc) => ProgressModel.fromMap(doc.data() as Map<String, dynamic>))
        .toList();
  }

  Future<void> verifyProgress(String progressId) async {
    await _progress.doc(progressId).update({'verified': true});
  }
}
