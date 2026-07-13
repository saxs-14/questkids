import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/providers/auth_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  testWidgets(
      'notificationPermission starts null before any auth state is known',
      (tester) async {
    final provider = AuthProvider(navigatorKey: GlobalKey<NavigatorState>());
    expect(provider.notificationPermission, isNull);
    await tester.pumpAndSettle();
    provider.dispose();
  });
}
