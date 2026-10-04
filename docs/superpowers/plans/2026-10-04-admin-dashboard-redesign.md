# Admin Dashboard Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restyle `AdminDashboard` (all 4 tabs) into the dark "Premium Dark" command-center
look approved in `docs/superpowers/specs/2026-10-04-admin-dashboard-redesign-design.md` and
validated in Figma (file `z1g8doKhAyTdO2M5XjRW3V`), with zero change to admin behavior,
data sources, or backend.

**Architecture:** Extract the new look into small, reusable presentational widgets
(`AdminColors` token file + 5 stateless widgets) under `lib/features/dashboard/`, each
unit-testable with plain data and no Firebase. `admin_dashboard.dart` keeps every existing
`AdminService` call, `StreamBuilder`/state method unchanged — only the widgets it returns
from `_overview()`/`_users()`/`_safety()`/`_operations()` change.

**Tech Stack:** Flutter (Material 3, no new packages), `flutter_test` for widget tests.

## Global Constraints

- `flutter analyze` must report 0 errors before any commit (CLAUDE.md §5/§9).
- `flutter test` must pass before any commit (CLAUDE.md §9).
- No changes to `AdminService`, Firestore queries/collections, or `firestore.rules`
  (design spec non-goal).
- No new dependencies in `pubspec.yaml`.
- No AI/Claude attribution anywhere (commit messages use the user's own git identity,
  plain descriptions only — no `Co-Authored-By`, no session links).
- Commit style: `type(scope): summary`, small reviewable commits, `flutter analyze` clean
  before each (CLAUDE.md §8).
- Package name under test is `questkids` (`pubspec.yaml`) — test imports use
  `package:questkids/...`.

---

## File Structure

| File | Responsibility |
|---|---|
| `lib/features/dashboard/theme/admin_colors.dart` | Create. Dark palette tokens (`AdminColors`), scoped to the admin dashboard only. |
| `lib/features/dashboard/widgets/admin_header.dart` | Create. `AdminSectionHeader` (eyebrow/title/subtitle) + `AdminStatusPill`. |
| `lib/features/dashboard/widgets/admin_stat_card.dart` | Create. `AdminStatCard` (icon/value/label glow card). |
| `lib/features/dashboard/widgets/admin_user_row.dart` | Create. `AdminRole` enum, `adminRoleFromString`, `AdminUserRow`. |
| `lib/features/dashboard/widgets/admin_report_card.dart` | Create. `AdminReportSeverity` enum, `severityForReportReason`, `AdminReportCard`. |
| `lib/features/dashboard/widgets/admin_operations_card.dart` | Create. `AdminOperationsCard` (section label + bullet list). |
| `lib/features/dashboard/widgets/admin_search_field.dart` | Create. `AdminSearchField` (dark pill text field used by the Users tab). |
| `lib/features/dashboard/screens/admin_dashboard.dart` | Modify. Wire all of the above into the existing 4 tabs; dark `Scaffold`/`AppBar`/`NavigationBar`; fix a pre-existing Safety-tab field-name bug and add real client-side user search (see Task 8). |
| `test/theme/admin_colors_test.dart` | Create. Sanity-checks the token values against the spec. |
| `test/widgets/admin_header_test.dart` | Create. |
| `test/widgets/admin_stat_card_test.dart` | Create. |
| `test/widgets/admin_user_row_test.dart` | Create. |
| `test/widgets/admin_report_card_test.dart` | Create. |
| `test/widgets/admin_operations_card_test.dart` | Create. |
| `test/widgets/admin_search_field_test.dart` | Create. |

**Spec correction noted here:** the design spec's Users-tab description says the search
bar "wraps the existing search behavior," but `admin_dashboard.dart` has no search/filter
logic at all today — there is nothing to wrap. Task 8 adds real, minimal client-side
filtering (over the already-streamed `docs` list — no new Firestore query, no
`AdminService` change) rather than shipping a decorative search box that does nothing.

---

### Task 1: `AdminColors` dark palette tokens

**Files:**
- Create: `lib/features/dashboard/theme/admin_colors.dart`
- Test: `test/theme/admin_colors_test.dart`

**Interfaces:**
- Produces: `class AdminColors` with static const `Color` fields: `bgPage`, `cardTop`,
  `cardBottom`, `borderGlow`, `textPrimary`, `textAccent`, `textSecondary`, `brandPrimary`,
  `statusOnline`, `severityAmber`, `severityRed`, `roleAdmin`, `roleParent`, `roleLearner`.
  Every later task consumes these exact names.

- [ ] **Step 1: Write the failing test**

```dart
// test/theme/admin_colors_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/features/dashboard/theme/admin_colors.dart';

void main() {
  test('AdminColors tokens match the approved Figma variable collection', () {
    expect(AdminColors.bgPage, const Color(0xFF0F0D18));
    expect(AdminColors.cardTop, const Color(0xFF211C33));
    expect(AdminColors.cardBottom, const Color(0xFF191625));
    expect(AdminColors.borderGlow, const Color(0xFF8C6EFF));
    expect(AdminColors.textPrimary, const Color(0xFFFFFFFF));
    expect(AdminColors.textAccent, const Color(0xFFB7A6FF));
    expect(AdminColors.textSecondary, const Color(0xFF9B93B5));
    expect(AdminColors.brandPrimary, const Color(0xFF5C35F5));
    expect(AdminColors.statusOnline, const Color(0xFF4ADE80));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/theme/admin_colors_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'questkids' in ... admin_colors.dart` (file doesn't exist yet).

- [ ] **Step 3: Write the implementation**

```dart
// lib/features/dashboard/theme/admin_colors.dart
import 'package:flutter/material.dart';

/// Dark "Premium Dark" command-center palette, scoped to the admin
/// dashboard only (does not affect Learner/Parent/Teacher theming).
/// Matches the Figma file "QuestKids Admin Console"
/// (z1g8doKhAyTdO2M5XjRW3V), variable collection "Admin Console Colors".
class AdminColors {
  static const Color bgPage = Color(0xFF0F0D18);
  static const Color cardTop = Color(0xFF211C33);
  static const Color cardBottom = Color(0xFF191625);
  static const Color borderGlow = Color(0xFF8C6EFF);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textAccent = Color(0xFFB7A6FF);
  static const Color textSecondary = Color(0xFF9B93B5);
  static const Color brandPrimary = Color(0xFF5C35F5);
  static const Color statusOnline = Color(0xFF4ADE80);

  // Safety-report severity accents (not in the Figma variable collection —
  // added for the Safety tab's severity-colored cards).
  static const Color severityAmber = Color(0xFFFABF24);
  static const Color severityRed = Color(0xFFF04545);

  // Role badge accents (Users tab) — admin reuses the existing accent
  // purple; parent/learner are new, chosen to stay legible at low opacity
  // on the dark background.
  static const Color roleAdmin = Color(0xFFB7A6FF);
  static const Color roleParent = Color(0xFF60A5FA);
  static const Color roleLearner = Color(0xFF4ADE80);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/theme/admin_colors_test.dart`
Expected: PASS (1 test)

- [ ] **Step 5: Commit**

```bash
git add lib/features/dashboard/theme/admin_colors.dart test/theme/admin_colors_test.dart
git commit -m "feat(admin): add dark command-center color tokens"
```

---

### Task 2: `AdminSectionHeader` and `AdminStatusPill`

**Files:**
- Create: `lib/features/dashboard/widgets/admin_header.dart`
- Test: `test/widgets/admin_header_test.dart`

**Interfaces:**
- Consumes: `AdminColors` (Task 1).
- Produces:
  - `AdminSectionHeader({required String eyebrow, required String title, String? subtitle})`
  - `AdminStatusPill({required String label})`

- [ ] **Step 1: Write the failing test**

```dart
// test/widgets/admin_header_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/features/dashboard/widgets/admin_header.dart';

void main() {
  testWidgets('AdminSectionHeader shows eyebrow, title and optional subtitle',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: AdminSectionHeader(
          eyebrow: 'QUESTKIDS ADMIN',
          title: 'Platform Overview',
          subtitle: 'Manage everything from one console.',
        ),
      ),
    ));

    expect(find.text('QUESTKIDS ADMIN'), findsOneWidget);
    expect(find.text('Platform Overview'), findsOneWidget);
    expect(find.text('Manage everything from one console.'), findsOneWidget);
  });

  testWidgets('AdminSectionHeader renders without a subtitle', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: AdminSectionHeader(eyebrow: 'QUESTKIDS ADMIN', title: 'Users'),
      ),
    ));

    expect(find.text('Users'), findsOneWidget);
  });

  testWidgets('AdminStatusPill shows its label', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: AdminStatusPill(label: 'All systems operational')),
    ));

    expect(find.text('All systems operational'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/admin_header_test.dart`
Expected: FAIL — `admin_header.dart` doesn't exist yet.

- [ ] **Step 3: Write the implementation**

```dart
// lib/features/dashboard/widgets/admin_header.dart
import 'package:flutter/material.dart';

import '../theme/admin_colors.dart';

class AdminSectionHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String? subtitle;

  const AdminSectionHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          eyebrow,
          style: const TextStyle(
            color: AdminColors.textAccent,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: const TextStyle(
            color: AdminColors.textPrimary,
            fontSize: 26,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            style: const TextStyle(color: AdminColors.textSecondary, fontSize: 14),
          ),
        ],
      ],
    );
  }
}

class AdminStatusPill extends StatelessWidget {
  final String label;

  const AdminStatusPill({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AdminColors.statusOnline.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AdminColors.statusOnline.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AdminColors.statusOnline,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: AdminColors.statusOnline,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widgets/admin_header_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/features/dashboard/widgets/admin_header.dart test/widgets/admin_header_test.dart
git commit -m "feat(admin): add dark header and status pill widgets"
```

---

### Task 3: `AdminStatCard`

**Files:**
- Create: `lib/features/dashboard/widgets/admin_stat_card.dart`
- Test: `test/widgets/admin_stat_card_test.dart`

**Interfaces:**
- Consumes: `AdminColors` (Task 1).
- Produces: `AdminStatCard({required IconData icon, required String value, required String label})`

- [ ] **Step 1: Write the failing test**

```dart
// test/widgets/admin_stat_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/features/dashboard/theme/admin_colors.dart';
import 'package:questkids/features/dashboard/widgets/admin_stat_card.dart';

void main() {
  testWidgets('AdminStatCard shows icon, value and label', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: AdminStatCard(icon: Icons.people, value: '82', label: 'Users'),
      ),
    ));

    expect(find.byIcon(Icons.people), findsOneWidget);
    expect(find.text('82'), findsOneWidget);
    expect(find.text('Users'), findsOneWidget);
  });

  testWidgets('AdminStatCard uses the dark gradient container', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: AdminStatCard(icon: Icons.people, value: '82', label: 'Users'),
      ),
    ));

    final container = tester.widget<Container>(find.byType(Container).first);
    final decoration = container.decoration as BoxDecoration;
    final gradient = decoration.gradient as LinearGradient;
    expect(gradient.colors, [AdminColors.cardTop, AdminColors.cardBottom]);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/admin_stat_card_test.dart`
Expected: FAIL — `admin_stat_card.dart` doesn't exist yet.

- [ ] **Step 3: Write the implementation**

```dart
// lib/features/dashboard/widgets/admin_stat_card.dart
import 'package:flutter/material.dart';

import '../theme/admin_colors.dart';

class AdminStatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const AdminStatCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AdminColors.cardTop, AdminColors.cardBottom],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminColors.borderGlow.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AdminColors.textAccent),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: AdminColors.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: AdminColors.textAccent,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widgets/admin_stat_card_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/features/dashboard/widgets/admin_stat_card.dart test/widgets/admin_stat_card_test.dart
git commit -m "feat(admin): add dark stat card widget"
```

---

### Task 4: `AdminRole` + `AdminUserRow`

**Files:**
- Create: `lib/features/dashboard/widgets/admin_user_row.dart`
- Test: `test/widgets/admin_user_row_test.dart`

**Interfaces:**
- Consumes: `AdminColors` (Task 1).
- Produces:
  - `enum AdminRole { admin, parent, learner }`
  - `AdminRole adminRoleFromString(String role)` — maps Firestore `role` field
    (`'admin'`/`'parent'`/anything else → `learner`, matching the existing
    `(data['role'] ?? 'learner')` fallback in `admin_dashboard.dart`).
  - `AdminUserRow({required String name, required String email, required AdminRole role, required Widget trailing})`

- [ ] **Step 1: Write the failing test**

```dart
// test/widgets/admin_user_row_test.dart
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
      expect(color, entry.value.withOpacity(0.18));
    }
  });
}
```

**Note (found during execution):** the first draft of the last test used
`tester.widgetList<Container>(find.byType(Container)).firstWhere((c) => ... color != null)`,
which matched the outer row `Container` (opaque `cardBottom`) instead of the badge — fixed
by locating the `Container` ancestor of the role-label `Text` instead.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/admin_user_row_test.dart`
Expected: FAIL — `admin_user_row.dart` doesn't exist yet.

- [ ] **Step 3: Write the implementation**

```dart
// lib/features/dashboard/widgets/admin_user_row.dart
import 'package:flutter/material.dart';

import '../theme/admin_colors.dart';

enum AdminRole { admin, parent, learner }

AdminRole adminRoleFromString(String role) {
  switch (role) {
    case 'admin':
      return AdminRole.admin;
    case 'parent':
      return AdminRole.parent;
    default:
      return AdminRole.learner;
  }
}

class AdminUserRow extends StatelessWidget {
  final String name;
  final String email;
  final AdminRole role;
  final Widget trailing;

  const AdminUserRow({
    super.key,
    required this.name,
    required this.email,
    required this.role,
    required this.trailing,
  });

  Color get _roleColor {
    switch (role) {
      case AdminRole.admin:
        return AdminColors.roleAdmin;
      case AdminRole.parent:
        return AdminColors.roleParent;
      case AdminRole.learner:
        return AdminColors.roleLearner;
    }
  }

  String get _roleLabel {
    switch (role) {
      case AdminRole.admin:
        return 'admin';
      case AdminRole.parent:
        return 'parent';
      case AdminRole.learner:
        return 'learner';
    }
  }

  @override
  Widget build(BuildContext context) {
    final roleColor = _roleColor;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminColors.cardBottom,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminColors.borderGlow.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AdminColors.brandPrimary,
            child: Text(
              name.isEmpty ? '?' : name[0].toUpperCase(),
              style: const TextStyle(
                color: AdminColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: AdminColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text(
                  email,
                  style: const TextStyle(color: AdminColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: roleColor.withOpacity(0.18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _roleLabel,
              style: TextStyle(color: roleColor, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widgets/admin_user_row_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/features/dashboard/widgets/admin_user_row.dart test/widgets/admin_user_row_test.dart
git commit -m "feat(admin): add role-badged user row widget"
```

---

### Task 5: `AdminReportCard` + reason-based severity

**Files:**
- Create: `lib/features/dashboard/widgets/admin_report_card.dart`
- Test: `test/widgets/admin_report_card_test.dart`

**Context:** `ChatBubble._showReportSheet` (`lib/features/ai_tutor/widgets/chat_bubble.dart:17-22`)
only ever writes one of exactly 4 fixed strings as `reason`: `'Confusing or wrong answer'`,
`'Made me uncomfortable'`, `'Not appropriate for school'`, `'Something else'`. This is a
closed, known vocabulary (not arbitrary free text), so mapping it to a severity tier is a
deterministic, honest classification — not a guess. `'Made me uncomfortable'` and
`'Not appropriate for school'` are safety/content concerns → `red`; the other two are
quality/unclear concerns → `amber` (default for any unrecognized value, so an unexpected
future reason still renders instead of crashing).

**Interfaces:**
- Consumes: `AdminColors` (Task 1).
- Produces:
  - `enum AdminReportSeverity { amber, red }`
  - `AdminReportSeverity severityForReportReason(String reason)`
  - `AdminReportCard({required String title, required String detail, required AdminReportSeverity severity, required VoidCallback onResolve})`

- [ ] **Step 1: Write the failing test**

```dart
// test/widgets/admin_report_card_test.dart
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/admin_report_card_test.dart`
Expected: FAIL — `admin_report_card.dart` doesn't exist yet.

- [ ] **Step 3: Write the implementation**

```dart
// lib/features/dashboard/widgets/admin_report_card.dart
import 'package:flutter/material.dart';

import '../theme/admin_colors.dart';

enum AdminReportSeverity { amber, red }

const _redFlagReasons = {
  'Made me uncomfortable',
  'Not appropriate for school',
};

AdminReportSeverity severityForReportReason(String reason) {
  return _redFlagReasons.contains(reason) ? AdminReportSeverity.red : AdminReportSeverity.amber;
}

class AdminReportCard extends StatelessWidget {
  final String title;
  final String detail;
  final AdminReportSeverity severity;
  final VoidCallback onResolve;

  const AdminReportCard({
    super.key,
    required this.title,
    required this.detail,
    required this.severity,
    required this.onResolve,
  });

  Color get _severityColor =>
      severity == AdminReportSeverity.red ? AdminColors.severityRed : AdminColors.severityAmber;

  @override
  Widget build(BuildContext context) {
    final color = _severityColor;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminColors.cardBottom,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.flag, color: color, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AdminColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: const TextStyle(color: AdminColors.textSecondary, fontSize: 13),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: onResolve,
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminColors.brandPrimary,
              foregroundColor: AdminColors.textPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Resolve', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widgets/admin_report_card_test.dart`
Expected: PASS (5 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/features/dashboard/widgets/admin_report_card.dart test/widgets/admin_report_card_test.dart
git commit -m "feat(admin): add severity-colored safety report card"
```

---

### Task 6: `AdminOperationsCard`

**Files:**
- Create: `lib/features/dashboard/widgets/admin_operations_card.dart`
- Test: `test/widgets/admin_operations_card_test.dart`

**Interfaces:**
- Consumes: `AdminColors` (Task 1).
- Produces: `AdminOperationsCard({required String title, required List<String> items})`

- [ ] **Step 1: Write the failing test**

```dart
// test/widgets/admin_operations_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/features/dashboard/widgets/admin_operations_card.dart';

void main() {
  testWidgets('AdminOperationsCard shows title and every bullet item', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: AdminOperationsCard(
          title: 'Content',
          items: [
            'Manage approved activities and CAPS curriculum reference data.',
            'Keep the game catalogue and learning objectives aligned.',
          ],
        ),
      ),
    ));

    expect(find.text('CONTENT'), findsOneWidget);
    expect(
      find.text('Manage approved activities and CAPS curriculum reference data.'),
      findsOneWidget,
    );
    expect(
      find.text('Keep the game catalogue and learning objectives aligned.'),
      findsOneWidget,
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/admin_operations_card_test.dart`
Expected: FAIL — `admin_operations_card.dart` doesn't exist yet.

- [ ] **Step 3: Write the implementation**

```dart
// lib/features/dashboard/widgets/admin_operations_card.dart
import 'package:flutter/material.dart';

import '../theme/admin_colors.dart';

class AdminOperationsCard extends StatelessWidget {
  final String title;
  final List<String> items;

  const AdminOperationsCard({super.key, required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AdminColors.cardBottom,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: AdminColors.textAccent,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•  ', style: TextStyle(color: AdminColors.textSecondary)),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(color: AdminColors.textSecondary, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widgets/admin_operations_card_test.dart`
Expected: PASS (1 test)

- [ ] **Step 5: Commit**

```bash
git add lib/features/dashboard/widgets/admin_operations_card.dart test/widgets/admin_operations_card_test.dart
git commit -m "feat(admin): add operations readout card widget"
```

---

### Task 7: `AdminSearchField`

**Files:**
- Create: `lib/features/dashboard/widgets/admin_search_field.dart`
- Test: `test/widgets/admin_search_field_test.dart`

**Interfaces:**
- Consumes: `AdminColors` (Task 1).
- Produces: `AdminSearchField({required String hintText, required ValueChanged<String> onChanged})`

- [ ] **Step 1: Write the failing test**

```dart
// test/widgets/admin_search_field_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/features/dashboard/widgets/admin_search_field.dart';

void main() {
  testWidgets('AdminSearchField shows its hint and reports typed text', (tester) async {
    String? typed;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AdminSearchField(
          hintText: 'Search by name, email, or role…',
          onChanged: (value) => typed = value,
        ),
      ),
    ));

    expect(find.text('Search by name, email, or role…'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'thandeka');
    expect(typed, 'thandeka');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/admin_search_field_test.dart`
Expected: FAIL — `admin_search_field.dart` doesn't exist yet.

- [ ] **Step 3: Write the implementation**

```dart
// lib/features/dashboard/widgets/admin_search_field.dart
import 'package:flutter/material.dart';

import '../theme/admin_colors.dart';

class AdminSearchField extends StatelessWidget {
  final String hintText;
  final ValueChanged<String> onChanged;

  const AdminSearchField({super.key, required this.hintText, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AdminColors.cardBottom,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminColors.borderGlow.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: AdminColors.textSecondary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              onChanged: onChanged,
              style: const TextStyle(color: AdminColors.textPrimary),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                hintText: hintText,
                hintStyle: const TextStyle(color: AdminColors.textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widgets/admin_search_field_test.dart`
Expected: PASS (1 test)

- [ ] **Step 5: Commit**

```bash
git add lib/features/dashboard/widgets/admin_search_field.dart test/widgets/admin_search_field_test.dart
git commit -m "feat(admin): add dark search field widget"
```

---

### Task 8: Rebuild `AdminDashboard` with the new widgets

**Files:**
- Modify: `lib/features/dashboard/screens/admin_dashboard.dart` (full-file replacement below)

**Interfaces:**
- Consumes: `AdminColors` (Task 1), `AdminSectionHeader`/`AdminStatusPill` (Task 2),
  `AdminStatCard` (Task 3), `AdminRole`/`adminRoleFromString`/`AdminUserRow` (Task 4),
  `AdminReportSeverity`/`severityForReportReason`/`AdminReportCard` (Task 5),
  `AdminOperationsCard` (Task 6), `AdminSearchField` (Task 7). `AdminService` (unchanged)
  and `AuthProvider` (unchanged, still gates on `user.role == 'admin'`).

**Behavioral changes intentionally included (both justified by, and limited to, this
redesign pass):**
1. The AppBar's light/dark `ThemeProvider` toggle is removed. The design spec's approved
   direction is "a dedicated dark ops-console theme" for the whole admin surface — the
   admin console no longer follows the user theme toggle, it is always dark. This also
   removes the now-unused `ThemeProvider` import.
2. Safety-tab bug fix: the old code read `data['message'] ?? data['details']` for the
   report body, but `FirestoreService.reportAiMessage`
   (`lib/core/services/firestore_service.dart:36-43`) actually writes the field as
   `messageText`. Every real AI report was therefore rendering "No details provided" in
   production. Fixed to read `messageText` first (old field names kept as fallbacks in
   case of other writers). This is a one-line correctness fix directly inside the Safety
   tab this task rebuilds, not a separate initiative.
3. Users-tab search is now real: a `_userSearchQuery` field filters the already-streamed
   `docs` list client-side (case-insensitive substring match on name, email, and role) —
   no new Firestore query, no `AdminService` change. This replaces what the spec
   mis-described as "wrapping existing search behavior" (none existed) with minimal real
   functionality matching the Figma search bar's implied purpose.

- [ ] **Step 1: Replace the file contents**

Replace the entire contents of `lib/features/dashboard/screens/admin_dashboard.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/services/admin_service.dart';
import '../../../providers/auth_provider.dart';
import '../theme/admin_colors.dart';
import '../widgets/admin_header.dart';
import '../widgets/admin_stat_card.dart';
import '../widgets/admin_user_row.dart';
import '../widgets/admin_report_card.dart';
import '../widgets/admin_operations_card.dart';
import '../widgets/admin_search_field.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final _service = AdminService();
  int _tab = 0;
  Map<String, int> _counts = {};
  bool _loadingCounts = true;
  String _userSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    try {
      final counts = await _service.getOverviewCounts();
      if (mounted) {
        setState(() {
          _counts = counts;
          _loadingCounts = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingCounts = false);
    }
  }

  Future<void> _changeRole(String uid, String role) async {
    try {
      await _service.setUserRole(uid: uid, role: role);
      await _loadCounts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User role updated.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Role update failed: $e')),
        );
      }
    }
  }

  Future<void> _toggleDisabled(String uid, bool disabled) async {
    try {
      await _service.setUserDisabled(uid: uid, disabled: disabled);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(disabled ? 'Account disabled.' : 'Account enabled.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Account update failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    if (user == null || user.role != 'admin') {
      return const SizedBox.shrink();
    }

    final pages = [_overview(), _users(), _safety(), _operations()];

    return Scaffold(
      backgroundColor: AdminColors.bgPage,
      appBar: AppBar(
        backgroundColor: AdminColors.bgPage,
        elevation: 0,
        foregroundColor: AdminColors.textPrimary,
        title: const Text('QuestKids Admin'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCounts,
          ),
        ],
      ),
      body: pages[_tab],
      bottomNavigationBar: NavigationBar(
        backgroundColor: AdminColors.cardBottom,
        indicatorColor: AdminColors.brandPrimary.withOpacity(0.3),
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined, color: AdminColors.textSecondary),
            selectedIcon: Icon(Icons.dashboard, color: AdminColors.textPrimary),
            label: 'Overview',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline, color: AdminColors.textSecondary),
            selectedIcon: Icon(Icons.people, color: AdminColors.textPrimary),
            label: 'Users',
          ),
          NavigationDestination(
            icon: Icon(Icons.shield_outlined, color: AdminColors.textSecondary),
            selectedIcon: Icon(Icons.shield, color: AdminColors.textPrimary),
            label: 'Safety',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined, color: AdminColors.textSecondary),
            selectedIcon: Icon(Icons.settings, color: AdminColors.textPrimary),
            label: 'Operations',
          ),
        ],
      ),
    );
  }

  Widget _overview() {
    if (_loadingCounts) {
      return const Center(
        child: CircularProgressIndicator(color: AdminColors.brandPrimary),
      );
    }

    final cards = [
      ['Users', _counts['users'] ?? 0, Icons.people],
      ['Parents', _counts['parents'] ?? 0, Icons.family_restroom],
      ['Children', _counts['children'] ?? 0, Icons.child_care],
      ['Admins', _counts['admins'] ?? 0, Icons.admin_panel_settings],
      ['Activities', _counts['activities'] ?? 0, Icons.menu_book],
      ['AI Reports', _counts['reports'] ?? 0, Icons.flag],
    ];

    return RefreshIndicator(
      onRefresh: _loadCounts,
      color: AdminColors.brandPrimary,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Expanded(
                child: AdminSectionHeader(
                  eyebrow: 'QUESTKIDS ADMIN',
                  title: 'Platform Overview',
                  subtitle:
                      'Manage QuestKids users, curriculum, child safety and platform operations from one protected console.',
                ),
              ),
              SizedBox(width: 12),
              AdminStatusPill(label: 'All systems operational'),
            ],
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cards.length,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 220,
              mainAxisExtent: 120,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemBuilder: (_, index) {
              final card = cards[index];
              return AdminStatCard(
                icon: card[2] as IconData,
                value: (card[1] as int).toString(),
                label: card[0] as String,
              );
            },
          ),
          const SizedBox(height: 20),
          AdminOperationsCard(
            title: 'Admin responsibilities',
            items: const [
              'User and account administration',
              'Parent-child relationship oversight',
              'Approved learning-content management',
              'Questy and AI safety review',
              'Missions, rewards and leaderboard operations',
              'System health and configuration monitoring',
            ],
          ),
        ],
      ),
    );
  }

  Widget _users() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _service.watchUsers(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Unable to load users: ${snapshot.error}',
              style: const TextStyle(color: AdminColors.textSecondary),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: AdminColors.brandPrimary),
          );
        }

        final query = _userSearchQuery.trim().toLowerCase();
        final docs = snapshot.data!.docs.where((doc) {
          if (query.isEmpty) return true;
          final data = doc.data();
          final name = (data['name'] ?? '').toString().toLowerCase();
          final email = (data['email'] ?? '').toString().toLowerCase();
          final role = (data['role'] ?? 'learner').toString().toLowerCase();
          return name.contains(query) || email.contains(query) || role.contains(query);
        }).toList();

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const AdminSectionHeader(
              eyebrow: 'QUESTKIDS ADMIN',
              title: 'User Management',
              subtitle:
                  'Role changes and account disabling are performed through protected server-side operations.',
            ),
            const SizedBox(height: 20),
            AdminSearchField(
              hintText: 'Search by name, email, or role…',
              onChanged: (value) => setState(() => _userSearchQuery = value),
            ),
            const SizedBox(height: 16),
            if (docs.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AdminColors.cardBottom,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  query.isEmpty ? 'No users found.' : 'No users match your search.',
                  style: const TextStyle(color: AdminColors.textSecondary),
                ),
              ),
            ...docs.map((doc) {
              final data = doc.data();
              final role = (data['role'] ?? 'learner').toString();
              final name = (data['name'] ?? data['email'] ?? 'Unknown user').toString();
              final email = (data['email'] ?? '').toString();

              return AdminUserRow(
                name: name,
                email: email,
                role: adminRoleFromString(role),
                trailing: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: AdminColors.textSecondary),
                  onSelected: (value) async {
                    if (value == 'disable') {
                      await _toggleDisabled(doc.id, true);
                    } else if (value == 'enable') {
                      await _toggleDisabled(doc.id, false);
                    } else {
                      await _changeRole(doc.id, value);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'learner', child: Text('Make Child')),
                    PopupMenuItem(value: 'parent', child: Text('Make Parent')),
                    PopupMenuItem(value: 'admin', child: Text('Make Admin')),
                    PopupMenuDivider(),
                    PopupMenuItem(value: 'disable', child: Text('Disable Account')),
                    PopupMenuItem(value: 'enable', child: Text('Enable Account')),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _safety() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _service.watchAiReports(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Unable to load AI reports: ${snapshot.error}',
              style: const TextStyle(color: AdminColors.textSecondary),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: AdminColors.brandPrimary),
          );
        }

        final docs = snapshot.data!.docs;

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const AdminSectionHeader(
              eyebrow: 'QUESTKIDS ADMIN',
              title: 'Child Safety & AI Review',
              subtitle: 'Review Questy reports submitted by children or parents.',
            ),
            const SizedBox(height: 20),
            if (docs.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AdminColors.cardBottom,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'No AI reports have been submitted.',
                  style: TextStyle(color: AdminColors.textSecondary),
                ),
              ),
            ...docs.map((doc) {
              final data = doc.data();
              final reason = (data['reason'] ?? data['category'] ?? 'AI report').toString();
              final detail = (data['messageText'] ??
                      data['message'] ??
                      data['details'] ??
                      'No details provided')
                  .toString();

              return AdminReportCard(
                title: reason,
                detail: detail,
                severity: severityForReportReason(reason),
                onResolve: () => _service.resolveAiReport(
                  reportId: doc.id,
                  status: 'resolved',
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _operations() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const AdminSectionHeader(
          eyebrow: 'QUESTKIDS ADMIN',
          title: 'Platform Operations',
          subtitle:
              'System status readouts — operational controls are not yet wired to live data.',
        ),
        const SizedBox(height: 20),
        AdminOperationsCard(
          title: 'Content',
          items: const [
            'Manage approved activities and CAPS curriculum reference data.',
            'Keep the game catalogue and learning objectives aligned.',
          ],
        ),
        AdminOperationsCard(
          title: 'Gamification',
          items: const [
            'Monitor daily missions, rewards and leaderboard refreshes.',
            'Investigate abnormal progress or reward activity.',
          ],
        ),
        AdminOperationsCard(
          title: 'Security',
          items: const [
            'Admin access is claim-based, not controlled by a client role field.',
            'Use the bootstrap script only for the first admin.',
          ],
        ),
        AdminOperationsCard(
          title: 'System health',
          items: const [
            'Use Firebase logs, Crashlytics and deployment checks for operational monitoring.',
          ],
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Run static analysis**

Run: `flutter analyze lib/features/dashboard/screens/admin_dashboard.dart lib/features/dashboard/theme/admin_colors.dart lib/features/dashboard/widgets/`
Expected: `No issues found!`

- [ ] **Step 3: Run the full test suite**

Run: `flutter test`
Expected: PASS — every pre-existing test plus the 7 new files from Tasks 1–7 (16 new
tests total: 1 colors + 3 header + 2 stat card + 4 user row + 5 report card + 1 operations
card + 1 search field).

- [ ] **Step 4: Manual smoke check (Definition of Done item 3, CLAUDE.md §9)**

Run: `flutter run -d chrome`
Steps:
1. Log in as an existing admin account (or run `questyChat`'s bootstrap flow if none
   exists locally — do not create a new one for this check if an admin account is
   already available).
2. Confirm the dashboard loads with the dark background, no red error screen.
3. Tap through all 4 `NavigationBar` destinations (Overview, Users, Safety, Operations)
   and confirm each renders without exceptions in the console.
4. On Users, type a known user's name (or a fragment of their email/role) into the search
   field and confirm the list actually narrows; clear it and confirm the full list returns.
5. On Users, open the `PopupMenuButton` on any row and confirm the menu still opens
   (do not need to actually change a role to verify this — opening the menu confirms the
   trailing widget wiring is intact).
6. Stop the run (`q` in the terminal, or close the Chrome tab) once confirmed — this is a
   manual verification step, not a persistent dev server.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dashboard/screens/admin_dashboard.dart
git commit -m "feat(admin): restyle dashboard tabs in dark command-center theme"
```

---

## Note (found during execution, Task 8)

`flutter analyze` on the finished Task 8 file surfaced 16 info-level issues not caught by
any single task's own analyze step: every `.withOpacity(x)` call across Tasks 2, 3, 4, 5,
7, and 8's own file is deprecated in the installed Flutter SDK (`deprecated_member_use` —
"Use .withValues() to avoid precision loss"), and grepping the rest of `lib/` confirmed
the codebase has zero other `withOpacity` usages — this was a new inconsistency, not a
pre-existing pattern. Fixed by replacing every `color.withOpacity(x)` with
`color.withValues(alpha: x)` in all 6 widget files plus `admin_dashboard.dart`, and
updating the two test files (`admin_user_row_test.dart`, `admin_report_card_test.dart`)
that compared against a `withOpacity(x)`-derived expected `Color` to use
`withValues(alpha: x)` too — `withOpacity` and `withValues` are not guaranteed to produce
bit-identical `Color` values (the deprecation itself is about `withOpacity`'s 8-bit
precision loss), so implementation and test expectations had to use the same call.
Six `prefer_const_constructors`/`prefer_const_literals_to_create_immutables` infos in
`admin_dashboard.dart` were also fixed by adding `const` where every child was already a
compile-time constant. Shipped as two follow-up commits (`2b360fd` the deprecation fix
across all affected files, `e1ee783` the dashboard rebuild itself) rather than rewriting
Tasks 2–7's already-merged commits, per the "always create new commits" rule. Both
commits are covered by Task 8 Steps 2–3's analyze/test verification, which passed clean
(0 analyze issues, 396/396 tests) after the fix.

## Definition of Done (full plan)

1. `flutter analyze` → 0 errors (CLAUDE.md §9.1).
2. `flutter test` → all green, including the 6 new test files (CLAUDE.md §9.2).
3. `flutter run -d chrome` smoke check passed per Task 8 Step 4 (CLAUDE.md §9.3).
4. `git status` reviewed — no new files match the forbidden-secrets patterns (CLAUDE.md §9.4).
5. Catalog invariants (CLAUDE.md §4) — not applicable, `game_catalog.dart` untouched.
6. Firestore rules emulator validation — not applicable, no rules changed.
7. No commit in this plan contains AI/Claude attribution.
