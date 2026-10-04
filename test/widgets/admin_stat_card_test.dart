import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/features/dashboard/theme/admin_colors.dart';
import 'package:questkids/features/dashboard/widgets/admin_stat_card.dart';

void main() {
  testWidgets('AdminStatCard shows icon, value and label', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: AdminStatCard(icon: Icons.people, value: '82', label: 'Users'),
      ),
    ));

    expect(find.byIcon(Icons.people), findsOneWidget);
    expect(find.text('82'), findsOneWidget);
    expect(find.text('Users'), findsOneWidget);
  });

  testWidgets('AdminStatCard uses the dark gradient container', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: AdminStatCard(icon: Icons.people, value: '82', label: 'Users'),
      ),
    ));

    final container = tester.widget<Container>(find.byType(Container).first);
    final decoration = container.decoration as BoxDecoration;
    final gradient = decoration.gradient as LinearGradient;
    expect(gradient.colors, [AdminColors.cardTop, AdminColors.cardBottom]);
  });
}
