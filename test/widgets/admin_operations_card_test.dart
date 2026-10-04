import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/features/dashboard/widgets/admin_operations_card.dart';

void main() {
  testWidgets('AdminOperationsCard shows title and every bullet item', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: AdminOperationsCard(
          title: 'Content',
          items: [
            'Manage approved activities and CAPS curriculum reference data.',
            'Keep the game catalogue and learning objectives aligned.',
          ],
        ),
      ),
    ));

    expect(find.text('CONTENT'), findsOneWidget);
    expect(
      find.text('Manage approved activities and CAPS curriculum reference data.'),
      findsOneWidget,
    );
    expect(
      find.text('Keep the game catalogue and learning objectives aligned.'),
      findsOneWidget,
    );
  });
}
