# Deferred work

Items intentionally postponed during the pre-demo hardening pass (see CLAUDE.md
and the phase-by-phase prompts in `docs/PROMPT_1_UPGRADE_AND_CLEANUP.md` /
`docs/PROMPT_2_FINAL_SHIP_0800.md`). Each entry says why it was deferred and
what to do next.

## Auth / Firestore rules (2026-08-02): parent/teacher registration still not fully working end-to-end

Found by actually running the real signup flow (`AuthProvider.registerParent`
→ `AuthService.registerWithEmail`) against the Firebase emulator with a fresh
Grade 4 test account. `firestore.rules`' `allow create` on `/users/{uid}`
required `role == 'learner'` unconditionally, so **any parent or teacher
self-registration was rejected outright** — the very first Firestore write
in the signup flow, before any child-related code runs. Fixed across three
commits: allow `role in ['parent', 'teacher']` to create without the POPIA
consent trail (which stays required for `learner`); require
`linkedChildrenUids.size() == 0` and `birthDate == null` on that branch to
close a claim-laundering / consent-bypass gap a plain role check would
otherwise leave open; corrected a false claim in the first fix's own comment
about which code path was actually safe. All three verified against the
Firestore emulator and the full `flutter test` suite (318/318).

**This closes the immediate crash. Items 1 and 2 below are now FIXED
(2026-08-03) — a real parent+child signup was driven through the actual
UI against the Firebase emulator and confirmed working end-to-end,
landing on the parent dashboard with the child correctly linked and
visible. Items 3 and 4 are still open.**

1. **FIXED: a self-registered parent/teacher's Firestore doc got created,
   but their Firebase Auth custom claim never followed, and even once it
   did server-side, the client never picked it up.** Two separate bugs,
   both fixed:

   - `assignDefaultRole` (see above) pins every new Auth user to
     `{role: "learner"}` — it fires at Auth-account-creation time, before
     the client's Firestore doc even exists, so it has no way to know a
     signup intends to be a parent or teacher. Added
     `grantSelfDeclaredRoleClaim` (`functions/src/admin/setUserRole.ts`),
     a Firestore `onDocumentCreated` trigger on `users/{uid}` that upgrades
     the claim to `parent`/`teacher` immediately after that doc is
     created, trusting the doc's self-declared `role` the same way the
     client's own registration flow already does (see the trigger's own
     doc comment for why that's safe — the real boundary is
     `linkedChildrenUids.size() == 0` at create, not this claim).
   - Even with the claim correctly upgraded server-side (confirmed via
     `admin.auth().getUser(uid).customClaims`), the **client never
     refreshed its cached ID token to pick it up — not even across a full
     page reload.** Confirmed directly via the Firestore Emulator UI's
     Requests tab: a query made well after the server-side claim was
     already `parent` was still presenting `role: "learner"` to
     `firestore.rules`. Firebase Auth does not retroactively update an
     already-issued token when a custom claim changes; the SDK just
     restores whatever's in local persistence on every app start unless
     something explicitly calls `getIdToken(forceRefresh: true)`. Fixed
     by forcing a refresh in `AuthProvider._init()`'s `authStateChanges`
     handler, so every session start self-heals regardless of whether any
     earlier claim-grant caught up in time.
   - `AuthService` also gained `_waitForRoleClaim`, called right after the
     parent/teacher doc is created during registration, so the *current*
     session can pick up the claim without needing a reload at all. **This
     does not fully work yet** — confirmed live: immediately after a
     successful registration, in the same continuous session, the parent
     dashboard still shows no linked child until the page is reloaded once.
     The `_init()` fix above makes this self-healing (reload once and it's
     fixed), but the root cause of why the same-session polling doesn't
     propagate to Firestore's own cached credential hasn't been pinned
     down — likely a `cloud_firestore`/`firebase_auth` plugin-level gap
     between "Auth's token is refreshed" and "Firestore's connection
     picks up the new token," not an application bug. Worth a follow-up
     if the one-reload requirement turns out to matter for the real UX
     (a toast telling the user to refresh, or an explicit
     `FirebaseFirestore.instance` reconnect call, are both plausible
     workarounds if so).
2. **FIXED (registration-time case only): a parent could never link a
   child to their own account — not even one they just created
   themselves.** `linkedChildrenUids` is a locked field
   (`lockedUserFields()`); `allow update` on `/users/{uid}` rejects every
   client write to it unconditionally, by design, so no client-side code
   could ever complete this link, including `UserRepository.linkChild()`
   during registration. Added `linkRegisteredChild`
   (`functions/src/parent/linkChild.ts`), a callable Cloud Function that
   verifies the caller is `uid == parentUid` and that the target child's
   own doc already declares `parentUid == parentUid` (set correctly at
   child-doc-creation time by the child's own temp Auth session), then
   completes the parent-side write via the Admin SDK. Rewired
   `UserRepository.linkChild()` to call it instead of writing directly.
   Also removed the now-redundant, separately-doomed child-side
   `.update({'parentUid': ...})` call this function used to make (that
   field is already set correctly at doc creation; the write was rejected
   on ownership anyway, not just redundant).

   Hit one real bug while building the fix itself, since it's worth
   recording: the function's first version used
   `admin.firestore.FieldValue.arrayUnion(...)` (the namespaced style
   already used everywhere else in this functions codebase) and threw
   `Cannot read properties of undefined (reading 'arrayUnion')` at
   runtime in the emulator, despite that exact pattern working in a
   standalone Node script against the same `firebase-admin` version.
   Switched to the modular `import { getFirestore, FieldValue } from
   "firebase-admin/firestore"` style, which resolved it. **Not
   confirmed whether the namespaced style is genuinely broken elsewhere
   in this codebase or whether this was specific to something about this
   one function/file** — every other `admin.firestore.FieldValue.X` call
   site (`badgeAward.ts`, `sendPush.ts`, `classBroadcast.ts`,
   `newMessage.ts`, `reminders.ts`, `index.ts`'s `sendEmail`) still uses
   the namespaced style and has not been directly observed failing, but
   none of them have been directly exercised end-to-end against the
   emulator this session either (several are scheduled functions the
   local emulator can't even run without pubsub). Worth switching them to
   the modular style preemptively, or at least verifying each one
   live, before trusting them.

   **Update (2026-08-03): 2 of the other 3 call sites are now also
   fixed.** First, an important correction to the original framing above:
   `ParentRepository.linkParentToChild` and `unlinkParentFromChild` had
   zero callers anywhere in `lib/` at the time they were first flagged —
   the real "link to an existing child" UI (`link_child_screen.dart`)
   goes through `sendLinkRequest` → `approveLinkRequest` (a request/
   approval model) for every sub-flow, code included, not a direct link.
   So `docs/DEMO_CHECKLIST.md` step 5 failing was really about
   `approveLinkRequest` alone, not four independently-broken call sites.

   - **`approveLinkRequest`: FIXED.** Added `approveParentLinkRequest`
     (`functions/src/parent/approveLinkRequest.ts`) — verifies the caller
     is the request's `primaryParentUid` (a different authorization model
     than `linkRegisteredChild`, since here a parent is being granted
     access to a child they didn't create, so it has to come from the
     primary parent's explicit approval of a specific pending request,
     not from anything the requester can assert about themselves) and a
     `status == 'pending'` check, then completes both writes via the
     Admin SDK. Tested directly against the emulator: wrong-parent
     approval attempt denied, correct approval succeeds with verified
     Firestore state on both sides, re-approving an already-resolved
     request denied. Deployed to production.
   - **`unlinkParentFromChild`: FIXED, and a real "Unlink" UI now
     exists** (`ChildAnalyticsScreen`'s new `link_off` icon button, next
     to the PDF export button, with an `AppDialog.confirm` destructive-
     action dialog). Added `unlinkParentChild`
     (`functions/src/parent/unlinkChild.ts`) — self-service only (a
     parent can remove their own link, never another parent's; revoking
     a co-parent's access is a separate, harder authorization question
     not addressed here) — verifies the caller is actually currently
     linked before removing both sides via the Admin SDK. Tested both
     directly against the emulator (unrelated parent denied; correct
     parent's self-unlink succeeds and leaves a co-parent's own link
     untouched) and through the real UI end-to-end: click Unlink →
     confirm → snackbar → pops back to the dashboard → "My Children"
     correctly shows the child removed, no reload needed (unlike the
     claim-upgrade case in item 1, a plain array removal doesn't need a
     token refresh to propagate through the live Firestore listener
     already in place). Deployed to production.
   - **`linkParentToChild` is still genuinely dead code, deliberately
     left unfixed.** It has no concept of the primary parent's consent at
     all — fixing it naively (the same kind of Cloud Function as the
     other three) would let any signed-in parent link themselves to an
     arbitrary child by uid alone, bypassing the exact approval step that
     makes `approveLinkRequest` safe. Fixing it requires first deciding
     whether it should exist at all, given `sendLinkRequest` →
     `approveLinkRequest` already covers the same use case more safely.
3. **Two implementations of "parent + child" signup exist; only one is
   wired up.** `AuthService.registerWithEmail`'s child branch is live (via
   `AuthProvider.registerParent` → the real signup UI). `registerParentWithChild`
   is dead code — no caller anywhere in `lib/providers/` or `lib/features/`.
   Its child-doc create was ALSO missing the POPIA consent fields the
   `learner` branch requires (the other two creation paths already had
   them) — fixed for consistency, but it hits the exact same item-2 gap the
   moment someone wires it up (its `linkChild` call at
   `auth_service.dart:311` has no orphan-cleanup around it either, unlike
   the other two live call sites — worse failure behavior than either,
   since by that point `tempApp` is already deleted, so a fix there needs
   the same `_cleanupOrphanedChild` treatment before this dead code should
   ever be wired up). Whoever does should first decide which of the two
   implementations is meant to be canonical, and delete the other — having
   both live invites them drifting out of sync again.
4. **Widening the `allow create` role check (item above) also widened what
   `allow delete: if isUser(uid)` can erase.** A signed-in user — including
   a learner, whose child-account credentials are deterministic on
   name+birthdate via `_generateChildEmail`/`_generateChildPassword`, so
   not meaningfully secret — can now delete their own `/users/{uid}` doc
   and recreate it as `role: 'parent'`, `birthDate: null`,
   `linkedChildrenUids: []`, erasing any POPIA consent trail the original
   doc carried with no server-side record it ever existed. Before this
   branch the recreate still required the four consent fields (forgeable,
   since they're self-supplied strings, but at least present); the delta
   introduced here is that the trail can now be removed outright, not just
   faked. **Not fixed in this branch** because the obvious fix
   (`allow delete: if false`) is unsafe: `AuthService._cleanupOrphanedChild`
   (added in this same branch, see item 1/2 above) relies on exactly this
   permission to delete an orphaned child's own doc via a client SDK call
   authenticated as that child — blocking client deletes outright would
   silently break that cleanup and reintroduce the orphaned-account
   problem it exists to prevent. A real fix needs delete to stay allowed
   for non-consent-bearing docs (or for an Admin SDK cleanup path
   specifically) while being blocked once a consent trail is present —
   that's a rule that needs to read `resource.data` for consent fields
   before authorizing delete, which is a design decision, not a
   mechanical tightening.

## Web platform (2026-08-02): dashboard XP/Level header still doesn't live-update after a game (root cause NOT fully found)

Found by actually playing games in a browser against the Firebase emulator
(per `docs/DEMO_CHECKLIST.md`'s step 3, "XP/coins shown on the result screen
match what's added to the dashboard header"): after finishing a game, the
result screen correctly shows the XP earned, and the reward really is
written to Firestore correctly (verified directly via the Admin SDK, twice,
across two separate games -- `users/{uid}.totalPoints` and
`rewards/{uid}.totalPoints` both land on the exact right total both times).
But the dashboard's XP/Level header stays frozen at its pre-game value
until a full page reload. **This is a display-only bug -- the underlying
reward data has been directly verified correct every time it was checked.**
Gold and Badges on the exact same header, sourced from a separate
`RewardsProvider.watchRewards()` stream, do update live correctly, which is
what makes this reproducible and worth chasing rather than a flake.

**Fixed, but did not resolve the symptom (kept anyway -- both are real,
independently-valid bugs):**
1. `cloud_firestore`'s Web SDK can return an integer field as a JS
   `double` (most reliably reproduced right after a `FieldValue.increment()`
   write -- `RewardsService.grantGameSessionRewards` increments
   `users/{uid}.totalPoints` this way). `UserModel.fromMap`'s
   `totalPoints: map['totalPoints'] ?? 0` bound that `double` straight to
   an `int`-typed field, which throws at runtime -- and since
   `UserRepository.watchUser()`'s `.map()` transform is consumed by
   `AuthProvider`'s `.listen()` call with no `onError` handler, a throw
   there would silently kill the stream after its first emission with no
   trace anywhere. `RewardsProvider`'s `goldBalance` field already guards
   against exactly this with `(map['goldBalance'] as num?)?.toInt() ?? 0`;
   `totalPoints` right next to it in the same model did not. Fixed both
   `UserModel.fromMap` (`totalPoints`, `streakDays`, and the `_tsToDate`
   helper used for `birthDate`/`lastActiveDate`/`createdAt`, which had the
   same `v is int` check silently failing to `null` instead of throwing)
   and the identical pattern in `RewardModel.fromMap` (`totalPoints`,
   `level`, `streakDays`, `lastActiveDate`) to match the already-correct
   `goldBalance` handling. **Rebuilt and re-tested against two full games
   after this fix -- the header was still stale both times**, so this was
   a real bug worth having fixed (it's a plausible crash/silent-stream-
   death vector generally) but not the cause of this specific symptom, or
   not the only one.
2. `main.dart`'s global `PlatformDispatcher.instance.onError`/
   `FlutterError.onError` handlers called `FirebaseCrashlytics.instance
   .recordError(...)` unconditionally; `firebase_crashlytics` has no web
   implementation, so on web the error handler itself throws, which could
   mask whatever it was trying to report. Guarded both with `kIsWeb`.
   Also did not resolve the symptom.

**Ruled out:** a stale browser cache/service-worker serving an older JS
bundle across rebuilds (real, and separately worth knowing about --
`flutter build web` output is aggressively cached by the Flutter-generated
service worker; `page.evaluate` unregistering service workers + clearing
`caches` before reload is required to actually pick up a new build when
testing this way, and it's easy to test against stale JS without realizing
it). Controlled for this explicitly on the final test round and the
staleness still reproduced.

**Not yet tried:** attaching Chrome DevTools / a debugger to see whether
`_userSubscription`'s `.listen()` callback fires at all after the first
emission (would definitively separate "stream never fires again" from
"fires but something in the widget tree doesn't rebuild") -- the tool used
for this testing pass (Playwright driving CanvasKit Flutter Web, no real
DOM) can't set Dart breakpoints or read Dart-level state, only observe via
screenshots, the accessibility bridge, and network/console logs, which
was enough to prove the bug and disprove two hypotheses but not enough to
find the real one. `flutter run -d chrome` with DevTools attached (noted
elsewhere in this doc as having its own DWDS websocket issues in this
environment) or a native (non-CanvasKit) debug session would be the next
step.

**Not yet audited: the same `map['x'] ?? 0`-without-`num`-coercion pattern
exists in `progress_model.dart`** (`score`, `pointsEarned`,
`timeTakenSeconds`) and possibly other model `fromMap` factories --
`grep -rn "'\] ?? 0" lib/data/models/` is the starting point. `ProgressModel
.fromMap` is used inside `ProgressRepository`'s `.snapshots()`-based list
streams (parent/teacher progress views), so the same silent-stream-death
failure mode is plausible there too, but this was not directly observed
broken in this testing pass (only the dashboard XP header was actually
exercised end-to-end in a browser) -- flagged here rather than fixed
speculatively, since fixing without reproducing first risks papering over a
different bug with the same-looking patch.

## Environment / tooling

- **`sqlite3: 2.9.4` `dependency_overrides` pin removed (Phase 1, UI
  redesign pass).** That pin (added in the `gamegen-0` commit to make
  `flutter test` runnable on networks that can't reach the sqlite3 build
  hook's GitHub release download) was actively breaking real Android
  builds: `sqflite_common_ffi 2.4.2` calls `Database.close()` /
  `CommonPreparedStatement.close()`, methods that don't exist on
  `sqlite3 2.9.4` (which only has `.dispose()`) — `flutter build apk
  --debug` failed with "The method 'close' isn't defined" every time.
  On a machine with normal internet access, the build hook resolves fine;
  removing the override lets pub resolve `sqlite3 3.4.0` (pulling in
  `native_toolchain_c` for the hook), which has `.close()` and fixes the
  Android build. `flutter test` was re-verified afterwards (164/164
  green) — the hook only needs network the first time it fetches the
  prebuilt binary, then it's cached in the pub cache.
  **If a future CI/sandbox run can't reach GitHub releases**, re-add
  `dependency_overrides: sqlite3: 2.9.4` for that environment only, but
  know it will break real device/app builds if left in permanently —
  don't reintroduce it as a blanket repo default.

## Game content pipeline (`tools/gamegen`)

- **`sequenceBuilder`'s `roundVariants` aren't consumed yet.** Every
  topic's content pack carries `roundVariants` — real, order-preserving
  sub-sequences of the topic's `steps`, generated for validator
  completeness and a future "replay variety" round — but
  `SequenceBuilderSession` still always plays the full `steps` list every
  round (matching the original single-sequence behaviour). To use them:
  have `_resetTray()` pick a random entry from `seqConfig.roundVariants`
  and constrain `_tray`/placement completion to that subset instead of
  `stages.length`.
- **`sequenceBuilder`'s animated backdrop doesn't vary by topic.**
  `SequenceBuilderGame` always renders `WaterCycleScene` regardless of
  `sceneType` — cosmetic only (the step text/order is correctly
  topic-specific for all 18 topics), but two different sequenceBuilder
  games still look the same behind the step list. Needs per-`sceneType`
  scene widgets or a generic parameterized one.
- **EMS has no dedicated `AppColors` constant.** Catalog entries for the
  EMS subject use a raw `Color(0xFF009688)` literal (pre-existing, not
  introduced by gamegen) rather than an `AppColors.ems`-style constant
  like the other six subjects.
- **Bespoke-engine reconciliation (Phase 14a) complete; 2 content-pack gaps remain.**
  The 54 topics using unique per-topic bespoke game engines (instead of 9 shared
  ones) have been fully reconciled: `topics.json` was synced with `game_catalog.dart`
  (commits 19b64f0, 4b31cfd, c774104), `classify.js` now derives `SHARED_ENGINES`
  for pipeline validation, and `extract.js`/`validate.js` are bespoke-aware.
  Five Grade 1 Life Skills topics accidentally deleted during the migration
  (`ls_g1_body`, `ls_g1_feelings`, `ls_g1_safety`, `ls_g1_community`, `ls_g1_habits`)
  were restored; one restoration (ls_g1_habits) revealed and fixed a pre-existing
  stale-snapshot bug (commit ddd241f). Five separate pre-existing `classify.js`
  classification gaps were also fixed: `ss_g7_neighbours` (never classified),
  and four Grade 7 topics whose real shipped engines (`sequenceBuilder`,
  `runnerCollector`) weren't permitted by stale cognitiveVerb mappings — these
  were actively causing `extract.js` to silently corrupt topics back to `tugOfWar`
  on every run (commit 98ddedf).
  **Two content-pack validation gaps remain and are out of scope**: `eng_g7_debate`
  and `eng_g7_spelling` are correctly `sequenceBuilder`-shaped (valid `sceneType`,
  6 valid `steps`) but only have 3 `roundVariants` where their tier requires 10.
  These are pre-existing content-authoring gaps, not regressions from this
  reconciliation — the fix site is `tools/gamegen/content/sequence_builder.js`,
  where `roundVariants` for these two topics would need to be authored/extended.
  They are allowlisted as known failures in `tools/gamegen/validate.js` so the
  mandatory gate stays green while still catching new regressions; see the
  validator output for details.
- **Stale bespoke content packs (`assets/content/*.json` for 54 bespoke topics).**
  The content packs on disk for all 54 bespoke-engine topics are stale leftovers
  from before the migration (e.g., `math_g1_addition.json` still declares
  `"engine": "tugOfWar"` while the catalog declares `additionAdventure`). The
  bespoke widgets are self-contained and hardcoded, so they don't read these
  packs and the mismatch is harmless. However, the Dart smoke test requires these
  files to exist and parse, so they're kept as-is. Future cleanup could either
  delete their now-unused engine-specific fields down to a minimal stub, or
  repurpose them as a designed-data layer if the bespoke widgets are ever
  refactored to read from packs — noted here to prevent confusion for anyone
  opening one of these files expecting it to reflect what the game actually shows.
- **Grade 2 curriculum content (Phase 14, 2026-08-02): added 15 catalog entries + 3 bugs fixed.**
  Phase 14 added Grade 2 its own dedicated difficulty band and 15 new `topics.json` entries:
  English x5 (`eng_g2_alphabet`, `eng_g2_grammar`, `eng_g2_phonics`, `eng_g2_reading`, `eng_g2_words`),
  Life Skills x5 (`ls_g2_body`, `ls_g2_community`, `ls_g2_feelings`, `ls_g2_habits`, `ls_g2_safety`),
  Mathematics x5 (`math_g2_addition`, `math_g2_counting`, `math_g2_mountain`, `math_g2_multiples`, `math_g2_subtraction`).
  All reuse existing shared engines (no new engine code). Narrowed the original 15 Grade 1 entries' `grades` arrays
  so Grade 1 content stops being silently served to Grade 2 learners. Authored structurally correct,
  schema-valid, difficulty-band-conformant Grade 2 content for all 15 topics across `facts.js`,
  `runner_collector.js`, `explorer_map.js`, `sequence_builder.js`, `multiples_merge.js` — see the
  content-quality follow-up list below for topics that still need a content-quality pass.
  Final state: 141 total catalog entries (was 126).

  **Three previously-hidden bugs surfaced and were fixed during this work:**
  1. `tools/gamegen/generate.js` had hardcoded `GRADE_ORDER = ['grade1','grade4','grade7']` — a remnant
     from before Grade 2 existed. This silently dropped any topic with a grade outside that list from
     the generated `game_catalog.dart`, even though the log line falsely claimed all topics were written.
     Fixed by adding `grade2`/`grade3`/`grade5`/`grade6` to `GRADE_ORDER`/`SUBJECT_ORDER`/`GRADE_BAND_LABEL`
     (the last three currently unused, added for future-proofing matching the `difficulty.js` bands
     already defined in Phase 14).
  2. `eng_g2_phonics` was initially authored using `engine: 'tugOfWar'`. `TugOfWarEngine` only renders
     arithmetic content correctly, so this would have shown wrong (generic multiplication) questions to
     Grade 2 English learners. Fixed by moving `eng_g2_phonics` to `sequenceBuilder`. Informed by the
     general lesson of a prior, unrelated commit (`aad5f25`, which found `TugOfWarEngine`'s
     arithmetic-only rendering breaks for non-math topics) — though that commit didn't touch this
     specific topic pattern, since Grade 1's phonics topic (`eng_g1_phonics`) uses a different, bespoke
     engine (`phonicsFun`) entirely, not `sequenceBuilder`.
  3. `ls_g2_habits` (commit `9a2c650`) was likewise assigned an engine (`tugOfWar`) that was already
     stale for its Grade 1 counterpart: a separate, earlier reconciliation had already corrected
     `ls_g1_habits` to `runnerCollector` in `classify.js`/`topics.json`, but the Grade 2 content plan
     was written before that fix landed, so `ls_g2_habits` inherited the old, wrong assignment. Caught
     during task review, before it ever reached the generated catalog. Fixed by assigning
     `runnerCollector`, mirroring `ls_g1_habits`'s actual current engine.

  **Grade 3, 5, 6 remain on the hand-me-down pattern.** Grade 3 currently receives only the 10 Life
  Skills/Mathematics Grade 1 entries as a hand-me-down — the 5 English entries already dropped `grade3`
  from their `grades` array in an earlier, unrelated change, so **Grade 3 has zero English games today**.
  A future Grade 3 phase should treat English as a priority, not just parity with Life Skills/Mathematics.
  Grades 5 and 6 hand-me-down from Grade 4 entries as originally described.
  `tools/gamegen/difficulty.js` already has `BANDS.grade3`/`grade5`/`grade6` defined — Phases 15–17
  just need to repeat Phase 14's pattern for each remaining grade: add `topics.json` entries mirroring
  the anchor grade's topicId/subtopicId pairs, narrow the anchor grade's `grades` array, author the
  non-procedural content banks, run `npm run generate && npm run author && npm run validate`.
  See `docs/superpowers/plans/2026-08-01-phase14-grade2-curriculum-content.md` for the detailed template.

  **Content-quality follow-ups identified by final review (structurally valid, not yet polished):**
  - `eng_g2_alphabet`: several sight-word questions print the answer verbatim in the question text
    (self-answering).
  - `math_g2_counting`: the underlying widget (`NumberCountingDuelGame`) is fully self-contained/hardcoded
    and doesn't actually vary by grade difficulty — Grade 2's experience is currently identical to
    Grade 1's despite the "Level 2" title; the pack's skip-counting claim also isn't reflected in the
    actual generated items.
  - `ls_g2_community`: reuses Grade 1's exact same 8 community-helper pins verbatim (sanctioned by the
    plan) — the description's "discover more" framing should be softened since there's no new content,
    only a higher question count.
  - `math_g2_mountain`/`eng_g2_phonics`/`eng_g2_words` (all `sequenceBuilder`): the engine only asks
    learners to order procedure-step cards, so descriptions promising "solving"/"blending"/"spelling"
    overstate what the mechanic actually does — should be reworded to describe the ordering/procedure
    mechanic accurately.
  - `eng_g2_phonics`/`eng_g2_words`: near-duplicate step sequences (one is a subset of the other) —
    consider differentiating further.
  - `math_g2_multiples`: authored `tables: [2,3,4,5,10]` overrides the Dart engine's own correct
    Grade 2 default (`[2,5,10]`, per `MultiplesMergeConfig.forGrade`) and contradicts its own
    description's "multiples of 2, 5 and 10" claim.
  - `ls_g2_feelings`: some vocabulary (`resentful`, `outraged`, `discouraged`, `heartbroken`,
    `homesick`) is above a Grade 2 reading level.

  **A fourth bug, caught by final whole-branch review (not task-level review): `math_g2_addition`
  generated sums up to ~169 despite promising "up to 100"**, because `tools/gamegen/content/math.js`'s
  `case 'addition':` drew both operands independently from `[min, max]`. Fixed in two passes — the
  first attempt (`706195c`) only narrowed the failure window rather than closing it (still ~1% violation
  rate, proven by simulation), the second (`42b3599`) bounds `a` itself to `[min, max-min]`, which is
  provably correct (not just empirically rare) whenever `max >= 2*min` — true for every band in this
  repo today. That precondition is implicit/unguarded in the code; a one-line assertion in the
  `'addition'` case (or a property-style test looping N draws per band) would make it self-enforcing
  instead of tribal knowledge, and is recommended before this generator is reused for a future
  narrow/custom `numberRange`.

## Android release build (Phase 4)

- **`flutter build appbundle --release` could not be run in this sandbox.**
  No Android SDK is installed, and the egress policy blocks
  `dl.google.com` (403), so `sdkmanager`/the SDK components can't be
  fetched here either. `flutter build web --release` was used instead as
  the strongest available compile smoke test (it compiles the full Dart
  codebase, including everything touched in Phases 0–3) and came back
  clean. **Before the demo, run on the actual dev machine:**
  ```bash
  flutter build appbundle --release
  # if R8 OOMs on the 8GB machine, retry once:
  flutter build appbundle --release --no-shrink
  ```
  `android/gradle.properties` still has `-Xmx3G -XX:MaxMetaspaceSize=512m`,
  `org.gradle.daemon=false`, `org.gradle.workers.max=4` from before — untouched
  by this pass except removing the machine-specific `org.gradle.java.home`
  line (Phase 1).

## Data model (Phase 11, firestore.rules)

- **Resolved (Phase 11):** teacher reads on `users/{uid}`, `game_sessions/{sessionId}`,
  `player_stats/{uid}`, and `game_progress/{uid}/engines/{engineType}` used to
  be scoped by role only (`allow read: if isTeacher();`) — any teacher could
  read any learner's data. Fixed by scoping to `linkedTeacherUids` array
  membership (the relationship `_showAddLearnerDialog` already writes), not
  a new `classId` field — see `firestore.rules` and the Phase 11 commit
  history for the exact change.
- **Still open, lower priority:** the fix above scopes reads to "learners
  this teacher has personally added," which is coarser than true
  multi-tenant class scoping (e.g. it can't yet express "teacher A's Grade 4
  class" as a first-class boundary independent of the ad-hoc add-a-learner
  flow). If that's ever needed: add a `classId` field to learner user docs, a
  `classId` custom claim via `functions/src/admin/setUserRole.ts`, and a
  `classId`-based rule variant alongside (not instead of) the
  `linkedTeacherUids` check.
