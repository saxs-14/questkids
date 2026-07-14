import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
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
        await childFirestore
            .collection('users')
            .doc(childUid)
            .set(childModel.toMap());
        // generate link code and save
        final code = parentRepo.generateLinkCode();
        await childFirestore.collection('users').doc(childUid).update({
          'childLinkCode': code,
          'consentGivenBy': name,
          'consentEmail': email,
          'consentAt': DateTime.now().millisecondsSinceEpoch,
          'policyVersion': AppConstants.consentPolicyVersion,
        });

        // update parent user document to include child uid
        await _userRepo.linkChild(parentUid, childUid);

        // create welcome notification for parent
        await notifRepo.createNotification({
          'recipientUid': parentUid,
          'title': 'Welcome to QuestKids',
          'body':
              'Your account and child account have been created successfully.',
          'type': 'welcome',
        });
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
      await childFirestore
          .collection('users')
          .doc(childUid)
          .set(childModel.toMap());
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

    // 3. Create Parent UserModel
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
      linkedChildrenUids: [childUid],
      createdAt: DateTime.now(),
    );
    await _userRepo.createUser(parentModel);
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
      await childFirestore
          .collection('users')
          .doc(childUid)
          .set(childModel.toMap());
      await childFirestore.collection('users').doc(childUid).update({
        'consentGivenBy': consentGivenBy,
        'consentEmail': consentEmail,
        'consentAt': DateTime.now().millisecondsSinceEpoch,
        'policyVersion': AppConstants.consentPolicyVersion,
      });

      // update parent and child linkage in main app
      await _userRepo.linkChild(parentUid, childUid);

      return childModel;
    } finally {
      await tempApp.delete();
    }
  }
}
