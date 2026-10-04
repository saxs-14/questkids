import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/features/dashboard/widgets/admin_search_field.dart';

void main() {
  testWidgets('AdminSearchField shows its hint and reports typed text', (tester) async {
    String? typed;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AdminSearchField(
          hintText: 'Search by name, email, or role…',
          onChanged: (value) => typed = value,
        ),
      ),
    ));

    expect(find.text('Search by name, email, or role…'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'thandeka');
    expect(typed, 'thandeka');
  });
}
