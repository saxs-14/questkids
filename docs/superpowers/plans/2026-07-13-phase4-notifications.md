# Phase 4 — Notifications Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make notifications actually work end-to-end — in-app, push, reminder, achievement, and parent notifications — by fixing the concrete bugs found (dead FCM service, a `targetUid`/`recipientUid` field mismatch that makes every notification the app already creates invisible, a `Timestamp`-vs-`int` crash bug, and a Firestore rule that would reject the parent-notification writes the app needs) and building the genuinely-missing server-side delivery infrastructure using the exact patterns this codebase already established (`sendEmail`'s `onDocumentCreated` trigger, `generateDailyMissions`'s `onSchedule` job).

**Architecture:** Client never writes notifications *for someone else* (that would require loosening `firestore.rules`, weakening a boundary that's currently correct). Instead, all cross-user notification creation (parent gets notified about their child) moves to Cloud Functions using the Admin SDK, which already bypasses rules — mirroring how `sendEmail`/`generateDailyMissions`/`refreshLeaderboards` already work. A single new Firestore trigger (`sendPushOnNotificationCreate`) becomes the one place that turns *any* notification document into an actual FCM push, so every future notification-creation call site (client or server) gets push delivery for free.

**Tech Stack:** Flutter (`firebase_messaging`, already a dependency), Firebase Cloud Functions v2 (TypeScript, existing `onDocumentCreated`/`onSchedule` patterns), Firestore. No new client packages — quest reminders are server-scheduled FCM pushes (matching `generateDailyMissions`'s existing pattern) rather than on-device `flutter_local_notifications` scheduling, since that would need a new package, timezone data, and Android 12+ exact-alarm permission handling for comparatively little benefit over a server-side check.

## Global Constraints

- `flutter analyze` → 0 new errors before any commit.
- `flutter test` → all tests green, including new tests this plan adds.
- `flutter build web --release` and `flutter build apk --debug` must both succeed before declaring the phase done.
- `cd functions && npm run build` (TypeScript compile) must succeed before any Cloud Functions commit; test locally with `firebase emulators:start --only functions,firestore,auth` before considering a function done, per CLAUDE.md §5.
- Do not loosen `firestore.rules`'s `notifications` collection `allow create` rule — it correctly blocks cross-user writes; route those through Cloud Functions instead (Rule 3: fix broken wiring, don't weaken security to route around it).
- Do not touch `functions/src/gemini/proxy.ts`, quota logic, or the `sendEmail`/`cleanupOldEmails` functions — out of scope, already correct.
- Commit style: `type(scope): summary`. Small, reviewable commits; run `flutter analyze` (and `npm run build` for functions changes) before each.

---

## File Structure

New files:
```
functions/src/notifications/sendPush.ts       # Task 4
functions/src/notifications/badgeAward.ts     # Task 5
functions/src/notifications/reminders.ts      # Task 6
lib/core/widgets/notification_banner.dart     # Task 3
test/widgets/notification_banner_test.dart    # Task 3
test/providers/notification_model_test.dart   # Task 1
```

Files modified: `lib/data/models/notification_model.dart`, `lib/data/repositories/notification_repository.dart`, `lib/features/notifications/screens/notifications_screen.dart`, `lib/core/services/notification_service.dart`, `lib/providers/auth_provider.dart`, `lib/main.dart`, `lib/core/services/firestore_service.dart`, `lib/data/repositories/grade4_repository.dart`, `functions/src/index.ts`, `ios/Runner/Info.plist`.

New file: `ios/Runner/Runner.entitlements`.

---

### Task 1: Fix notification field consistency + the `Timestamp` crash bug

**Why:** `NotificationsScreen` queries `.where('targetUid', ...)`, but every real creation call site (`parent_provider.dart`, `auth_service.dart`, `grade4_repository.dart`) writes `recipientUid` only — so every notification the app has ever created is invisible. Separately, `NotificationRepository.createNotification()` sets `createdAt` via `FieldValue.serverTimestamp()`, which reads back as a Firestore `Timestamp`, but `NotificationModel.fromMap` calls `DateTime.fromMillisecondsSinceEpoch(map['createdAt'])` expecting an `int` — this throws a runtime `TypeError` the moment any real (non-manually-seeded) notification is rendered.

**Files:**
- Modify: `lib/data/models/notification_model.dart`
- Modify: `lib/data/repositories/notification_repository.dart`
- Test: `test/providers/notification_model_test.dart`

**Interfaces:**
- `NotificationModel.fromMap` gains the same `Timestamp`-or-`int`-or-null handling `UserModel._tsToDate` already uses elsewhere in this codebase (consistent pattern, not a new one).
- `NotificationRepository.getUserNotifications` is removed (superseded by the already-correct `watchNotifications`, which every screen should use instead).

- [ ] **Step 1: Write the failing test**

```dart
// test/providers/notification_model_test.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/data/models/notification_model.dart';

void main() {
  test('fromMap handles a Firestore Timestamp for createdAt without throwing', () {
    final ts = Timestamp.fromMillisecondsSinceEpoch(1700000000000);
    final map = {
      'title': 'Badge earned',
      'body': 'You earned Math Wizard!',
      'type': 'achievement',
      'recipientUid': 'uid123',
      'isRead': false,
      'createdAt': ts,
    };
    final model = NotificationModel.fromMap(map, 'notif1');
    expect(model.createdAt, ts.toDate());
    expect(model.recipientUid, 'uid123');
  });

  test('fromMap still handles a legacy int millisecondsSinceEpoch', () {
    final map = {
      'title': 'Welcome',
      'body': 'Hi!',
      'type': 'welcome',
      'recipientUid': 'uid123',
      'createdAt': 1700000000000,
    };
    final model = NotificationModel.fromMap(map, 'notif2');
    expect(model.createdAt, DateTime.fromMillisecondsSinceEpoch(1700000000000));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/providers/notification_model_test.dart`
Expected: FAIL — `type 'Timestamp' is not a subtype of type 'int'`.

- [ ] **Step 3: Fix `NotificationModel.fromMap`**

Read the current file, then replace the `createdAt` parsing:

```dart
  static DateTime _parseCreatedAt(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return DateTime.now();
  }
```

Add `import 'package:cloud_firestore/cloud_firestore.dart';` at the top, and change the `fromMap` factory's `createdAt:` line to `createdAt: _parseCreatedAt(map['createdAt']),`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/providers/notification_model_test.dart`
Expected: PASS (2/2)

- [ ] **Step 5: Remove the broken `getUserNotifications` method**

In `notification_repository.dart`, delete the `getUserNotifications` method entirely (it queries the wrong field and nothing outside this plan's Task 2 rewrite of `NotificationsScreen` should reference it — confirm via `grep -rn "getUserNotifications" lib/` that only the screen used it, which Task 2 will fix).

- [ ] **Step 6: `flutter analyze` clean, then commit**

```bash
flutter analyze lib/data/models/notification_model.dart lib/data/repositories/notification_repository.dart
git add lib/data/models/notification_model.dart lib/data/repositories/notification_repository.dart test/providers/notification_model_test.dart
git commit -m "fix(notifications): fix Timestamp crash and remove the targetUid query that made every real notification invisible"
```

---

### Task 2: Rebuild `NotificationsScreen` on the correct query + design system

**Files:**
- Modify: `lib/features/notifications/screens/notifications_screen.dart`

**Interfaces:**
- Consumes: `NotificationRepository.watchNotifications` (existing, correct), `NotificationRepository.markAllAsRead` (existing, was unused), `AppLoadingView`/`AppEmptyState` (Phase 1 design system).

- [ ] **Step 1: Replace the stream source and loading/empty states**

Change `stream: repo.getUserNotifications(uid)` to `stream: repo.watchNotifications(uid)`. Replace the `ConnectionState.waiting` branch's bare `CircularProgressIndicator` with `const AppLoadingView(message: 'Loading notifications...')`. Replace the empty-state block (including the `'s📭'` typo) with:

```dart
            return const AppEmptyState(
              emoji: '📭',
              title: 'No notifications yet',
              message: "You'll see updates about quests, badges, and messages from Questy here.",
            );
```

Add imports for `AppLoadingView`/`AppEmptyState` from `core/widgets/`.

- [ ] **Step 2: Add a "Mark all as read" app bar action**

Add to the `AppBar`'s `actions:`:

```dart
        actions: [
          TextButton(
            onPressed: () => repo.markAllAsRead(uid),
            child: const Text('Mark all read', style: TextStyle(color: Colors.white)),
          ),
        ],
```

- [ ] **Step 3: Manual verification**

Run: `flutter run -d chrome`. Open Notifications from any dashboard's bell icon — confirm no crash, the empty state renders correctly (emoji fixed), and (once Task 5's Cloud Function has fired at least once in later testing) a real notification appears and "Mark all read" clears the bold/unread styling.

- [ ] **Step 4: `flutter analyze` clean, then commit**

```bash
flutter analyze lib/features/notifications/screens/notifications_screen.dart
git add lib/features/notifications/screens/notifications_screen.dart
git commit -m "fix(notifications): query the correct field, fix empty-state typo, add mark-all-read"
```

---

### Task 3: Foreground push banner

**Why:** `FirebaseMessaging.onMessage` currently only logs — a push arriving while the app is open shows nothing to the user.

**Files:**
- Create: `lib/core/widgets/notification_banner.dart`
- Test: `test/widgets/notification_banner_test.dart`

**Interfaces:**
- Produces: `NotificationBanner.show(BuildContext context, {required String title, required String body})` — a static helper showing a themed, dismissible banner using `ScaffoldMessenger`'s existing floating `SnackBar` styling (Phase 1's `snackBarTheme`), consistent with the rest of the app rather than inventing a new overlay system.

- [ ] **Step 1: Write the failing test**

```dart
// test/widgets/notification_banner_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/core/widgets/notification_banner.dart';

void main() {
  testWidgets('NotificationBanner.show displays title and body in a SnackBar', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => NotificationBanner.show(
              context,
              title: 'New Badge!',
              body: 'You earned Math Wizard',
            ),
            child: const Text('Trigger'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Trigger'));
    await tester.pump();

    expect(find.text('New Badge!'), findsOneWidget);
    expect(find.text('You earned Math Wizard'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/notification_banner_test.dart`
Expected: FAIL — file doesn't exist.

- [ ] **Step 3: Implement `NotificationBanner`**

```dart
// lib/core/widgets/notification_banner.dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'questy_avatar_placeholder_stub.dart' show placeholderUnused; // REMOVE — see note below
```

(The import line above is a placeholder to delete — write the real file as:)

```dart
// lib/core/widgets/notification_banner.dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Shows an in-app banner for a push notification received while the app
/// is in the foreground (FirebaseMessaging.onMessage doesn't show anything
/// on its own on either platform).
class NotificationBanner {
  static void show(BuildContext context, {required String title, required String body}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.notifications_active, color: AppColors.gold),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(body, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 5),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widgets/notification_banner_test.dart`
Expected: PASS

- [ ] **Step 5: `flutter analyze` clean, then commit**

```bash
flutter analyze lib/core/widgets/notification_banner.dart
git add lib/core/widgets/notification_banner.dart test/widgets/notification_banner_test.dart
git commit -m "feat(notifications): add in-app banner for foreground push messages"
```

---

### Task 4: Wire up `NotificationService` for real (multi-device tokens + foreground banner)

**Files:**
- Modify: `lib/core/services/notification_service.dart`
- Modify: `lib/providers/auth_provider.dart`

**Interfaces:**
- `NotificationService.init(String uid, {required GlobalKey<NavigatorState> navigatorKey})` — on successful permission grant, saves the FCM token into a **`fcmTokens` array field** (via `FieldValue.arrayUnion([token])`, replacing the single-scalar `fcmToken` field so a second device doesn't silently evict the first), and on `FirebaseMessaging.onMessage`, calls `NotificationBanner.show` using the app's global navigator key's current context (since this fires from a stream listener with no local `BuildContext`).
- Consumes: `NotificationBanner` (Task 3).

- [ ] **Step 1: Read the current file in full**, then rewrite:

```dart
// lib/core/services/notification_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import '../widgets/notification_banner.dart';

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> init(String userId, GlobalKey<NavigatorState> navigatorKey) async {
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
        if (context != null && notification != null) {
          NotificationBanner.show(
            context,
            title: notification.title ?? 'QuestKids',
            body: notification.body ?? '',
          );
        }
      });
    }
  }

  Future<void> _saveTokenToDatabase(String userId, String token) async {
    await _firestore.collection('users').doc(userId).update({
      'fcmTokens': FieldValue.arrayUnion([token]),
    });
  }

  Future<void> removeTokenOnSignOut(String userId) async {
    final token = await _fcm.getToken();
    if (token == null) return;
    await _firestore.collection('users').doc(userId).update({
      'fcmTokens': FieldValue.arrayRemove([token]),
    });
  }
}
```

- [ ] **Step 2: Wire `.init()` into the real auth flow**

Read `lib/providers/auth_provider.dart` in full first (need the exact current `_init()`/`signOut()` bodies before editing). In the `authStateChanges` listener's authenticated branch (where `_user = await _userRepo.getUser(firebaseUser.uid); _status = AuthStatus.authenticated;` currently runs), add a call to `NotificationService().init(firebaseUser.uid, navigatorKey)`. This requires a `GlobalKey<NavigatorState>` accessible from `AuthProvider` — add `final GlobalKey<NavigatorState> navigatorKey;` as a constructor parameter to `AuthProvider`, pass a shared `GlobalKey<NavigatorState>()` instance from `main.dart` when constructing `AuthProvider` in the `MultiProvider`, and set `MaterialApp(navigatorKey: ...)` to the same key so `navigatorKey.currentContext` resolves to the live app tree.

In `AuthProvider.signOut()`, add `await NotificationService().removeTokenOnSignOut(_user!.uid);` before clearing `_user` (guard with `if (_user != null)`).

- [ ] **Step 3: Manual verification**

Run: `flutter run -d chrome`. Log in — confirm (via browser dev tools' Application > IndexedDB/Firestore network calls, or by checking the Firestore console) that `users/{uid}.fcmTokens` now contains an array with one token. Web FCM requires a VAPID key for `getToken()` to succeed in a real browser — if `_fcm.getToken()` throws/returns null on web without one configured, confirm the `if (token != null)` guard prevents a crash either way (don't add web-specific VAPID config in this task — that's a separate credential-provisioning step; note it as a known limitation if web token retrieval doesn't work here, and confirm Android via `flutter build apk --debug` + a real device/emulator if available, or rely on the code-level correctness plus this guard).

- [ ] **Step 4: `flutter analyze` clean, then commit**

```bash
flutter analyze lib/core/services/notification_service.dart lib/providers/auth_provider.dart lib/main.dart
git add lib/core/services/notification_service.dart lib/providers/auth_provider.dart lib/main.dart
git commit -m "feat(notifications): wire up NotificationService for real (was fully dead code), multi-device token array, remove token on sign-out"
```

---

### Task 5: Cloud Function — `sendPushOnNotificationCreate`

**Why:** No notification document, however created, currently results in an actual push being sent — this is the single missing link that makes every other fix in this plan (and every future notification-creating feature) actually reach a device.

**Files:**
- Create: `functions/src/notifications/sendPush.ts`
- Modify: `functions/src/index.ts` (export it)

**Interfaces:**
- Produces: `export const sendPushOnNotificationCreate` — `onDocumentCreated` trigger on `notifications/{notificationId}`, mirroring `sendEmail`'s exact structure (read the doc, look up the recipient's `fcmTokens`, send, mark the doc with a delivery status, log/catch errors without throwing).

- [ ] **Step 1: Implement the trigger**

```typescript
// functions/src/notifications/sendPush.ts
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";

/**
 * Cloud Function: send an FCM push whenever a document is created in the
 * 'notifications' collection, regardless of which function or client wrote
 * it. This is the single delivery point so future notification-creation
 * call sites don't each need their own push-sending code.
 */
export const sendPushOnNotificationCreate = onDocumentCreated(
  "notifications/{notificationId}",
  async (event) => {
    const data = event.data?.data();
    if (!data) {
      console.error("No notification data found");
      return;
    }

    const recipientUid: string | undefined = data.recipientUid;
    if (!recipientUid) {
      console.error("Notification has no recipientUid, skipping push");
      return;
    }

    try {
      const userDoc = await admin
        .firestore()
        .collection("users")
        .doc(recipientUid)
        .get();
      const tokens: string[] = userDoc.data()?.fcmTokens ?? [];

      if (tokens.length === 0) {
        console.log(`No FCM tokens for ${recipientUid}, skipping push`);
        return;
      }

      const response = await admin.messaging().sendEachForMulticast({
        tokens,
        notification: {
          title: data.title ?? "QuestKids",
          body: data.body ?? "",
        },
        data: { type: data.type ?? "general", notificationId: event.params.notificationId },
      });

      // Drop tokens FCM reports as no-longer-registered so the array
      // doesn't grow unboundedly with dead devices.
      const staleTokens: string[] = [];
      response.responses.forEach((r, i) => {
        if (!r.success && r.error?.code === "messaging/registration-token-not-registered") {
          staleTokens.push(tokens[i]);
        }
      });
      if (staleTokens.length > 0) {
        await admin
          .firestore()
          .collection("users")
          .doc(recipientUid)
          .update({ fcmTokens: admin.firestore.FieldValue.arrayRemove(...staleTokens) });
      }

      await event.data?.ref.update({
        pushSent: true,
        pushSentAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (error) {
      console.error("Error sending push notification:", error);
      await event.data?.ref.update({ pushSent: false, pushError: String(error) });
    }
  });
```

- [ ] **Step 2: Export it from `index.ts`**

Add `export { sendPushOnNotificationCreate } from "./notifications/sendPush";` alongside the existing re-exports.

- [ ] **Step 3: Build and emulator-test**

Run: `cd functions && npm run build` — expect 0 TypeScript errors.
Run: `firebase emulators:start --only functions,firestore,auth`, then manually add a document to `notifications` in the emulator UI with a `recipientUid` matching a test user that has a `fcmTokens` array — confirm the function log shows it ran (a real push send will fail in the emulator without a real device token, which is expected; confirm no uncaught exception and that `pushSent`/`pushError` gets written back).

- [ ] **Step 4: Commit**

```bash
git add functions/src/notifications/sendPush.ts functions/src/index.ts
git commit -m "feat(notifications): add sendPushOnNotificationCreate trigger, the single FCM delivery point for all notification docs"
```

---

### Task 6: Cloud Function — badge-award notifications (learner + parents)

**Why:** Earning a badge through the main game flow (`quiz_result_screen.dart` → `RewardsProvider.checkForNewBadges` → `RewardRepository.awardBadge`) only shows an ephemeral dialog today — nothing is persisted, and no parent is notified. This is the "Achievement notifications" + "Parent notifications" spec items for the mainstream flow (not just the isolated Grade4 feature).

**Files:**
- Create: `functions/src/notifications/badgeAward.ts`
- Modify: `functions/src/index.ts`
- Modify: `lib/data/repositories/grade4_repository.dart` (read first — remove the now-redundant, currently-failing direct `createNotification` calls in `unlockAchievement`/`unlockWorld`, since both call `_rewardRepo.awardBadge` which writes to the same `rewards/{uid}` document this new trigger watches — the server-side trigger now covers grade4 achievements/world-unlocks too, for free)

**Interfaces:**
- Produces: `export const onBadgeAwarded` — `onDocumentUpdated` trigger on `rewards/{uid}`, diffs the `badges` array before/after, and for each newly-added badge writes a `notifications` doc for the learner (self) and one per entry in `linkedParentUids` on the learner's `users/{uid}` doc.

- [ ] **Step 1: Implement the trigger**

```typescript
// functions/src/notifications/badgeAward.ts
import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";

interface BadgeMap {
  id?: string;
  name?: string;
  icon?: string;
}

export const onBadgeAwarded = onDocumentUpdated(
  "rewards/{uid}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;

    const beforeIds = new Set(
      (before.badges ?? []).map((b: BadgeMap) => b.id).filter(Boolean)
    );
    const newBadges: BadgeMap[] = (after.badges ?? []).filter(
      (b: BadgeMap) => b.id && !beforeIds.has(b.id)
    );
    if (newBadges.length === 0) return;

    const uid = event.params.uid;
    const userDoc = await admin.firestore().collection("users").doc(uid).get();
    const learner = userDoc.data();
    if (!learner) return;

    const learnerName: string = learner.name ?? "Your child";
    const linkedParentUids: string[] = learner.linkedParentUids ?? [];

    const batch = admin.firestore().batch();
    for (const badge of newBadges) {
      // Notify the learner themselves.
      const learnerRef = admin.firestore().collection("notifications").doc();
      batch.set(learnerRef, {
        title: "Badge earned! 🏅",
        body: `You earned the ${badge.name ?? "a new"} badge!`,
        type: "achievement",
        recipientUid: uid,
        read: false,
        isRead: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Notify each linked parent.
      for (const parentUid of linkedParentUids) {
        const parentRef = admin.firestore().collection("notifications").doc();
        batch.set(parentRef, {
          title: `${learnerName} earned a badge! 🏅`,
          body: `${learnerName} just earned the ${badge.name ?? "a new"} badge.`,
          type: "parent_update",
          recipientUid: parentUid,
          read: false,
          isRead: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    }
    await batch.commit();
  });
```

- [ ] **Step 2: Export it from `index.ts`**

Add `export { onBadgeAwarded } from "./notifications/badgeAward";`.

- [ ] **Step 3: Remove the now-redundant, currently-failing grade4 client-side parent notifications**

Read `lib/data/repositories/grade4_repository.dart` in full. In `unlockAchievement()` and `unlockWorld()`, remove the loop calling `_notificationRepo.createNotification({'recipientUid': p, ...})` for each linked parent (these calls currently fail Firestore's create rule at runtime since `recipientUid` there is the parent's uid while the authenticated caller is the child — confirm this is genuinely the case by re-reading the exact code before deleting). Leave `_rewardRepo.awardBadge(...)` untouched — that write now triggers `onBadgeAwarded` automatically, covering both the learner and parent notifications that the deleted code was trying (and failing) to send directly. Do **not** touch the tug-of-war "battle win" notification call site (a `game_sessions`-style event, not a badge award — out of scope for this task, and grade4 is explicitly an isolated legacy feature per the investigation, not worth expanding scope for).

- [ ] **Step 4: Build and emulator-test**

Run: `cd functions && npm run build` — expect 0 TypeScript errors.
Run the Firestore emulator, manually update a test `rewards/{uid}` doc's `badges` array to add a new badge object with an `id`, confirm two `notifications` docs get created (one `recipientUid` = the learner, one per linked parent uid found on `users/{uid}.linkedParentUids`).

- [ ] **Step 5: `flutter analyze` clean on the Dart change, then commit**

```bash
flutter analyze lib/data/repositories/grade4_repository.dart
git add functions/src/notifications/badgeAward.ts functions/src/index.ts lib/data/repositories/grade4_repository.dart
git commit -m "feat(notifications): server-side badge-award notifications for learner and linked parents, remove grade4's redundant failing client writes"
```

---

### Task 7: Cloud Function — `sendQuestReminders` scheduled reminder

**Why:** The "Quest reminders" / "Reminder notifications" spec items, and the existing-but-inert `reminders` Firestore collection (parent dashboard lets a parent create a reminder record that currently does nothing but sit in a list).

**Files:**
- Create: `functions/src/notifications/reminders.ts`
- Modify: `functions/src/index.ts`

**Interfaces:**
- Produces: `export const sendQuestReminders` — `onSchedule`, daily at 17:00 Africa/Johannesburg (matching the timezone convention already used by `generateDailyMissions`/`refreshLeaderboards`), queries learners whose `daily_missions/{uid}/today/missions` doc shows zero completed missions, and writes a `notifications` doc (type `reminder`) for each — which Task 5's trigger then turns into a push automatically.

- [ ] **Step 1: Read `functions/src/missions/generate.ts` first** to confirm the exact `daily_missions/{uid}/today/missions` document shape (field names for completion status) before querying it.

- [ ] **Step 2: Implement the scheduled function**

```typescript
// functions/src/notifications/reminders.ts
import { onSchedule } from "firebase-functions/v2/scheduler";
import * as admin from "firebase-admin";

export const sendQuestReminders = onSchedule(
  { schedule: "every day 17:00", timeZone: "Africa/Johannesburg" },
  async () => {
    const usersSnap = await admin
      .firestore()
      .collection("users")
      .where("role", "==", "learner")
      .get();

    const batch = admin.firestore().batch();
    let remindersSent = 0;

    for (const userDoc of usersSnap.docs) {
      const uid = userDoc.id;
      const missionsDoc = await admin
        .firestore()
        .doc(`daily_missions/${uid}/today/missions`)
        .get();
      const missions = missionsDoc.data()?.missions ?? [];
      if (missions.length === 0) continue;

      const completedCount = missions.filter(
        (m: { completed?: boolean }) => m.completed
      ).length;
      if (completedCount > 0) continue; // already played today

      const ref = admin.firestore().collection("notifications").doc();
      batch.set(ref, {
        title: "Your quests are waiting! 🎯",
        body: "You haven't completed today's missions yet — jump back in!",
        type: "reminder",
        recipientUid: uid,
        read: false,
        isRead: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      remindersSent++;
    }

    if (remindersSent > 0) await batch.commit();
    console.log(`Sent ${remindersSent} quest reminders`);
  });
```

(Adjust the `missions`/`completed` field names in Step 2 to match whatever Step 1's read of `generate.ts` actually shows — do not guess field names that turn out wrong.)

- [ ] **Step 3: Export it from `index.ts`**

Add `export { sendQuestReminders } from "./notifications/reminders";`.

- [ ] **Step 4: Build and emulator-test**

Run: `cd functions && npm run build` — expect 0 TypeScript errors. Scheduled functions can be invoked directly for testing via `firebase functions:shell` in the emulator (`sendQuestReminders()`), or by temporarily deploying to a test project — at minimum confirm the build compiles and the Firestore query syntax is valid against the emulator with seeded test data.

- [ ] **Step 5: Commit**

```bash
git add functions/src/notifications/reminders.ts functions/src/index.ts
git commit -m "feat(notifications): add daily quest-reminder scheduled function"
```

---

### Task 8: iOS native push configuration (best-effort)

**Why:** Confirmed via investigation: no `UIBackgroundModes` in `Info.plist`, no `.entitlements` file at all. Without these, FCM push cannot function on iOS regardless of how correct the Dart/Cloud-Functions side is.

**Files:**
- Modify: `ios/Runner/Info.plist`
- Create: `ios/Runner/Runner.entitlements`

**Note:** This task covers the text-file configuration only. Full iOS push also requires an APNs authentication key uploaded to the Firebase project console and the "Push Notifications" capability enabled in Xcode's signing settings — neither is achievable from a text-editing pass and must be done by whoever has access to the Apple Developer account. Document this clearly rather than claiming iOS push is fully done.

- [ ] **Step 1: Read `ios/Runner/Info.plist` in full**, then add the background mode inside the existing `<dict>`:

```xml
	<key>UIBackgroundModes</key>
	<array>
		<string>remote-notification</string>
	</array>
```

- [ ] **Step 2: Create `ios/Runner/Runner.entitlements`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>aps-environment</key>
	<string>development</string>
</dict>
</plist>
```

(Note in the commit message that `aps-environment` must be switched to `production` for release builds, and that this entitlements file must be linked in Xcode's Signing & Capabilities tab — a step outside this plan's file-editing scope.)

- [ ] **Step 3: Commit**

```bash
git add ios/Runner/Info.plist ios/Runner/Runner.entitlements
git commit -m "feat(notifications): add iOS push background mode and entitlements (Xcode capability + APNs key still required manually)"
```

---

### Task 9: Remove dead competing notification-write path

**Files:**
- Modify: `lib/core/services/firestore_service.dart`

- [ ] **Step 1: Confirm zero call sites**

Run: `grep -rn "sendNotification" lib/` — expect only the method's own definition.

- [ ] **Step 2: Delete `sendNotification()`** from `firestore_service.dart` (read the file first to remove cleanly without disturbing `reportAiMessage` or other methods in the same class).

- [ ] **Step 3: `flutter analyze` clean, then commit**

```bash
flutter analyze lib/core/services/firestore_service.dart
git add lib/core/services/firestore_service.dart
git commit -m "chore(notifications): remove unused competing sendNotification() write path"
```

---

## End-of-Phase Checklist

- [ ] `flutter analyze` → 0 new errors
- [ ] `flutter test` → all green, including new tests this plan adds
- [ ] `cd functions && npm run build` → 0 TypeScript errors
- [ ] `flutter build web --release` and `flutter build apk --debug` both succeed
- [ ] `NotificationsScreen` shows real notifications without crashing (Timestamp bug fixed, correct field queried)
- [ ] A badge earned through the normal quiz flow creates a notification for the learner and every linked parent, server-side
- [ ] Any created notification document results in an actual FCM push attempt (`sendPushOnNotificationCreate` fires)
- [ ] `NotificationService` actually requests permission and saves a token array on login; removes it on sign-out
- [ ] A foreground push shows an in-app banner
- [ ] A daily scheduled function exists that reminds learners with zero completed missions
- [ ] iOS Info.plist/entitlements updated (with the remaining manual Xcode/APNs steps clearly documented as outstanding)
- [ ] Dead `sendNotification()` removed
- [ ] No files matching forbidden-secrets patterns were added
- [ ] Firestore rules for `notifications` were **not** loosened
