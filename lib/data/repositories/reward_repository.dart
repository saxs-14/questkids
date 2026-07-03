import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/reward_model.dart';
import '../../core/constants/app_constants.dart';

class RewardRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference get _rewards => _db.collection(AppConstants.colRewards);

  Future<void> initRewards(String uid) async {
    final existing = await _rewards.doc(uid).get();
    if (!existing.exists) {
      await _rewards.doc(uid).set(RewardModel(
            uid: uid,
            lastActiveDate: DateTime.now(),
          ).toMap());
    }
  }

  Future<RewardModel?> getRewards(String uid) async {
    final doc = await _rewards.doc(uid).get();
    if (!doc.exists) return null;
    return RewardModel.fromMap(doc.data() as Map<String, dynamic>);
  }

  Stream<RewardModel?> watchRewards(String uid) {
    return _rewards.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return RewardModel.fromMap(doc.data() as Map<String, dynamic>);
    });
  }

  Future<void> addPoints(String uid, int points) async {
    final current = await getRewards(uid);
    if (current == null) return;
    final newTotal = current.totalPoints + points;
    final newLevel = (newTotal ~/ 100) + 1;
    await _rewards.doc(uid).update({
      'totalPoints': newTotal,
      'level': newLevel,
      'lastActiveDate': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> awardBadge(String uid, BadgeModel badge) async {
    await _rewards.doc(uid).update({
      'badges': FieldValue.arrayUnion([badge.toMap()]),
    });
  }

  Future<void> updateStreak(String uid, int streak) async {
    await _rewards.doc(uid).update({'streakDays': streak});
  }
}
