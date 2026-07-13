import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:questkids/core/theme/theme_provider.dart';
import 'package:questkids/core/widgets/theme_toggle.dart';
import 'package:questkids/features/profile/screens/settings_screen.dart';
import 'package:questkids/providers/auth_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  testWidgets('SettingsScreen toggles dark mode via ThemeProvider', (tester) async {
    final themeProvider = ThemeProvider();
    final authProvider = AuthProvider(navigatorKey: GlobalKey<NavigatorState>());

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dark Mode'), findsOneWidget);
    final toggleFinder = find.byType(ThemeToggle);
    expect(toggleFinder, findsOneWidget);

    final initial = themeProvider.isDark;
    await tester.tap(toggleFinder);
    await tester.pumpAndSettle();

    expect(themeProvider.isDark, isNot(initial));

    authProvider.dispose();
  });
}
