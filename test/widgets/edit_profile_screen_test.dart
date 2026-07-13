import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/features/profile/screens/edit_profile_screen.dart';

void main() {
  testWidgets('EditProfileScreen shows editable name and surname fields', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: EditProfileScreen(
        initialName: 'Jane',
        initialSurname: 'Doe',
        initialGrade: 'Grade 4',
        initialLanguage: 'English',
      ),
    ));

    expect(find.widgetWithText(TextFormField, 'Jane'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Doe'), findsOneWidget);
    expect(find.text('Save Changes'), findsOneWidget);
  });
}
