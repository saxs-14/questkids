# Deferred work

Items intentionally postponed during the pre-demo hardening pass (see CLAUDE.md
and the phase-by-phase prompts in `docs/PROMPT_1_UPGRADE_AND_CLEANUP.md` /
`docs/PROMPT_2_FINAL_SHIP_0800.md`). Each entry says why it was deferred and
what to do next.

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
