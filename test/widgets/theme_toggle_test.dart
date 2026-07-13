import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:questkids/core/theme/theme_provider.dart';
import 'package:questkids/core/widgets/theme_toggle.dart';

void main() {
  testWidgets('ThemeToggle toggles ThemeProvider on tap', (tester) async {
    final theme = ThemeProvider();
    await tester.pumpWidget(
      ChangeNotifierProvider<ThemeProvider>.value(
        value: theme,
        child: const MaterialApp(home: Scaffold(body: ThemeToggle())),
      ),
    );
    await tester.pumpAndSettle();

    final initial = theme.isDark;
    await tester.tap(find.byType(ThemeToggle));
    await tester.pumpAndSettle();

    expect(theme.isDark, isNot(initial));
  });
}
