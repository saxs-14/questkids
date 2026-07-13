import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:questkids/core/widgets/profile_settings_tile.dart';
import 'package:questkids/providers/auth_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  testWidgets('ProfileSettingsTile shows Settings and Sign Out, confirms before signing out', (tester) async {
    final auth = AuthProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp(
          routes: {'/settings': (_) => const Scaffold(body: Text('Settings Page'))},
          home: const Scaffold(body: ProfileSettingsTile()),
        ),
      ),
    );

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Sign Out'), findsOneWidget);

    await tester.tap(find.text('Sign Out'));
    await tester.pumpAndSettle();

    // A confirmation dialog must appear before any sign-out happens.
    expect(find.text('Are you sure you want to sign out?'), findsOneWidget);

    auth.dispose();
  });
}
