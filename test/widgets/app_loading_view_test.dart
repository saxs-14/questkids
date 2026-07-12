import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/core/widgets/app_loading_view.dart';

void main() {
  testWidgets('AppLoadingView shows spinner and optional message', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: AppLoadingView(message: 'Loading your quests...')),
    ));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Loading your quests...'), findsOneWidget);
  });
}
