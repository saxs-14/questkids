import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/data/models/user_model.dart';
import 'package:questkids/features/parent/screens/parent_access_screen.dart';

import '../helpers/fake_firebase_functions.dart';

UserModel _childFixture() => UserModel(
      uid: 'child-1',
      name: 'Testy',
      email: '',
      role: 'learner',
      grade: 'Grade 1',
      createdAt: DateTime(2026, 1, 1),
    );

Map<String, dynamic> _secondaryParent({
  bool viewProgress = true,
  bool viewReports = true,
  bool verifyProgress = false,
  bool viewMood = true,
  bool manageCalendar = false,
}) => {
      'uid': 'parent-2',
      'name': 'Secondary',
      'surname': 'Parent',
      'email': 'secondary@example.com',
      'permissions': {
        'viewProgress': viewProgress,
        'viewReports': viewReports,
        'verifyProgress': verifyProgress,
        'viewMood': viewMood,
        'manageCalendar': manageCalendar,
      },
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  late FakeFirebaseFunctionsPlatform fakeFunctions;

  setUpAll(() async {
    await Firebase.initializeApp();
    // Created once for the whole file, not per test: FirebaseFunctions
    // .instanceFor() has its own internal static cache keyed by
    // (app, region) and only calls FirebaseFunctionsPlatform.instance
    // .delegateFor() the first time a given key is requested -- every
    // later call, in any later test, returns that same cached wrapper
    // regardless of what FirebaseFunctionsPlatform.instance is reassigned
    // to. Reassigning the fake platform per test silently did nothing
    // from the second test onward; clearing this single fake's state
    // between tests (see setUp below) is what actually isolates them.
    fakeFunctions = setupFakeFirebaseFunctions();
  });

  setUp(() {
    fakeFunctions.callHandlers.clear();
    fakeFunctions.calls.clear();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(home: ParentAccessScreen(children: [_childFixture()])),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('loads and renders the linked secondary parent with their current permissions',
      (tester) async {
    fakeFunctions.callHandlers['getParentAccess'] = (_) async => {
          'parents': [_secondaryParent()],
        };

    await pumpScreen(tester);

    expect(find.text('Secondary Parent'), findsOneWidget);
    expect(find.text('No secondary parents are linked to this child yet.'), findsNothing);
    expect(find.text('Unsaved changes'), findsNothing);
    expect(find.text('Save Changes'), findsNothing);
  });

  testWidgets('shows the empty state when no secondary parents are linked', (tester) async {
    fakeFunctions.callHandlers['getParentAccess'] = (_) async => {'parents': []};

    await pumpScreen(tester);

    expect(find.text('No secondary parents are linked to this child yet.'), findsOneWidget);
  });

  testWidgets('toggling a switch stages a pending change without calling the network',
      (tester) async {
    fakeFunctions.callHandlers['getParentAccess'] = (_) async => {
          'parents': [_secondaryParent(verifyProgress: false)],
        };

    await pumpScreen(tester);

    await tester.tap(find.widgetWithText(SwitchListTile, 'Verify progress'));
    await tester.pumpAndSettle();

    expect(find.text('Unsaved changes'), findsOneWidget);
    expect(find.text('Save Changes'), findsOneWidget);
    expect(find.text('Discard'), findsOneWidget);
    // Flipping a switch must never call setParentPermissions by itself --
    // that's the entire point of the batched-save redesign this screen
    // got this session (one OTP prompt per Save, not per toggle).
    expect(fakeFunctions.calls.where((c) => c.$1 == 'setParentPermissions'), isEmpty);
  });

  testWidgets('Discard reverts a pending change back to the last-saved value', (tester) async {
    fakeFunctions.callHandlers['getParentAccess'] = (_) async => {
          'parents': [_secondaryParent(verifyProgress: false)],
        };

    await pumpScreen(tester);

    await tester.ensureVisible(find.widgetWithText(SwitchListTile, 'Verify progress'));
    await tester.tap(find.widgetWithText(SwitchListTile, 'Verify progress'));
    await tester.pumpAndSettle();
    expect(find.text('Unsaved changes'), findsOneWidget);

    await tester.ensureVisible(find.text('Discard'));
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();

    expect(find.text('Unsaved changes'), findsNothing);
    final switchTile = tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, 'Verify progress'),
    );
    expect(switchTile.value, false);
  });

  testWidgets(
      'Save Changes requests an OTP, submits the full pending permissions once verified, '
      'and clears the unsaved-changes indicator', (tester) async {
    fakeFunctions.callHandlers['getParentAccess'] = (_) async => {
          'parents': [_secondaryParent(verifyProgress: false)],
        };
    fakeFunctions.callHandlers['requestActionOtp'] = (_) async => {
          'sent': true,
          'expiresInSeconds': 300,
        };
    fakeFunctions.callHandlers['setParentPermissions'] = (_) async => {
          'updated': true,
          'permissions': {'verifyProgress': true},
        };

    await pumpScreen(tester);

    await tester.ensureVisible(find.widgetWithText(SwitchListTile, 'Verify progress'));
    await tester.tap(find.widgetWithText(SwitchListTile, 'Verify progress'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save Changes'));
    await tester.tap(find.text('Save Changes'));
    // Not pumpAndSettle(): the dialog's resend-cooldown starts a 60s timer
    // that reschedules itself every second, so "settle until nothing is
    // pending" never terminates and pumpAndSettle times out. A couple of
    // bounded pumps is enough to flush the fake's instantly-resolving
    // requestActionOtp Future and the resulting rebuild.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // The OTP dialog requests a code as soon as it opens.
    expect(
      fakeFunctions.calls.where(
        (c) => c.$1 == 'requestActionOtp' && (c.$2 as Map)['action'] == 'setParentPermissions',
      ),
      hasLength(1),
    );

    await tester.enterText(find.byType(TextField), '123456');
    await tester.tap(find.text('Verify'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final setCalls =
        fakeFunctions.calls.where((c) => c.$1 == 'setParentPermissions').toList();
    expect(setCalls, hasLength(1));
    final payload = setCalls.single.$2 as Map;
    expect(payload['childUid'], 'child-1');
    expect(payload['parentUid'], 'parent-2');
    expect(payload['otpCode'], '123456');
    expect((payload['permissions'] as Map)['verifyProgress'], true);

    // Dialog closed and the save succeeded -- no more "unsaved" indicator.
    expect(find.text('Unsaved changes'), findsNothing);
    expect(find.text('Access changes saved.'), findsOneWidget);

    // Drain the dialog's 60s resend-cooldown timer chain before the test
    // ends -- the test framework hard-fails on any timer still pending at
    // teardown, even one whose owning widget was already disposed.
    await tester.pump(const Duration(seconds: 61));
  });

  testWidgets('an incorrect OTP code shows an inline error without closing the dialog',
      (tester) async {
    fakeFunctions.callHandlers['getParentAccess'] = (_) async => {
          'parents': [_secondaryParent(verifyProgress: false)],
        };
    fakeFunctions.callHandlers['requestActionOtp'] = (_) async => {'sent': true};
    fakeFunctions.callHandlers['setParentPermissions'] = (_) async {
      throw Exception('permission-denied: Incorrect verification code.');
    };

    await pumpScreen(tester);
    await tester.ensureVisible(find.widgetWithText(SwitchListTile, 'Verify progress'));
    await tester.tap(find.widgetWithText(SwitchListTile, 'Verify progress'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save Changes'));
    await tester.tap(find.text('Save Changes'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.enterText(find.byType(TextField), '000000');
    await tester.tap(find.text('Verify'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Dialog stays open (still showing the code field, not re-requesting a
    // fresh code) and the pending change is still unsaved.
    expect(find.text('Something went wrong. Please try again.'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    // Drain the dialog's 60s resend-cooldown timer chain before the test
    // ends -- the test framework hard-fails on any timer still pending at
    // teardown.
    await tester.pump(const Duration(seconds: 61));
  });
}
