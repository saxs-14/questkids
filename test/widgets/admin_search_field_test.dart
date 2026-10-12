import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/features/dashboard/theme/admin_colors.dart';
import 'package:questkids/features/dashboard/widgets/admin_search_field.dart';

void main() {
  testWidgets('AdminSearchField shows its hint and reports typed text',
      (tester) async {
    String? typed;
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AdminSearchField(
          hintText: 'Search by name, email, or role…',
          onChanged: (value) => typed = value,
          controller: controller,
        ),
      ),
    ));

    expect(find.text('Search by name, email, or role…'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'thandeka');
    await tester.pump();
    expect(typed, 'thandeka');
    expect(find.text('thandeka'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).style?.color,
      AdminColors.textPrimary,
    );
    expect(find.byTooltip('Clear search'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pump();
    expect(controller.text, isEmpty);
    expect(typed, isEmpty);
    expect(find.text('Search by name, email, or role…'), findsOneWidget);
  });
}
