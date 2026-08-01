# Phase 1 — UI/UX Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign QuestKids' UI/UX into a consistent, child-friendly, Material 3 "educational game" system — a reusable design-system widget layer, dark-mode-safe auth screens, a redesigned splash/login/register/forgot-password flow, a new Settings screen with the dark-mode toggle, a side menu, sign-out confirmation, and a proper 404/error page — without touching game engines, Firebase config, or existing business logic.

**Architecture:** QuestKids is an already-mature Flutter 3 + Firebase app (Provider state management, classic `Navigator` named routes, Material 3, feature-first folders). Phase 1 does **not** rebuild the theme engine (it already has a complete `AppColors`/`AppTheme`/`ThemeProvider` light+dark system) — it adds a missing reusable widget layer (`AppButton`, `AppLoadingView`, `AppEmptyState`, `AppErrorView`, `AppDialog`, `AppSideMenu`) on top of the existing theme, then applies it to the screens/gaps the investigation found: 3 screens with hardcoded non-theme-aware colors that break dark mode, a missing `/forgot_password` route, a missing Settings screen, a missing side menu, a missing sign-out confirmation, and a missing unknown-route/404 handler.

**Tech Stack:** Flutter (Dart ≥3.4), Material 3, `provider` for state, `google_fonts` (Nunito), `flutter_animate` for animation, existing `ShaderBackground` (GLSL aurora shader with gradient fallback) for animated backdrops.

## Global Constraints

- `flutter analyze` → 0 new errors before any commit (warnings only if pre-existing).
- `flutter test` → all tests green, including any new tests added by this plan.
- App must boot to the splash/login screen on `flutter run -d chrome` with no red screen after every task.
- Do not touch: `lib/firebase_options.dart`, `db_bootstrap_io.dart`/`db_bootstrap_stub.dart`, Firebase project IDs/bundle ID, any `<engine>/` game folder, `game_catalog.dart` invariants.
- Do not rewrite git history or force-push.
- No secrets committed (`.env`, `serviceAccountKey*.json`, anything with `private_key`/`client_secret`).
- Child-facing UI conventions (already established, keep following them): min 56dp touch targets, short sentences, emoji-friendly, South African context, no profanity/dark patterns.
- Commit style: `type(scope): summary` (e.g. `feat(ui): add AppButton design-system widget`). Small, reviewable commits; run `flutter analyze` before each.
- Preserve all existing auth/business logic exactly (`AuthProvider` methods, validators, navigation targets, Firestore field writes) — this is a **UI/UX redesign phase**, not a logic rewrite (per project Rule 3: fix broken wiring, never redesign working logic away).

---

## File Structure

New files this plan creates:
```
lib/core/widgets/
├── app_button.dart          # Task 1
├── app_loading_view.dart    # Task 2
├── app_empty_state.dart     # Task 2
├── app_error_view.dart      # Task 2
├── app_dialog.dart          # Task 2
└── app_side_menu.dart       # Task 9
lib/features/profile/screens/
└── settings_screen.dart     # Task 8
test/widgets/
├── app_button_test.dart     # Task 1
├── app_loading_view_test.dart   # Task 2
├── app_empty_state_test.dart    # Task 2
└── settings_screen_test.dart    # Task 8
test/main/
└── unknown_route_test.dart  # Task 11
```

Files this plan modifies: `lib/core/theme/app_theme.dart`, `lib/main.dart`, `lib/features/auth/screens/{login_screen,register_screen,forgot_password_screen,splash_screen}.dart`, `lib/features/profile/screens/profile_screen.dart`, `lib/features/dashboard/screens/learner_dashboard.dart`, `lib/core/widgets/responsive_scaffold.dart`.

---

### Task 1: `AppButton` design-system widget + theme dialog/snackbar polish

**Files:**
- Create: `lib/core/widgets/app_button.dart`
- Modify: `lib/core/theme/app_theme.dart` (add `dialogTheme` + `snackBarTheme` to both `lightTheme` and `darkTheme`)
- Test: `test/widgets/app_button_test.dart`

**Interfaces:**
- Produces: `enum AppButtonVariant { primary, secondary, danger }` and `class AppButton extends StatelessWidget` with constructor `AppButton({Key? key, required String label, required VoidCallback? onPressed, bool isLoading = false, AppButtonVariant variant = AppButtonVariant.primary, IconData? icon, bool fullWidth = true})`. Later tasks (4, 5, 6, 7, 10) replace ad-hoc `ElevatedButton`/`OutlinedButton` + `auth.isLoading ? CircularProgressIndicator : Text(...)` blocks with this widget.

This directly DRYs up a pattern duplicated verbatim in `login_screen.dart:299-309`, `register_screen.dart:413-420` and `:437-441`, and `forgot_password_screen.dart:83-93`.

- [ ] **Step 1: Write the failing widget test**

```dart
// test/widgets/app_button_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/core/widgets/app_button.dart';

void main() {
  testWidgets('AppButton shows label and calls onPressed', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AppButton(
          label: 'Sign In',
          onPressed: () => tapped = true,
        ),
      ),
    ));

    expect(find.text('Sign In'), findsOneWidget);
    await tester.tap(find.byType(AppButton));
    await tester.pump();
    expect(tapped, isTrue);
  });

  testWidgets('AppButton shows spinner and disables tap when isLoading', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AppButton(
          label: 'Sign In',
          isLoading: true,
          onPressed: () => tapped = true,
        ),
      ),
    ));

    expect(find.text('Sign In'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byType(AppButton), warnIfMissed: false);
    await tester.pump();
    expect(tapped, isFalse);
  });

  testWidgets('AppButton danger variant uses AppColors.error foreground', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AppButton(
          label: 'Sign Out',
          variant: AppButtonVariant.danger,
          onPressed: () {},
        ),
      ),
    ));

    expect(find.byType(OutlinedButton), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/app_button_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:questkids/core/widgets/app_button.dart'`

(Check the app's actual package name in `pubspec.yaml`'s `name:` field first — replace `questkids` above if different.)

- [ ] **Step 3: Implement `AppButton`**

```dart
// lib/core/widgets/app_button.dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum AppButtonVariant { primary, secondary, danger }

/// Shared button used across auth, profile, and dialog flows so loading
/// state, icon layout, and the danger (destructive-action) style are
/// defined once instead of duplicated per screen.
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool fullWidth;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.fullWidth = true,
  });

  @override
  Widget build(BuildContext context) {
    final spinnerColor = variant == AppButtonVariant.primary
        ? Colors.white
        : (variant == AppButtonVariant.danger
            ? AppColors.error
            : AppColors.primary);

    final content = isLoading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              color: spinnerColor,
              strokeWidth: 2,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: 8),
              ],
              Text(label),
            ],
          );

    final onTap = isLoading ? null : onPressed;

    final button = switch (variant) {
      AppButtonVariant.primary => ElevatedButton(
          onPressed: onTap,
          child: content,
        ),
      AppButtonVariant.secondary => OutlinedButton(
          onPressed: onTap,
          child: content,
        ),
      AppButtonVariant.danger => OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.error,
            side: const BorderSide(color: AppColors.error, width: 1.5),
          ),
          child: content,
        ),
    };

    if (!fullWidth) return button;
    return SizedBox(width: double.infinity, height: 52, child: button);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widgets/app_button_test.dart`
Expected: PASS (3/3)

- [ ] **Step 5: Add `dialogTheme` and `snackBarTheme` to `AppTheme`**

In `lib/core/theme/app_theme.dart`, add the following inside `lightTheme`'s `ThemeData(...)` (after the `chipTheme:` block, before the closing `);` at line 94):

```dart
        dialogTheme: DialogThemeData(
          backgroundColor: AppColors.cardLight,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titleTextStyle: GoogleFonts.nunito(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
          contentTextStyle: GoogleFonts.nunito(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.textPrimary,
          contentTextStyle: GoogleFonts.nunito(color: Colors.white),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
```

And inside `darkTheme`'s `ThemeData(...)` (after `bottomNavigationBarTheme:`, before the closing `);` at line 168):

```dart
        dialogTheme: DialogThemeData(
          backgroundColor: AppColors.cardDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titleTextStyle: GoogleFonts.nunito(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
          contentTextStyle: GoogleFonts.nunito(
            fontSize: 14,
            color: AppColors.textDark.withValues(alpha: 0.75),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.primaryLight,
          contentTextStyle: GoogleFonts.nunito(color: AppColors.backgroundDark),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
```

- [ ] **Step 6: Verify app still boots clean**

Run: `flutter analyze`
Expected: 0 new errors.

Run: `flutter run -d chrome` (or `flutter test`), confirm no red screen / no `DialogTheme` type-mismatch runtime error (Flutter 3.24+ uses `DialogThemeData` for `ThemeData.dialogTheme` — if the project's Flutter SDK is older and expects a `DialogTheme` object instead, use `DialogTheme(...)` in place of `DialogThemeData(...)` above; check `flutter --version` against the `DialogThemeData` API before assuming).

- [ ] **Step 7: Commit**

```bash
git add lib/core/widgets/app_button.dart lib/core/theme/app_theme.dart test/widgets/app_button_test.dart
git commit -m "feat(ui): add AppButton design-system widget and dialog/snackbar theming"
```

---

### Task 2: `AppLoadingView`, `AppEmptyState`, `AppErrorView`, `AppDialog`

**Files:**
- Create: `lib/core/widgets/app_loading_view.dart`
- Create: `lib/core/widgets/app_empty_state.dart`
- Create: `lib/core/widgets/app_error_view.dart`
- Create: `lib/core/widgets/app_dialog.dart`
- Test: `test/widgets/app_loading_view_test.dart`
- Test: `test/widgets/app_empty_state_test.dart`

**Interfaces:**
- Consumes: `AppButton` from Task 1 (used inside `AppEmptyState`'s optional action and `AppErrorView`'s retry button).
- Produces: `AppLoadingView({String? message})`, `AppEmptyState({required String emoji, required String title, required String message, String? actionLabel, VoidCallback? onAction})`, `AppErrorView({required String message, VoidCallback? onRetry})`, and `AppDialog.confirm(BuildContext, {required String title, required String message, String confirmLabel = 'Confirm', String cancelLabel = 'Cancel', bool isDanger = false}) → Future<bool>`. Task 10 consumes `AppDialog.confirm`; Task 11 consumes `AppErrorView`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/widgets/app_loading_view_test.dart
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
```

```dart
// test/widgets/app_empty_state_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/core/widgets/app_empty_state.dart';

void main() {
  testWidgets('AppEmptyState shows title/message and invokes onAction', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AppEmptyState(
          emoji: '🎯',
          title: 'No quests yet',
          message: 'Complete a game to see it here.',
          actionLabel: 'Play now',
          onAction: () => tapped = true,
        ),
      ),
    ));

    expect(find.text('No quests yet'), findsOneWidget);
    expect(find.text('Play now'), findsOneWidget);
    await tester.tap(find.text('Play now'));
    await tester.pump();
    expect(tapped, isTrue);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/widgets/app_loading_view_test.dart test/widgets/app_empty_state_test.dart`
Expected: FAIL — missing source files.

- [ ] **Step 3: Implement the four widgets**

```dart
// lib/core/widgets/app_loading_view.dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Centered spinner + optional message, replacing bare
/// `Center(child: CircularProgressIndicator())` calls scattered across screens.
class AppLoadingView extends StatelessWidget {
  final String? message;

  const AppLoadingView({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
```

```dart
// lib/core/widgets/app_empty_state.dart
import 'package:flutter/material.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_colors.dart';
import 'app_button.dart';

/// Friendly "nothing here yet" placeholder for quests/games/rewards lists.
class AppEmptyState extends StatelessWidget {
  final String emoji;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AppEmptyState({
    super.key,
    required this.emoji,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(title, style: AppTextStyles.h3, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              message,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              AppButton(label: actionLabel!, onPressed: onAction, fullWidth: false),
            ],
          ],
        ),
      ),
    );
  }
}
```

```dart
// lib/core/widgets/app_error_view.dart
import 'package:flutter/material.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_colors.dart';
import 'app_button.dart';

/// Shown when a screen fails to load data or a route can't be resolved.
class AppErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const AppErrorView({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('😕', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text('Oops, something went wrong', style: AppTextStyles.h3, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              message,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              AppButton(label: 'Try Again', onPressed: onRetry, fullWidth: false, icon: Icons.refresh),
            ],
          ],
        ),
      ),
    );
  }
}
```

```dart
// lib/core/widgets/app_dialog.dart
import 'package:flutter/material.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_colors.dart';

/// Static helpers for the app's confirm/destructive-action dialogs, so every
/// screen gets the same shape/copy style instead of a bespoke AlertDialog.
class AppDialog {
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool isDanger = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: AppTextStyles.h4),
        content: Text(message, style: AppTextStyles.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(cancelLabel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: isDanger
                ? ElevatedButton.styleFrom(backgroundColor: AppColors.error)
                : null,
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/widgets/app_loading_view_test.dart test/widgets/app_empty_state_test.dart`
Expected: PASS (2/2)

- [ ] **Step 5: `flutter analyze` clean, then commit**

```bash
flutter analyze
git add lib/core/widgets/app_loading_view.dart lib/core/widgets/app_empty_state.dart lib/core/widgets/app_error_view.dart lib/core/widgets/app_dialog.dart test/widgets/app_loading_view_test.dart test/widgets/app_empty_state_test.dart
git commit -m "feat(ui): add AppLoadingView, AppEmptyState, AppErrorView, AppDialog"
```

---

### Task 3: Dark-mode safety fixes — hardcoded colors in auth screens

**Why this is a real bug, not cosmetic:** `login_screen.dart` and `register_screen.dart` use raw `Colors.grey.shade200/400/50` and `Colors.white` for pill toggles, date pickers, and role/parent selector cards. These do not read `Theme.of(context).brightness`, so in dark mode a user sees light-grey/white cards on a dark scaffold — the exact "Dark Mode must behave perfectly" requirement is currently violated. Per Rule 3, this is a fix, not a redesign-from-scratch.

**Files:**
- Modify: `lib/features/auth/screens/login_screen.dart:231-286` (child/adult toggle pills), `:117-134` (child birthdate picker container)
- Modify: `lib/features/auth/screens/register_screen.dart:274-327` (mother/father/guardian selector cards), `:366-377` (child birthdate picker container), `:401-409` (link-later info card)
- Test: manual — Steps 5-6 below define the verification (dark mode has no widget-testable "looks right"; verified via `flutter run` in both theme modes, consistent with how `ThemeProvider`/dark mode is already verified in this codebase — no prior dark-mode widget tests exist to extend).

- [ ] **Step 1: Replace the login screen's toggle-pill background**

In `login_screen.dart`, replace the `Container` at line 231-235:

```dart
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
```

with:

```dart
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
```

And the unselected-pill text color at lines 253-254 and 276-277 (`color: Colors.grey.shade600`) → `color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.grey.shade600`.

- [ ] **Step 2: Replace the login screen's date-picker container**

Replace lines 117-123:

```dart
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey.shade50,
            ),
```

with:

```dart
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white24
                    : Colors.grey.shade400,
              ),
              borderRadius: BorderRadius.circular(12),
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.grey.shade50,
            ),
```

Also change the icon color at line 126 (`const Icon(Icons.calendar_today, color: Colors.grey)`) → drop `const` and use `Icon(Icons.calendar_today, color: AppColors.textSecondary)` (already theme-neutral grey-blue, reads fine on both backgrounds — no branching needed here).

- [ ] **Step 3: Fix the register screen's mother/father/guardian selector cards**

In `register_screen.dart`, all three `Card(color: _parentRole == '...' ? AppColors.primary : Colors.white, ...)` blocks (lines 274-327) hardcode `Colors.white` as the unselected background and pure black default text — replace each `Colors.white` with a theme-aware expression. Since the three cards repeat the same pattern, extract a small local helper at the top of `_buildStep2Parent()` (before the `return Column(`):

```dart
  Widget _buildStep2Parent() {
    final auth = context.watch<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color unselectedCardColor() =>
        isDark ? AppColors.cardDark : Colors.white;
    Color textColorFor(bool selected) =>
        selected ? Colors.white : (isDark ? AppColors.textDark : AppColors.textPrimary);
```

Then replace each of the three `color: _parentRole == 'X' ? AppColors.primary : Colors.white,` with `color: _parentRole == 'X' ? AppColors.primary : unselectedCardColor(),` and wrap each card's `Text('Mother'|'Father'|'Guardian')` with `style: TextStyle(color: textColorFor(_parentRole == 'X'))`.

- [ ] **Step 4: Fix the register screen's child birthdate container and link-later info card**

Apply the same `Theme.of(context).brightness == Brightness.dark` branch used in Step 2 to the `Container` at lines 366-377 (border `Colors.grey` → `Colors.white24`/`Colors.grey`), and change the `Card(color: AppColors.surface, ...)` at line 401-409 to also branch: `color: isDark ? AppColors.cardDark : AppColors.surface,` (reusing the `isDark` local from Step 3, already in scope of `_buildStep2Parent()`).

- [ ] **Step 5: Manual dark-mode verification**

Run: `flutter run -d chrome`. On the login screen, toggle the OS/browser to dark mode (or temporarily set `ThemeProvider._themeMode = ThemeMode.dark` in `_loadTheme()` for the test run) and visually confirm: toggle pills, date picker, and (on the register flow, step 2) the mother/father/guardian cards all render with dark-mode-appropriate backgrounds and readable text — no white cards on the dark scaffold. Revert any temporary `ThemeProvider` edit before committing.

- [ ] **Step 6: `flutter analyze` clean, then commit**

```bash
flutter analyze
git add lib/features/auth/screens/login_screen.dart lib/features/auth/screens/register_screen.dart
git commit -m "fix(auth): make login/register screens dark-mode safe"
```

---

### Task 4: Splash Screen redesign

**Files:**
- Modify: `lib/features/auth/screens/splash_screen.dart` (full body rewrite, `_navigate()` logic untouched)

**Interfaces:**
- Consumes: `ShaderBackground` (`lib/core/widgets/shader_background.dart`, already exists — takes exactly 3 `colors`), `AppColors.heroGradient` (2 colors — extend to 3 for the shader, see Step 1).

- [ ] **Step 1: Add a third gradient stop for the shader**

`AppColors.heroGradient` currently has 2 colors (`app_colors.dart:52-55`) but `ShaderBackground` requires exactly 3. Add a new constant right after `heroGradient`:

```dart
  static const List<Color> heroGradientTriple = [
    Color(0xFF5C35F5),
    Color(0xFF7C4DFF),
    Color(0xFF9C27B0),
  ];
```

- [ ] **Step 2: Rewrite the splash body to use `ShaderBackground` and a mascot-style entrance**

Replace `splash_screen.dart`'s `build()` method (lines 69-122) with:

```dart
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ShaderBackground(
        colors: AppColors.heroGradientTriple,
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: ScaleTransition(
              scale: _scaleAnim,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(36),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 36,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(36),
                      child: Image.asset(
                        'assets/icon/questkids_logo.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Center(
                            child: Text('🎮', style: TextStyle(fontSize: 60))),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text('QuestKids',
                      style: AppTextStyles.h1.copyWith(color: Colors.white)),
                  const SizedBox(height: 8),
                  Text('Learn. Play. Grow.',
                      style: AppTextStyles.bodyLarge
                          .copyWith(color: Colors.white70)),
                  const SizedBox(height: 60),
                  const CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
```

Note this is the same widget tree as before, just wrapped in `ShaderBackground` instead of a flat `backgroundColor: AppColors.primary` `Scaffold` — remove the now-unused `backgroundColor: AppColors.primary,` line and the `import '../../../core/theme/app_colors.dart';` stays (still used for `heroGradientTriple`). Add `import '../../../core/widgets/shader_background.dart';`.

- [ ] **Step 3: Verify boot behavior unchanged**

Run: `flutter run -d chrome`. Confirm: splash shows the animated aurora gradient behind the logo for ~2s, then navigates to login (unauthenticated) or dashboard (authenticated) exactly as before — `_navigate()` was not touched, so this is a visual-only change.

- [ ] **Step 4: `flutter analyze` clean, then commit**

```bash
flutter analyze
git add lib/features/auth/screens/splash_screen.dart lib/core/theme/app_colors.dart
git commit -m "feat(ui): animated shader background on splash screen"
```

---

### Task 5: Login Screen redesign

**Files:**
- Modify: `lib/features/auth/screens/login_screen.dart` (hero header + submit button only; form logic, controllers, validators untouched)

**Interfaces:**
- Consumes: `AppButton` (Task 1).

- [ ] **Step 1: Replace the plain logo block with a gradient hero card**

Replace the `Center(child: Column(... Container(width: 90, height: 90 ...` block (lines 190-227) with a gradient-backed version consistent with the dashboard's `_HeroSection` style (`learner_dashboard.dart:279-292`):

```dart
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, Color(0xFF9C27B0)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.asset(
                            'assets/icon/questkids_logo.png',
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Text('🎮', style: TextStyle(fontSize: 36)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('QuestKids',
                          style: AppTextStyles.h1.copyWith(color: Colors.white)),
                      Text('Learn. Play. Grow.',
                          style: AppTextStyles.bodyMedium
                              .copyWith(color: Colors.white.withValues(alpha: 0.85))),
                    ],
                  ),
                ),
```

(Drop the surrounding `Center(child: Column(children: [` wrapper since the gradient card is already centered content — keep `const SizedBox(height: 40),` before and after it as in the original.)

- [ ] **Step 2: Replace the sign-in `ElevatedButton` with `AppButton`**

Replace lines 299-309:

```dart
                ElevatedButton(
                  onPressed: auth.isLoading ? null : _login,
                  child: auth.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Sign In'),
                ),
```

with:

```dart
                AppButton(
                  label: 'Sign In',
                  isLoading: auth.isLoading,
                  onPressed: _login,
                ),
```

Add `import '../../../core/widgets/app_button.dart';` at the top.

- [ ] **Step 3: Verify login still works end-to-end**

Run: `flutter run -d chrome`. Manually log in with an existing test account (both the "Child" and "Parent/Teacher" tabs) and confirm navigation to the correct dashboard still happens, and the error `SnackBar` still shows on bad credentials (now floating/rounded per Task 1's `snackBarTheme`).

- [ ] **Step 4: `flutter analyze` clean, then commit**

```bash
flutter analyze
git add lib/features/auth/screens/login_screen.dart
git commit -m "feat(ui): redesign login screen hero header and submit button"
```

---

### Task 6: Register Screen redesign

**Files:**
- Modify: `lib/features/auth/screens/register_screen.dart` (step-progress indicator + submit buttons only; the 4-step state machine, `_register()`, and all field controllers untouched)

**Interfaces:**
- Consumes: `AppButton` (Task 1).

- [ ] **Step 1: Add a step-progress indicator above the form**

In `build()`, inside the `SingleChildScrollView`'s `Form`'s `child:` (line 468-479), add a progress row before the step content:

```dart
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Row(
                    children: List.generate(4, (i) {
                      final active = i <= _step;
                      return Expanded(
                        child: Container(
                          margin: EdgeInsets.only(right: i < 3 ? 6 : 0),
                          height: 6,
                          decoration: BoxDecoration(
                            color: active
                                ? AppColors.primary
                                : AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                () {
                  if (_step == 0) return _buildStep0();
                  if (_step == 1) return _buildStep1();
                  if (_step == 2) return _buildStep2Parent();
                  if (_step == 3) return _buildStep3Teacher();
                  return const SizedBox();
                }(),
              ],
            ),
```

(This wraps the existing step-dispatch closure in a `Column` with the new progress bar — the `Form(key: _formKey, child: ...)` wrapper stays as-is around this new `Column`.)

- [ ] **Step 2: Replace the three `ElevatedButton`/loading-spinner submit buttons with `AppButton`**

- `_buildStep0()` line 163-166 (`Next →`): replace `ElevatedButton(onPressed: () => setState(() => _step = 1), child: const Text('Next →'))` with `AppButton(label: 'Next →', onPressed: () => setState(() => _step = 1))`.
- `_buildStep1()` line 248-255 (`Next →`): replace similarly, keeping the existing `onPressed` closure body (`if (_formKey.currentState!.validate()) { setState(() => _step = _role == 'parent' ? 2 : 3); }`) — wrap it as `AppButton(label: 'Next →', onPressed: () { if (_formKey.currentState!.validate()) { setState(() => _step = _role == 'parent' ? 2 : 3); } })`.
- `_buildStep2Parent()` line 413-420: replace with `AppButton(label: 'Create Accounts 🚀', isLoading: auth.isLoading, onPressed: (_registerChild && !_consentGiven) ? null : _register)`.
- `_buildStep3Teacher()` line 437-441: replace with `AppButton(label: 'Create Account 🚀', isLoading: auth.isLoading, onPressed: _register)`.

Add `import '../../../core/widgets/app_button.dart';` at the top.

- [ ] **Step 3: Verify registration still works end-to-end**

Run: `flutter run -d chrome`. Walk through registering a parent account with a child (`_registerChild = true`), confirm the consent checkbox still gates the submit button (via `AppButton`'s `onPressed: null` when ungated), and confirm a teacher registration also completes and navigates to `TeacherDashboard`.

- [ ] **Step 4: `flutter analyze` clean, then commit**

```bash
flutter analyze
git add lib/features/auth/screens/register_screen.dart
git commit -m "feat(ui): add step-progress indicator and AppButton to register screen"
```

---

### Task 7: Forgot Password — route fix + redesign

**Why this is a Rule-3 fix, not just polish:** `forgot_password_screen.dart` exists and is fully functional (calls `AuthProvider.resetPassword`), but is **not registered in `main.dart`'s routes map** — it's only reachable via the direct `Navigator.push(MaterialPageRoute(...))` call from `login_screen.dart:164-167`. Any future deep link or `Navigator.pushNamed(context, '/forgot_password')` call would silently fail. Fix the wiring, then apply the same design-system pass as Task 5.

**Files:**
- Modify: `lib/main.dart:58-68` (add route)
- Modify: `lib/features/auth/screens/forgot_password_screen.dart` (AppButton + AppColors gradient icon treatment)

**Interfaces:**
- Consumes: `AppButton` (Task 1).

- [ ] **Step 1: Register the route**

In `lib/main.dart`, add to the `routes:` map (after `'/register': (_) => const RegisterScreen(),` at line 60):

```dart
        '/forgot_password': (_) => const ForgotPasswordScreen(),
```

Add the import near the other auth screen imports (after `import 'features/auth/screens/register_screen.dart';`):

```dart
import 'features/auth/screens/forgot_password_screen.dart';
```

- [ ] **Step 2: Replace the two `ElevatedButton`s with `AppButton`**

Replace lines 55-58 (`ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Back to Login'))`) with:

```dart
                    AppButton(
                      label: 'Back to Login',
                      onPressed: () => Navigator.pop(context),
                      fullWidth: false,
                    ),
```

Replace lines 83-93 (the send-reset-link button) with:

```dart
                    AppButton(
                      label: 'Send Reset Link',
                      isLoading: auth.isLoading,
                      onPressed: _send,
                    ),
```

Add `import '../../../core/widgets/app_button.dart';` at the top.

- [ ] **Step 3: Verify both the pushed and named-route paths work**

Run: `flutter run -d chrome`. From the login screen, tap "Forgot Password?" (still uses direct `Navigator.push`, unaffected) and confirm the screen renders and the reset email send flow still completes. Then, separately, confirm `Navigator.pushNamed(context, '/forgot_password')` now resolves (e.g. temporarily call it from a debug button, or verify via a widget test below) rather than throwing "could not find a generator".

- [ ] **Step 4: Add a regression test for the route registration**

```dart
// test/widgets/app_loading_view_test.dart already exists from Task 2 — create a new file instead:
```

```dart
// test/main/unknown_route_test.dart is created in Task 11 and will also cover
// this route map — no separate test file needed here; instead add this
// assertion inline as part of Task 11's test (see Task 11 Step 1).
```

(No new test file for this step — Task 11's route test asserts the full `routes` map, including `/forgot_password`, so this task's regression coverage lands there to avoid duplicating a routes-map test twice.)

- [ ] **Step 5: `flutter analyze` clean, then commit**

```bash
flutter analyze
git add lib/main.dart lib/features/auth/screens/forgot_password_screen.dart
git commit -m "fix(auth): register missing /forgot_password named route, apply AppButton"
```

---

### Task 8: Settings Screen (new) — dark mode toggle + entry points

**Why this is needed:** `ThemeProvider.toggleTheme()` already exists and already persists to `SharedPreferences` (`theme_provider.dart`), and the learner dashboard's AppBar already has a quick sun/moon icon toggle (`learner_dashboard.dart:123-126`) — but there is **no dedicated Settings screen**, and `ProfileScreen` (the standalone, non-dashboard-embedded one at `lib/features/profile/screens/profile_screen.dart`) has no way to reach one. This task builds it and wires it in per the Phase 3 spec's "Settings should be inside the profile" requirement, pulled forward since it's the natural home for the dark-mode toggle this phase requires.

**Files:**
- Create: `lib/features/profile/screens/settings_screen.dart`
- Modify: `lib/main.dart` (add `/settings` route)
- Modify: `lib/features/profile/screens/profile_screen.dart` (add "Settings" entry point)
- Test: `test/widgets/settings_screen_test.dart`

**Interfaces:**
- Consumes: `ThemeProvider` (`context.watch<ThemeProvider>()`, `.isDark`, `.toggleTheme()` — all pre-existing, unchanged), `AppDialog.confirm` is NOT used here (no destructive action on this screen).
- Produces: `class SettingsScreen extends StatelessWidget`, route name `/settings`.

- [ ] **Step 1: Write the failing test**

```dart
// test/widgets/settings_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:questkids/core/theme/theme_provider.dart';
import 'package:questkids/features/profile/screens/settings_screen.dart';

void main() {
  testWidgets('SettingsScreen toggles dark mode via ThemeProvider', (tester) async {
    final themeProvider = ThemeProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider<ThemeProvider>.value(
        value: themeProvider,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dark Mode'), findsOneWidget);
    final switchFinder = find.byType(Switch);
    expect(switchFinder, findsOneWidget);

    final initial = themeProvider.isDark;
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    expect(themeProvider.isDark, isNot(initial));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/settings_screen_test.dart`
Expected: FAIL — missing `settings_screen.dart`.

- [ ] **Step 3: Implement `SettingsScreen`**

```dart
// lib/features/profile/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/theme_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Appearance', style: AppTextStyles.label),
          const SizedBox(height: 8),
          Card(
            child: SwitchListTile(
              secondary: Icon(
                theme.isDark ? Icons.nightlight_round : Icons.wb_sunny,
                color: AppColors.primary,
              ),
              title: Text('Dark Mode', style: AppTextStyles.bodyMedium),
              subtitle: Text(
                theme.isDark ? 'On' : 'Off',
                style: AppTextStyles.bodySmall,
              ),
              value: theme.isDark,
              onChanged: (_) => theme.toggleTheme(),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widgets/settings_screen_test.dart`
Expected: PASS

- [ ] **Step 5: Register the route and add a profile entry point**

In `lib/main.dart`, add to `routes:`:

```dart
        '/settings': (_) => const SettingsScreen(),
```

with import `import 'features/profile/screens/settings_screen.dart';`.

In `lib/features/profile/screens/profile_screen.dart`, add a settings entry point after the `Divider()` that follows the "Preferences" language dropdown (after line 96, before the `SizedBox(height: 24)` at line 97):

```dart
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.settings_outlined, color: AppColors.primary),
            title: Text('Settings', style: AppTextStyles.bodyMedium),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, '/settings'),
          ),
```

- [ ] **Step 6: Verify navigation manually**

Run: `flutter run -d chrome`. Navigate to the standalone `ProfileScreen` (or wherever it's reachable in the current nav — confirm via `grep -r ProfileScreen lib/` if unsure which route/tab renders it), tap "Settings", confirm the Settings screen opens and the dark-mode switch toggles the whole app's theme live.

- [ ] **Step 7: `flutter analyze` clean, then commit**

```bash
flutter analyze
git add lib/features/profile/screens/settings_screen.dart lib/main.dart lib/features/profile/screens/profile_screen.dart test/widgets/settings_screen_test.dart
git commit -m "feat(profile): add Settings screen with dark mode toggle"
```

---

### Task 9: Side Menu (`Drawer`) for the learner dashboard

**Why this is needed:** The Phase 1 spec explicitly lists "Side Menu" as a required nav surface. `ResponsiveScaffold` currently only produces a `BottomNavigationBar` (narrow) or `NavigationRail` (wide) — there is no `Drawer` anywhere in the app. Add an optional `drawer` slot to `ResponsiveScaffold` and a `AppSideMenu` widget surfacing the items that don't fit the 6-tab bottom nav (Settings, Notifications, Offline sync status already have tabs — so this menu covers Help/About and Sign Out, avoiding duplicating existing tabs).

**Files:**
- Create: `lib/core/widgets/app_side_menu.dart`
- Modify: `lib/core/widgets/responsive_scaffold.dart` (add `drawer` parameter, pass through to both `Scaffold`s)
- Modify: `lib/features/dashboard/screens/learner_dashboard.dart` (wire `AppSideMenu` in, add a menu button to the AppBar)

**Interfaces:**
- Consumes: `AuthProvider` (`context.read<AuthProvider>().signOut()`), `AppDialog.confirm` (Task 2, for the sign-out confirmation — same call built in Task 10, reused here).
- Produces: `AppSideMenu({required dynamic user})` — a `Drawer`.

- [ ] **Step 1: Add `drawer` to `ResponsiveScaffold`**

In `lib/core/widgets/responsive_scaffold.dart`, add a field and constructor parameter:

```dart
  final Widget? drawer;
```

(add after `final Widget? floatingActionButton;` at line 30), and in the constructor (line 32-40) add `this.drawer,`.

Then pass it through to both returned `Scaffold`s — add `drawer: drawer,` to the narrow-layout `Scaffold` (after `appBar: appBar,` at line 51) and to the wide-layout `Scaffold` (after `appBar: appBar,` at line 70).

- [ ] **Step 2: Implement `AppSideMenu`**

```dart
// lib/core/widgets/app_side_menu.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../../providers/auth_provider.dart';
import 'app_dialog.dart';

class AppSideMenu extends StatelessWidget {
  final dynamic user;

  const AppSideMenu({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, Color(0xFF9C27B0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.white24,
                    backgroundImage:
                        user?.avatarUrl != null ? NetworkImage(user!.avatarUrl!) : null,
                    child: user?.avatarUrl == null
                        ? Text(
                            user?.name?.isNotEmpty == true
                                ? user!.name[0].toUpperCase()
                                : '?',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      user?.name ?? 'Learner',
                      style: AppTextStyles.h4.copyWith(color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined, color: AppColors.primary),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/settings');
              },
            ),
            ListTile(
              leading: const Icon(Icons.help_outline, color: AppColors.primary),
              title: const Text('Help & About'),
              onTap: () {
                Navigator.pop(context);
                showAboutDialog(
                  context: context,
                  applicationName: 'QuestKids',
                  applicationVersion: '2.0.0',
                  applicationLegalese: 'Learn. Play. Grow.',
                );
              },
            ),
            const Spacer(),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.error),
              title: const Text('Sign Out', style: TextStyle(color: AppColors.error)),
              onTap: () async {
                Navigator.pop(context);
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
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Wire the drawer into the learner dashboard**

In `lib/features/dashboard/screens/learner_dashboard.dart`, add `drawer: AppSideMenu(user: user),` to the `ResponsiveScaffold(...)` call (after `onDestinationSelected:` at line 82), and add a menu `IconButton` as the AppBar's `leading` widget (the `AppBar` currently has no `leading:` — add it after `title:` closes, before `elevation: 2,` at line 121):

```dart
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
```

Add `import '../../../core/widgets/app_side_menu.dart';` at the top.

- [ ] **Step 4: Verify manually**

Run: `flutter run -d chrome`. Confirm the hamburger icon opens the drawer, "Settings" navigates to `/settings`, "Help & About" opens the standard `AboutDialog`, and "Sign Out" shows the confirm dialog then signs out and returns to `/login` when confirmed.

- [ ] **Step 5: `flutter analyze` clean, then commit**

```bash
flutter analyze
git add lib/core/widgets/app_side_menu.dart lib/core/widgets/responsive_scaffold.dart lib/features/dashboard/screens/learner_dashboard.dart
git commit -m "feat(ui): add side menu (Drawer) with settings/help/sign-out"
```

---

### Task 10: Sign-out confirmation on the standalone Profile screens

**Why this is needed:** `profile_screen.dart:98-106` and `learner_dashboard.dart`'s `_ProfileTab` (lines 1208-1224) both call `auth.signOut()` directly with no confirmation — a single misplaced tap logs the learner out. Task 9 already added a confirmed sign-out inside `AppSideMenu`; this task applies the same `AppDialog.confirm` pattern to the two remaining direct-call sites so all three sign-out paths behave consistently.

**Files:**
- Modify: `lib/features/profile/screens/profile_screen.dart:98-106`
- Modify: `lib/features/dashboard/screens/learner_dashboard.dart:1208-1224` (`_ProfileTab`'s sign-out button)

**Interfaces:**
- Consumes: `AppDialog.confirm` (Task 2), `AppButton` (Task 1, replacing the raw `OutlinedButton.icon` in both spots for consistent styling — `AppButton` does not currently expose an `.icon` + `danger` combination test in Task 1, but does support `variant: AppButtonVariant.danger` + `icon:` together, so no widget change is needed here).

- [ ] **Step 1: Update `profile_screen.dart`**

Replace lines 98-106:

```dart
          OutlinedButton.icon(
            onPressed: () => auth.signOut(),
            icon: const Icon(Icons.logout, color: AppColors.error),
            label: const Text('Sign Out',
                style: TextStyle(color: AppColors.error)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.error),
            ),
          ),
```

with:

```dart
          AppButton(
            label: 'Sign Out',
            icon: Icons.logout,
            variant: AppButtonVariant.danger,
            fullWidth: false,
            onPressed: () async {
              final confirmed = await AppDialog.confirm(
                context,
                title: 'Sign Out',
                message: 'Are you sure you want to sign out?',
                confirmLabel: 'Sign Out',
                isDanger: true,
              );
              if (confirmed) await auth.signOut();
            },
          ),
```

Add imports `import '../../../core/widgets/app_button.dart';` and `import '../../../core/widgets/app_dialog.dart';`.

- [ ] **Step 2: Update `learner_dashboard.dart`'s `_ProfileTab`**

Replace lines 1208-1224:

```dart
            child: OutlinedButton.icon(
              onPressed: () {
                auth.signOut();
                Navigator.pushNamedAndRemoveUntil(
                    context, '/login', (route) => false);
              },
              icon: const Icon(Icons.logout, color: AppColors.error),
              label: const Text('Sign Out',
                  style: TextStyle(color: AppColors.error)),
              style: OutlinedButton.styleFrom(
                minimumSize: Size(isMobile ? double.infinity : 200, 52),
                side: const BorderSide(color: AppColors.error, width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
```

with:

```dart
            child: AppButton(
              label: 'Sign Out',
              icon: Icons.logout,
              variant: AppButtonVariant.danger,
              fullWidth: isMobile,
              onPressed: () async {
                final confirmed = await AppDialog.confirm(
                  context,
                  title: 'Sign Out',
                  message: 'Are you sure you want to sign out?',
                  confirmLabel: 'Sign Out',
                  isDanger: true,
                );
                if (confirmed && context.mounted) {
                  await auth.signOut();
                  if (context.mounted) {
                    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                  }
                }
              },
            ),
```

(Add the same two imports as Step 1 if not already present in this file.)

- [ ] **Step 3: Verify manually**

Run: `flutter run -d chrome`. From both the standalone Profile screen and the dashboard's Profile tab, tap Sign Out, confirm the dialog appears, cancel it and confirm you're still signed in, then confirm it and confirm you land on `/login`.

- [ ] **Step 4: `flutter analyze` clean, then commit**

```bash
flutter analyze
git add lib/features/profile/screens/profile_screen.dart lib/features/dashboard/screens/learner_dashboard.dart
git commit -m "feat(ui): require confirmation before signing out"
```

---

### Task 11: Unknown-route / 404 error page

**Why this is needed:** `MaterialApp` in `main.dart` defines `routes:` and `home:` but no `onUnknownRoute`. Any bad/stale deep link (e.g. an old push-notification payload pointing at a route removed in a future refactor) currently crashes with Flutter's default "black screen with red Navigator assertion" in debug, or a blank screen in release — this is the literal "Error Pages" gap named in the Phase 1 spec.

**Files:**
- Modify: `lib/main.dart` (add `onUnknownRoute`)
- Test: `test/main/unknown_route_test.dart`

**Interfaces:**
- Consumes: `AppErrorView` (Task 2), `AppButton` (transitively, via `AppErrorView`'s retry button).

- [ ] **Step 1: Write the failing test**

```dart
// test/main/unknown_route_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/core/widgets/app_error_view.dart';

void main() {
  testWidgets('onUnknownRoute shows AppErrorView with a Go Home action',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      initialRoute: '/this-route-does-not-exist',
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

    expect(find.text('Page Not Found'), findsOneWidget);
    expect(find.byType(AppErrorView), findsOneWidget);

    await tester.tap(find.text('Try Again'));
    await tester.pumpAndSettle();
    expect(find.text('Login'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/main/unknown_route_test.dart`
Expected: FAIL — `AppErrorView` not found until Task 2 is done (if Task 2 is already complete by this point in execution order, it will instead fail because `onUnknownRoute` isn't wired into the real `main.dart` `MaterialApp` yet — this test defines the wiring inline first, matching TDD-for-config style, then Step 3 moves the same logic into `main.dart`).

- [ ] **Step 3: Add `onUnknownRoute` to the real `MaterialApp`**

In `lib/main.dart`, add to the `MaterialApp(...)` (after the `routes: { ... },` map, before the closing `);` at line 69):

```dart
      onUnknownRoute: (settings) => MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Page Not Found')),
          body: AppErrorView(
            message: "We couldn't find that page.",
            onRetry: () => Navigator.pushNamedAndRemoveUntil(
              context,
              '/login',
              (route) => false,
            ),
          ),
        ),
      ),
```

Add `import 'core/widgets/app_error_view.dart';` at the top.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/main/unknown_route_test.dart`
Expected: PASS

- [ ] **Step 5: Manual verification against the real route table**

Run: `flutter run -d chrome`, then in the browser address bar (Flutter web) navigate to a nonsense path, e.g. append `#/this-does-not-exist` — confirm "Page Not Found" renders with the friendly `AppErrorView` instead of a crash, and "Try Again" returns to `/login`.

- [ ] **Step 6: `flutter analyze` clean, then commit**

```bash
flutter analyze
flutter test
git add lib/main.dart test/main/unknown_route_test.dart
git commit -m "feat(ui): add friendly 404/unknown-route error page"
```

---

## End-of-Phase Checklist (per project Rule 1 — do not report Phase 1 complete until all of these hold)

- [ ] `flutter analyze` → 0 errors
- [ ] `flutter test` → all green, including the 6 new test files this plan adds
- [ ] `flutter run -d chrome` boots to splash → login with no red screen, in both light and dark mode
- [ ] Login, Register (all 4 steps, both parent and teacher paths), Forgot Password (both entry points: pushed from login, and `/forgot_password` named route) all complete successfully against a real Firebase Auth test account
- [ ] Dark mode: login toggle pills, register role/parent cards, date pickers all render correctly (no white-on-dark or dark-text-on-dark)
- [ ] Settings screen reachable from Profile, dark-mode toggle there and the dashboard AppBar toggle stay in sync (same `ThemeProvider` instance)
- [ ] Side menu opens from the dashboard hamburger icon; Settings/Help/Sign-Out all work
- [ ] Sign-out requires confirmation in all three places it's offered (side menu, standalone Profile screen, dashboard Profile tab)
- [ ] Navigating to a nonexistent route shows the friendly error page, not a crash
- [ ] No files matching forbidden-secrets patterns were added (`git status` reviewed)
- [ ] Nothing in `lib/features/games/**`, `lib/firebase_options.dart`, `db_bootstrap_*.dart`, or `firestore.rules`/`storage.rules` was touched
