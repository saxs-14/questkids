import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../config/emulator_config.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/repositories/reward_repository.dart';
import '../../data/repositories/parent_repository.dart';
import '../../data/repositories/notification_repository.dart';
import '../constants/app_constants.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late final GoogleSignIn _googleSignIn;
  final UserRepository _userRepo = UserRepository();
  final RewardRepository _rewardRepo = RewardRepository();

  AuthService() {
    // Initialize GoogleSignIn with clientId on web
    if (kIsWeb) {
      _googleSignIn = GoogleSignIn(
        clientId:
            '882077922348-ohk1u6nqk3ujt5dn5k6ck4j4j4j4j4j4.apps.googleusercontent.com',
      );
    } else {
      _googleSignIn = GoogleSignIn();
    }
  }

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y$m$d';
  }

  String _generateChildEmail(String name, DateTime birthDate) {
    final cleanName = name.replaceAll(' ', '').toLowerCase();
    final dateStr = _formatDate(birthDate);
    return '$cleanName.$dateStr@questkids.child';
  }

  String _generateChildPassword(DateTime birthDate) {
    return 'Child@${birthDate.year}';
  }

  // firebase_crashlytics has no web implementation (its pubspec declares
  // only android/ios/macos) -- on web, recordError throws instead of
  // reporting. Since this is always awaited right before a `rethrow` (or
  // inside a cleanup catch block that itself must not throw), an unguarded
  // call would mask the real error on web, and inside a cleanup catch it
  // would abort the remaining cleanup steps entirely. Reporting must never
  // be able to break the flow it's reporting on.
  Future<void> _reportNonFatal(Object e, StackTrace st, String reason) async {
    if (kIsWeb) return;
    try {
      await FirebaseCrashlytics.instance
          .recordError(e, st, reason: reason, fatal: false);
    } catch (_) {}
  }

  // Deletes a just-created child's Firestore doc and Auth account after a
  // post-creation step (e.g. linkChild) failed. Without this, the child is
  // left as an orphaned account, and since _generateChildEmail/
  // _generateChildPassword are deterministic on name+birthdate, every retry
  // with the same details would then permanently fail with
  // email-already-in-use. `childFirestore`/`childFirebaseUser` must belong
  // to the same temp app the child was created in, authenticated as the
  // child themself (required for the Firestore doc delete to satisfy
  // `allow delete: if isUser(uid)`).
  Future<void> _cleanupOrphanedChild({
    required FirebaseFirestore childFirestore,
    required User childFirebaseUser,
    required String childUid,
    required String context,
  }) async {
    try {
      await childFirestore.collection('users').doc(childUid).delete();
    } catch (e, st) {
      await _reportNonFatal(e, st,
          '$context: failed to clean up orphaned child Firestore doc $childUid');
    }
    try {
      await childFirebaseUser.delete();
    } catch (e, st) {
      await _reportNonFatal(e, st,
          '$context: failed to clean up orphaned child Auth account $childUid');
    }
  }

  // A parent/teacher's Auth custom claim starts as 'learner', set
  // synchronously by the assignDefaultRole Cloud Function before this
  // doc even exists (it has no way to know the intended role at that
  // point). A separate Firestore trigger (grantSelfDeclaredRoleClaim,
  // functions/src/admin/setUserRole.ts) upgrades the claim to match this
  // doc's self-declared role immediately after create, but that trigger
  // runs asynchronously server-side -- without waiting here, the
  // freshly-registered user would land on their dashboard with a stale
  // 'learner' ID token, and every parent/teacher-gated Firestore read or
  // write (which authorize off the token claim, never this doc's role
  // field) would be denied until the SDK's own next natural token
  // refresh, up to an hour later. Bounded retry, not an indefinite wait:
  // if the trigger is ever slow or fails, the user still lands on the
  // right dashboard shell (NavigationService routes off this doc's role)
  // and self-heals once the SDK's background refresh eventually catches
  // up, so failing to catch up here is degraded, not broken.
  Future<void> _waitForRoleClaim(User user, String expectedRole) async {
    for (var attempt = 0; attempt < 8; attempt++) {
      await Future.delayed(const Duration(milliseconds: 500));
      try {
        final result = await user.getIdTokenResult(true);
        if (result.claims?['role'] == expectedRole) return;
      } catch (_) {
        // Transient token-refresh failure -- keep retrying within budget.
      }
    }
  }

  // Teacher/Standard Register
  Future<UserModel?> registerWithEmail({
    required String email,
    required String password,
    required String name,
    required String role,
    required String grade,
    String? surname,
    String? title,
    String? gender,
    // Optional child data
    String? childName,
    String? childGender,
    DateTime? childBirthDate,
    String? childGrade,
    // POPIA: required (checked below) whenever a child account is created
    // alongside the parent account. See CLAUDE.md §6.5.
    bool childConsentGiven = false,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = cred.user!;
    await user.updateDisplayName(name);
    // send email verification
    try {
      await user.sendEmailVerification();
    } catch (_) {}

    final userModel = UserModel(
      uid: user.uid,
      name: name,
      surname: surname,
      title: title,
      gender: gender,
      email: email,
      role: role,
      grade: grade,
      createdAt: DateTime.now(),
    );
    await _userRepo.createUser(userModel);
    if (role == 'parent' || role == 'teacher') {
      await _waitForRoleClaim(user, role);
    }
    await _rewardRepo.initRewards(user.uid);

    // If optional child data provided, create child account and link
    if (childName != null && childBirthDate != null) {
      if (!childConsentGiven) {
        throw Exception(
            'Parent/guardian consent is required to register a child.');
      }
      final parentUid = user.uid;
      final parentRepo = ParentRepository();
      final notifRepo = NotificationRepository();

      // create child via temp app similar to existing flow
      FirebaseApp tempApp = await Firebase.initializeApp(
        name: 'temp_auth_app_$parentUid',
        options: Firebase.app().options,
      );
      await connectToEmulatorsIfEnabled(tempApp);

      String childUid = '';
      try {
        final tempAuth = FirebaseAuth.instanceFor(app: tempApp);
        final dummyEmail = _generateChildEmail(childName, childBirthDate);
        final dummyPassword = _generateChildPassword(childBirthDate);

        final childCred = await tempAuth.createUserWithEmailAndPassword(
          email: dummyEmail,
          password: dummyPassword,
        );
        final childFirebaseUser = childCred.user!;
        childUid = childFirebaseUser.uid;

        final childModel = UserModel(
          uid: childUid,
          name: childName,
          surname: surname,
          email: dummyEmail,
          role: 'learner',
          gender: childGender,
          birthDate: childBirthDate,
          grade: childGrade ?? grade,
          parentUid: parentUid,
          linkedParentUids: [parentUid],
          createdAt: DateTime.now(),
        );

        final childFirestore = FirebaseFirestore.instanceFor(app: tempApp);
        final code = parentRepo.generateLinkCode();
        await childFirestore.collection('users').doc(childUid).set({
          ...childModel.toMap(),
          'childLinkCode': code,
          'consentGivenBy': name,
          'consentEmail': email,
          'consentAt': DateTime.now().millisecondsSinceEpoch,
          'policyVersion': AppConstants.consentPolicyVersion,
        });

        try {
          // update parent user document to include child uid
          await _userRepo.linkChild(parentUid, childUid);
        } catch (linkError, linkStack) {
          // linkChild failed after the child's Auth account and Firestore
          // doc already exist -- clean up both before rethrowing so the
          // parent can actually retry. See _cleanupOrphanedChild.
          await _cleanupOrphanedChild(
            childFirestore: childFirestore,
            childFirebaseUser: childFirebaseUser,
            childUid: childUid,
            context: 'registerWithEmail',
          );
          await _reportNonFatal(linkError, linkStack,
              'registerWithEmail: linkChild failed for parent $parentUid / child $childUid');
          rethrow;
        }

        // Best-effort: the parent<->child link already succeeded above, so
        // a failure here must NOT trigger the orphan cleanup -- that would
        // delete a successfully-linked child while leaving its uid stuck
        // in the parent's (locked, client-unfixable) linkedChildrenUids.
        try {
          await notifRepo.createNotification({
            'recipientUid': parentUid,
            'title': 'Welcome to QuestKids',
            'body':
                'Your account and child account have been created successfully.',
            'type': 'welcome',
          });
        } catch (e, st) {
          await _reportNonFatal(e, st,
              'registerWithEmail: welcome notification failed for parent $parentUid / child $childUid');
        }
      } finally {
        await tempApp.delete();
      }
    }
    return userModel;
  }

  // Parent + Child Register
  Future<UserModel?> registerParentWithChild({
    // Parent details
    required String parentEmail,
    required String parentPassword,
    required String parentName,
    required String parentSurname,
    required String parentTitle,
    required String parentGender,
    required String relationToChild,
    // Child details
    required String childName,
    required String childGender,
    required DateTime childBirthDate,
    required String childGrade,
  }) async {
    // 1. Register Parent
    final parentCred = await _auth.createUserWithEmailAndPassword(
      email: parentEmail,
      password: parentPassword,
    );
    final parentUser = parentCred.user!;
    await parentUser.updateDisplayName(parentName);

    // 2. Register Child via Temporary Firebase App
    FirebaseApp tempApp = await Firebase.initializeApp(
      name: 'temp_auth_app',
      options: Firebase.app().options,
    );
    await connectToEmulatorsIfEnabled(tempApp);

    String childUid = '';
    try {
      final tempAuth = FirebaseAuth.instanceFor(app: tempApp);
      final dummyEmail = _generateChildEmail(childName, childBirthDate);
      final dummyPassword = _generateChildPassword(childBirthDate);

      final childCred = await tempAuth.createUserWithEmailAndPassword(
        email: dummyEmail,
        password: dummyPassword,
      );
      final childFirebaseUser = childCred.user!;
      childUid = childFirebaseUser.uid;

      // Create Child UserModel
      final childModel = UserModel(
        uid: childUid,
        name: childName,
        surname: parentSurname,
        email: dummyEmail,
        role: 'learner',
        gender: childGender,
        birthDate: childBirthDate,
        grade: childGrade,
        parentUid: parentUser.uid,
        createdAt: DateTime.now(),
      );

      final childFirestore = FirebaseFirestore.instanceFor(app: tempApp);
      // POPIA consent fields required by firestore.rules' `allow create` for
      // role:'learner' (see CLAUDE.md §6.5) -- missing here previously,
      // which meant this function's child-doc create was rejected even
      // before reaching the parent-doc create fixed elsewhere in this file.
      await childFirestore.collection('users').doc(childUid).set({
        ...childModel.toMap(),
        'consentGivenBy': parentName,
        'consentEmail': parentEmail,
        'consentAt': DateTime.now().millisecondsSinceEpoch,
        'policyVersion': AppConstants.consentPolicyVersion,
      });
      await childFirestore.collection('rewards').doc(childUid).set({
        'uid': childUid,
        'unlockedAvatars': [],
        'badges': [],
        'totalStars': 0,
        'currentLevel': 1,
      });
    } finally {
      await tempApp.delete();
    }

    // 3. Create Parent UserModel. linkedChildrenUids starts empty and is
    // populated by a separate linkChild() call below (matching
    // registerWithEmail's pattern) rather than being set here: it's a
    // locked field firestore.rules' `allow create` requires to be empty,
    // to stop a client pre-claiming read access to other users' data the
    // moment an admin later grants their real 'parent' custom claim.
    final parentModel = UserModel(
      uid: parentUser.uid,
      name: parentName,
      surname: parentSurname,
      title: parentTitle,
      gender: parentGender,
      relationToChild: relationToChild,
      email: parentEmail,
      role: 'parent',
      grade: childGrade, // Keep as reference or empty
      createdAt: DateTime.now(),
    );
    await _userRepo.createUser(parentModel);
    await _userRepo.linkChild(parentUser.uid, childUid);
    return parentModel;
  }

  // Email & Password Login (Parent / Teacher)
  Future<UserModel?> loginWithEmail({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return await _userRepo.getUser(cred.user!.uid);
  }

  // Child Login (Name + Birthdate)
  Future<UserModel?> loginChild({
    required String name,
    required DateTime birthDate,
  }) async {
    final dummyEmail = _generateChildEmail(name, birthDate);
    final dummyPassword = _generateChildPassword(birthDate);

    final cred = await _auth.signInWithEmailAndPassword(
      email: dummyEmail,
      password: dummyPassword,
    );
    return await _userRepo.getUser(cred.user!.uid);
  }

  // Google Sign In
  Future<UserModel?> signInWithGoogle({
    required String role,
    required String grade,
  }) async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final cred = await _auth.signInWithCredential(credential);
    final user = cred.user!;
    final existing = await _userRepo.getUser(user.uid);
    if (existing != null) return existing;
    final userModel = UserModel(
      uid: user.uid,
      name: user.displayName ?? 'Learner',
      email: user.email ?? '',
      role: role,
      grade: grade,
      avatarUrl: user.photoURL,
      createdAt: DateTime.now(),
    );
    await _userRepo.createUser(userModel);
    if (role == 'parent' || role == 'teacher') {
      await _waitForRoleClaim(user, role);
    }
    await _rewardRepo.initRewards(user.uid);
    return userModel;
  }

  // Password Reset
  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // Sign Out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // Create a child account and link to existing parent
  Future<UserModel?> createChildForParent({
    required String parentUid,
    required String childName,
    required String childGender,
    required DateTime childBirthDate,
    required String childGrade,
    // POPIA: required — see CLAUDE.md §6.5.
    required bool consentGiven,
    required String consentGivenBy,
    required String consentEmail,
    String? parentSurname,
  }) async {
    if (!consentGiven) {
      throw Exception(
          'Parent/guardian consent is required to register a child.');
    }
    FirebaseApp tempApp = await Firebase.initializeApp(
      name: 'temp_create_child_$parentUid',
      options: Firebase.app().options,
    );
    await connectToEmulatorsIfEnabled(tempApp);

    try {
      final tempAuth = FirebaseAuth.instanceFor(app: tempApp);
      final dummyEmail = _generateChildEmail(childName, childBirthDate);
      final dummyPassword = _generateChildPassword(childBirthDate);

      final childCred = await tempAuth.createUserWithEmailAndPassword(
        email: dummyEmail,
        password: dummyPassword,
      );
      final childFirebaseUser = childCred.user!;
      final childUid = childFirebaseUser.uid;

      final childModel = UserModel(
        uid: childUid,
        name: childName,
        surname: parentSurname,
        email: dummyEmail,
        role: 'learner',
        gender: childGender,
        birthDate: childBirthDate,
        grade: childGrade,
        parentUid: parentUid,
        linkedParentUids: [parentUid],
        createdAt: DateTime.now(),
      );

      final childFirestore = FirebaseFirestore.instanceFor(app: tempApp);
      await childFirestore.collection('users').doc(childUid).set({
        ...childModel.toMap(),
        'consentGivenBy': consentGivenBy,
        'consentEmail': consentEmail,
        'consentAt': DateTime.now().millisecondsSinceEpoch,
        'policyVersion': AppConstants.consentPolicyVersion,
      });

      try {
        // update parent and child linkage in main app
        await _userRepo.linkChild(parentUid, childUid);
      } catch (linkError, linkStack) {
        // Same cleanup as registerWithEmail's child branch, and for the
        // same reason: without it, a failed linkChild (see
        // docs/DEFERRED.md) leaves an orphaned child Auth account, and
        // since the child's email/password are deterministic on
        // name+birthdate, every retry -- including this exact flow, which
        // is the one an existing parent actually uses to retry -- would
        // otherwise permanently fail with email-already-in-use.
        await _cleanupOrphanedChild(
          childFirestore: childFirestore,
          childFirebaseUser: childFirebaseUser,
          childUid: childUid,
          context: 'createChildForParent',
        );
        await _reportNonFatal(linkError, linkStack,
            'createChildForParent: linkChild failed for parent $parentUid / child $childUid');
        rethrow;
      }

      return childModel;
    } finally {
      await tempApp.delete();
    }
  }
}
