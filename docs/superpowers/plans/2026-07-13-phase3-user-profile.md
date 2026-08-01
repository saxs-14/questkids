# Phase 3 — User Profile Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the profile experience match the Phase 3 spec (profile picture, grade, XP, level, achievements, parent connection, settings, account management, editable personal information) for all three roles, and clean up the fragmentation discovered during investigation: there are **three independent, duplicated profile-tab implementations** (one per role dashboard) plus a **fourth, fully dead/unreachable** standalone `ProfileScreen` that Phase 1 mistakenly enhanced.

**Architecture:** No new screens-per-role architecture change — each dashboard (`learner_dashboard.dart`, `parent_dashboard.dart`, `teacher_dashboard.dart`) keeps its own private `_ProfileTab`/`_ParentProfileTab` widget, since the three roles genuinely need different content. This phase (1) deletes the dead code, (2) extracts the duplicated "Settings entry + confirmed sign-out" pattern into one shared widget reused by all three tabs, (3) adds the missing spec items (Level, Achievements, Parent connection) to the learner and parent tabs using data/widgets that already exist but aren't wired in, and (4) adds one shared, reusable Edit Profile screen for account management.

**Tech Stack:** Flutter (Dart ≥3.4), Provider, existing `AppDialog`/`AppButton`/`AppLoadingView` design-system widgets from Phase 1, existing `ChildQrCode` (qr_flutter) and `ChildCard` widgets that are already fully functional but currently unreachable/underused.

## Global Constraints

- `flutter analyze` → 0 new errors before any commit.
- `flutter test` → all tests green, including new tests this plan adds.
- `flutter build web --release` and `flutter build apk --debug` must both succeed before declaring the phase done (per the Phase 1 lesson — `flutter test` alone doesn't catch real compile issues).
- Do not touch `firestore.rules`'s locked-fields list (`role`, `xp`, `coins`, `level`, `linkedChildrenUids` must stay client-write-blocked) — the Edit Profile screen must only ever call `UserRepository.updateUser` with editable fields (name, surname, grade, gender, preferredLanguage), never those locked ones.
- Preserve existing avatar upload logic (`ProfileAvatarPicker`, `StorageService.uploadAvatar`) exactly — do not modify it, only reuse it.
- Commit style: `type(scope): summary`. Small, reviewable commits; run `flutter analyze` before each.

---

## File Structure

New files:
```
lib/core/widgets/profile_settings_tile.dart   # Task 1
lib/features/profile/screens/edit_profile_screen.dart   # Task 7
test/widgets/profile_settings_tile_test.dart  # Task 1
test/widgets/edit_profile_screen_test.dart    # Task 7
```

Deleted files: `lib/features/profile/screens/profile_screen.dart` (Task 2 — confirmed zero imports anywhere in `lib/`).

Files modified: `lib/features/dashboard/screens/{learner_dashboard,parent_dashboard,teacher_dashboard}.dart`, `lib/main.dart`.

---

### Task 1: Shared `ProfileSettingsTile` widget (Settings entry + confirmed sign-out)

**Why:** Only the learner profile tab has a Settings entry point and a confirmed sign-out (both added in Phase 1). The parent and teacher tabs still have a bare `onPressed: () => auth.signOut()` with zero confirmation — the exact bug Phase 1 fixed for learners, just never applied to the other two roles because Phase 1 only touched `learner_dashboard.dart`.

**Files:**
- Create: `lib/core/widgets/profile_settings_tile.dart`
- Test: `test/widgets/profile_settings_tile_test.dart`

**Interfaces:**
- Produces: `class ProfileSettingsTile extends StatelessWidget` — a self-contained `Column` with a "Settings" `ListTile` (navigates to `/settings`) and a "Sign Out" `AppButton` (danger variant, confirmed via `AppDialog.confirm`, then `AuthProvider.signOut()` + `Navigator.pushNamedAndRemoveUntil(context, '/login', ...)`). No constructor params needed — it reads `AuthProvider` via `context.read` internally, matching the existing call-site pattern in all three dashboards.

- [ ] **Step 1: Write the failing test**

```dart
// test/widgets/profile_settings_tile_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:questkids/core/widgets/profile_settings_tile.dart';
import 'package:questkids/providers/auth_provider.dart';

void main() {
  testWidgets('ProfileSettingsTile shows Settings and Sign Out, confirms before signing out', (tester) async {
    final auth = AuthProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp(
          routes: {'/settings': (_) => const Scaffold(body: Text('Settings Page'))},
          home: const Scaffold(body: ProfileSettingsTile()),
        ),
      ),
    );

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Sign Out'), findsOneWidget);

    await tester.tap(find.text('Sign Out'));
    await tester.pumpAndSettle();

    // A confirmation dialog must appear before any sign-out happens.
    expect(find.text('Are you sure you want to sign out?'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/profile_settings_tile_test.dart`
Expected: FAIL — `ProfileSettingsTile` doesn't exist.

- [ ] **Step 3: Implement `ProfileSettingsTile`**

```dart
// lib/core/widgets/profile_settings_tile.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../../providers/auth_provider.dart';
import 'app_button.dart';
import 'app_dialog.dart';

/// Settings entry + confirmed sign-out, shared by all three role profile
/// tabs (learner/parent/teacher) instead of each dashboard re-implementing
/// its own (previously inconsistent) version.
class ProfileSettingsTile extends StatelessWidget {
  const ProfileSettingsTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.settings_outlined, color: AppColors.primary),
          title: Text('Settings', style: AppTextStyles.bodyMedium),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.pushNamed(context, '/settings'),
        ),
        const SizedBox(height: 12),
        AppButton(
          label: 'Sign Out',
          icon: Icons.logout,
          variant: AppButtonVariant.danger,
          onPressed: () async {
            final confirmed = await AppDialog.confirm(
              context,
              title: 'Sign Out',
              message: 'Are you sure you want to sign out?',
              confirmLabel: 'Sign Out',
              isDanger: true,
            );
            if (confirmed && context.mounted) {
              await context.read<AuthProvider>().signOut();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
              }
            }
          },
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widgets/profile_settings_tile_test.dart`
Expected: PASS

- [ ] **Step 5: `flutter analyze` clean, then commit**

```bash
flutter analyze lib/core/widgets/profile_settings_tile.dart
git add lib/core/widgets/profile_settings_tile.dart test/widgets/profile_settings_tile_test.dart
git commit -m "feat(profile): add shared ProfileSettingsTile (settings entry + confirmed sign-out)"
```

---

### Task 2: Delete the dead `profile_screen.dart`

**Why:** Confirmed via `grep -rn "profile_screen.dart" lib/` that zero files import it. It is unreachable — no route, no `Navigator.push` call, nothing. Phase 1 spent effort adding a Settings entry and sign-out confirmation to this file, which was wasted since no user can ever see it. Per the project's own rule ("if you are certain something is unused, delete it completely"), remove it rather than leave dead code.

**Files:**
- Delete: `lib/features/profile/screens/profile_screen.dart`

- [ ] **Step 1: Re-confirm zero references immediately before deleting**

Run: `grep -rn "profile_screen.dart\|import.*ProfileScreen" lib/ test/` — expect no output (re-verify since other tasks in this plan touch nearby files and could theoretically add a reference).

- [ ] **Step 2: Delete the file**

```bash
git rm lib/features/profile/screens/profile_screen.dart
```

- [ ] **Step 3: Verify the app still compiles with it gone**

Run: `flutter analyze` (full project) — expect the same error/warning count as before this task (0 new errors), confirming nothing referenced the deleted file.

- [ ] **Step 4: Commit**

```bash
git commit -m "chore(profile): remove dead, unreachable ProfileScreen (zero imports anywhere)"
```

---

### Task 3: Level + Achievements gallery on the learner profile tab

**Why:** `RewardModel.level` and `RewardsProvider.badges` already exist and are already used elsewhere (dashboard home tab, rewards screen) but the learner's own Profile tab currently shows Total Points, Streak, Grade, Member Since — no explicit Level, no badge list. Phase 3 explicitly asks for both.

**Files:**
- Modify: `lib/features/dashboard/screens/learner_dashboard.dart` (read first — locate `_ProfileTabState.build()`'s `_ProfileStatRow` list, added in earlier phases)

**Interfaces:**
- Consumes: `RewardsProvider` (already imported in this file), `RewardsService.getLevelTitle`/`getLevelEmoji` (existing, unchanged), `BadgeModel` (existing).

- [ ] **Step 1: Read the current `_ProfileTab`/`_ProfileTabState` build method in full** to find the exact `_ProfileStatRow` list and confirm current field names.

- [ ] **Step 2: Add a Level stat row**

Add a `_ProfileStatRow` for Level (using `context.watch<RewardsProvider>().level` and `RewardsService.getLevelTitle(level)`/`getLevelEmoji(level)`) alongside the existing Total Points/Streak/Grade/Member Since rows, in the same `Column` of `_ProfileStatRow`s.

- [ ] **Step 3: Add a badge gallery section below the stats card**

Add a new section (`Text('🏅 Achievements', style: AppTextStyles.h4)` header + a `Wrap` of small badge chips, each showing `badge.icon` + `badge.name`, reading `context.watch<RewardsProvider>().badges`) below the existing stats `Container`. If `badges.isEmpty`, show `AppEmptyState(emoji: '🏅', title: 'No badges yet', message: 'Complete quests to start earning badges!')` (Phase 1 widget, already imported project-wide — add the import to this file if not already present).

- [ ] **Step 4: Manual verification**

Run: `flutter run -d chrome`. Log in as a learner with at least one badge (or check the empty state renders correctly for a fresh account) — confirm Level and the badge gallery both appear in the Profile tab.

- [ ] **Step 5: `flutter analyze` clean, then commit**

```bash
flutter analyze lib/features/dashboard/screens/learner_dashboard.dart
git add lib/features/dashboard/screens/learner_dashboard.dart
git commit -m "feat(profile): show Level and an achievements gallery on the learner profile tab"
```

---

### Task 4: Surface the learner's link code (QR) for parent connection

**Why:** Every learner account already has a `childLinkCode` assigned at registration (`auth_service.dart`'s `registerParentWithChild`), and a fully functional `ChildQrCode` widget already exists (`lib/features/parent/widgets/child_qr_code.dart` — renders the QR + a working Share button) — but it is never imported or shown anywhere. This is exactly the "Parent connection" spec item, and it's a wire-up fix, not new functionality (Rule 5 — no placeholders; this is genuinely already built).

**Files:**
- Modify: `lib/features/dashboard/screens/learner_dashboard.dart` (same `_ProfileTab`, add below the achievements section from Task 3)

**Interfaces:**
- Consumes: `ChildQrCode(code: user.childLinkCode!, size: ...)` (existing, unchanged).

- [ ] **Step 1: Add a "My Parent Link Code" card**

Below the achievements section, if `user?.childLinkCode != null`, add a card: header `Text('👨‍👩‍👧 Parent Connection', style: AppTextStyles.h4)`, subtitle explaining "Ask your parent to scan this code or enter it in their app to connect", then `ChildQrCode(code: user.childLinkCode!)`. If `user.linkedParentUids.isNotEmpty`, additionally show `Text('✅ Linked to ${user.linkedParentUids.length} parent(s)')`; otherwise `Text('Not linked to a parent yet')`.

Add the import `import '../../parent/widgets/child_qr_code.dart';`.

- [ ] **Step 2: Manual verification**

Run: `flutter run -d chrome`. As a learner, open the Profile tab — confirm the QR code renders (a scannable pattern, not a broken image) and the share button works (opens the OS share sheet or equivalent in the browser).

- [ ] **Step 3: `flutter analyze` clean, then commit**

```bash
flutter analyze lib/features/dashboard/screens/learner_dashboard.dart
git add lib/features/dashboard/screens/learner_dashboard.dart
git commit -m "feat(profile): surface the learner's parent-link QR code (previously built but unreachable)"
```

---

### Task 5: Real linked-children list on the parent profile tab

**Why:** `_ParentProfileTab` currently shows only a child *count* (`'${user?.linkedChildrenUids?.length ?? 0}'`) in a plain info row. `ChildCard` (avatar, name, grade, points, streak) and `UserRepository.getChildren(uids)` already exist and are used elsewhere (parent dashboard's Home tab) — reuse them here instead of a bare number, giving parents an actual "Parent connection" view from their own profile.

**Files:**
- Modify: `lib/features/dashboard/screens/parent_dashboard.dart` (read first — confirm exact current `_ParentProfileTab` structure and how the Home tab already fetches/displays children, to reuse the same data-loading pattern rather than inventing a new one)

**Interfaces:**
- Consumes: `ChildCard` (existing), `UserRepository.getChildren` (existing).

- [ ] **Step 1: Read the current `_ParentProfileTab` and the Home tab's child-loading code** to match the existing pattern (likely a `FutureBuilder` or a provider-held list already used for `ChildCard`s on the Home tab — reuse that exact data source if the Home tab already loads it into a provider/state, rather than issuing a duplicate Firestore fetch).

- [ ] **Step 2: Replace the "Children" count row with a `ChildCard` list**

Remove the `_ProfileInfoRow(icon: Icons.groups_outlined, label: 'Children', value: '${user?.linkedChildrenUids?.length ?? 0}')` row. Below the existing info card, add a section header `Text('My Children', style: AppTextStyles.h4)` followed by a `Column` of `ChildCard` widgets (one per linked child), each `onTap` navigating to that child's analytics screen if such navigation already exists elsewhere in this file (reuse it — don't invent new navigation if `child_analytics_screen.dart` is already reachable from the Home tab's own `ChildCard` usage).

- [ ] **Step 3: Manual verification**

Run: `flutter run -d chrome`. As a parent with a linked child, open the Profile tab — confirm the child now renders as a full card (avatar, grade, points, streak) instead of a bare count.

- [ ] **Step 4: `flutter analyze` clean, then commit**

```bash
flutter analyze lib/features/dashboard/screens/parent_dashboard.dart
git add lib/features/dashboard/screens/parent_dashboard.dart
git commit -m "feat(profile): show real linked-children cards on the parent profile tab instead of a bare count"
```

---

### Task 6: Add Settings + confirmed sign-out to parent and teacher profile tabs

**Files:**
- Modify: `lib/features/dashboard/screens/parent_dashboard.dart`
- Modify: `lib/features/dashboard/screens/teacher_dashboard.dart`

**Interfaces:**
- Consumes: `ProfileSettingsTile` (Task 1).

- [ ] **Step 1: Replace `_ParentProfileTab`'s bare sign-out button**

In `parent_dashboard.dart`, replace the `OutlinedButton.icon(onPressed: () { auth.signOut(); Navigator.pushNamedAndRemoveUntil(...); }, ...)` block with `const ProfileSettingsTile()`. Remove the now-unused `final auth = context.read<AuthProvider>();` line if nothing else in the widget uses `auth` (check first). Add the import `import '../../../core/widgets/profile_settings_tile.dart';`.

- [ ] **Step 2: Replace `_ProfileTab`'s (teacher) bare sign-out button**

Same replacement in `teacher_dashboard.dart`'s `_ProfileTab`.

- [ ] **Step 3: Manual verification**

Run: `flutter run -d chrome`. As a parent, then as a teacher, open the Profile tab — confirm both now show a Settings entry (navigating to `/settings`, dark-mode toggle works) and a confirmed sign-out.

- [ ] **Step 4: `flutter analyze` clean, then commit**

```bash
flutter analyze lib/features/dashboard/screens/parent_dashboard.dart lib/features/dashboard/screens/teacher_dashboard.dart
git add lib/features/dashboard/screens/parent_dashboard.dart lib/features/dashboard/screens/teacher_dashboard.dart
git commit -m "feat(profile): add Settings entry and confirmed sign-out to parent/teacher profile tabs"
```

---

### Task 7: Shared Edit Profile screen (account management + editable personal info)

**Why:** None of the three real profile tabs let a user edit their own name/surname/grade/language — the only editable field anywhere was the language dropdown on the now-deleted dead `profile_screen.dart`. This is the literal "Account management" + "Editable personal information" spec items.

**Files:**
- Create: `lib/features/profile/screens/edit_profile_screen.dart`
- Modify: `lib/main.dart` (add `/edit_profile` route)
- Test: `test/widgets/edit_profile_screen_test.dart`

**Interfaces:**
- Produces: `class EditProfileScreen extends StatefulWidget` — form with Name, Surname, Grade (reusing the existing `GradeSelector` widget from `lib/features/auth/widgets/grade_selector.dart`), and Language (reusing the same `_saLanguages` list pattern from the deleted `profile_screen.dart` — copy the list, don't try to import from the deleted file) fields, a Save button (`AppButton`) calling `UserRepository().updateUser(uid, {...})` with only those editable fields, never `role`/`xp`/`coins`/`level`/`linkedChildrenUids` (the Firestore-rules-locked fields).
- Consumes: `AuthProvider` (to get the current user + refresh after save), `GradeSelector` (existing).

- [ ] **Step 1: Write the failing test**

```dart
// test/widgets/edit_profile_screen_test.dart
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/edit_profile_screen_test.dart`
Expected: FAIL — file doesn't exist.

- [ ] **Step 3: Implement `EditProfileScreen`**

Read `lib/features/auth/widgets/grade_selector.dart` first to confirm its exact constructor (`selectedGrade`, `onGradeChanged`, per prior phases' usage in `register_screen.dart`).

```dart
// lib/features/profile/screens/edit_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../providers/auth_provider.dart';
import '../../auth/widgets/grade_selector.dart';

class EditProfileScreen extends StatefulWidget {
  final String initialName;
  final String initialSurname;
  final String initialGrade;
  final String initialLanguage;

  const EditProfileScreen({
    super.key,
    required this.initialName,
    required this.initialSurname,
    required this.initialGrade,
    required this.initialLanguage,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  static const _saLanguages = [
    'English', 'Afrikaans', 'isiZulu', 'isiXhosa', 'siSwati', 'isiNdebele',
    'Sesotho', 'Northern Sotho', 'Setswana', 'Tshivenda', 'Xitsonga',
  ];

  final _formKey = GlobalKey<FormState>();
  late final _nameCtrl = TextEditingController(text: widget.initialName);
  late final _surnameCtrl = TextEditingController(text: widget.initialSurname);
  late String _grade = widget.initialGrade;
  late String _language = widget.initialLanguage;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _surnameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final uid = context.read<AuthProvider>().user?.uid;
    if (uid != null) {
      await UserRepository().updateUser(uid, {
        'name': _nameCtrl.text.trim(),
        'surname': _surnameCtrl.text.trim(),
        'grade': _grade,
        'preferredLanguage': _language,
      });
    }
    if (mounted) {
      setState(() => _saving = false);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'First Name'),
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _surnameCtrl,
                  decoration: const InputDecoration(labelText: 'Surname'),
                ),
                const SizedBox(height: 16),
                Text('Grade', style: AppTextStyles.label),
                const SizedBox(height: 8),
                GradeSelector(
                  selectedGrade: _grade,
                  onGradeChanged: (g) => setState(() => _grade = g),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _language,
                  decoration: const InputDecoration(labelText: 'Preferred Language'),
                  items: _saLanguages
                      .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _language = v);
                  },
                ),
                const SizedBox(height: 32),
                AppButton(
                  label: 'Save Changes',
                  isLoading: _saving,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widgets/edit_profile_screen_test.dart`
Expected: PASS

- [ ] **Step 5: Register the route and add entry points from all three profile tabs**

In `main.dart`, this route needs the current user's data to construct initial values, so register it as a wrapper reading `AuthProvider`:

```dart
'/edit_profile': (_) => Consumer<AuthProvider>(
  builder: (context, auth, _) {
    final user = auth.user;
    return EditProfileScreen(
      initialName: user?.name ?? '',
      initialSurname: user?.surname ?? '',
      initialGrade: user?.grade ?? 'Grade 1',
      initialLanguage: user?.preferredLanguage ?? 'English',
    );
  },
),
```

Add imports for `EditProfileScreen`, `AuthProvider`, and `Consumer` (already available via the existing `provider` import). In each of the three profile tabs (`learner_dashboard.dart`'s `_ProfileTab`, `parent_dashboard.dart`'s `_ParentProfileTab`, `teacher_dashboard.dart`'s `_ProfileTab`), add an "Edit Profile" `ListTile`/`IconButton` near the name/avatar header that calls `Navigator.pushNamed(context, '/edit_profile')`.

- [ ] **Step 6: Manual verification**

Run: `flutter run -d chrome`. As each of the three roles, tap "Edit Profile", change the name, save, confirm the profile tab reflects the new name (may require the tab's own data source — `AuthProvider.user` or a `watchUser` stream — to refresh; verify it does, since `UserRepository.updateUser` writes to Firestore and `AuthProvider` should already be listening if it uses `watchUser` elsewhere, per existing patterns in this codebase).

- [ ] **Step 7: `flutter analyze` clean, then commit**

```bash
flutter analyze lib/features/profile/screens/edit_profile_screen.dart lib/main.dart lib/features/dashboard/screens/learner_dashboard.dart lib/features/dashboard/screens/parent_dashboard.dart lib/features/dashboard/screens/teacher_dashboard.dart
git add lib/features/profile/screens/edit_profile_screen.dart lib/main.dart lib/features/dashboard/screens/learner_dashboard.dart lib/features/dashboard/screens/parent_dashboard.dart lib/features/dashboard/screens/teacher_dashboard.dart test/widgets/edit_profile_screen_test.dart
git commit -m "feat(profile): add shared Edit Profile screen for account management, wired into all three roles"
```

---

## End-of-Phase Checklist

- [ ] `flutter analyze` → 0 new errors
- [ ] `flutter test` → all green, including new tests this plan adds
- [ ] `flutter build web --release` and `flutter build apk --debug` both succeed
- [ ] Dead `profile_screen.dart` removed, confirmed nothing broke
- [ ] Learner profile tab shows: profile picture, grade, XP, level, achievements gallery, parent-link QR code, settings, confirmed sign-out
- [ ] Parent profile tab shows: profile picture, real linked-children cards (not a bare count), settings, confirmed sign-out
- [ ] Teacher profile tab shows: profile picture, grade/class, settings, confirmed sign-out
- [ ] Edit Profile is reachable and functional from all three roles, only ever writes non-locked fields
- [ ] No files matching forbidden-secrets patterns were added
