# Phase 7: Device Permissions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every device-permission-triggering flow in the app (camera/photo pick for avatars, homework-photo attach to Questy, push notifications) fails gracefully with a friendly, actionable message instead of a silent no-op or a raw exception string, and offers a real "Open Settings" remediation path when a permission is denied. Remove permission declarations that describe a feature (voice/speech input) which does not exist anywhere in the app.

**Architecture:** `image_picker` and `file_selector` already trigger the native OS permission prompts themselves — this phase does not build a parallel pre-request flow. It adds a thin `PermissionService` helper (using `permission_handler` only for `openAppSettings()` and mapping `image_picker`'s `PlatformException` codes to friendly text), consolidates a duplicated avatar-upload implementation onto the existing shared `ProfileAvatarPicker`/`ProfileImageService` pipeline, adds a one-time in-app rationale before the very first avatar picker use, and makes the FCM push-notification permission's denial state visible and actionable in Settings instead of silently doing nothing.

**Tech Stack:** Flutter/Dart, `image_picker` (existing), `file_selector` (existing), `firebase_messaging` (existing), new: `permission_handler`.

## Global Constraints

- `flutter analyze` must stay at 0 errors before every commit (warnings only if pre-existing).
- `flutter test` must stay green; add tests for anything this phase touches, per repo `CLAUDE.md` §9.
- Per Rule 3: fix broken existing functionality exactly as intended, do not redesign. Per Rule 5: no placeholder functionality — every fix must be fully functional.
- Do not build a new voice/speech-input feature — the orphaned `RECORD_AUDIO`/microphone/speech-recognition declarations are removed as dead config, not implemented, since no such feature exists anywhere in `lib/` or the original 13-phase spec.
- Child-facing copy: short sentences, no jargon, no raw exception text ever shown to the user (per repo `CLAUDE.md` §8 conventions).
- Fix any other bug encountered while doing this work, even if unrelated to Phase 7, per the standing "fix it for all phases" instruction.

---

### Task 1: Add `permission_handler` and create `PermissionService`

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/core/services/permission_service.dart`
- Test: `test/services/permission_service_test.dart` (new)

**Interfaces:**
- Produces: `PermissionService.openSettings() → Future<bool>`, `PermissionService.isPermissionDenied(Object error) → bool`, `PermissionService.friendlyMessage(Object error) → String` — consumed by Tasks 2, 4, 5.

- [ ] **Step 1: Add the dependency**

In `pubspec.yaml`, under the existing `# Local Storage (Offline)` / device-capability section (near `image_picker`), add:
```yaml
  permission_handler: ^11.3.0
```

Run: `flutter pub get`
Expected: resolves cleanly, no version conflicts (confirm by checking command exits 0).

- [ ] **Step 2: Write the failing test**

Create `test/services/permission_service_test.dart`:
```dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/core/services/permission_service.dart';

void main() {
  group('PermissionService.isPermissionDenied', () {
    test('true for image_picker camera_access_denied', () {
      final e = PlatformException(code: 'camera_access_denied');
      expect(PermissionService.isPermissionDenied(e), isTrue);
    });

    test('true for image_picker photo_access_denied', () {
      final e = PlatformException(code: 'photo_access_denied');
      expect(PermissionService.isPermissionDenied(e), isTrue);
    });

    test('false for an unrelated PlatformException code', () {
      final e = PlatformException(code: 'some_other_error');
      expect(PermissionService.isPermissionDenied(e), isFalse);
    });

    test('false for a non-PlatformException error', () {
      expect(PermissionService.isPermissionDenied(Exception('boom')), isFalse);
    });
  });

  group('PermissionService.friendlyMessage', () {
    test('permission-specific message for a denied camera', () {
      final e = PlatformException(code: 'camera_access_denied');
      expect(
        PermissionService.friendlyMessage(e),
        contains('Settings'),
      );
    });

    test('generic message for an unrelated error', () {
      final message = PermissionService.friendlyMessage(Exception('boom'));
      expect(message, isNot(contains('Settings')));
      expect(message, isNotEmpty);
    });
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/services/permission_service_test.dart`
Expected: FAIL — `permission_service.dart` doesn't exist yet.

- [ ] **Step 4: Implement**

Create `lib/core/services/permission_service.dart`:
```dart
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// Thin helper around device permissions used across the avatar picker,
/// the Questy image-attach flow, and CSV import.
///
/// image_picker and file_selector already trigger the native OS
/// permission prompt themselves -- this class does not duplicate that
/// request. It only (a) opens the OS Settings app after a denial, and
/// (b) turns image_picker's PlatformException codes into a short,
/// friendly, child-appropriate message instead of raw exception text.
class PermissionService {
  static const _deniedCodes = {'camera_access_denied', 'photo_access_denied'};

  static Future<bool> openSettings() => openAppSettings();

  static bool isPermissionDenied(Object error) {
    if (error is! PlatformException) return false;
    return _deniedCodes.contains(error.code);
  }

  static String friendlyMessage(Object error) {
    if (isPermissionDenied(error)) {
      return "We can't get to your camera or photos right now. "
          'You can turn this on in Settings.';
    }
    return 'Something went wrong. Please try again.';
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/services/permission_service_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 6: Run `flutter analyze` and the full test suite**

Run: `flutter analyze && flutter test`
Expected: 0 errors; all tests green.

- [ ] **Step 7: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/core/services/permission_service.dart test/services/permission_service_test.dart
git commit -m "feat(permissions): add permission_handler and a shared PermissionService for friendly denial messages"
```

---

### Task 2: Fix the silent failure in Questy's homework-photo attach

**Files:**
- Modify: `lib/features/ai_tutor/screens/ai_tutor_screen.dart`
- Test: manual verification (this screen has no existing test file; the fix is a try/catch around an already-manually-verified flow, and `PermissionService`'s logic is already unit tested in Task 1)

**Interfaces:**
- Consumes: `PermissionService.friendlyMessage`, `PermissionService.isPermissionDenied`, `PermissionService.openSettings` (from Task 1).

`_pickImage()` (`ai_tutor_screen.dart:104-120`) has zero try/catch. If the user denies photo-library access, `_picker.pickImage()` throws inside the async `onPressed` callback with nothing awaiting/catching it — the "attach image" button silently does nothing with zero user feedback. This is the most impactful fix in this phase (a genuinely broken, not just unpolished, existing flow).

- [ ] **Step 1: Wrap the pick call in try/catch with a friendly, actionable snackbar**

In `lib/features/ai_tutor/screens/ai_tutor_screen.dart`, add the import:
```dart
import '../../../core/services/permission_service.dart';
```

Replace `_pickImage()` (lines 104-120):
```dart
  Future<void> _pickImage() async {
    XFile? image;
    try {
      image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        imageQuality: 85,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(PermissionService.friendlyMessage(e)),
            action: PermissionService.isPermissionDenied(e)
                ? SnackBarAction(
                    label: 'Settings',
                    onPressed: PermissionService.openSettings,
                  )
                : null,
          ),
        );
      }
      return;
    }
    if (image == null) return;
    final bytes = await image.readAsBytes();
    setState(() => _showQuickPrompts = false);
    if (mounted) {
      await context.read<AiTutorProvider>().sendImageMessage(
            imageBytes: bytes,
            prompt: 'Please help me with this homework question 📸',
          );
      _scrollToBottom();
    }
  }
```

- [ ] **Step 2: Run `flutter analyze`**

Run: `flutter analyze lib/features/ai_tutor/screens/ai_tutor_screen.dart`
Expected: 0 errors.

- [ ] **Step 3: Run the full test suite**

Run: `flutter test`
Expected: all green (no test exercises this screen's picker flow today; this step only guards against an unrelated regression).

- [ ] **Step 4: Live-verify in browser**

Using the existing local test server / test account workflow: open the Questy tab, tap the image-attach icon, cancel the picker — confirm no error shown (cancellation is not an error). This confirms the `image == null` early-return path still works after the refactor. (Simulating an actual OS-level permission denial isn't reproducible in the Chrome-emulator test environment used in prior phases, since the browser file picker doesn't model native denial — this is documented as a manual/physical-device verification gap, consistent with how camera/photo permission testing has been handled in prior phases' web-based live checks.)

- [ ] **Step 5: Commit**

```bash
git add lib/features/ai_tutor/screens/ai_tutor_screen.dart
git commit -m "fix(permissions): stop silently failing when photo access is denied in Questy's image attach"
```

---

### Task 3: Consolidate the duplicate avatar-upload implementation in the learner dashboard

**Files:**
- Modify: `lib/features/dashboard/screens/learner_dashboard.dart`
- Test: `flutter test` regression only (no dedicated new test; this is a UI consolidation, not new logic — the underlying `ProfileAvatarPicker` behavior is exercised by Task 4's manual verification)

**Interfaces:**
- Consumes: `ProfileAvatarPicker` (`lib/core/widgets/profile_avatar_picker.dart`, existing, unchanged signature: `ProfileAvatarPicker({double radius = 55, Color? accentColor})`).

`_ProfileTab._pickAndUploadImage()` (`learner_dashboard.dart:1114-1148`) duplicates `ProfileImageService`'s pick→compress→upload→Firestore-update pipeline inline, gallery-only (no camera option, unlike the shared picker), with a raw `'Error: $e'` snackbar. Fixing this by hand a second time would duplicate Task 4's fix. Instead, replace the whole hand-rolled avatar UI with the existing shared `ProfileAvatarPicker` widget, which every other role's profile tab already uses.

- [ ] **Step 1: Replace the avatar Stack with `ProfileAvatarPicker`**

In `lib/features/dashboard/screens/learner_dashboard.dart`, replace the `Stack` at lines 1174-1219 (the `CircleAvatar` + camera-badge `GestureDetector`) with:
```dart
                const ProfileAvatarPicker(radius: 60),
```
matching the existing `parent_dashboard.dart:830` / `teacher_dashboard.dart:1525` call sites exactly (neither overrides `accentColor` — it defaults to `AppColors.primary`). Do not pass `accentColor: Colors.white`: `ProfileAvatarPicker` renders the accent color as both the initials text color and the camera-badge icon color on a white badge background, so a white accent would render invisible white-on-white. Verify the default accent reads clearly against this tab's purple gradient header during Step 7's live check; adjust only if it's actually hard to see, not preemptively.

Note `ProfileAvatarPicker` reads the avatar URL from `AuthProvider` (not from `widget.user`), so this also fixes a latent staleness issue: the old code read `widget.user?.avatarUrl`, a snapshot passed down at tab-build time, while `ProfileAvatarPicker` uses `context.watch<AuthProvider>().user` and updates live.

- [ ] **Step 2: Remove the now-dead `_pickAndUploadImage`, `_isUploading`, and unused fields**

Delete `_pickAndUploadImage()` (lines 1114-1148) and the `bool _isUploading = false;` field (line 1112) from `_ProfileTabState`.

Since `widget.storage`/`widget.userRepo` (`_ProfileTab`'s constructor params, `learner_dashboard.dart:1098-1105`) were only ever read inside the now-deleted method, remove the `storage`/`userRepo` fields and constructor parameters from `_ProfileTab`, and update its single call site:
```dart
_ProfileTab(user: user, storage: _storage, userRepo: _userRepo),
```
becomes:
```dart
_ProfileTab(user: user),
```

- [ ] **Step 3: Remove the now-unused `image_picker` import**

`grep -n "ImagePicker\|ImageSource" lib/features/dashboard/screens/learner_dashboard.dart` should return no matches after Step 2 (confirmed during investigation that `image_picker` was only used in the deleted method). Remove the `import 'package:image_picker/image_picker.dart';` line.

- [ ] **Step 4: Add the `ProfileAvatarPicker` import**

Add near the other core-widget imports:
```dart
import '../../../core/widgets/profile_avatar_picker.dart';
```

- [ ] **Step 5: Run `flutter analyze`**

Run: `flutter analyze lib/features/dashboard/screens/learner_dashboard.dart`
Expected: 0 errors, no unused-import/unused-field warnings.

- [ ] **Step 6: Run the full test suite**

Run: `flutter test`
Expected: all green.

- [ ] **Step 7: Live-verify in browser**

Load the learner dashboard's Profile tab, confirm the avatar renders with the camera badge, tap it, confirm the "Choose from Gallery" / "Take a Photo" bottom sheet now appears (previously this tab only offered gallery, no camera option) — this is a direct fix of the duplicated-implementation gap, not new functionality (the camera option already existed in the shared picker used elsewhere; the learner tab was simply the one place it was missing due to the duplication).

- [ ] **Step 8: Commit**

```bash
git add lib/features/dashboard/screens/learner_dashboard.dart
git commit -m "fix(permissions): replace learner dashboard's duplicated gallery-only avatar picker with the shared ProfileAvatarPicker"
```

---

### Task 4: Friendly denial messages + one-time rationale in the shared avatar picker

**Files:**
- Modify: `lib/core/widgets/profile_avatar_picker.dart`
- Modify: `lib/core/services/profile_image_service.dart` (doc-comment fix)
- Test: `test/widgets/profile_avatar_picker_test.dart` (new)

**Interfaces:**
- Consumes: `PermissionService` (Task 1).

Two fixes bundled since they touch the same file/flow: (1) the existing `catch (e)` at `profile_avatar_picker.dart:51-56` shows a raw `'Upload failed: $e'` string instead of a friendly, actionable message; (2) there is no in-app explanation shown before the native OS camera/photo prompt anywhere in the app, which is a real gap for a children's app (Play/App Store review guidance favors explaining first). Both fixes land in `_ProfileAvatarPickerState`.

- [ ] **Step 1: Write the failing test**

Create `test/widgets/profile_avatar_picker_test.dart`:
```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:questkids/core/widgets/profile_avatar_picker.dart';
import 'package:questkids/providers/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  testWidgets('tapping the avatar shows the one-time rationale before the picker sheet',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: AuthProvider(navigatorKey: GlobalKey<NavigatorState>()),
        child: const MaterialApp(
          home: Scaffold(body: ProfileAvatarPicker()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ProfileAvatarPicker));
    await tester.pumpAndSettle();

    expect(find.textContaining('Profile Picture'), findsWidgets);
    expect(find.text('Continue'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/profile_avatar_picker_test.dart`
Expected: FAIL — no rationale dialog exists yet, `'Continue'` not found (the widget currently goes straight to the source-picker bottom sheet, which has no `'Continue'` button).

- [ ] **Step 3: Implement — rationale dialog + friendly error handling**

Add the import to `lib/core/widgets/profile_avatar_picker.dart`:
```dart
import 'package:shared_preferences/shared_preferences.dart';
import '../services/permission_service.dart';
```

Add a rationale-tracking constant and method, and wire it before `_showSourcePicker`'s current entry point. Replace `_pick` and add a new `_maybeShowRationaleThenPick` flow:

```dart
class _ProfileAvatarPickerState extends State<ProfileAvatarPicker> {
  bool _uploading = false;
  static const _rationaleSeenPrefKey = 'avatar_permission_rationale_seen';

  Future<void> _pick(ImageSource source) async {
    final auth = context.read<AuthProvider>();
    final uid = auth.user?.uid;
    if (uid == null) return;

    setState(() => _uploading = true);
    try {
      final url = await ProfileImageService.pickAndUpload(
        uid: uid,
        source: source,
      );
      if (url != null && mounted) {
        auth.updateAvatarUrl(url);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture updated!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(PermissionService.friendlyMessage(e)),
            action: PermissionService.isPermissionDenied(e)
                ? SnackBarAction(
                    label: 'Settings',
                    onPressed: PermissionService.openSettings,
                  )
                : null,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _onTap() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_rationaleSeenPrefKey) != true) {
      if (!mounted) return;
      final continue_ = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Add a Profile Picture'),
          content: const Text(
            "QuestKids can use your camera or photos so you can pick a "
            "profile picture. You'll be asked to allow this next.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Not now'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      await prefs.setBool(_rationaleSeenPrefKey, true);
      if (continue_ != true) return;
    }
    if (mounted) await _showSourcePicker();
  }

  Future<void> _showSourcePicker() async {
```

Update the `build()` method's `GestureDetector.onTap` (currently `onTap: _uploading ? null : _showSourcePicker,`) to:
```dart
      onTap: _uploading ? null : _onTap,
```

- [ ] **Step 4: Fix `ProfileImageService.pickAndUpload`'s inaccurate doc comment**

In `lib/core/services/profile_image_service.dart`, the doc comment at line 17 says "Returns null if the user cancelled or an error occurred" — inaccurate, since a `PlatformException` (e.g. permission denial) propagates as a thrown exception, not a null return. Fix:
```dart
  /// Pick an image from [source], compress it (native only), upload to
  /// Firebase Storage, update Firestore `avatarUrl`, and return the URL.
  /// Returns null if the user cancelled. Throws if the pick, upload, or
  /// Firestore update fails (e.g. a denied camera/photo permission) --
  /// callers must catch.
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/widgets/profile_avatar_picker_test.dart`
Expected: PASS.

- [ ] **Step 6: Run `flutter analyze` and the full test suite**

Run: `flutter analyze && flutter test`
Expected: 0 errors; all tests green.

- [ ] **Step 7: Commit**

```bash
git add lib/core/widgets/profile_avatar_picker.dart lib/core/services/profile_image_service.dart test/widgets/profile_avatar_picker_test.dart
git commit -m "feat(permissions): one-time rationale before the avatar picker prompt, friendly denial messages with an Open Settings action"
```

---

### Task 5: Friendly error message for the parent CSV import

**Files:**
- Modify: `lib/features/dashboard/screens/parent_dashboard.dart`

**Interfaces:**
- Consumes: `PermissionService.friendlyMessage` (Task 1) — `file_selector` doesn't throw `image_picker`'s permission-specific codes, so `isPermissionDenied` will correctly fall through to the generic message here; reusing the same helper still removes the raw `'Import failed: $e'` text.

- [ ] **Step 1: Replace the raw error snackbar**

In `lib/features/dashboard/screens/parent_dashboard.dart`, add the import:
```dart
import '../../../core/services/permission_service.dart';
```

Replace the `catch (e)` block in `_importCsv` (lines 490-494):
```dart
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Import failed: $e')));
    }
```
with:
```dart
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(PermissionService.friendlyMessage(e))),
        );
      }
    }
```

- [ ] **Step 2: Run `flutter analyze`**

Run: `flutter analyze lib/features/dashboard/screens/parent_dashboard.dart`
Expected: 0 errors (pre-existing `curly_braces_in_flow_control_structures` info lints on neighboring lines are unrelated baseline, not introduced here since the replaced block now uses braces).

- [ ] **Step 3: Run the full test suite**

Run: `flutter test`
Expected: all green.

- [ ] **Step 4: Commit**

```bash
git add lib/features/dashboard/screens/parent_dashboard.dart
git commit -m "fix(permissions): friendly error message for failed CSV calendar import instead of raw exception text"
```

---

### Task 6: Make FCM push-notification permission denial visible and actionable

**Files:**
- Modify: `lib/core/services/notification_service.dart`
- Modify: `lib/providers/auth_provider.dart`
- Modify: `lib/features/profile/screens/settings_screen.dart`
- Test: `test/providers/auth_provider_notification_status_test.dart` (new) — narrowly scoped since `AuthProvider` is otherwise Firebase-Auth-stream-driven and hard to unit test end-to-end (matches the codebase's existing testing depth for this provider — no `auth_provider_test.dart` exists today)

**Interfaces:**
- Produces: `NotificationService.init(...) → Future<NotificationPermissionState>` (breaking return-type change from `Future<void>`), `enum NotificationPermissionState { granted, denied }`, `AuthProvider.notificationPermission → NotificationPermissionState?` getter.

Today, `NotificationService.init()`'s `else` branch (permission denied/provisional) does nothing at all — the entire push pipeline (Phase 4's work) silently never activates for that user, with no way for the user to know why notifications aren't arriving or how to fix it.

- [ ] **Step 1: Write the failing test**

Create `test/providers/auth_provider_notification_status_test.dart`:
```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/providers/auth_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  test('notificationPermission starts null before any auth state is known', () {
    final provider = AuthProvider(navigatorKey: GlobalKey<NavigatorState>());
    expect(provider.notificationPermission, isNull);
    provider.dispose();
  });
}
```

- [ ] **Step 2: Run test to verify it fails or passes trivially**

Run: `flutter test test/providers/auth_provider_notification_status_test.dart`
Expected: this specific assertion should already PASS with the current code (the field doesn't exist yet, so this actually FAILS to compile since `notificationPermission` getter doesn't exist). Confirms the getter needs to be added.

- [ ] **Step 3: Add `NotificationPermissionState` and change `init()`'s return type**

In `lib/core/services/notification_service.dart`, add the enum above the class and change `init`:
```dart
enum NotificationPermissionState { granted, denied }

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<NotificationPermissionState> init(
      String userId, GlobalKey<NavigatorState> navigatorKey) async {
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      final token = await _fcm.getToken();
      if (token != null) await _saveTokenToDatabase(userId, token);
      _fcm.onTokenRefresh.listen((newToken) => _saveTokenToDatabase(userId, newToken));

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final context = navigatorKey.currentContext;
        final notification = message.notification;
        if (context != null && context.mounted && notification != null) {
          NotificationBanner.show(
            context,
            title: notification.title ?? 'QuestKids',
            body: notification.body ?? '',
          );
        }
      });
      return NotificationPermissionState.granted;
    }
    return NotificationPermissionState.denied;
  }

  /// Re-checks the OS-level permission without re-prompting, so the
  /// Settings screen can refresh its status after the user returns from
  /// the system Settings app.
  Future<NotificationPermissionState> currentStatus() async {
    final settings = await _fcm.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized
        ? NotificationPermissionState.granted
        : NotificationPermissionState.denied;
  }
```
(`_saveTokenToDatabase` and `removeTokenOnSignOut` are unchanged.)

- [ ] **Step 4: Wire the result through `AuthProvider`**

In `lib/providers/auth_provider.dart`, add the import and field/getter:
```dart
import '../core/services/notification_service.dart';
```
(already imported) — add near the other fields:
```dart
  NotificationPermissionState? _notificationPermission;
  NotificationPermissionState? get notificationPermission => _notificationPermission;
```
Update `_init()`'s callback (line 38) to await and store the result:
```dart
        _user = await _userRepo.getUser(firebaseUser.uid);
        _status = AuthStatus.authenticated;
        _notificationPermission =
            await _notificationService.init(firebaseUser.uid, navigatorKey);
```
Add a public method for the Settings screen to call after the user returns from system Settings:
```dart
  Future<void> refreshNotificationPermission() async {
    _notificationPermission = await _notificationService.currentStatus();
    notifyListeners();
  }
```

- [ ] **Step 5: Add a Notifications section to Settings**

In `lib/features/profile/screens/settings_screen.dart`, add imports:
```dart
import '../../../core/services/notification_service.dart';
import '../../../core/services/permission_service.dart';
import '../../../providers/auth_provider.dart';
```
Add a second `Card` below the existing Dark Mode one, inside the same `ListView`:
```dart
          const SizedBox(height: 20),
          Text('Notifications', style: AppTextStyles.label),
          const SizedBox(height: 8),
          Consumer<AuthProvider>(
            builder: (context, auth, _) {
              final granted =
                  auth.notificationPermission == NotificationPermissionState.granted;
              return Card(
                child: ListTile(
                  leading: Icon(
                    granted ? Icons.notifications_active : Icons.notifications_off,
                    color: AppColors.primary,
                  ),
                  title: Text('Push Notifications', style: AppTextStyles.bodyMedium),
                  subtitle: Text(
                    granted
                        ? 'On'
                        : "Off — turn this on in Settings to get badge and quest reminders",
                    style: AppTextStyles.bodySmall,
                  ),
                  trailing: granted
                      ? null
                      : TextButton(
                          onPressed: () async {
                            await PermissionService.openSettings();
                            if (context.mounted) {
                              await auth.refreshNotificationPermission();
                            }
                          },
                          child: const Text('Open Settings'),
                        ),
                ),
              );
            },
          ),
```

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/providers/auth_provider_notification_status_test.dart`
Expected: PASS.

- [ ] **Step 7: Run `flutter analyze` and the full test suite**

Run: `flutter analyze && flutter test`
Expected: 0 errors; all tests green. Pay particular attention to `test/widgets/settings_screen_test.dart` (Phase 5) — it constructs `SettingsScreen` with only a `ThemeProvider` in its widget tree; since this task adds a `Consumer<AuthProvider>`, that test will need an `AuthProvider` available too. If it fails, wrap that test's `ChangeNotifierProvider<ThemeProvider>.value` in a `MultiProvider` that also provides `ChangeNotifierProvider<AuthProvider>.value(value: AuthProvider(navigatorKey: GlobalKey<NavigatorState>()))`, matching the pattern already used in `test/widgets/profile_settings_tile_test.dart`.

- [ ] **Step 8: Live-verify in browser**

Load Settings, confirm the new Notifications card renders with correct status text matching the already-granted test-account permission state (from Phase 4's live testing, notifications should show "On").

- [ ] **Step 9: Commit**

```bash
git add lib/core/services/notification_service.dart lib/providers/auth_provider.dart lib/features/profile/screens/settings_screen.dart test/providers/auth_provider_notification_status_test.dart
git commit -m "feat(permissions): surface push-notification permission status in Settings with an Open Settings recovery path"
```

(If Step 7 required updating `test/widgets/settings_screen_test.dart`, include it in this commit too.)

---

### Task 7: Remove orphaned voice/speech-recognition permission declarations

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `ios/Runner/Info.plist`

**Interfaces:** none (config-only).

`RECORD_AUDIO` (Android) and `NSMicrophoneUsageDescription`/`NSSpeechRecognitionUsageDescription` (iOS) describe a "talk to Questy" voice-input feature that does not exist anywhere in `lib/` — confirmed via grep for `RECORD_AUDIO|speech_to_text|SpeechToText|microphone|Microphone` returning zero matches, and no `speech_to_text`/`record`/similar package in `pubspec.yaml`. These are dead declarations that add unnecessary Play/App Store privacy-disclosure surface with no corresponding feature.

- [ ] **Step 1: Confirm no code references these before removing**

Run: `grep -rn "RECORD_AUDIO\|speech_to_text\|SpeechToText" lib/ pubspec.yaml`
Expected: no matches (already confirmed during investigation; re-verify before editing to guard against drift).

- [ ] **Step 2: Remove the Android permission**

In `android/app/src/main/AndroidManifest.xml`, remove:
```xml
    <uses-permission android:name="android.permission.RECORD_AUDIO"/>
```

- [ ] **Step 3: Remove the iOS usage descriptions**

In `ios/Runner/Info.plist`, remove both key/string pairs:
```xml
	<key>NSMicrophoneUsageDescription</key>
	<string>QuestKids needs microphone access so you can talk to QuestBot.</string>
	<key>NSSpeechRecognitionUsageDescription</key>
	<string>QuestKids uses speech recognition so you can ask QuestBot questions with your voice.</string>
```

- [ ] **Step 4: Run `flutter analyze`, the full test suite, and both builds**

Run: `flutter analyze && flutter test && flutter build web --release && flutter build apk --debug`
Expected: 0 errors; all tests green; both builds succeed (manifest/plist changes don't affect the web build but the Android build exercises the manifest change directly).

- [ ] **Step 5: Commit**

```bash
git add android/app/src/main/AndroidManifest.xml ios/Runner/Info.plist
git commit -m "chore(permissions): remove unused RECORD_AUDIO/microphone/speech-recognition declarations -- no voice feature exists in the app"
```

---

### Task 8: End-of-phase verification + summary

**Files:** none (verification only)

- [ ] **Step 1: Full static + test verification**

Run:
```bash
flutter analyze
flutter test
flutter build web --release
flutter build apk --debug
```
Expected: 0 analyzer errors/new warnings (baseline: 61 pre-existing info lints, unchanged since Phase 5/6); all tests green; both builds succeed.

- [ ] **Step 2: Live end-to-end verification in browser**

Using the existing local test server + persisted test account:
1. Profile tab → tap avatar → confirm the one-time "Add a Profile Picture" rationale dialog appears (first time only), tapping "Continue" opens the Gallery/Camera bottom sheet as before.
2. Cancel the picker — confirm no error shown.
3. Questy tab → tap the image-attach icon → cancel the picker — confirm no error shown, confirm the button is responsive on a second attempt (regression check for Task 2's fix).
4. Settings screen → confirm the new Notifications card renders with the correct status for the test account.
5. Parent dashboard → Reports/Calendar tab → attempt a CSV import with a non-CSV or malformed file → confirm a friendly (not raw-exception) message appears.

- [ ] **Step 3: Write the phase completion report**

Summary of work, files created/modified, bugs fixed (silent Questy image-attach failure, duplicated avatar-picker implementation, raw exception messages across 3 call sites, silent FCM-denial no-op, orphaned voice-permission declarations), features added (PermissionService, one-time rationale dialog, Notifications status card with Open Settings), tests performed, any remaining/deferred issues — then stop and wait for "Continue" per the standing phase-gating rule.
