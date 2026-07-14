import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/core/widgets/quest_boy_mascot.dart';

void main() {
  testWidgets('QuestBoyMascot renders for every state', (tester) async {
    for (final state in QuestBoyState.values) {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: QuestBoyMascot(size: 48, state: state),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(QuestBoyMascot), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    }
  });

  testWidgets('QuestBoyMascot animates when reduced motion is off',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: false),
        child: child!,
      ),
      home: const Scaffold(body: QuestBoyMascot(state: QuestBoyState.waving)),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    // An animated state must keep scheduling frames.
    expect(tester.binding.hasScheduledFrame, isTrue);
  });

  testWidgets('QuestBoyMascot stays still when reduced motion is on',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
      home: const Scaffold(body: QuestBoyMascot(state: QuestBoyState.waving)),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    // Reduced motion must not keep scheduling frames forever.
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
