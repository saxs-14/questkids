import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Desktop (Windows/Linux): sqflite has no native implementation, so
/// route it through sqflite_common_ffi. Android/iOS/macOS keep the
/// default platform-channel factory.
void initLocalDatabase() {
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
}
