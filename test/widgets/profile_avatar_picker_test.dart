import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:questkids/core/widgets/profile_avatar_picker.dart';
import 'package:questkids/providers/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  testWidgets('tapping the avatar shows the one-time rationale before the picker sheet',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: AuthProvider(navigatorKey: GlobalKey<NavigatorState>()),
        child: const MaterialApp(
          home: Scaffold(body: ProfileAvatarPicker()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ProfileAvatarPicker));
    await tester.pumpAndSettle();

    expect(find.textContaining('Profile Picture'), findsWidgets);
    expect(find.text('Continue'), findsOneWidget);
  });
}
