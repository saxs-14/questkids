# Phase 5 — Dark Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dark mode's *infrastructure* is already fully built (`ThemeProvider`, `AppTheme.lightTheme`/`darkTheme`, `SharedPreferences` persistence, a toggle already wired in Settings and the dashboard app bars) — this phase closes the real gaps found by a full-app audit: one **gameplay-breaking bug** (quiz answer text becomes invisible in dark mode), nine other hardcoded-light-color spots that produce washed-out or invisible text/UI, an untheme d third-party calendar widget, and the two remaining spec items that aren't bug fixes — a more "professional, child-friendly" toggle and a smooth (non-instant) theme transition.

**Architecture:** No new theme system — every fix in this plan either (a) branches on `Theme.of(context).brightness`/`isDark` matching the pattern already established throughout the codebase (e.g. `learner_dashboard.dart`'s `_StatsRow`, `child_analytics_screen.dart`'s `_chartCard`), or (b) replaces a hardcoded color with the existing theme-aware equivalent (`Theme.of(context).cardColor`, `AppColors.cardDark`, etc.) that other files in the same codebase already use correctly. Game screens under `lib/features/games/**` are explicitly out of scope — they're intentionally theme-independent by design (CLAUDE.md), not a bug.

**Tech Stack:** Flutter, existing `ThemeProvider`/`AppTheme`/`AppColors`. `AnimatedTheme` (built into Flutter, no new package) for the smooth-transition requirement.

## Global Constraints

- `flutter analyze` → 0 new errors before any commit.
- `flutter test` → all tests green.
- `flutter build web --release` and `flutter build apk --debug` must both succeed before declaring the phase done.
- Do not touch anything under `lib/features/games/` — game screens are intentionally exempt from app theming.
- Do not touch `lib/core/theme/{app_colors,app_theme,theme_provider}.dart`'s existing structure beyond what's needed (e.g. no wholesale rewrite) — the theme system itself is correct, only specific screens misuse/bypass it.
- Commit style: `type(scope): summary`. Small, reviewable commits; run `flutter analyze` before each.
- Given these are targeted color/contrast fixes (not new logic), most tasks are verified via `flutter analyze` + manual/live visual check rather than new unit tests — consistent with how the equivalent Phase 1 login/register dark-mode fixes were verified. Tasks that add new widgets (the toggle) get a real test.

---

## File Structure

New files:
```
lib/core/widgets/theme_toggle.dart       # Task 9
test/widgets/theme_toggle_test.dart      # Task 9
```

Files modified: `lib/features/quests/widgets/question_card.dart`, `lib/features/quests/screens/quests_screen.dart`, `lib/features/grade4/grade4_hub.dart`, `lib/features/auth/screens/parent_child_setup_screen.dart`, `lib/features/dashboard/screens/parent_dashboard.dart`, `lib/features/dashboard/screens/teacher_dashboard.dart`, `lib/features/auth/widgets/role_selector.dart`, `lib/features/auth/widgets/grade_selector.dart`, `lib/features/dashboard/widgets/daily_missions_card.dart`, `lib/features/profile/screens/settings_screen.dart`, `lib/main.dart`.

---

### Task 1: Fix invisible quiz answer text (critical — breaks core gameplay in dark mode)

**Why:** `question_card.dart`'s unselected/unrevealed answer option text is hardcoded to `AppColors.textPrimary` (near-black) sitting on a transparent box over the dark scaffold — near-black text on a near-black background makes every quiz question unreadable in dark mode.

**Files:**
- Modify: `lib/features/quests/widgets/question_card.dart`

- [ ] **Step 1: Read the file in full** to confirm the exact current color-selection logic (the audit found it around line 48, in a function choosing text color per option state — verify against the live file, not the audit's line number, before editing).

- [ ] **Step 2: Make the default text color theme-aware**

Replace the hardcoded `AppColors.textPrimary` return for the default/unselected case with a brightness-aware choice, matching the pattern already used elsewhere in this codebase:

```dart
Theme.of(context).brightness == Brightness.dark
    ? AppColors.textDark
    : AppColors.textPrimary
```

(Adjust to fit the actual function signature — if it's a non-widget helper without a `BuildContext` parameter, thread one through from the calling `build()` method rather than reaching for a global; keep the change minimal and consistent with the file's existing structure.)

- [ ] **Step 3: Manual verification**

Run: `flutter run -d chrome`. Toggle dark mode, start any quiz — confirm answer option text is clearly readable in both themes.

- [ ] **Step 4: `flutter analyze` clean, then commit**

```bash
flutter analyze lib/features/quests/widgets/question_card.dart
git add lib/features/quests/widgets/question_card.dart
git commit -m "fix(darkmode): quiz answer text was near-black on near-black background in dark mode"
```

---

### Task 2: Fix the Game Hub screen ignoring dark mode entirely

**Why:** `quests_screen.dart`'s non-embedded `Scaffold`/`AppBar` are hardcoded to `AppColors.backgroundLight`/`Colors.white`, and its game cards (`_GameCard`) are hardcoded `AppColors.cardLight` — reachable from `learner_dashboard.dart`'s "Start" button (`QuestsScreen()`, non-embedded), so the whole Game Hub ignores dark mode.

**Files:**
- Modify: `lib/features/quests/screens/quests_screen.dart`

- [ ] **Step 1: Read the file in full**, confirm the exact `Scaffold`/`AppBar`/`_GameCard` structure.

- [ ] **Step 2: Make the Scaffold/AppBar theme-aware**

Replace the hardcoded `backgroundColor: AppColors.backgroundLight` and the `AppBar`'s `backgroundColor: Colors.white` with theme-driven values — since `AppTheme` already sets `scaffoldBackgroundColor` and `appBarTheme` per mode, the simplest correct fix is often to **remove the hardcoded overrides entirely** so the `Scaffold`/`AppBar` fall through to the ambient theme (verify this doesn't change the intended light-mode look before removing — if the light-mode color already matches `AppTheme.lightTheme`'s ambient values, removing the override is safe and is the more maintainable fix; if it doesn't match, branch on `isDark` instead).

- [ ] **Step 3: Make `_GameCard` theme-aware**

Replace `color: AppColors.cardLight` with `color: Theme.of(context).brightness == Brightness.dark ? AppColors.cardDark : AppColors.cardLight`, matching the pattern used in `learner_dashboard.dart`'s `_StatsRow`.

- [ ] **Step 4: Manual verification**

Run: `flutter run -d chrome`. Toggle dark mode, navigate to the Game Hub (via the dashboard's daily-challenge "Start" button or Quests tab's "browse all" entry) — confirm the whole screen and every game card follow dark mode.

- [ ] **Step 5: `flutter analyze` clean, then commit**

```bash
flutter analyze lib/features/quests/screens/quests_screen.dart
git add lib/features/quests/screens/quests_screen.dart
git commit -m "fix(darkmode): Game Hub screen and game cards now follow the app theme"
```

---

### Task 3: Fix invisible World Map tile labels (Grade 4 hub)

**Files:**
- Modify: `lib/features/grade4/grade4_hub.dart`

- [ ] **Step 1: Read the file in full**, confirm the exact tile-background logic (`unlocked ? Colors.white : AppColors.surface`).

- [ ] **Step 2: Make tile backgrounds theme-aware**

```dart
color: unlocked
    ? (isDark ? AppColors.cardDark : Colors.white)
    : (isDark ? AppColors.cardDark.withValues(alpha: 0.6) : AppColors.surface),
```

(Derive `isDark` via `Theme.of(context).brightness == Brightness.dark` at the top of the enclosing `build()`, matching the established pattern; adjust exactly to the surrounding widget's structure after reading it.)

- [ ] **Step 3: Manual verification**

Run: `flutter run -d chrome`. Toggle dark mode, open the Grade 4 world map (if reachable from a test account's grade) — confirm location tile labels are readable.

- [ ] **Step 4: `flutter analyze` clean, then commit**

```bash
flutter analyze lib/features/grade4/grade4_hub.dart
git add lib/features/grade4/grade4_hub.dart
git commit -m "fix(darkmode): World Map tile labels were near-invisible on their hardcoded light backgrounds"
```

---

### Task 4: Fix washed-out text on the parent-child linking card

**Files:**
- Modify: `lib/features/auth/screens/parent_child_setup_screen.dart`

- [ ] **Step 1: Read the file in full**, confirm the exact `Card(color: AppColors.surface, ...)` block (audit found it around line 167).

- [ ] **Step 2: Make the card theme-aware**

```dart
Card(
  color: Theme.of(context).brightness == Brightness.dark
      ? AppColors.cardDark
      : AppColors.surface,
  ...
)
```

- [ ] **Step 3: Manual verification + `flutter analyze` clean, then commit**

```bash
flutter analyze lib/features/auth/screens/parent_child_setup_screen.dart
git add lib/features/auth/screens/parent_child_setup_screen.dart
git commit -m "fix(darkmode): parent-child linking card text was washed out on a fixed light background"
```

---

### Task 5: Fix near-invisible headings on the parent dashboard Home tab

**Why:** The child-switcher card, "Add Child" card, and "No child selected" card all use `color: AppColors.surface` (fixed light) while their text is theme-adaptive (near-white in dark mode) — three spots in the same file.

**Files:**
- Modify: `lib/features/dashboard/screens/parent_dashboard.dart`

- [ ] **Step 1: Read the relevant section of `_ParentHomeTab` in full** (the audit found the three `AppColors.surface` cards around lines 514, 543, 605).

- [ ] **Step 2: Make all three cards theme-aware**, using the same `isDark ? AppColors.cardDark : AppColors.surface` branch as Task 4, deriving `isDark` once at the top of `_ParentHomeTabState.build()` and reusing it for all three (avoid recomputing `Theme.of(context).brightness` three separate times inline — this file already has a `final isMobile = ...` pattern at the top of `build()` to follow).

- [ ] **Step 3: Manual verification + `flutter analyze` clean, then commit**

```bash
flutter analyze lib/features/dashboard/screens/parent_dashboard.dart
git add lib/features/dashboard/screens/parent_dashboard.dart
git commit -m "fix(darkmode): parent dashboard Home tab cards had invisible headings in dark mode"
```

---

### Task 6: Theme the parent Calendar tab's `TableCalendar`

**Why:** `table_calendar`'s default `DaysOfWeekStyle` uses hardcoded dark greys for weekday/weekend labels, which have very low contrast against the app's near-black dark scaffold.

**Files:**
- Modify: `lib/features/dashboard/screens/parent_dashboard.dart` (same file as Task 5 — can be the same commit if convenient, but written as its own step for clarity)

- [ ] **Step 1: Read the `TableCalendar(...)` widget's current configuration in full** (audit found it around line 352).

- [ ] **Step 2: Add theme-aware `calendarStyle`/`daysOfWeekStyle`**

```dart
TableCalendar(
  // ...existing params...
  daysOfWeekStyle: DaysOfWeekStyle(
    weekdayStyle: TextStyle(color: isDark ? AppColors.textDark : AppColors.textPrimary),
    weekendStyle: TextStyle(color: isDark ? AppColors.primaryLight : AppColors.primary),
  ),
  calendarStyle: CalendarStyle(
    defaultTextStyle: TextStyle(color: isDark ? AppColors.textDark : AppColors.textPrimary),
    weekendTextStyle: TextStyle(color: isDark ? AppColors.primaryLight : AppColors.primary),
    todayDecoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
    selectedDecoration: const BoxDecoration(color: AppColors.primaryDark, shape: BoxShape.circle),
  ),
)
```

(Match parameter names exactly to the installed `table_calendar` version's API — verify via the package's actual class definitions if the above names don't compile, rather than guessing further.)

- [ ] **Step 3: Manual verification**

Run: `flutter run -d chrome`. As a parent, toggle dark mode, open the Calendar tab — confirm weekday headers and day numbers are readable.

- [ ] **Step 4: `flutter analyze` clean, then commit**

```bash
flutter analyze lib/features/dashboard/screens/parent_dashboard.dart
git add lib/features/dashboard/screens/parent_dashboard.dart
git commit -m "fix(darkmode): theme the parent Calendar tab's TableCalendar (was using low-contrast default greys)"
```

---

### Task 7: Fix teacher dashboard dark-mode contrast issues

**Why:** Three spots in one file: a hardcoded light-grey XP progress-bar track (on an otherwise theme-aware card), and two bottom-sheet drag handles using 26%-opacity black (invisible on the dark sheet surface).

**Files:**
- Modify: `lib/features/dashboard/screens/teacher_dashboard.dart`

- [ ] **Step 1: Read the three relevant sections in full** (audit found: `_LearnerCard`'s progress track ~line 764; `_LearnerDetailSheet`'s drag handle ~line 832; `_CreateActivitySheet`'s drag handle ~line 1388).

- [ ] **Step 2: Fix the progress-bar track**

Replace `color: Colors.grey.shade200` with a theme-aware track color, matching the card's own already-correct `Theme.of(context).cardColor` pattern in the same widget (e.g. `Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.12) : Colors.grey.shade200`, mirroring `_SubjectProgressBar`'s track-color branch already used in `learner_dashboard.dart`).

- [ ] **Step 3: Fix both drag handles**

Replace each `color: Colors.black26` with a theme-aware handle color: `Theme.of(context).brightness == Brightness.dark ? Colors.white24 : Colors.black26`.

- [ ] **Step 4: Manual verification + `flutter analyze` clean, then commit**

```bash
flutter analyze lib/features/dashboard/screens/teacher_dashboard.dart
git add lib/features/dashboard/screens/teacher_dashboard.dart
git commit -m "fix(darkmode): teacher dashboard progress-bar track and bottom-sheet drag handles were invisible in dark mode"
```

---

### Task 8: Fix low-contrast unselected role/grade selector chips

**Why:** Shared by `register_screen.dart`, `parent_child_setup_screen.dart`, and `edit_profile_screen.dart` — unselected chip text is hardcoded `AppColors.textPrimary` (dark navy) on a background that's ~92% transparent over the dark scaffold, producing low-contrast text.

**Files:**
- Modify: `lib/features/auth/widgets/role_selector.dart`
- Modify: `lib/features/auth/widgets/grade_selector.dart`

- [ ] **Step 1: Read both files in full** (audit found the unselected-label color branch at `role_selector.dart:67` and `grade_selector.dart:58`, both of the shape `color: isSelected ? Colors.white : AppColors.textPrimary`).

- [ ] **Step 2: Make the unselected label color theme-aware in both files**

```dart
color: isSelected
    ? Colors.white
    : (Theme.of(context).brightness == Brightness.dark
        ? AppColors.textDark
        : AppColors.textPrimary),
```

- [ ] **Step 3: Manual verification**

Run: `flutter run -d chrome`. Toggle dark mode, open Register (role selector, step 0) and Edit Profile (grade selector) — confirm unselected chip labels are readable.

- [ ] **Step 4: `flutter analyze` clean, then commit**

```bash
flutter analyze lib/features/auth/widgets/role_selector.dart lib/features/auth/widgets/grade_selector.dart
git add lib/features/auth/widgets/role_selector.dart lib/features/auth/widgets/grade_selector.dart
git commit -m "fix(darkmode): role/grade selector chips had low-contrast unselected labels"
```

---

### Task 9: Polished, "professional" animated theme toggle

**Why:** The Phase 5 spec explicitly asks for a "professional toggle" and "child-friendly design" — today it's a bare `SwitchListTile` in Settings and a plain sun/moon `IconButton` in dashboard app bars, both functionally correct but not a designed toggle component. This also folds in Task 11's minor `daily_missions_card.dart` white-overlay flag as a drive-by fix since it's touched while auditing nearby dashboard chrome.

**Files:**
- Create: `lib/core/widgets/theme_toggle.dart`
- Test: `test/widgets/theme_toggle_test.dart`
- Modify: `lib/features/profile/screens/settings_screen.dart`
- Modify: `lib/features/dashboard/widgets/daily_missions_card.dart`

**Interfaces:**
- Produces: `ThemeToggle extends StatelessWidget` — an animated pill-shaped switch (sun/moon icon slides + crossfades between positions using `AnimatedAlign`/`AnimatedSwitcher`, ~250ms), reading/calling `ThemeProvider` directly via `context.watch`/`context.read` (no constructor params needed, matching `ProfileSettingsTile`'s self-contained pattern from Phase 3).

- [ ] **Step 1: Write the failing test**

```dart
// test/widgets/theme_toggle_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:questkids/core/theme/theme_provider.dart';
import 'package:questkids/core/widgets/theme_toggle.dart';

void main() {
  testWidgets('ThemeToggle toggles ThemeProvider on tap', (tester) async {
    final theme = ThemeProvider();
    await tester.pumpWidget(
      ChangeNotifierProvider<ThemeProvider>.value(
        value: theme,
        child: const MaterialApp(home: Scaffold(body: ThemeToggle())),
      ),
    );
    await tester.pumpAndSettle();

    final initial = theme.isDark;
    await tester.tap(find.byType(ThemeToggle));
    await tester.pumpAndSettle();

    expect(theme.isDark, isNot(initial));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/theme_toggle_test.dart`
Expected: FAIL — file doesn't exist.

- [ ] **Step 3: Implement `ThemeToggle`**

```dart
// lib/core/widgets/theme_toggle.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../theme/theme_provider.dart';

/// A pill-shaped, animated light/dark toggle -- used in Settings and
/// dashboard app bars in place of a bare IconButton/SwitchListTile.
class ThemeToggle extends StatelessWidget {
  const ThemeToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDark;

    return GestureDetector(
      onTap: () => context.read<ThemeProvider>().toggleTheme(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 56,
        height: 30,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: isDark ? AppColors.primaryDark : AppColors.gold.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(20),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          alignment: isDark ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                isDark ? Icons.nightlight_round : Icons.wb_sunny,
                key: ValueKey(isDark),
                size: 16,
                color: isDark ? AppColors.primaryDark : AppColors.goldDark,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widgets/theme_toggle_test.dart`
Expected: PASS

- [ ] **Step 5: Wire it into Settings, replacing the bare `SwitchListTile`**

Read `settings_screen.dart` in full first. Replace the `SwitchListTile(...)` with a `ListTile` whose `trailing: const ThemeToggle()` (keep the leading icon/title/subtitle structure, just swap the interactive control).

- [ ] **Step 6: Drive-by fix — `daily_missions_card.dart`'s white overlay wash**

Read the file, locate the `Colors.white.withValues(alpha: 0.6)` completed-mission overlay (audit found it ~line 187), change to a theme-aware value: `Theme.of(context).brightness == Brightness.dark ? Colors.black.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.6)`.

- [ ] **Step 7: Manual verification**

Run: `flutter run -d chrome`. Open Settings, confirm the new toggle animates smoothly and still persists across app restart (Phase 1/existing `SharedPreferences` persistence is unchanged — only the visual control changed).

- [ ] **Step 8: `flutter analyze` clean, then commit**

```bash
flutter analyze lib/core/widgets/theme_toggle.dart lib/features/profile/screens/settings_screen.dart lib/features/dashboard/widgets/daily_missions_card.dart
git add lib/core/widgets/theme_toggle.dart lib/features/profile/screens/settings_screen.dart lib/features/dashboard/widgets/daily_missions_card.dart test/widgets/theme_toggle_test.dart
git commit -m "feat(darkmode): add a polished animated ThemeToggle, replacing the bare SwitchListTile"
```

---

### Task 10: Smooth (non-instant) theme transition

**Why:** Toggling dark mode today is an instant, jarring color swap — `MaterialApp` has no `AnimatedTheme`/transition wrapper anywhere.

**Files:**
- Modify: `lib/main.dart`

**Interfaces:**
- Wraps `QuestKidsApp`'s `MaterialApp`'s `home`/`routes` content in an `AnimatedTheme` so theme-dependent colors crossfade instead of snapping — `MaterialApp` itself doesn't support animating `theme`/`darkTheme` directly, so the standard approach is a `Builder`/`AnimatedTheme` immediately inside `MaterialApp.builder`.

- [ ] **Step 1: Read the current `QuestKidsApp.build()` in full.**

- [ ] **Step 2: Add an `AnimatedTheme` via `MaterialApp.builder`**

```dart
return MaterialApp(
  navigatorKey: navigatorKey,
  title: 'QuestKids',
  debugShowCheckedModeBanner: false,
  theme: AppTheme.lightTheme,
  darkTheme: AppTheme.darkTheme,
  themeMode: themeProvider.themeMode,
  builder: (context, child) {
    return AnimatedTheme(
      data: themeProvider.isDark ? AppTheme.darkTheme : AppTheme.lightTheme,
      duration: const Duration(milliseconds: 300),
      child: child!,
    );
  },
  home: const SplashScreen(),
  routes: { /* unchanged */ },
  onUnknownRoute: /* unchanged */,
);
```

(This layers a second, animated `Theme` inside the tree that crossfades `ThemeData` properties like colors over 300ms, while `MaterialApp`'s own `theme`/`darkTheme`/`themeMode` continue to provide the correct instant fallback/base — verify visually that this doesn't produce a double-theme conflict; if it does, the alternative is wrapping only specific screens' backgrounds in `AnimatedContainer` instead of a global `AnimatedTheme` — prefer the global approach first since it's the standard Flutter pattern for this exact requirement.)

- [ ] **Step 3: Manual verification**

Run: `flutter run -d chrome`. Toggle dark mode from Settings — confirm the color change crossfades smoothly rather than snapping instantly, and that no screen looks broken/double-rendered immediately after toggling.

- [ ] **Step 4: `flutter analyze` clean, then commit**

```bash
flutter analyze lib/main.dart
git add lib/main.dart
git commit -m "feat(darkmode): smooth crossfade transition when toggling theme instead of an instant snap"
```

---

## End-of-Phase Checklist

- [ ] `flutter analyze` → 0 new errors
- [ ] `flutter test` → all green, including the new `ThemeToggle` test
- [ ] `flutter build web --release` and `flutter build apk --debug` both succeed
- [ ] Quiz answer text is readable in dark mode (critical gameplay fix)
- [ ] Game Hub screen, World Map tiles, parent dashboard Home/Calendar tabs, teacher dashboard cards/sheets, and role/grade selector chips all render correctly in dark mode
- [ ] Dark mode toggle is visually polished (animated pill/icon, not a bare switch) and still persists across restarts
- [ ] Theme changes crossfade smoothly instead of snapping instantly
- [ ] No files matching forbidden-secrets patterns were added
- [ ] `lib/features/games/**` was not touched
