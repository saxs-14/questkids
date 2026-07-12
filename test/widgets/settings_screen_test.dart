import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:questkids/core/theme/theme_provider.dart';
import 'package:questkids/features/profile/screens/settings_screen.dart';

void main() {
  testWidgets('SettingsScreen toggles dark mode via ThemeProvider', (tester) async {
    final themeProvider = ThemeProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider<ThemeProvider>.value(
        value: themeProvider,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dark Mode'), findsOneWidget);
    final switchFinder = find.byType(Switch);
    expect(switchFinder, findsOneWidget);

    final initial = themeProvider.isDark;
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    expect(themeProvider.isDark, isNot(initial));
  });
}
