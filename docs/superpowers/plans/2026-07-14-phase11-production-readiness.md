# Phase 11 — Production Readiness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the one real data-exposure gap found in a full production-readiness audit (any teacher can currently read every learner's data, not just learners they've added), and add the missing production observability/safety infrastructure the audit found completely absent: crash reporting, analytics, App Check client wiring, and CI. Genuinely user-blocked items (release keystore, hosted privacy policy, App Check console enablement, dev/prod project separation) are explicitly out of scope for code changes and are instead written up as a clear pre-launch punch list in the phase report.

**Architecture:** No new engines, no UI redesign. Four independent workstreams:
1. **Security fix** — scope four `firestore.rules` teacher-read blocks to `linkedTeacherUids` array membership on the target learner's own doc, mirroring the exact pattern already used for parents (`linkedChildrenUids`). This uses data the app already writes (`teacher_dashboard.dart`'s `_showAddLearnerDialog`) — no new data model field, no new custom claim, no Cloud Function change.
2. **Crash reporting** — `firebase_crashlytics`, wired into `FlutterError.onError` and `PlatformDispatcher.instance.onError` in `main.dart`.
3. **Analytics** — `firebase_analytics` (already a dependency, currently unused) wired via a `FirebaseAnalyticsObserver` on `MaterialApp.navigatorObservers` for automatic screen tracking, plus a small `AnalyticsService` wrapper called from 4 existing chokepoints (signup, login, game session complete, quest complete).
4. **App Check client + CI** — add the `firebase_app_check` package and initialize it in debug mode (the existing server-side `ENFORCE_APP_CHECK` flag stays `false`, so this is inert until a future deploy flips it — see the punch list). Add a GitHub Actions workflow running `flutter analyze`/`flutter test` and `functions`' `build`/`lint` on every push.

**Tech Stack:** Flutter/Dart, Firestore Security Rules, Firebase Crashlytics/Analytics/App Check Flutter packages, GitHub Actions YAML.

## Global Constraints

- `flutter analyze` → 0 errors before every commit (60 pre-existing info lints is the current baseline).
- `flutter test` → all green after every task.
- No `GameCatalogEntry`/content changes in this phase — this phase touches only `lib/main.dart`, `lib/core/services/`, `firestore.rules`, `pubspec.yaml`, Android Gradle files, and new CI/service files.
- `ENFORCE_APP_CHECK` (`functions/src/config.ts:17`) must stay `false` after this phase — do not flip it. Enabling enforcement requires configuring Play Integrity/App Attest/reCAPTCHA in the Firebase Console first (a user action, tracked in the phase report, not this plan).
- Do not author real Privacy Policy / Terms of Service legal text, and do not attempt to provision a second Firebase project — both are explicitly out of scope (see Goal).
- Firestore rules changes should be validated by careful manual trace (this repo has no `@firebase/rules-unit-testing` emulator test harness — consistent with how Phase 9's rules changes were verified) and flagged for emulator testing before deploy, per CLAUDE.md's own Definition of Done §9 point 6.

---

## Task 1: Fix teacher data-exposure gap in Firestore rules

**Files:**
- Modify: `firestore.rules`

**Interfaces:**
- Consumes: the existing `linkedTeacherUids` array field on `users/{uid}` learner docs, already written by `teacher_dashboard.dart`'s `_showAddLearnerDialog` via `FieldValue.arrayUnion([teacherUid])` — confirmed the only writer of this field.
- Produces: nothing consumed by later tasks in this plan — this is a standalone rules change.

- [ ] **Step 1: Remove the now-superseded `isTeacherOfClass` helper and its TODO markers**

In `firestore.rules`, delete the `isTeacherOfClass` function (currently unused — zero callers anywhere in the file) and its preceding TODO comment:

```
// TODO(data-model): once classId is stored per-learner, replace this with
// a match on request.auth.token.classId == resource.data.classId so
// teacher reads are scoped to their own class instead of relying on a
// higher-level check at the call site.
function isTeacherOfClass(classId) {
  return isTeacher() && request.auth.token.classId == classId;
}
```

(This function described a *future* classId-based model that was never built — no UI, no data field, no custom claim ever implemented it. The fix below uses the relationship data that already exists today instead.)

- [ ] **Step 2: Scope the `users/{uid}` teacher-read rule**

Replace:

```
      // TODO(data-model): scope this to the teacher's own class once
      // learner docs carry a classId field — see isTeacherOfClass().
      allow read: if isTeacher();
```

with:

```
      // Teachers can read learners they have actually added (the
      // linkedTeacherUids array is written by
      // teacher_dashboard.dart's _showAddLearnerDialog) -- not every
      // learner in the system.
      allow read: if isTeacher() &&
                      request.auth.uid in resource.data.linkedTeacherUids;
```

- [ ] **Step 3: Scope the `game_sessions/{sessionId}` teacher-read rule**

Replace:

```
      // TODO(data-model): scope to teacher's own class once sessions carry classId.
      allow read: if isTeacher();
```

with:

```
      // Teachers can read sessions belonging to learners they've added --
      // look up the learner's own linkedTeacherUids (game_sessions docs
      // don't carry that array themselves, only the learner's uid).
      allow read: if isTeacher() &&
                      request.auth.uid in
                        get(/databases/$(database)/documents/users/$(resource.data.uid)).data.linkedTeacherUids;
```

- [ ] **Step 4: Scope the `player_stats/{uid}` teacher-read rule**

Replace:

```
      // TODO(data-model): scope to teacher's own class once player_stats carry classId.
      allow read: if isTeacher();
```

with:

```
      // uid here is the learner's own uid (player_stats is keyed by it),
      // so look up that learner's linkedTeacherUids directly.
      allow read: if isTeacher() &&
                      request.auth.uid in
                        get(/databases/$(database)/documents/users/$(uid)).data.linkedTeacherUids;
```

- [ ] **Step 5: Scope the `game_progress/{uid}/engines/{engineType}` teacher-read rule**

Replace:

```
        // TODO(data-model): scope to teacher's own class once game_progress carries classId.
        allow read: if isTeacher();
```

with:

```
        // uid here is the learner's own uid (game_progress is keyed by
        // it), so look up that learner's linkedTeacherUids directly.
        allow read: if isTeacher() &&
                        request.auth.uid in
                          get(/databases/$(database)/documents/users/$(uid)).data.linkedTeacherUids;
```

- [ ] **Step 6: Trace-verify the change by hand**

For each of the 4 scoped rules above, confirm by reading the surrounding `match` block:
1. The `get()` path targets `users/{learnerUid}` where `learnerUid` is genuinely the learner's uid in that collection (not the requesting teacher's uid) — `resource.data.uid` for `game_sessions` (a foreign-key field), `uid` (the path segment itself) for `player_stats`/`game_progress`.
2. `request.auth.uid in ...linkedTeacherUids` fails closed (denies read) if the field is absent (a learner never linked to any teacher) — Firestore rules' `in` operator on a missing/null field evaluates false-ish/denies rather than granting access; this is the same pattern already relied on by the existing, already-shipped `isParent()` rules using `linkedChildrenUids`, so it's a proven-safe pattern in this codebase, not a new risk.
3. No rule in the file still references `isTeacherOfClass` (grep to confirm zero matches remain after Step 1).

Run: `grep -n "isTeacherOfClass\|classId" firestore.rules`
Expected: no output (both fully removed).

- [ ] **Step 7: Commit**

```bash
git add firestore.rules
git commit -m "$(cat <<'EOF'
fix(rules): scope teacher reads to learners they've actually added

Previously any authenticated teacher could read every learner's
users/, game_sessions/, player_stats/, and game_progress/ docs --
completely unscoped (allow read: if isTeacher();), a real data
exposure for a children's app. Fixed using data that already exists:
linkedTeacherUids, written whenever a teacher adds a learner via
teacher_dashboard.dart's _showAddLearnerDialog, mirroring the exact
pattern already used for parents (linkedChildrenUids).

Removes the unused isTeacherOfClass() stub and its TODO markers,
which described a classId-based model that was never actually built
(no data field, no custom claim, no UI ever implemented it) -- the
array-membership check above uses the real, already-shipped
teacher-learner relationship instead.

Not yet deployed -- validate in the Firebase emulator before
`firebase deploy --only firestore:rules` per CLAUDE.md's Definition
of Done.
EOF
)"
```

---

## Task 2: Add Firebase Crashlytics

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/main.dart`
- Modify: `android/settings.gradle.kts`
- Modify: `android/app/build.gradle.kts`

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: nothing consumed by later tasks — standalone infra addition.

- [ ] **Step 1: Add the Dart package**

Run: `flutter pub add firebase_crashlytics`
Expected: `pubspec.yaml` gains a `firebase_crashlytics: ^X.Y.Z` line (pub resolves the version compatible with this project's `firebase_core: ^3.0.0`); `flutter pub get` runs automatically and succeeds.

- [ ] **Step 2: Add the Android Gradle plugin**

In `android/settings.gradle.kts`, add the Crashlytics Gradle plugin next to the existing `google-services` entry:

```kotlin
plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    // START: FlutterFire Configuration
    id("com.google.gms.google-services") version("4.3.15") apply false
    id("com.google.firebase.crashlytics") version("3.0.2") apply false
    // END: FlutterFire Configuration
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}
```

In `android/app/build.gradle.kts`, apply it in the app module's plugins block:

```kotlin
plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}
```

If `flutter build apk --debug` in Step 4 fails with a Gradle plugin resolution error naming a different required version, update the version number in `settings.gradle.kts` to whatever the error message specifies as compatible — Google occasionally revises the minimum compatible Crashlytics Gradle plugin version faster than this plan can track.

- [ ] **Step 3: Wire up global error handling in main.dart**

In `lib/main.dart`, add the import and initialize Crashlytics right after `Firebase.initializeApp`, capturing both Flutter framework errors and uncaught async/platform errors:

```dart
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
```

```dart
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Route every uncaught Flutter framework error to Crashlytics instead of
  // just printing to the console, so crashes are visible after launch.
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    FirebaseCrashlytics.instance.recordFlutterFatalError(details);
  };
  // Catches errors outside the Flutter framework's own error zone (e.g.
  // from a Future that isn't awaited) that FlutterError.onError misses.
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  FirebaseFirestore.instance.settings = const Settings(
```

Add the `dart:ui` import for `PlatformDispatcher` if not already present (check the top of `main.dart` first — `flutter/material.dart` re-exports `dart:ui` symbols including `PlatformDispatcher`, so no separate import should be needed; confirm via `flutter analyze` in Step 4 rather than adding a speculative import).

- [ ] **Step 4: Verify the app still builds**

Run: `flutter analyze`
Expected: 0 errors, same 60 pre-existing info lints (or a `PlatformDispatcher` undefined-name error if the note in Step 3 was wrong — in that case add `import 'dart:ui';` to `main.dart` and re-run).

Run: `flutter build apk --debug`
Expected: succeeds. This is the step that actually exercises the new Gradle plugin wiring from Step 2 — a plugin version mismatch will surface here as a Gradle sync/build failure, not in `flutter analyze`.

- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/main.dart android/settings.gradle.kts android/app/build.gradle.kts
git commit -m "$(cat <<'EOF'
feat(observability): add Firebase Crashlytics

Previously zero crash visibility -- a crash in production would be
invisible unless a user happened to report it. Wires
FlutterError.onError and PlatformDispatcher.instance.onError so both
Flutter framework errors and uncaught async/platform errors reach
Crashlytics.

Requires enabling Crashlytics in the Firebase Console (free, one
click) before it will actually report -- see the phase report's
pre-launch punch list.
EOF
)"
```

---

## Task 3: Wire up baseline Firebase Analytics

**Files:**
- Create: `lib/core/services/analytics_service.dart`
- Modify: `lib/main.dart`
- Modify: `lib/providers/auth_provider.dart`
- Modify: `lib/features/games/core/game_session_state.dart`

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: `AnalyticsService` — a static-method wrapper (`AnalyticsService.logSignUp(role)`, `AnalyticsService.logLogin(role)`, `AnalyticsService.logGameComplete({required String engineType, required String subject, required int score})`, `AnalyticsService.logQuestComplete(String catalogId)`) that later tasks/phases can extend with more events without touching call sites' surrounding logic.

- [ ] **Step 1: Create the analytics service wrapper**

```dart
// lib/core/services/analytics_service.dart
import 'package:firebase_analytics/firebase_analytics.dart';

/// Thin wrapper around FirebaseAnalytics so call sites never touch the
/// FirebaseAnalytics singleton directly -- keeps event names and
/// parameter shapes centralized in one file as the event set grows.
class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// Attached to MaterialApp.navigatorObservers for automatic screen-view
  /// tracking -- no per-screen instrumentation needed.
  static FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  static Future<void> logSignUp(String role) =>
      _analytics.logSignUp(signUpMethod: role);

  static Future<void> logLogin(String role) =>
      _analytics.logLogin(loginMethod: role);

  static Future<void> logGameComplete({
    required String engineType,
    required String subject,
    required int score,
  }) =>
      _analytics.logEvent(name: 'game_session_complete', parameters: {
        'engine_type': engineType,
        'subject': subject,
        'score': score,
      });

  static Future<void> logQuestComplete(String catalogId) =>
      _analytics.logEvent(
          name: 'quest_complete', parameters: {'catalog_id': catalogId});
}
```

- [ ] **Step 2: Attach the screen-view observer in main.dart**

In `lib/main.dart`, import the new service and add the observer to `MaterialApp`. First find the `MaterialApp(` constructor (search for `navigatorKey: navigatorKey` inside it, since `navigatorKey` is already wired there) and add:

```dart
import 'core/services/analytics_service.dart';
```

```dart
      navigatorKey: navigatorKey,
      navigatorObservers: [AnalyticsService.observer],
```

(If `navigatorObservers` already has entries, append to the existing list rather than replacing it — read the surrounding `MaterialApp(...)` block first to confirm.)

- [ ] **Step 3: Log sign-up and login events**

In `lib/providers/auth_provider.dart`, find the methods that complete a successful registration (`registerTeacher`, `registerWithEmail`/similar for parent/learner registration — grep `Future<bool> register` in the file) and the methods that complete a successful login (`loginWithEmail`, `loginChild`, `signInWithGoogle`). After each one's success path (where `_user` is set and `_status = AuthStatus.authenticated`), add the matching call:

```dart
      await AnalyticsService.logSignUp(role);
```

or

```dart
      await AnalyticsService.logLogin(role);
```

using whatever role string is available at that call site (e.g. `'teacher'`, `'parent'`, `'learner'` literal for role-specific methods; `_user!.role` if the method is generic). Add `import '../core/services/analytics_service.dart';` to the top of the file. Wrap each call in the same non-fatal-failure pattern already used elsewhere in this file for `_notificationService.init(...)` (a `try { } catch (_) { }` if the surrounding code isn't already inside one) so an analytics failure can never block a real login/signup.

- [ ] **Step 4: Log game and quest completion**

In `lib/features/games/core/game_session_state.dart`'s `finishSession` method (the same method Task 5 of Phase 8/9 already instruments for reward-granting), add an analytics call inside the existing `if (online)` success branch, right after the existing `_repo.logGameSession(session)` call:

```dart
      if (online) {
        try {
          await _repo.logGameSession(session);
          writeSucceeded = true;
          try {
            await AnalyticsService.logGameComplete(
              engineType: config.engineType,
              subject: config.subject,
              score: _result!.score,
            );
          } catch (_) {
            // Non-fatal: analytics failures must never affect gameplay.
          }
          try {
            await RewardsService().grantGameSessionRewards(session);
          } catch (_) {
            // Non-fatal: the session itself is already saved; a failure
            // here just means this session's XP won't show on the
            // Rewards screen/dashboard until the next successful grant.
          }
        } catch (_) {
          writeSucceeded = false;
        }
      }
```

Add `import '../../../core/services/analytics_service.dart';` to the top of the file.

For quest completion, grep `logQuestCompleted\|missionCompleted\|questCompleted` in `lib/providers/mission_provider.dart` to find the existing method that marks a daily mission/quest complete, and add `AnalyticsService.logQuestComplete(catalogId)` there in the same non-fatal try/catch style, using whatever catalog/mission id is already in scope at that call site.

- [ ] **Step 5: Run the full test suite**

Run: `flutter test`
Expected: all green. `AnalyticsService`'s static methods call `FirebaseAnalytics.instance`, which (like `FirebaseFirestore.instance` elsewhere in this codebase) requires the Firebase test mocks (`setupFirebaseCoreMocks()` + `Firebase.initializeApp()`) in any test that exercises a call site — confirm no existing test newly fails; if one does, it's exercising a code path that now touches `AnalyticsService` for the first time without those mocks set up, and needs the same `setUpAll` pattern already used throughout `test/` added to it.

- [ ] **Step 6: Run flutter analyze**

Run: `flutter analyze`
Expected: 0 errors, 60 pre-existing info lints.

- [ ] **Step 7: Commit**

```bash
git add lib/core/services/analytics_service.dart lib/main.dart lib/providers/auth_provider.dart lib/features/games/core/game_session_state.dart lib/providers/mission_provider.dart
git commit -m "$(cat <<'EOF'
feat(observability): wire up Firebase Analytics (was a declared-but-unused dependency)

Adds automatic screen-view tracking via FirebaseAnalyticsObserver and
four baseline events (sign_up, login, game_session_complete,
quest_complete) through a small AnalyticsService wrapper so future
event additions stay centralized. All calls are wrapped non-fatally --
an analytics failure can never block login, signup, or gameplay.
EOF
)"
```

---

## Task 4: Add App Check client wiring

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/main.dart`

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: nothing consumed by later tasks.

- [ ] **Step 1: Add the Dart package**

Run: `flutter pub add firebase_app_check`
Expected: `pubspec.yaml` gains a `firebase_app_check: ^X.Y.Z` line; `flutter pub get` succeeds.

- [ ] **Step 2: Initialize App Check in debug mode**

In `lib/main.dart`, add the import and activation call right after Crashlytics setup from Task 2, before `runApp`:

```dart
import 'package:firebase_app_check/firebase_app_check.dart';
```

```dart
  // Debug providers only for now -- functions/src/config.ts's
  // ENFORCE_APP_CHECK stays false until Play Integrity (Android)/App
  // Attest (iOS)/reCAPTCHA v3 (Web) are configured in the Firebase
  // Console and this is swapped to the release providers. Activating
  // App Check even in debug mode is still useful: it starts attaching
  // (unenforced) tokens to requests now, so switching providers later
  // doesn't require touching this call site again.
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
    appleProvider: AppleProvider.debug,
    // webProvider intentionally omitted: reCAPTCHA v3 needs a real site
    // key from the Firebase Console, which isn't available yet -- web
    // builds simply won't attach an App Check token until that's set.
  );
```

- [ ] **Step 3: Verify the app still builds and runs**

Run: `flutter analyze`
Expected: 0 errors, 60 pre-existing info lints.

Run: `flutter build web --release`
Expected: succeeds (confirms the web platform doesn't fail hard just because `webProvider` was omitted).

Run: `flutter build apk --debug`
Expected: succeeds.

- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/main.dart
git commit -m "$(cat <<'EOF'
feat(security): add App Check client wiring (debug providers, enforcement still off)

functions/src/config.ts already had an ENFORCE_APP_CHECK flag with
nowhere on the client to attach a token from. Activates App Check with
debug providers on Android/iOS; web's reCAPTCHA provider is left
unconfigured pending a site key from the Firebase Console. Server-side
enforcement stays off -- see the phase report's pre-launch punch list
for the Firebase Console steps needed before flipping it on.
EOF
)"
```

---

## Task 5: Add a CI workflow

**Files:**
- Create: `.github/workflows/ci.yml`

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: nothing consumed by later tasks.

- [ ] **Step 1: Write the workflow**

```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches: ['**']
  pull_request:
    branches: ['**']

jobs:
  flutter:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
      - run: flutter pub get
      - run: flutter analyze
      - run: flutter test

  functions:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: functions
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '22'
      - run: npm ci
      - run: npm run build
      - run: npm run lint
```

(Mirrors this repo's own Definition of Done from CLAUDE.md §9: `flutter analyze` 0 errors, `flutter test` green, and — for any Cloud Functions change — `npm run build`/`npm run lint`. `node-version: '22'` matches `functions/package.json`'s `"engines": { "node": "22" }`.)

- [ ] **Step 2: Validate the YAML is well-formed**

Run: `node -e "require('js-yaml') ? console.log('has js-yaml') : 0" 2>/dev/null; python3 -c "import yaml, sys; yaml.safe_load(open('.github/workflows/ci.yml')); print('valid yaml')" 2>&1 || node -e "const fs=require('fs'); const s=fs.readFileSync('.github/workflows/ci.yml','utf8'); if(!s.includes('runs-on')) throw new Error('malformed'); console.log('looks ok')"`
Expected: `valid yaml` (or the Node fallback's `looks ok` if Python/PyYAML isn't available) — this is a lightweight sanity check since the workflow can't actually be executed without pushing to GitHub Actions.

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "$(cat <<'EOF'
ci: add GitHub Actions workflow running flutter analyze/test and functions build/lint

No CI existed at all -- every check before this was manual. Mirrors
CLAUDE.md's own Definition of Done (§9) so a push that breaks either
the Flutter app or Cloud Functions build is caught automatically.
EOF
)"
```

---

## Task 6: Clean up stray build/crash artifact files

**Files:**
- Delete (untracked, disk-only): `build_debug.txt`, `build_out.txt`, `build_output.txt`, `hs_err_pid13844.log`, `hs_err_pid17272.log`, `hs_err_pid22308.log`, `hs_err_pid24668.log`, `hs_err_pid25308.log`, `hs_err_pid6512.log`, `replay_pid13844.log`, `replay_pid17272.log`, `replay_pid24668.log`, `replay_pid6512.log`

**Interfaces:**
- Consumes: nothing.
- Produces: nothing.

These are JVM crash-log/build-output artifacts left at the repo root from earlier Gradle/dart2js OOM incidents during this engagement (see CLAUDE.md's R8/memory notes and `docs/DEFERRED.md`'s Android release build entry) — already gitignored (confirmed untracked via `git status --short` showing nothing for them), so this is disk cleanup only, not a git operation.

- [ ] **Step 1: Confirm none are tracked by git before deleting**

Run: `git status --short | grep -E "build_debug|build_out|hs_err|replay_pid"`
Expected: no output (confirms these are all untracked, so deleting them cannot lose any committed history).

- [ ] **Step 2: Delete the files**

Run:
```bash
rm -f build_debug.txt build_out.txt build_output.txt hs_err_pid*.log replay_pid*.log
```
Expected: exit code 0, files removed.

- [ ] **Step 3: Verify**

Run: `ls *.log *.txt 2>&1`
Expected: `ls: cannot access '*.log': No such file or directory` (or platform-equivalent "not found") for both patterns.

No commit needed — these were never tracked, so there's nothing for git to record.

---

## Task 7: End-of-phase verification + summary

**Files:** none (verification only)

- [ ] **Step 1: Full regression suite**

Run in order (checking free memory before each build per this engagement's established pattern — this machine has repeatedly run low on RAM mid-build; clean up leftover `dart`/`java` processes first if needed):
```bash
flutter analyze
flutter test
flutter build web --release
flutter build apk --debug
cd functions && npm run build && npm run lint && cd ..
```
Expected: `flutter analyze` 0 errors (60 pre-existing info lints); `flutter test` all green; both Flutter builds succeed; functions build and lint clean.

- [ ] **Step 2: Live verification of what's observable without deploying**

Firestore rules changes (Task 1) and the Firebase-Console-gated features (Crashlytics reporting, Analytics dashboard, App Check enforcement) cannot be verified live in this sandbox — they require either a rules emulator run or a real Firebase Console, neither available here. What *can* be verified with the existing local web server:
1. Confirm the app still boots to the dashboard with no new console errors introduced by the Crashlytics/Analytics/App Check initialization calls added in `main.dart` (a mistake in any of the three would likely throw during `main()` and produce a blank/broken app on load).
2. Log in as the learner test account, play one quick game to completion, confirm the session still saves and rewards still grant (exercises the new non-fatal analytics call sites in `game_session_state.dart` without regressing the existing reward-granting path from Phase 9's Task 5).

Document honestly in the report that Firestore rules, Crashlytics, Analytics, and App Check enforcement are unverified beyond code review + successful builds, matching how prior phases handled similarly deploy-gated changes.

- [ ] **Step 3: Write the phase completion report**

Cover what was fixed/added (the teacher data-exposure rules fix, Crashlytics, Analytics, App Check client wiring, CI workflow, stray file cleanup), files touched, verification performed and its limits, and then a clearly separated **pre-launch punch list** of everything genuinely blocked on the user, gathered from the audit and this phase's work:

- Generate a real Android release keystore and `android/key.properties` (release builds currently fall back to debug signing).
- Author and host a real Privacy Policy + Terms of Service page, and link it from the in-app consent screens (`register_screen.dart`, `parent_child_setup_screen.dart` currently show the phrase "our Privacy Policy (POPIA)" as plain unlinked text) — this needs real legal content, not something to generate automatically.
- Enable Crashlytics in the Firebase Console (free, one click) or reports from Task 2's wiring go nowhere.
- Configure Play Integrity (Android) / App Attest (iOS) / reCAPTCHA v3 (Web) in the Firebase Console for App Check, then set `ENFORCE_APP_CHECK=true` at the next Cloud Functions deploy.
- Decide on environment separation: every platform in `firebase_options.dart` currently points at the single `questkids-mobile` project, meaning this entire engagement's test-account activity has been writing to what will become the production database — either provision a second Firebase project for dev/staging or commit to disciplined test-account cleanup (already tracked as deferred item #29) before any real users sign up.
- Run a real `flutter build appbundle --release` on the dev machine (never successfully completed in any sandbox per `docs/DEFERRED.md`) to confirm R8/signing actually works end-to-end.
- Deploy this phase's `firestore.rules` change (validate in the emulator first).
- All prior phases' still-open deferred items (`MAIL_PASSWORD` secret already set per the audit — confirm; Gemini Cloud Functions redeploy; Firestore composite indexes deploy; the post-registration navigation bug).

- [ ] **Step 4: Stop and wait for "Continue"**

Per the standing engagement rule, do not start Phase 12 until the user explicitly says to continue.
