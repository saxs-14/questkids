import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/core/theme/app_colors.dart';
import 'package:questkids/core/widgets/app_button.dart';

void main() {
  testWidgets('AppButton shows label and calls onPressed', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AppButton(
          label: 'Sign In',
          onPressed: () => tapped = true,
        ),
      ),
    ));

    expect(find.text('Sign In'), findsOneWidget);
    await tester.tap(find.byType(AppButton));
    await tester.pump();
    expect(tapped, isTrue);
  });

  testWidgets('AppButton shows spinner and disables tap when isLoading', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AppButton(
          label: 'Sign In',
          isLoading: true,
          onPressed: () => tapped = true,
        ),
      ),
    ));

    expect(find.text('Sign In'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byType(AppButton), warnIfMissed: false);
    await tester.pump();
    expect(tapped, isFalse);
  });

  testWidgets(
      'AppButton danger variant renders the error border color and still taps',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AppButton(
          label: 'Sign Out',
          variant: AppButtonVariant.danger,
          onPressed: () => tapped = true,
        ),
      ),
    ));

    expect(find.text('Sign Out'), findsOneWidget);
    await tester.tap(find.byType(AppButton));
    await tester.pump();
    expect(tapped, isTrue);

    final container =
        tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.border?.top.color, AppColors.error);
  });
}
