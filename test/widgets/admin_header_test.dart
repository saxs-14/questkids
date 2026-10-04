import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/features/dashboard/widgets/admin_header.dart';

void main() {
  testWidgets('AdminSectionHeader shows eyebrow, title and optional subtitle',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: AdminSectionHeader(
          eyebrow: 'QUESTKIDS ADMIN',
          title: 'Platform Overview',
          subtitle: 'Manage everything from one console.',
        ),
      ),
    ));

    expect(find.text('QUESTKIDS ADMIN'), findsOneWidget);
    expect(find.text('Platform Overview'), findsOneWidget);
    expect(find.text('Manage everything from one console.'), findsOneWidget);
  });

  testWidgets('AdminSectionHeader renders without a subtitle', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: AdminSectionHeader(eyebrow: 'QUESTKIDS ADMIN', title: 'Users'),
      ),
    ));

    expect(find.text('Users'), findsOneWidget);
  });

  testWidgets('AdminStatusPill shows its label', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: AdminStatusPill(label: 'All systems operational')),
    ));

    expect(find.text('All systems operational'), findsOneWidget);
  });
}
