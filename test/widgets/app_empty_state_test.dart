import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/core/widgets/app_empty_state.dart';

void main() {
  testWidgets('AppEmptyState shows title/message and invokes onAction', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AppEmptyState(
          emoji: '🎯',
          title: 'No quests yet',
          message: 'Complete a game to see it here.',
          actionLabel: 'Play now',
          onAction: () => tapped = true,
        ),
      ),
    ));

    expect(find.text('No quests yet'), findsOneWidget);
    expect(find.text('Play now'), findsOneWidget);
    await tester.tap(find.text('Play now'));
    await tester.pump();
    expect(tapped, isTrue);
  });
}
