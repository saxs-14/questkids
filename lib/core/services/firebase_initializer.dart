import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../firebase_options.dart';

/// Firebase initialization and setup helper
class FirebaseInitializer {
  // Singleton instance
  static final FirebaseInitializer _instance = FirebaseInitializer._internal();

  factory FirebaseInitializer() {
    return _instance;
  }

  FirebaseInitializer._internal();

  // Firebase instances
  late FirebaseAuth _auth;
  late FirebaseFirestore _firestore;
  bool _initialized = false;

  /// Get Firebase Auth instance
  FirebaseAuth get auth => _auth;

  /// Get Firestore instance
  FirebaseFirestore get firestore => _firestore;

  /// Check if Firebase is initialized
  bool get isInitialized => _initialized;

  /// Initialize Firebase
  Future<void> initialize() async {
    if (_initialized) {
      debugPrint('Firebase already initialized');
      return;
    }

    try {
      debugPrint('Initializing Firebase...');

      // Initialize Firebase App
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Get Firebase instances
      _auth = FirebaseAuth.instance;
      _firestore = FirebaseFirestore.instance;

      // Configure Firestore
      _configureFirestore();

      // Configure Auth
      _configureAuth();

      _initialized = true;
      debugPrint('✅ Firebase initialized successfully');
    } catch (e) {
      debugPrint('❌ Firebase initialization error: $e');
      rethrow;
    }
  }

  /// Configure Firestore settings
  void _configureFirestore() {
    try {
      // Enable offline persistence for web/mobile
      try {
        _firestore.settings = const Settings(
          persistenceEnabled: true,
          cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
        );
      } catch (e) {
        // Persistence might not be available on all platforms
        debugPrint('Note: Firestore persistence not available: $e');
      }

      debugPrint('Firestore configured');
    } catch (e) {
      debugPrint('Error configuring Firestore: $e');
    }
  }

  /// Configure Firebase Auth settings
  void _configureAuth() {
    try {
      // Set language code (optional)
      _auth.setLanguageCode('en');

      // Enable app verification for phone auth (Android only)
      // This is configured automatically

      debugPrint('Firebase Auth configured');
    } catch (e) {
      debugPrint('Error configuring Firebase Auth: $e');
    }
  }

  /// Get current user
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  /// Check if user is authenticated
  bool isUserAuthenticated() {
    return _auth.currentUser != null;
  }

  /// Get current user UID
  String? getCurrentUserUID() {
    return _auth.currentUser?.uid;
  }

  /// Get current user email
  String? getCurrentUserEmail() {
    return _auth.currentUser?.email;
  }

  /// Sign out current user
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      debugPrint('User signed out');
    } catch (e) {
      debugPrint('Error signing out: $e');
      rethrow;
    }
  }

  /// Create a reference to a Firestore collection
  CollectionReference<Map<String, dynamic>> getCollection(String collectionPath) {
    return _firestore.collection(collectionPath);
  }

  /// Create a reference to a Firestore document
  DocumentReference<Map<String, dynamic>> getDocument(String documentPath) {
    return _firestore.doc(documentPath);
  }

  /// Get a specific document from a collection
  Future<DocumentSnapshot<Map<String, dynamic>>> getDocumentData(
    String collectionPath,
    String documentId,
  ) async {
    return _firestore.collection(collectionPath).doc(documentId).get();
  }

  /// Query a Firestore collection
  Query<Map<String, dynamic>> queryCollection(
    String collectionPath,
    List<QueryConstraint> constraints,
  ) {
    Query<Map<String, dynamic>> query = _firestore.collection(collectionPath);

    for (var constraint in constraints) {
      query = constraint.apply(query);
    }

    return query;
  }

  /// Batch write operations
  WriteBatch batch() {
    return _firestore.batch();
  }

  /// Run a transaction
  Future<T> runTransaction<T>(
    Future<T> Function(Transaction transaction) updateFunction,
  ) {
    return _firestore.runTransaction(updateFunction);
  }
}

/// Query constraint for building dynamic queries
abstract class QueryConstraint {
  Query<Map<String, dynamic>> apply(Query<Map<String, dynamic>> query);
}

/// Where constraint
class WhereConstraint implements QueryConstraint {
  final String field;
  final dynamic value;
  final String? operator;

  WhereConstraint({
    required this.field,
    required this.value,
    this.operator,
  });

  @override
  Query<Map<String, dynamic>> apply(Query<Map<String, dynamic>> query) {
    if (operator == '==') {
      return query.where(field, isEqualTo: value);
    } else if (operator == '<') {
      return query.where(field, isLessThan: value);
    } else if (operator == '<=') {
      return query.where(field, isLessThanOrEqualTo: value);
    } else if (operator == '>') {
      return query.where(field, isGreaterThan: value);
    } else if (operator == '>=') {
      return query.where(field, isGreaterThanOrEqualTo: value);
    } else if (operator == '!=') {
      return query.where(field, isNotEqualTo: value);
    } else if (operator == 'in') {
      return query.where(field, whereIn: value);
    } else if (operator == 'array-contains') {
      return query.where(field, arrayContains: value);
    }
    return query.where(field, isEqualTo: value);
  }
}

/// Order by constraint
class OrderByConstraint implements QueryConstraint {
  final String field;
  final bool descending;

  OrderByConstraint({
    required this.field,
    this.descending = false,
  });

  @override
  Query<Map<String, dynamic>> apply(Query<Map<String, dynamic>> query) {
    return query.orderBy(field, descending: descending);
  }
}

/// Limit constraint
class LimitConstraint implements QueryConstraint {
  final int limit;

  LimitConstraint({required this.limit});

  @override
  Query<Map<String, dynamic>> apply(Query<Map<String, dynamic>> query) {
    return query.limit(limit);
  }
}

/// Offset constraint
class OffsetConstraint implements QueryConstraint {
  final int offset;

  OffsetConstraint({required this.offset});

  @override
  Query<Map<String, dynamic>> apply(Query<Map<String, dynamic>> query) {
    // Firestore in Flutter doesn't natively support offset, use cursor startAfter instead.
    return query;
  }
}
