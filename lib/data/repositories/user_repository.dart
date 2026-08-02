import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/user_model.dart';
import '../../core/constants/app_constants.dart';

class UserRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference get _users => _db.collection(AppConstants.colUsers);

  Future<void> createUser(UserModel user) async {
    await _users.doc(user.uid).set(user.toMap());
  }

  Future<UserModel?> getUser(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.data() as Map<String, dynamic>, uid);
  }

  Stream<UserModel?> watchUser(String uid) {
    return _users.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserModel.fromMap(doc.data() as Map<String, dynamic>, uid);
    });
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await _users.doc(uid).update(data);
  }

  Future<void> addPoints(String uid, int points) async {
    await _users.doc(uid).update({
      'totalPoints': FieldValue.increment(points),
    });
  }

  // linkedChildrenUids is a locked field -- firestore.rules' `allow update`
  // rejects every client write to it unconditionally, including a parent
  // linking a child they just created themselves (see CLAUDE.md §6.3).
  // The child doc's own `parentUid` is already set correctly at doc-
  // creation time by the child's own temp Auth session (see
  // AuthService.registerWithEmail/createChildForParent), so writing it
  // again here would be both redundant and separately rejected on
  // ownership -- linkRegisteredChild (functions/src/parent/linkChild.ts)
  // only needs to complete the parent side, via the Admin SDK.
  Future<void> linkChild(String parentUid, String childUid) async {
    await FirebaseFunctions.instanceFor(region: 'us-central1')
        .httpsCallable('linkRegisteredChild')
        .call({'childUid': childUid});
  }

  Future<List<UserModel>> getChildren(List<String> childUids) async {
    if (childUids.isEmpty) return [];
    final List<UserModel> children = [];
    for (final uid in childUids) {
      final user = await getUser(uid);
      if (user != null) children.add(user);
    }
    return children;
  }
}
