/// Initializes the local database factory for the current platform.
///
/// On Windows/Linux this switches sqflite to its FFI implementation;
/// on Android/iOS/macOS the default sqflite factory is used; on web
/// it is a no-op because [LocalStorageService] uses shared_preferences.
library;

export 'db_bootstrap_stub.dart' if (dart.library.io) 'db_bootstrap_io.dart';
