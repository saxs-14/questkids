import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/core/widgets/notification_banner.dart';

void main() {
  testWidgets('NotificationBanner.show displays title and body in a SnackBar', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => NotificationBanner.show(
              context,
              title: 'New Badge!',
              body: 'You earned Math Wizard',
            ),
            child: const Text('Trigger'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Trigger'));
    await tester.pump();

    expect(find.text('New Badge!'), findsOneWidget);
    expect(find.text('You earned Math Wizard'), findsOneWidget);
  });
}
