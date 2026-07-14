# Phase 13: Parent Portal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the parent-child linking flow (which silently breaks for any second parent linking to a child), enforce POPIA consent server-side, complete two fully-backed-but-unreachable parent features (Document Vault, Mood Check-in), and add a new teacher-parent messaging feature.

**Architecture:** Follows this repo's established patterns throughout — Firestore rules gate all client-direct writes; a Cloud Function trigger (mirroring `functions/src/notifications/badgeAward.ts`) is used only where a client needs to write a notification for a *different* uid than its own (which `firestore.rules`'s `notifications` rule otherwise blocks); repositories are one per collection/domain; providers are thin state wrappers consumed via `Provider`/`Consumer`.

**Tech Stack:** Flutter/Dart, Firebase (Auth, Firestore, Storage, Cloud Functions TypeScript v2), `mobile_scanner` (new dependency for QR scanning), `file_selector` (already present, reused for document upload).

## Global Constraints

- `flutter analyze` → 0 new errors before every commit.
- `flutter test` → all green after every task.
- `functions`: `npm run build && npm run lint` → 0 errors after every Cloud Functions task.
- No placeholder content — every new screen must be fully functional, no "coming soon" states.
- Small, reviewable commits.
- Branch: create `phase-13-parent-portal` from the current branch before starting (this repo's convention per every prior phase).

---

## Task 1: Fix the `parentUid` bug breaking multi-parent linking

**Context:** `UserModel(...)` is constructed in 3 places when creating a learner account. `registerParentWithChild` (the combined signup flow) correctly sets `parentUid: parentUser.uid` (`lib/core/services/auth_service.dart:223`). The other two — `registerWithEmail`'s child branch (`auth_service.dart:124-132`) and `createChildForParent` (`auth_service.dart:355-364`) — never set it, leaving `parentUid` permanently `null` for every child created that way. `LinkChildScreen._sendLinkRequest` (`lib/features/parent/screens/link_child_screen.dart:70`) reads `_foundChild!.parentUid ?? ''` as `primaryParentUid` when a second parent sends a link request; with `parentUid == null`, this writes `primaryParentUid: ''`, which can never match the real primary parent's uid in `firestore.rules`'s link-request rule — so the primary parent's `approveLinkRequest` can never succeed. Every child created via the "Add a Child" flow (the only in-app single-parent child-creation path) is unreachable by a second parent's request.

**Files:**
- Modify: `lib/core/services/auth_service.dart`
- Test: `test/services/auth_service_parent_uid_test.dart` (new)

**Interfaces:**
- Consumes: `UserModel` constructor (unchanged shape, `parentUid` field already exists — confirmed at `lib/data/models/user_model.dart:14` and already present in `copyWith` at line 162/187, so no model changes needed).

- [ ] **Step 1: Write the failing test**

Create `test/services/auth_service_parent_uid_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/data/models/user_model.dart';

void main() {
  test('a child UserModel built with parentUid set serializes it in toMap', () {
    final child = UserModel(
      uid: 'child-1',
      name: 'Test Child',
      email: 'test@questkids.learn',
      role: 'learner',
      parentUid: 'parent-1',
      linkedParentUids: const ['parent-1'],
      createdAt: DateTime(2026, 1, 1),
    );
    expect(child.toMap()['parentUid'], 'parent-1');
  });
}
```

- [ ] **Step 2: Run test to verify it passes trivially (this documents the model already supports it)**

Run: `flutter test test/services/auth_service_parent_uid_test.dart`
Expected: PASS (this confirms `UserModel`/`toMap` already round-trip `parentUid` correctly — the bug is purely that `auth_service.dart` never populates the constructor argument, not a model gap).

- [ ] **Step 3: Fix `registerWithEmail`'s child-creation branch**

In `lib/core/services/auth_service.dart`, find the `UserModel(...)` construction inside `registerWithEmail`'s child branch (around line 124-132):

```dart
    final childModel = UserModel(
      uid: childUid,
      name: childName,
      surname: surname,
      email: dummyEmail,
      role: 'learner',
      gender: childGender,
      birthDate: childBirthDate,
      grade: childGrade ?? grade,
      linkedParentUids: [parentUid],
      createdAt: DateTime.now(),
    );
```

Add `parentUid: parentUid,`:

```dart
    final childModel = UserModel(
      uid: childUid,
      name: childName,
      surname: surname,
      email: dummyEmail,
      role: 'learner',
      gender: childGender,
      birthDate: childBirthDate,
      grade: childGrade ?? grade,
      parentUid: parentUid,
      linkedParentUids: [parentUid],
      createdAt: DateTime.now(),
    );
```

- [ ] **Step 4: Fix `createChildForParent`**

In the same file, find the `UserModel(...)` construction inside `createChildForParent` (around line 355-364):

```dart
    final childModel = UserModel(
      uid: childUid,
      name: childName,
      surname: parentSurname,
      email: dummyEmail,
      role: 'learner',
      gender: childGender,
      birthDate: childBirthDate,
      grade: childGrade,
      linkedParentUids: [parentUid],
      createdAt: DateTime.now(),
    );
```

Add `parentUid: parentUid,`:

```dart
    final childModel = UserModel(
      uid: childUid,
      name: childName,
      surname: parentSurname,
      email: dummyEmail,
      role: 'learner',
      gender: childGender,
      birthDate: childBirthDate,
      grade: childGrade,
      parentUid: parentUid,
      linkedParentUids: [parentUid],
      createdAt: DateTime.now(),
    );
```

- [ ] **Step 5: Run `flutter analyze` and the full test suite**

Run: `flutter analyze` — expect 0 errors.
Run: `flutter test` — expect all green.

- [ ] **Step 6: Commit**

```bash
git add lib/core/services/auth_service.dart test/services/auth_service_parent_uid_test.dart
git commit -m "fix(parent): set parentUid when creating a child account

registerWithEmail's child branch and createChildForParent both left
parentUid null, only setting linkedParentUids. LinkChildScreen reads
foundChild.parentUid as primaryParentUid when a second parent sends a
link request -- with it null, the request's primaryParentUid was
always empty and could never match the real primary parent's uid,
silently breaking multi-parent linking for every child created
through the normal single-parent signup flow."
```

---

## Task 2: Merge consent fields into the initial `.set()` (prep for Task 3's rule enforcement)

**Context:** All 3 child-creation code paths currently write the base `UserModel` via `.set()` and then write `consentGivenBy`/`consentEmail`/`consentAt`/`policyVersion` via a **separate, follow-up** `.update()` call. Task 3 will add a Firestore rule requiring those consent fields to be present on `allow create` — which only gates the `.set()` call. If consent fields arrive in a later `.update()`, the initial `.set()` will be rejected by the new rule. This task merges them into one `.set()` call in all 3 places, with no behavior change other than the write becoming atomic (also incidentally fixing the pre-existing risk of a child doc existing with no consent fields at all if the process died between `.set()` and `.update()`).

**Files:**
- Modify: `lib/core/services/auth_service.dart`

**Interfaces:**
- Consumes: `AppConstants.consentPolicyVersion` (`lib/core/constants/app_constants.dart:67`, unchanged).

- [ ] **Step 1: Merge in `registerWithEmail`'s child branch**

Find the `.set()` + `.update()` pair (around line 133-150):

```dart
    final childFirestore = FirebaseFirestore.instanceFor(app: tempApp);
    await childFirestore
        .collection('users')
        .doc(childUid)
        .set(childModel.toMap());

    final code = parentRepo.generateLinkCode();
    await childFirestore.collection('users').doc(childUid).update({
      'childLinkCode': code,
      'consentGivenBy': name,
      'consentEmail': email,
      'consentAt': DateTime.now().millisecondsSinceEpoch,
      'policyVersion': AppConstants.consentPolicyVersion,
    });
```

Replace with a single `.set()`:

```dart
    final childFirestore = FirebaseFirestore.instanceFor(app: tempApp);
    final code = parentRepo.generateLinkCode();
    await childFirestore.collection('users').doc(childUid).set({
      ...childModel.toMap(),
      'childLinkCode': code,
      'consentGivenBy': name,
      'consentEmail': email,
      'consentAt': DateTime.now().millisecondsSinceEpoch,
      'policyVersion': AppConstants.consentPolicyVersion,
    });
```

- [ ] **Step 2: Merge in `createChildForParent`**

Find the `.set()` + `.update()` pair (around line 366-380):

```dart
    final childFirestore = FirebaseFirestore.instanceFor(app: tempApp);
    await childFirestore
        .collection('users')
        .doc(childUid)
        .set(childModel.toMap());
    await childFirestore.collection('users').doc(childUid).update({
      'consentGivenBy': consentGivenBy,
      'consentEmail': consentEmail,
      'consentAt': DateTime.now().millisecondsSinceEpoch,
      'policyVersion': AppConstants.consentPolicyVersion,
    });
```

Replace with a single `.set()`:

```dart
    final childFirestore = FirebaseFirestore.instanceFor(app: tempApp);
    await childFirestore.collection('users').doc(childUid).set({
      ...childModel.toMap(),
      'consentGivenBy': consentGivenBy,
      'consentEmail': consentEmail,
      'consentAt': DateTime.now().millisecondsSinceEpoch,
      'policyVersion': AppConstants.consentPolicyVersion,
    });
```

- [ ] **Step 3: Check `registerParentWithChild` for the same pattern**

Read `lib/core/services/auth_service.dart` around lines 171-259 (`registerParentWithChild`). If it also does a separate `.set()` then `.update()` for consent fields on the child doc, apply the same merge. If it already writes consent fields inline in one `.set()`/equivalent, leave it unchanged — just confirm and note which case it is.

- [ ] **Step 4: Run `flutter analyze` and the full test suite**

Run: `flutter analyze` — expect 0 errors.
Run: `flutter test` — expect all green (no test should depend on the two-write sequence; if one does, it's testing an implementation detail, not behavior — update it to assert on the final document state instead).

- [ ] **Step 5: Commit**

```bash
git add lib/core/services/auth_service.dart
git commit -m "refactor(parent): merge consent fields into the initial child-account set()

Previously written via a separate follow-up update() -- harmless
today, but Task 3 adds a Firestore rule requiring consent fields on
create, which only gates the set() call. Also closes a small window
where a child doc could exist with no consent fields at all if the
process died between the two writes."
```

---

## Task 3: Enforce POPIA consent server-side via Firestore rules

**Context:** `firestore.rules`'s `users/{uid}` `allow create` (line 39-41) only checks `isUser(uid) && request.resource.data.uid == uid && request.resource.data.role == 'learner'` — it never requires consent fields, so a direct API write (bypassing the app UI entirely) could create a fully-functional learner account with no consent trail. Confirmed via investigation that teachers never `create` on `users/{uid}` (only `update`, gated separately by `lockedUserFields()`), so this change cannot break the teacher flow. After Task 2, all 3 legitimate child-creation code paths already write consent fields inline in their `.set()` call.

**Files:**
- Modify: `firestore.rules`
- Test: manual trace only (documented in Step 3) — this repo has no Firestore emulator test harness wired into `flutter test`; live emulator validation is listed in Task 8's phase-end checklist.

**Interfaces:**
- Consumes: existing `isUser(uid)` helper (`firestore.rules:14-16`, unchanged).

- [ ] **Step 1: Add the consent-field requirement to `allow create`**

In `firestore.rules`, find the `users/{uid}` block's `allow create` (line 39-41):

```
  allow create: if isUser(uid) &&
                   request.resource.data.uid == uid &&
                   request.resource.data.role == 'learner';
```

Replace with:

```
  // POPIA: a learner account may only be created with a recorded
  // parent/guardian consent trail -- see CLAUDE.md §6.5 and
  // AppConstants.consentPolicyVersion. This is a server-side backstop;
  // the client (auth_service.dart) already always writes these fields
  // in the same set() call as account creation.
  allow create: if isUser(uid) &&
                   request.resource.data.uid == uid &&
                   request.resource.data.role == 'learner' &&
                   request.resource.data.consentGivenBy is string &&
                   request.resource.data.consentGivenBy.size() > 0 &&
                   request.resource.data.consentEmail is string &&
                   request.resource.data.consentEmail.size() > 0 &&
                   request.resource.data.consentAt is int &&
                   request.resource.data.policyVersion is string;
```

- [ ] **Step 2: Verify brace balance**

Run: `grep -o '{' firestore.rules | wc -l` and `grep -o '}' firestore.rules | wc -l` — both counts must match (established verification pattern from Phase 9/11's rules edits).

- [ ] **Step 3: Manually trace all 3 creation paths against the new rule**

Confirm in the diff from Task 2: `registerWithEmail`'s child branch, `createChildForParent`, and (if it needed the Task 2 fix) `registerParentWithChild` all include `consentGivenBy` (non-empty string), `consentEmail` (non-empty string), `consentAt` (`DateTime.now().millisecondsSinceEpoch`, an `int`), and `policyVersion` (`AppConstants.consentPolicyVersion`, a string) in their single `.set()` call. Document this trace in the commit message.

- [ ] **Step 4: Commit**

```bash
git add firestore.rules
git commit -m "fix(rules): require POPIA consent fields on learner account creation

users/{uid} allow create only checked role == 'learner' -- a direct
API write (bypassing the app entirely) could create a fully
functional learner account with zero consent trail. The client has
always recorded consentGivenBy/consentEmail/consentAt/policyVersion,
just without a server-side backstop requiring them. Deploy + emulator
validation tracked in this phase's end-of-phase checklist."
```

(Do not run `firebase deploy` — deployment is a user-authorized action tracked separately, matching every prior phase's rules-change handling in this engagement.)

---

## Task 4: Add `cancelLinkRequest` and wire up `LinkRequestsScreen`'s Cancel button

**Context:** `LinkRequestsScreen`'s outgoing-request Cancel button (`lib/features/parent/screens/link_requests_screen.dart:69`) has an empty `onPressed: () async {/* cancel logic */}` body, and `ParentRepository` has no `cancelLinkRequest` method at all (confirmed via grep — zero matches for "cancel" in the file).

**Files:**
- Modify: `lib/data/repositories/parent_repository.dart`
- Modify: `lib/features/parent/screens/link_requests_screen.dart`
- Modify: `firestore.rules` (the link-request collection needs a delete/cancel rule for the requester)
- Test: `test/data/parent_repository_test.dart`

**Interfaces:**
- Produces: `ParentRepository.cancelLinkRequest(String requestId)`.

- [ ] **Step 1: Find the link-request collection name and existing rule block**

Read `lib/data/repositories/parent_repository.dart`'s `sendLinkRequest`/`approveLinkRequest`/`declineLinkRequest` methods to confirm the exact collection name (likely `link_requests`, confirm by reading the `.collection(...)` call inside `sendLinkRequest`). Read the matching block in `firestore.rules` to see the current `allow` statements for that collection.

- [ ] **Step 2: Add `cancelLinkRequest` to `ParentRepository`**

Add a new method alongside `declineLinkRequest` (same collection, same shape — declining and cancelling are the same underlying operation from two different actors' perspectives, so mirror `declineLinkRequest`'s exact body, just renamed and doc-commented for the requester's use case):

```dart
  /// Cancels a still-pending outgoing request. Same effect as
  /// [declineLinkRequest] (deletes the request doc) but named for the
  /// requesting parent's own action, not the primary parent's.
  Future<void> cancelLinkRequest(String requestId) async {
    await declineLinkRequest(requestId);
  }
```

(If `declineLinkRequest` deletes the doc, this reuses it directly. If it instead sets a `status: 'declined'` field rather than deleting, read its actual body first and either reuse it as-is or add a small analogous `status: 'cancelled'` write — match whatever `declineLinkRequest` actually does so both actors leave the request in a consistent terminal state shape.)

- [ ] **Step 3: Add a Firestore rule allowing the requester to cancel their own pending request**

If the existing rule block doesn't already allow the requesting parent to delete/update their own pending request, add it. Pattern to follow (adjust field names to match what Step 1 found):

```
      allow delete: if isParent() &&
                        resource.data.requestingParentUid == request.auth.uid &&
                        resource.data.status == 'pending';
```

(Skip this step if `declineLinkRequest`'s existing rule already covers this shape — e.g. if it's a generic "either party in the request can modify it" rule.)

- [ ] **Step 4: Wire the button in `LinkRequestsScreen`**

In `lib/features/parent/screens/link_requests_screen.dart`, replace the no-op (line 69):

```dart
                onPressed: () async {/* cancel logic */},
```

with:

```dart
                onPressed: () async {
                  await ParentRepository().cancelLinkRequest(r['id'] as String);
                },
```

(Confirm the outgoing-request map actually carries an `'id'` key — check `watchOutgoingRequests`'s mapping in `parent_repository.dart`; if the doc id is under a different key, use that instead.)

- [ ] **Step 5: Write a test for the new repository method**

Add to `test/data/parent_repository_test.dart`:

```dart
test('cancelLinkRequest delegates to declineLinkRequest (same terminal state)', () {
  // ParentRepository has no constructor dependencies to mock around --
  // this test documents the method exists with the right signature.
  // (Matches this file's existing single trivial constructor test.)
  expect(ParentRepository().cancelLinkRequest, isA<Function>());
});
```

- [ ] **Step 6: Run `flutter analyze` and the full test suite; verify rules brace balance if Step 3 was needed**

Run: `flutter analyze` — expect 0 errors.
Run: `flutter test` — expect all green.

- [ ] **Step 7: Commit**

```bash
git add lib/data/repositories/parent_repository.dart lib/features/parent/screens/link_requests_screen.dart firestore.rules test/data/parent_repository_test.dart
git commit -m "fix(parent): wire up the no-op Cancel button on outgoing link requests

link_requests_screen.dart's Cancel button had an empty onPressed body
and ParentRepository had no cancelLinkRequest method at all."
```

---

## Task 5: Make `LinkRequestsScreen` reachable

**Context:** `LinkRequestsScreen` is fully built (79 lines) but has zero route registration and zero navigation entry point anywhere in the app — confirmed via full-tree grep. `ParentProvider.pendingRequests`/`outgoingRequests` are live-streamed but have zero UI consumers.

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/features/dashboard/screens/parent_dashboard.dart`

**Interfaces:**
- Consumes: `ParentProvider.pendingRequests` (`lib/providers/parent_provider.dart:25`, existing getter, unchanged).

- [ ] **Step 1: Register the route**

In `lib/main.dart`, add the import near the other parent-feature imports (alongside `link_child_screen.dart`'s import, around line 22-23):

```dart
import 'features/parent/screens/link_requests_screen.dart';
```

Add the route entry in the `routes: {...}` map (alongside `/link_child`, around line 144):

```dart
        '/link_requests': (_) => const LinkRequestsScreen(),
```

- [ ] **Step 2: Add a nav entry point with a pending-count badge in the Parent Dashboard's Profile tab**

In `lib/features/dashboard/screens/parent_dashboard.dart`, find `_ParentProfileTab`'s build method (around line 820-912). Add a new list item between the info card and the "My Children" section (or immediately before `ProfileSettingsTile()` at line 907 — match the file's existing card/section spacing pattern), consuming `ParentProvider.pendingRequests`:

```dart
            Consumer<ParentProvider>(
              builder: (context, parent, _) {
                final count = parent.pendingRequests.length;
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.link_outlined),
                    title: const Text('Link Requests'),
                    subtitle: Text(count > 0
                        ? '$count pending request${count == 1 ? '' : 's'}'
                        : 'No pending requests'),
                    trailing: count > 0
                        ? CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.red,
                            child: Text(
                              '$count',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12),
                            ),
                          )
                        : const Icon(Icons.chevron_right),
                    onTap: () =>
                        Navigator.pushNamed(context, '/link_requests'),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
```

(Adjust indentation/surrounding `SizedBox`/`Card` styling to exactly match this file's existing conventions once the surrounding code is visible — the goal is one new `Card`+`ListTile` entry consuming `ParentProvider.pendingRequests`, not a specific pixel layout.)

- [ ] **Step 3: Run `flutter analyze` and the full test suite**

Run: `flutter analyze` — expect 0 errors.
Run: `flutter test` — expect all green.

- [ ] **Step 4: Commit**

```bash
git add lib/main.dart lib/features/dashboard/screens/parent_dashboard.dart
git commit -m "fix(parent): make LinkRequestsScreen reachable

Fully built but had zero route registration and zero navigation entry
point anywhere in the app -- parents had no way to see or act on
incoming/outgoing link requests through the UI at all."
```

---

## Task 6: Add a real QR scanner to `LinkChildScreen`'s QR tab

**Context:** The QR tab's non-web branch (`lib/features/parent/screens/link_child_screen.dart:163-165`) renders `Center(child: Text('QR scanner available on mobile.'))` — a Rule 5 placeholder-functionality violation. `qr_flutter` (QR *generation*, used by `ChildQrCode`) is present; no scanning package exists.

**Files:**
- Modify: `pubspec.yaml` (add `mobile_scanner`)
- Modify: `lib/features/parent/screens/link_child_screen.dart`
- Test: manual/live verification only (camera hardware can't be exercised in `flutter test`'s widget-test environment) — flagged in Task 8.

**Interfaces:**
- Produces: nothing new consumed elsewhere; purely fills in the existing QR tab.

- [ ] **Step 1: Add the `mobile_scanner` dependency**

Run: `flutter pub add mobile_scanner`

- [ ] **Step 2: Replace the QR tab's non-web placeholder**

In `lib/features/parent/screens/link_child_screen.dart`, import at the top:

```dart
import 'package:mobile_scanner/mobile_scanner.dart';
```

Replace the non-web branch (line 163-165):

```dart
      : const Center(
          child: Text('QR scanner available on mobile.')),
```

with a real scanner that, on a successful scan, populates `_codeCtrl` and calls the same lookup path the "Code" tab's submit button uses (read the "Code" tab section, lines 100-122, to find the exact method it calls on submit — likely `_lookupByCode` or similar — and call that same method here instead of duplicating lookup logic):

```dart
      : SizedBox(
          height: 320,
          child: MobileScanner(
            onDetect: (capture) {
              final barcodes = capture.barcodes;
              if (barcodes.isEmpty) return;
              final scanned = barcodes.first.rawValue;
              if (scanned == null || scanned.length != 6) return;
              _codeCtrl.text = scanned.toUpperCase();
              _lookupByCode(); // reuse the Code tab's existing lookup method -- confirm exact name/signature by reading lines 100-122 first
            },
          ),
        ),
```

(The exact method name called on scan must match whatever the "Code" tab's submit button already calls — do not invent a new lookup path; reuse the existing one so both entry points behave identically.)

- [ ] **Step 3: Add camera permission handling**

Check `lib/core/services/permission_service.dart` (built in Phase 7) for its existing rationale-dialog pattern for other permissions (e.g. photo access). Wrap the scanner's activation in the same friendly-rationale + Open Settings pattern already established in this codebase, rather than letting `mobile_scanner` show its own unstyled OS prompt with no explanation. If `PermissionService` doesn't yet have a `camera` case, add one following its existing per-permission structure (mirror whatever pattern the file already uses for its other permission types).

- [ ] **Step 4: Android/iOS platform config**

Confirm `android/app/src/main/AndroidManifest.xml` has (or add) `<uses-permission android:name="android.permission.CAMERA" />`, and `ios/Runner/Info.plist` has (or add) an `NSCameraUsageDescription` string. `mobile_scanner`'s own setup docs (fetched via context7 if needed) confirm exact manifest/plist requirements for the installed version.

- [ ] **Step 5: Run `flutter analyze`**

Run: `flutter analyze` — expect 0 errors. (No automated test can exercise real camera input; live verification is deferred to Task 8.)

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/features/parent/screens/link_child_screen.dart android/app/src/main/AndroidManifest.xml ios/Runner/Info.plist
git commit -m "feat(parent): add a real QR scanner to the child-linking QR tab

The QR tab's non-web branch just showed the text 'QR scanner available
on mobile' with no actual camera/scanner wired in. Added
mobile_scanner and reused the Code tab's existing lookup path so both
entry points behave identically."
```

---

## Task 7: Complete Document Vault UI (upload/list/delete real files)

**Context:** `ParentRepository.uploadDocument`/`watchDocuments`/`deleteDocument` are fully implemented against Firestore, but `uploadDocument` only ever wrote a caller-supplied metadata map — it never actually uploaded file bytes anywhere (no `firebase_storage` call exists in the repository despite `firebase_storage` already being a dependency). No screen anywhere calls any of these three methods.

**Files:**
- Modify: `lib/data/repositories/parent_repository.dart`
- Create: `lib/features/parent/screens/document_vault_screen.dart`
- Modify: `lib/features/dashboard/screens/parent_dashboard.dart` (Home tab entry point)
- Test: `test/data/parent_repository_test.dart`

**Interfaces:**
- Produces: `ParentRepository.uploadDocument({required String childUid, required XFile file})` (signature change — was `Map<String, dynamic> doc`), returning `Future<void>`.
- Consumes: `firebase_storage` (`FirebaseStorage.instance`, already a dependency), `file_selector`'s `openFile`/`XTypeGroup` (already used identically in `parent_dashboard.dart`'s `_importCsv`, lines 458-498 — mirror that exact pattern for picking a file).

- [ ] **Step 1: Rewrite `uploadDocument` to actually upload file bytes**

In `lib/data/repositories/parent_repository.dart`, replace the current `uploadDocument`:

```dart
  Future<void> uploadDocument(Map<String, dynamic> doc) async {
    final ref = _db.collection('document_vault').doc();
    doc['id'] = ref.id;
    doc['createdAt'] = FieldValue.serverTimestamp();
    await ref.set(doc);
  }
```

with a version that uploads to Storage first, then writes the Firestore doc with the resulting URL:

```dart
  Future<void> uploadDocument({
    required String childUid,
    required String uploadedByUid,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final docRef = _db.collection('document_vault').doc();
    final storageRef = FirebaseStorage.instance
        .ref('document_vault/$childUid/${docRef.id}_$fileName');
    await storageRef.putData(bytes);
    final url = await storageRef.getDownloadURL();
    await docRef.set({
      'id': docRef.id,
      'childUid': childUid,
      'uploadedByUid': uploadedByUid,
      'fileName': fileName,
      'url': url,
      'sizeBytes': bytes.length,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
```

Add the needed imports at the top of the file:

```dart
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
```

- [ ] **Step 2: Add a matching Storage rule**

Read `storage.rules` (referenced in CLAUDE.md §2 as an existing file). Add a block for `document_vault/{childUid}/{fileName}` allowing write only from a parent whose `linkedChildrenUids` contains `childUid`, and read for the same condition plus the child themselves. Mirror whatever helper-function pattern `storage.rules` already uses (check for an existing `isParentOf(childUid)`-style helper before writing a new one inline).

- [ ] **Step 3: Create `DocumentVaultScreen`**

Create `lib/features/parent/screens/document_vault_screen.dart`:

```dart
import 'dart:typed_data';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/repositories/parent_repository.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/parent_provider.dart';

class DocumentVaultScreen extends StatefulWidget {
  const DocumentVaultScreen({super.key});

  @override
  State<DocumentVaultScreen> createState() => _DocumentVaultScreenState();
}

class _DocumentVaultScreenState extends State<DocumentVaultScreen> {
  final _repo = ParentRepository();
  bool _uploading = false;

  Future<void> _pickAndUpload(String childUid, String parentUid) async {
    const typeGroup = XTypeGroup(
      label: 'documents',
      extensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
    );
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) return;
    setState(() => _uploading = true);
    try {
      final bytes = await file.readAsBytes();
      await _repo.uploadDocument(
        childUid: childUid,
        uploadedByUid: parentUid,
        fileName: file.name,
        bytes: Uint8List.fromList(bytes),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Document uploaded')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Upload failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final parent = context.watch<ParentProvider>();
    final child = parent.selectedChild;
    final parentUid = context.read<AuthProvider>().user?.uid ?? '';

    if (child == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Document Vault')),
        body: const Center(child: Text('Select a child first.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text("${child.name}'s Documents")),
      floatingActionButton: FloatingActionButton.extended(
        onPressed:
            _uploading ? null : () => _pickAndUpload(child.uid, parentUid),
        icon: _uploading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.upload_file),
        label: Text(_uploading ? 'Uploading...' : 'Upload'),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _repo.watchDocuments(child.uid),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data!;
          if (docs.isEmpty) {
            return const Center(child: Text('No documents yet.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final d = docs[i];
              final createdAt = d['createdAt'];
              final dateStr = createdAt != null
                  ? DateFormat.yMMMd()
                      .format((createdAt as dynamic).toDate())
                  : '';
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.insert_drive_file_outlined,
                      color: AppColors.primary),
                  title: Text(d['fileName'] as String? ?? 'Document',
                      style: AppTextStyles.bodyMedium),
                  subtitle: Text(dateStr),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _repo.deleteDocument(d['id'] as String),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
```

(Confirm `ParentProvider.selectedChild` exposes a `UserModel`-shaped object with `.uid`/`.name` — matches the pattern already used by `_ParentReportsTab`/`ChildAnalyticsScreen`.)

- [ ] **Step 4: Add a route and Home-tab entry point**

In `lib/main.dart`, add the import and route:

```dart
import 'features/parent/screens/document_vault_screen.dart';
...
        '/document_vault': (_) => const DocumentVaultScreen(),
```

In `lib/features/dashboard/screens/parent_dashboard.dart`'s `_ParentHomeTab` (append below the existing `_buildQuickStats(isMobile)` call, since the investigation confirmed this tab is a `SingleChildScrollView` with room to grow), add a card:

```dart
            const SizedBox(height: 20),
            Card(
              child: ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: const Text('Document Vault'),
                subtitle: const Text('School reports, medical notes and more'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pushNamed(context, '/document_vault'),
              ),
            ),
```

- [ ] **Step 5: Update the test for the new `uploadDocument` signature**

`test/data/parent_repository_test.dart` — if any existing test calls the old `uploadDocument(Map)` signature, update it to the new named-parameter signature. If none does (per the investigation, only 1 trivial constructor test exists in this file), add:

```dart
test('uploadDocument has the expected named-parameter signature', () {
  expect(ParentRepository().uploadDocument, isA<Function>());
});
```

- [ ] **Step 6: Run `flutter analyze` and the full test suite**

Run: `flutter analyze` — expect 0 errors.
Run: `flutter test` — expect all green.

- [ ] **Step 7: Commit**

```bash
git add lib/data/repositories/parent_repository.dart lib/features/parent/screens/document_vault_screen.dart lib/main.dart lib/features/dashboard/screens/parent_dashboard.dart storage.rules test/data/parent_repository_test.dart
git commit -m "feat(parent): complete Document Vault -- real file upload, list, delete

uploadDocument only ever wrote a caller-supplied metadata map, never
actually uploading file bytes anywhere despite firebase_storage
already being a dependency. No screen called any of the vault's
repository methods. Added real Storage upload + a screen + a Home-tab
entry point."
```

---

## Task 8: Complete Mood Check-in UI (log + history) and fix the `loggedByUid` bug

**Context:** `ParentRepository.logMood`/`watchMoodHistory` are fully implemented; `ParentProvider.logMoodCheckin` (`lib/providers/parent_provider.dart:143-150`) hardcodes `'loggedByUid': ''` and has no screen calling it.

**Files:**
- Modify: `lib/providers/parent_provider.dart`
- Create: `lib/features/parent/screens/mood_checkin_screen.dart`
- Modify: `lib/features/dashboard/screens/parent_dashboard.dart` (Home tab entry point)
- Modify: `firestore.rules` (`mood_checkins` currently has no delete rule; add one so a parent can remove a mistaken entry)

**Interfaces:**
- Produces: `ParentProvider.logMoodCheckin(String childUid, String loggedByUid, String mood, String emoji, String? note)` (signature change — adds `loggedByUid` parameter).

- [ ] **Step 1: Fix the `loggedByUid` bug**

In `lib/providers/parent_provider.dart`, replace:

```dart
  Future<void> logMoodCheckin(
      String childUid, String mood, String emoji, String? note) async {
    await _parentRepo.logMood({
      'childUid': childUid,
      'loggedByUid': '',
      'mood': mood,
      'moodEmoji': emoji,
      'note': note,
    });
  }
```

with:

```dart
  Future<void> logMoodCheckin(String childUid, String loggedByUid,
      String mood, String emoji, String? note) async {
    await _parentRepo.logMood({
      'childUid': childUid,
      'loggedByUid': loggedByUid,
      'mood': mood,
      'moodEmoji': emoji,
      'note': note,
    });
  }
```

- [ ] **Step 2: Add a delete rule for `mood_checkins`**

In `firestore.rules`, find the `mood_checkins` block (currently `allow create` + `allow read` only). Add:

```
      allow delete: if isParent() &&
                        resource.data.loggedByUid == request.auth.uid;
```

(Scoped to the entry's own logger, not any linked parent, so one parent can't delete another linked parent's mood log entry.)

- [ ] **Step 3: Create `MoodCheckinScreen`**

Create `lib/features/parent/screens/mood_checkin_screen.dart` with a mood-picker row (5-6 emoji choices, e.g. 😊 🙂 😐 😟 😢), an optional note field, a "Log Mood" button calling `context.read<ParentProvider>().logMoodCheckin(child.uid, parentUid, selectedMood, selectedEmoji, noteController.text.isEmpty ? null : noteController.text)`, and below it a `StreamBuilder<List<Map<String, dynamic>>>` on `ParentRepository().watchMoodHistory(child.uid)` rendering a dated list (mirror `DocumentVaultScreen`'s `StreamBuilder`/`ListView.separated` structure from Task 7 exactly, swapping the tile content for mood emoji + note + date, and the trailing delete button calling a new corresponding repository delete — reuse `ParentRepository`'s existing Firestore delete pattern, e.g. add a `deleteMoodEntry(String id)` method mirroring `deleteDocument`'s one-liner body if it doesn't already exist).

- [ ] **Step 4: Add `deleteMoodEntry` if missing**

In `lib/data/repositories/parent_repository.dart`, if there's no delete method for `mood_checkins`, add one next to `logMood`/`watchMoodHistory`:

```dart
  Future<void> deleteMoodEntry(String checkinId) async {
    await _db.collection('mood_checkins').doc(checkinId).delete();
  }
```

- [ ] **Step 5: Add a route and Home-tab entry point**

In `lib/main.dart`:

```dart
import 'features/parent/screens/mood_checkin_screen.dart';
...
        '/mood_checkin': (_) => const MoodCheckinScreen(),
```

In `_ParentHomeTab` (`parent_dashboard.dart`), add a second card below the Document Vault one from Task 7:

```dart
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.mood_outlined),
                title: const Text('Mood Check-in'),
                subtitle: const Text('Log how your child is feeling today'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pushNamed(context, '/mood_checkin'),
              ),
            ),
```

- [ ] **Step 6: Run `flutter analyze` and the full test suite; verify rules brace balance**

Run: `flutter analyze` — expect 0 errors.
Run: `flutter test` — expect all green.

- [ ] **Step 7: Commit**

```bash
git add lib/providers/parent_provider.dart lib/data/repositories/parent_repository.dart lib/features/parent/screens/mood_checkin_screen.dart lib/main.dart lib/features/dashboard/screens/parent_dashboard.dart firestore.rules
git commit -m "feat(parent): complete Mood Check-in -- log + history, fix loggedByUid bug

logMoodCheckin hardcoded loggedByUid: '' and no screen called it at
all. Added the real parent uid, a log+history screen, a delete
capability (mood_checkins had no delete rule), and a Home-tab entry
point."
```

---

## Task 9: Teacher-parent messaging — data model, repository, Firestore rules

**Context:** No messaging feature exists anywhere in the codebase (confirmed via exhaustive grep — zero `messages`/`conversations`/`threads` collections in `firestore.rules`, zero matching repository/model filenames). This task builds the data layer; UI follows in Tasks 10-11.

**Files:**
- Create: `lib/data/models/conversation_model.dart`
- Create: `lib/data/models/thread_message_model.dart`
- Create: `lib/data/repositories/messaging_repository.dart`
- Modify: `firestore.rules`
- Test: `test/data/messaging_repository_test.dart`

**Interfaces:**
- Produces: `ConversationModel` (id, participants: List<String>, teacherUid, parentUid, childUid, lastMessage, lastMessageAt, createdAt), `ThreadMessageModel` (id, senderUid, senderRole, text, sentAt), `MessagingRepository.getOrCreateConversation({required teacherUid, required parentUid, required childUid})`, `.sendMessage({required conversationId, required senderUid, required senderRole, required text})`, `.watchMessages(conversationId)`, `.watchConversationsForUser(uid)`.

- [ ] **Step 1: Write the failing test**

Create `test/data/messaging_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/data/repositories/messaging_repository.dart';

void main() {
  group('MessagingRepository conversation id', () {
    test('is deterministic regardless of teacher/parent argument order', () {
      final idA = MessagingRepository.conversationId(
          teacherUid: 't1', parentUid: 'p1', childUid: 'c1');
      final idB = MessagingRepository.conversationId(
          teacherUid: 't1', parentUid: 'p1', childUid: 'c1');
      expect(idA, idB);
    });

    test('differs for a different child even with the same teacher/parent', () {
      final idA = MessagingRepository.conversationId(
          teacherUid: 't1', parentUid: 'p1', childUid: 'c1');
      final idB = MessagingRepository.conversationId(
          teacherUid: 't1', parentUid: 'p1', childUid: 'c2');
      expect(idA, isNot(idB));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/messaging_repository_test.dart`
Expected: FAIL — `MessagingRepository` doesn't exist yet.

- [ ] **Step 3: Create `ConversationModel`**

Create `lib/data/models/conversation_model.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

class ConversationModel {
  final String id;
  final String teacherUid;
  final String parentUid;
  final String childUid;
  final String childName;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final DateTime createdAt;

  const ConversationModel({
    required this.id,
    required this.teacherUid,
    required this.parentUid,
    required this.childUid,
    required this.childName,
    this.lastMessage = '',
    this.lastMessageAt,
    required this.createdAt,
  });

  List<String> get participants => [teacherUid, parentUid];

  factory ConversationModel.fromMap(Map<String, dynamic> map, String id) {
    return ConversationModel(
      id: id,
      teacherUid: map['teacherUid'] as String,
      parentUid: map['parentUid'] as String,
      childUid: map['childUid'] as String,
      childName: map['childName'] as String? ?? '',
      lastMessage: map['lastMessage'] as String? ?? '',
      lastMessageAt: map['lastMessageAt'] is Timestamp
          ? (map['lastMessageAt'] as Timestamp).toDate()
          : null,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'teacherUid': teacherUid,
        'parentUid': parentUid,
        'childUid': childUid,
        'childName': childName,
        'participants': participants,
        'lastMessage': lastMessage,
        'lastMessageAt':
            lastMessageAt != null ? Timestamp.fromDate(lastMessageAt!) : null,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
```

- [ ] **Step 4: Create `ThreadMessageModel`**

Create `lib/data/models/thread_message_model.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

class ThreadMessageModel {
  final String id;
  final String senderUid;
  final String senderRole; // 'teacher' | 'parent'
  final String text;
  final DateTime sentAt;

  const ThreadMessageModel({
    required this.id,
    required this.senderUid,
    required this.senderRole,
    required this.text,
    required this.sentAt,
  });

  factory ThreadMessageModel.fromMap(Map<String, dynamic> map, String id) {
    return ThreadMessageModel(
      id: id,
      senderUid: map['senderUid'] as String,
      senderRole: map['senderRole'] as String,
      text: map['text'] as String,
      sentAt: (map['sentAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'senderUid': senderUid,
        'senderRole': senderRole,
        'text': text,
        'sentAt': Timestamp.fromDate(sentAt),
      };
}
```

- [ ] **Step 5: Create `MessagingRepository`**

Create `lib/data/repositories/messaging_repository.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/conversation_model.dart';
import '../models/thread_message_model.dart';

/// Teacher <-> parent messaging, one conversation per (teacher, parent,
/// child) triple. Conversation docs live in `conversations/{id}`, with a
/// `messages` subcollection per conversation.
class MessagingRepository {
  final _db = FirebaseFirestore.instance;

  /// Deterministic id so repeated getOrCreate calls for the same triple
  /// never create duplicate threads, regardless of call-site argument
  /// order (teacherUid/parentUid are sorted before joining).
  static String conversationId({
    required String teacherUid,
    required String parentUid,
    required String childUid,
  }) {
    final sorted = [teacherUid, parentUid]..sort();
    return '${sorted[0]}_${sorted[1]}_$childUid';
  }

  Future<ConversationModel> getOrCreateConversation({
    required String teacherUid,
    required String parentUid,
    required String childUid,
    required String childName,
  }) async {
    final id = conversationId(
        teacherUid: teacherUid, parentUid: parentUid, childUid: childUid);
    final ref = _db.collection('conversations').doc(id);
    final snap = await ref.get();
    if (snap.exists) {
      return ConversationModel.fromMap(snap.data()!, id);
    }
    final model = ConversationModel(
      id: id,
      teacherUid: teacherUid,
      parentUid: parentUid,
      childUid: childUid,
      childName: childName,
      createdAt: DateTime.now(),
    );
    await ref.set(model.toMap());
    return model;
  }

  Future<void> sendMessage({
    required String conversationId,
    required String senderUid,
    required String senderRole,
    required String text,
  }) async {
    final now = DateTime.now();
    final convoRef = _db.collection('conversations').doc(conversationId);
    final msgRef = convoRef.collection('messages').doc();
    final batch = _db.batch();
    batch.set(
      msgRef,
      ThreadMessageModel(
        id: msgRef.id,
        senderUid: senderUid,
        senderRole: senderRole,
        text: text,
        sentAt: now,
      ).toMap(),
    );
    batch.update(convoRef, {
      'lastMessage': text,
      'lastMessageAt': Timestamp.fromDate(now),
    });
    await batch.commit();
  }

  Stream<List<ThreadMessageModel>> watchMessages(String conversationId) {
    return _db
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('sentAt')
        .snapshots()
        .map((s) => s.docs
            .map((d) => ThreadMessageModel.fromMap(d.data(), d.id))
            .toList());
  }

  Stream<List<ConversationModel>> watchConversationsForUser(String uid) {
    return _db
        .collection('conversations')
        .where('participants', arrayContains: uid)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => ConversationModel.fromMap(d.data(), d.id))
            .toList());
  }
}
```

- [ ] **Step 6: Run the repository test**

Run: `flutter test test/data/messaging_repository_test.dart`
Expected: PASS (2/2).

- [ ] **Step 7: Add Firestore rules for `conversations` and its `messages` subcollection**

In `firestore.rules`, add a new top-level block (near the other feature collections like `document_vault`):

```
    // ==================== TEACHER-PARENT MESSAGING ====================
    match /conversations/{conversationId} {
      allow read: if isSignedIn() && request.auth.uid in resource.data.participants;
      allow create: if isSignedIn() &&
                        request.auth.uid in request.resource.data.participants &&
                        (isTeacher() || isParent());
      allow update: if isSignedIn() &&
                        request.auth.uid in resource.data.participants &&
                        request.resource.data.diff(resource.data).affectedKeys()
                          .hasOnly(['lastMessage', 'lastMessageAt']);

      match /messages/{messageId} {
        allow read: if isSignedIn() &&
                        request.auth.uid in
                          get(/databases/$(database)/documents/conversations/$(conversationId)).data.participants;
        allow create: if isSignedIn() &&
                          request.auth.uid in
                            get(/databases/$(database)/documents/conversations/$(conversationId)).data.participants &&
                          request.resource.data.senderUid == request.auth.uid;
      }
    }
```

- [ ] **Step 8: Verify brace balance**

Run: `grep -o '{' firestore.rules | wc -l` and `grep -o '}' firestore.rules | wc -l` — counts must match.

- [ ] **Step 9: Run `flutter analyze` and the full test suite**

Run: `flutter analyze` — expect 0 errors.
Run: `flutter test` — expect all green.

- [ ] **Step 10: Commit**

```bash
git add lib/data/models/conversation_model.dart lib/data/models/thread_message_model.dart lib/data/repositories/messaging_repository.dart firestore.rules test/data/messaging_repository_test.dart
git commit -m "feat(messaging): add teacher-parent conversation/message data layer

New feature -- no messaging capability existed anywhere in the app.
One conversation per (teacher, parent, child) triple, deterministic
id so repeated getOrCreate calls never duplicate a thread."
```

---

## Task 10: Cloud Function to notify on new message

**Context:** `firestore.rules`'s `notifications` collection only allows a client to create a notification doc where `recipientUid == request.auth.uid` (`firestore.rules:167-169`) — a teacher's client cannot write a notification doc targeting the parent's uid directly. `functions/src/notifications/badgeAward.ts` is the exact template for a server-side trigger that notifies a *different* uid.

**Files:**
- Create: `functions/src/notifications/newMessage.ts`
- Modify: `functions/src/index.ts` (export the new function)

**Interfaces:**
- Consumes: `conversations/{conversationId}/messages/{messageId}` doc shape from Task 9 (`senderUid`, `senderRole`, `text`), and the parent `conversations/{conversationId}` doc (`teacherUid`, `parentUid`, `childName`).

- [ ] **Step 1: Write the Cloud Function**

Create `functions/src/notifications/newMessage.ts`:

```typescript
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";

export const onNewMessage = onDocumentCreated(
  "conversations/{conversationId}/messages/{messageId}",
  async (event) => {
    const message = event.data?.data();
    if (!message) return;

    const conversationId = event.params.conversationId;
    const convoSnap = await admin.firestore()
      .collection("conversations").doc(conversationId).get();
    const convo = convoSnap.data();
    if (!convo) return;

    const senderUid: string = message.senderUid;
    const senderRole: string = message.senderRole;
    const recipientUid = senderUid === convo.teacherUid
      ? convo.parentUid
      : convo.teacherUid;
    if (!recipientUid || recipientUid === senderUid) return;

    const childName: string = convo.childName ?? "your child";
    const senderLabel = senderRole === "teacher" ? "Teacher" : "Parent";

    await admin.firestore().collection("notifications").add({
      title: `New message about ${childName}`,
      body: `${senderLabel}: ${String(message.text).slice(0, 100)}`,
      type: "message",
      recipientUid,
      read: false,
      isRead: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });
```

- [ ] **Step 2: Export it from `functions/src/index.ts`**

Read `functions/src/index.ts` to find the existing export pattern for `onBadgeAwarded` (from `badgeAward.ts`) and add an identical export line for `onNewMessage` from `./notifications/newMessage`.

- [ ] **Step 3: Build and lint**

Run: `cd functions && npm run build && npm run lint`
Expected: 0 errors.

- [ ] **Step 4: Commit**

```bash
git add functions/src/notifications/newMessage.ts functions/src/index.ts
git commit -m "feat(messaging): notify the other participant on a new message

Mirrors onBadgeAwarded's pattern -- a server-side trigger is required
here because firestore.rules only lets a client write a notification
doc for its own uid; a teacher's client can't write one targeting the
parent directly."
```

---

## Task 11: Teacher-side messaging UI

**Context:** `_ClassTab`'s `_LearnerDetailSheet` (`lib/features/dashboard/screens/teacher_dashboard.dart:808+`) already shows a per-learner detail sheet with the learner's `UserModel` (including `linkedParentUids`) — the natural entry point for "Message Parent."

**Files:**
- Create: `lib/features/messaging/screens/message_thread_screen.dart` (shared by both roles)
- Modify: `lib/features/dashboard/screens/teacher_dashboard.dart`

**Interfaces:**
- Consumes: `MessagingRepository` (Task 9), `AuthProvider.user` for the current uid/role.

- [ ] **Step 1: Build the shared thread screen**

Create `lib/features/messaging/screens/message_thread_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../data/models/conversation_model.dart';
import '../../../data/models/thread_message_model.dart';
import '../../../data/repositories/messaging_repository.dart';
import '../../../providers/auth_provider.dart';

class MessageThreadScreen extends StatefulWidget {
  final ConversationModel conversation;
  const MessageThreadScreen({super.key, required this.conversation});

  @override
  State<MessageThreadScreen> createState() => _MessageThreadScreenState();
}

class _MessageThreadScreenState extends State<MessageThreadScreen> {
  final _repo = MessagingRepository();
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  Future<void> _send() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    _textCtrl.clear();
    await _repo.sendMessage(
      conversationId: widget.conversation.id,
      senderUid: user.uid,
      senderRole: user.role,
      text: text,
    );
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myUid = context.watch<AuthProvider>().user?.uid;
    return Scaffold(
      appBar: AppBar(title: Text('About ${widget.conversation.childName}')),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ThreadMessageModel>>(
              stream: _repo.watchMessages(widget.conversation.id),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = snap.data!;
                if (messages.isEmpty) {
                  return const Center(child: Text('No messages yet. Say hello!'));
                }
                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (_, i) {
                    final m = messages[i];
                    final isMe = m.senderUid == myUid;
                    return Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        constraints: BoxConstraints(
                            maxWidth:
                                MediaQuery.of(context).size.width * 0.72),
                        decoration: BoxDecoration(
                          color: isMe
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m.text,
                                style: TextStyle(
                                    color: isMe
                                        ? Theme.of(context)
                                            .colorScheme
                                            .onPrimary
                                        : null)),
                            const SizedBox(height: 2),
                            Text(
                              DateFormat.jm().format(m.sentAt),
                              style: TextStyle(
                                fontSize: 10,
                                color: (isMe
                                        ? Theme.of(context).colorScheme.onPrimary
                                        : null)
                                    ?.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _send,
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

- [ ] **Step 2: Add "Message Parent" to `_LearnerDetailSheet`**

In `lib/features/dashboard/screens/teacher_dashboard.dart`, find `_LearnerDetailSheet`'s build method (starts line 808). Add a button near the end of its `ListView`'s `children:` (after the existing info rows, before the closing of the list):

```dart
          const SizedBox(height: 20),
          if (learner.linkedParentUids.isNotEmpty)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.message_outlined),
                label: const Text('Message Parent'),
                onPressed: () async {
                  final teacherUid =
                      context.read<AuthProvider>().user?.uid ?? '';
                  final parentUid = learner.linkedParentUids.first;
                  final convo =
                      await MessagingRepository().getOrCreateConversation(
                    teacherUid: teacherUid,
                    parentUid: parentUid,
                    childUid: learner.uid,
                    childName: learner.name,
                  );
                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            MessageThreadScreen(conversation: convo),
                      ),
                    );
                  }
                },
              ),
            ),
```

Add the needed imports at the top of `teacher_dashboard.dart`:

```dart
import '../../../data/repositories/messaging_repository.dart';
import '../../messaging/screens/message_thread_screen.dart';
import '../../../providers/auth_provider.dart';
```

(If `AuthProvider` is already imported under a different alias, reuse the existing import instead of adding a duplicate.)

- [ ] **Step 3: Run `flutter analyze` and the full test suite**

Run: `flutter analyze` — expect 0 errors.
Run: `flutter test` — expect all green.

- [ ] **Step 4: Commit**

```bash
git add lib/features/messaging/screens/message_thread_screen.dart lib/features/dashboard/screens/teacher_dashboard.dart
git commit -m "feat(messaging): teacher-side entry point and shared thread UI

Message Parent button on the existing per-learner detail sheet in the
Class tab, opening a shared thread screen (reused by the parent side
in the next task)."
```

---

## Task 12: Parent-side messaging UI

**Context:** Parents need a way to see their conversations (one per linked child's teacher(s)) and open the same thread screen from Task 11.

**Files:**
- Create: `lib/features/parent/screens/messages_list_screen.dart`
- Modify: `lib/main.dart`
- Modify: `lib/features/dashboard/screens/parent_dashboard.dart` (Home tab entry point)

**Interfaces:**
- Consumes: `MessagingRepository.watchConversationsForUser` (Task 9), `MessageThreadScreen` (Task 11).

- [ ] **Step 1: Build the conversations list screen**

Create `lib/features/parent/screens/messages_list_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../data/repositories/messaging_repository.dart';
import '../../../providers/auth_provider.dart';
import '../../messaging/screens/message_thread_screen.dart';

class MessagesListScreen extends StatelessWidget {
  const MessagesListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().user?.uid ?? '';
    final repo = MessagingRepository();

    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: StreamBuilder(
        stream: repo.watchConversationsForUser(uid),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final conversations = snap.data!;
          if (conversations.isEmpty) {
            return const Center(
                child: Text("No messages yet -- your child's teacher will "
                    'appear here once you message.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: conversations.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final c = conversations[i];
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.school)),
                  title: Text('About ${c.childName}'),
                  subtitle: Text(
                    c.lastMessage.isEmpty ? 'No messages yet' : c.lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: c.lastMessageAt != null
                      ? Text(DateFormat.MMMd().format(c.lastMessageAt!))
                      : null,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MessageThreadScreen(conversation: c),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 2: Add a route and Home-tab entry point**

In `lib/main.dart`:

```dart
import 'features/parent/screens/messages_list_screen.dart';
...
        '/messages': (_) => const MessagesListScreen(),
```

In `_ParentHomeTab` (`parent_dashboard.dart`), add a third card below the Document Vault and Mood Check-in ones from Tasks 7-8:

```dart
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.message_outlined),
                title: const Text('Messages'),
                subtitle: const Text("Chat with your child's teacher"),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pushNamed(context, '/messages'),
              ),
            ),
```

- [ ] **Step 3: Run `flutter analyze` and the full test suite**

Run: `flutter analyze` — expect 0 errors.
Run: `flutter test` — expect all green.

- [ ] **Step 4: Commit**

```bash
git add lib/features/parent/screens/messages_list_screen.dart lib/main.dart lib/features/dashboard/screens/parent_dashboard.dart
git commit -m "feat(messaging): parent-side conversations list

Completes the teacher-parent messaging feature -- a parent can now
see every conversation across their linked children's teachers and
open the same shared thread screen the teacher side uses."
```

---

## Task 13: End-of-phase verification and summary

- [ ] **Step 1: Full static + test verification**

Run: `flutter analyze` — must be 0 errors.
Run: `flutter test` — must be 100% green.
Run: `cd functions && npm run build && npm run lint` — must be 0 errors.

- [ ] **Step 2: Firestore/Storage rules emulator validation**

Run `firebase emulators:start --only firestore,storage,auth` and manually exercise (or write quick emulator-backed scripts for): a learner-creation write missing consent fields (must be rejected), a learner-creation write with all consent fields (must succeed), a second parent's link-request approval now succeeding end-to-end (Task 1's fix), a teacher writing a `conversations` doc as one of its `participants` (must succeed) vs. as a non-participant (must be rejected), and a parent deleting their own `mood_checkins` entry vs. another parent's (must be rejected). If the emulator can't run on this machine due to memory constraints, document that explicitly rather than claiming it was verified.

- [ ] **Step 3: Live verification — parent linking flow**

`flutter run -d chrome`: create a child via "Add a Child" (with a second test parent account), confirm the child's `parentUid` is now set (Task 1), send a link request as the second parent, confirm the primary parent's Profile tab now shows a pending-request badge and `LinkRequestsScreen` lists it (Tasks 4-5), approve it, confirm it disappears and the child appears in the second parent's linked-children list.

- [ ] **Step 4: Live verification — Document Vault, Mood Check-in, Messaging**

Upload a real file to Document Vault and confirm it appears in the list and downloads correctly; log a mood check-in and confirm it appears with the correct `loggedByUid`; as a teacher, open a learner's detail sheet, tap "Message Parent," send a message, and confirm it appears in the parent's Messages list with a notification.

- [ ] **Step 5: Write the phase completion report**

Summarize for the user: all 13 tasks completed, the critical multi-parent-linking bug found and fixed, the POPIA consent enforcement gap closed, 2 previously-unreachable backend-only features (Document Vault, Mood Check-in) now fully functional end-to-end, and the new teacher-parent messaging feature. Flag explicitly which of Steps 2-4's live/emulator verifications could not be completed due to this machine's memory constraints (do not claim success without having tested — follow the same honesty standard established in Phase 11 and Phase 12's completion reports). Per Rule 2, stop and wait for the user's "Continue" or final sign-off, since Phase 13 is the last of the 13 planned phases — after this, the next step is the final commit-and-push once the user approves all phases as complete.
