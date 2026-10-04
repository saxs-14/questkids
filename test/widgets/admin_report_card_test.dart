import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/features/dashboard/theme/admin_colors.dart';
import 'package:questkids/features/dashboard/widgets/admin_report_card.dart';

void main() {
  group('severityForReportReason', () {
    test('flags safety/content reasons as red', () {
      expect(severityForReportReason('Made me uncomfortable'), AdminReportSeverity.red);
      expect(severityForReportReason('Not appropriate for school'), AdminReportSeverity.red);
    });

    test('flags quality/unclear reasons as amber, including unknown values', () {
      expect(severityForReportReason('Confusing or wrong answer'), AdminReportSeverity.amber);
      expect(severityForReportReason('Something else'), AdminReportSeverity.amber);
      expect(severityForReportReason('a future reason not seen before'),
          AdminReportSeverity.amber);
    });
  });

  testWidgets('AdminReportCard shows title, detail and calls onResolve when tapped',
      (tester) async {
    var resolved = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AdminReportCard(
          title: 'Made me uncomfortable',
          detail: 'A learner flagged a QuestBot reply.',
          severity: AdminReportSeverity.red,
          onResolve: () => resolved = true,
        ),
      ),
    ));

    expect(find.text('Made me uncomfortable'), findsOneWidget);
    expect(find.text('A learner flagged a QuestBot reply.'), findsOneWidget);

    await tester.tap(find.text('Resolve'));
    await tester.pump();
    expect(resolved, isTrue);
  });

  testWidgets('AdminReportCard border color follows severity', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AdminReportCard(
          title: 'Something else',
          detail: 'Detail text.',
          severity: AdminReportSeverity.amber,
          onResolve: () {},
        ),
      ),
    ));

    final card = tester.widget<Container>(find.byType(Container).first);
    final border = (card.decoration as BoxDecoration).border as Border;
    expect(border.top.color, AdminColors.severityAmber.withOpacity(0.5));
  });
}
