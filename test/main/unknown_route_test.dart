import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/core/widgets/app_error_view.dart';

void main() {
  testWidgets('onUnknownRoute shows AppErrorView with a Go Home action',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: const Scaffold(body: Text('Home')),
      routes: {
        '/login': (_) => const Scaffold(body: Text('Login')),
      },
      onUnknownRoute: (settings) => MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Page Not Found')),
          body: AppErrorView(
            message: "We couldn't find that page.",
            onRetry: () => Navigator.pushNamedAndRemoveUntil(
                context, '/login', (route) => false),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Simulate hitting a bad/stale deep link mid-session.
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pushNamed('/this-route-does-not-exist');
    await tester.pumpAndSettle();

    expect(find.text('Page Not Found'), findsOneWidget);
    expect(find.byType(AppErrorView), findsOneWidget);

    await tester.tap(find.text('Try Again'));
    await tester.pumpAndSettle();
    expect(find.text('Login'), findsOneWidget);
  });
}
