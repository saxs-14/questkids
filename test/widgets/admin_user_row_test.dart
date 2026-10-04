import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/features/dashboard/theme/admin_colors.dart';
import 'package:questkids/features/dashboard/widgets/admin_user_row.dart';

void main() {
  group('adminRoleFromString', () {
    test('maps known roles', () {
      expect(adminRoleFromString('admin'), AdminRole.admin);
      expect(adminRoleFromString('parent'), AdminRole.parent);
      expect(adminRoleFromString('learner'), AdminRole.learner);
    });

    test('falls back to learner for unknown or empty roles', () {
      expect(adminRoleFromString(''), AdminRole.learner);
      expect(adminRoleFromString('something-else'), AdminRole.learner);
    });
  });

  testWidgets('AdminUserRow shows name, email, role badge and trailing widget',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AdminUserRow(
          name: 'Thandeka Mokoena',
          email: 'thandeka@example.com',
          role: AdminRole.parent,
          trailing: const Icon(Icons.more_vert),
        ),
      ),
    ));

    expect(find.text('Thandeka Mokoena'), findsOneWidget);
    expect(find.text('thandeka@example.com'), findsOneWidget);
    expect(find.text('parent'), findsOneWidget);
    expect(find.byIcon(Icons.more_vert), findsOneWidget);
  });

  testWidgets('AdminUserRow badge uses the role-specific accent color',
      (tester) async {
    for (final entry in {
      AdminRole.admin: AdminColors.roleAdmin,
      AdminRole.parent: AdminColors.roleParent,
      AdminRole.learner: AdminColors.roleLearner,
    }.entries) {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AdminUserRow(
            name: 'Test User',
            email: 'test@example.com',
            role: entry.key,
            trailing: const Icon(Icons.more_vert),
          ),
        ),
      ));

      final badge = tester.widget<Container>(
        find
            .ancestor(
              of: find.text(entry.key.name),
              matching: find.byType(Container),
            )
            .first,
      );
      final color = (badge.decoration as BoxDecoration).color;
      expect(color, entry.value.withValues(alpha: 0.18));
    }
  });
}
