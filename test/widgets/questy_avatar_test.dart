import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/features/ai_tutor/widgets/questy_avatar.dart';

void main() {
  testWidgets('QuestyAvatar renders for every expression', (tester) async {
    for (final expr in QuestyExpression.values) {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: QuestyAvatar(size: 48, expression: expr),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(QuestyAvatar), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    }
  });

  testWidgets('QuestyAvatar keeps animating over time', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: QuestyAvatar(expression: QuestyExpression.idle)),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    // An animated idle state must keep scheduling frames.
    expect(tester.binding.hasScheduledFrame, isTrue);
  });
}
