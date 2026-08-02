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

**This closes the immediate crash, but real design decisions remain before
self-registration is genuinely usable end-to-end — not mechanical fixes:**

1. **A self-registered parent/teacher's Firestore doc now gets created, but
   their Firebase Auth custom claim doesn't follow.** `functions/src/admin/setUserRole.ts`'s
   `assignDefaultRole` trigger pins *every* new Auth user's `customClaims`
   to `{role: "learner"}`, and nothing else grants `parent`/`teacher` except
   an admin manually calling `setUserRole`. Firestore rules authorize off
   `request.auth.token.role` (the claim), never the mirrored doc field — so
   a self-registered parent is routed to `ParentDashboard`
   (`NavigationService.getDashboard` reads the doc's `role`) but every
   parent-gated read/write there is denied, since their real claim is still
   `learner`. Needs a decision: does self-registration grant the claim
   immediately (and if so, gated by what — email verification? nothing?),
   or does it land in an explicit "pending admin approval" state? Either
   way this is a Cloud Function change (claims can only be set server-side),
   not a rules change — **and whatever that function is, it must not trust
   this doc's mirrored `role` field when deciding what to grant**, since a
   client can now self-declare it (see the `firestore.rules` comment on the
   `allow create` block: the POPIA consent trail on the `parent`/`teacher`
   branch is client-declared, not server-enforced, until this function
   exists).
2. **Linking a child to a parent is blocked for every client, not just at
   create time — and now the failure comes AFTER real Auth accounts and
   Firestore docs already exist for both parent and child. This is not one
   call site; it's the same root cause in four places.**
   `UserRepository.linkChild()` calls `.update()` on the parent doc to set
   `linkedChildrenUids` (rejected — that field is in `lockedUserFields()`,
   and `allow update` blocks it unconditionally for all clients by design,
   see CLAUDE.md §6) and on the child doc to set `parentUid` (rejected
   separately — `allow update: if isUser(uid)` and the parent is not the
   child, so this one fails on ownership, not on a locked field; a fix that
   only unlocked `linkedChildrenUids` would still leave this second call
   denied). The identical pair of rejections hits three more call sites in
   `ParentRepository` — `approveLinkRequest` (approving a
   "Link to Existing Child" request), `linkParentToChild` (the direct
   link-code flow), and `unlinkParentFromChild` — each of which runs a
   transaction that updates the parent's `linkedChildrenUids` (locked
   field, rejected) and the child's `linkedParentUids` (not a locked
   field, but still rejected on ownership: `allow update: if isUser(uid)`
   and the parent is not the child). **This is why `docs/DEMO_CHECKLIST.md`
   step 5 ("Parent link") also fails** — it exercises this exact path, not
   a separate bug. All four call sites need the same fix: a Cloud Function
   callable (Admin SDK, bypasses rules) that verifies the caller is
   authorized (the child's actual parent, or — for `approveLinkRequest` —
   the primary parent approving a pending request) before performing the
   link/unlink — not a client-side rules exception, since that would let
   any signed-in user link themselves to an arbitrary child uid.

   **Real-user impact today, mitigated but not fixed:** `registerWithEmail`'s
   child branch (the live "parent + child" signup path — see item 3) now
   creates the parent Auth account + Firestore doc, then the child Auth
   account + Firestore doc, and only THEN hits the `linkChild` rejection —
   worse than before this branch's fixes, where it failed at the first
   step with a single orphaned account. Mitigated (not fixed) by wrapping
   the `linkChild`/notification step in a try/catch that deletes the
   child's just-created Firestore doc and Auth account before rethrowing,
   so a retry with the same child name+birthdate doesn't permanently fail
   with `email-already-in-use` (child email/password are deterministic on
   those two fields). The parent's Auth account + Firestore doc are still
   left behind on every failed attempt — cleaning those up too would mean
   deleting the account the user is mid-signing-up-as, which needs its own
   design decision (roll back entirely vs. let them retry as that same
   parent and re-attempt adding a child). **Until the Cloud Function in
   this item exists, `docs/DEMO_CHECKLIST.md`'s parent+child signup step
   will fail with a visible error and should not be demoed as working.**
3. **Two implementations of "parent + child" signup exist; only one is
   wired up.** `AuthService.registerWithEmail`'s child branch is live (via
   `AuthProvider.registerParent` → the real signup UI). `registerParentWithChild`
   is dead code — no caller anywhere in `lib/providers/` or `lib/features/`.
   Its child-doc create was ALSO missing the POPIA consent fields the
   `learner` branch requires (the other two creation paths already had
   them) — fixed for consistency, but it hits the exact same item-2 gap the
   moment someone wires it up. Whoever does should first decide which of
   the two implementations is meant to be canonical, and delete the other
   — having both live invites them drifting out of sync again.

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
