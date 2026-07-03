# Deferred work

Items intentionally postponed during the pre-demo hardening pass (see CLAUDE.md
and the phase-by-phase prompts in `docs/PROMPT_1_UPGRADE_AND_CLEANUP.md` /
`docs/PROMPT_2_FINAL_SHIP_0800.md`). Each entry says why it was deferred and
what to do next.

## Environment / tooling

- **`flutter test` now runs natively.** The earlier blocker was
  `sqlite3`'s Dart build hook downloading a prebuilt `libsqlite3` binary
  from a GitHub release at build/test time — unreachable from locked-down
  CI/sandbox networks (the proxy returns a JSON access-denied body, which
  the hook then hashes and rejects as a corrupt download). Fixed by
  pinning `sqlite3: 2.9.4` via `dependency_overrides` in `pubspec.yaml`
  (see the `gamegen-0` commit) — the last release before that package
  switched to build hooks, so `sqflite_common_ffi` (test/offline-desktop
  only) just `dlopen`s the system `libsqlite3` instead. No network access
  needed to run tests, on this machine or any other CI runner.

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
- **`multiplesMerge`'s 5 "pairs mode" topics fall back to the numeric
  demo.** `eng_g4_idioms`, `eng_g4_vocabulary`, `eng_g7_vocabulary`,
  `ss_g7_leaders`, `ss_g7_population` were assigned `multiplesMerge`
  (count/compare — matching pairs) but the engine's grid (`MergeRound
  .values`) is `List<int>`; rendering their `tokenGroups` (word/phrase
  pairs) needs `MergeRound` and the grid widget to support string tokens,
  not just a config swap. `MultiplesMergeConfig.fromPack` already detects
  `pack['mode'] == 'pairs'` and falls back to `.forGrade()` for these.
- **`tugOfWar` doesn't support decimal or negative-integer answers.**
  `TugOfWarKeypad` is digits 0-9 + clear/confirm only — no decimal point,
  no minus sign. `math_g4_decimals` (decimal operations) and
  `math_g7_integers` (signed-number operations) both need one of those,
  so `TugOfWarConfig`'s topic→questionType table intentionally excludes
  them and they still play multiplication questions. Fixing this needs a
  keypad UI change (add `.`/`-` keys) plus `TugOfWarEngine` cases for
  `'decimal'`/`'integer'` (the arithmetic itself already exists in
  `tools/gamegen/content/math.js`'s JS generator as a reference — it just
  isn't safe to port to the current keypad).
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

## Data model (Phase 0, firestore.rules)

- Teacher reads on `users/{uid}`, `game_sessions/{sessionId}`,
  `player_stats/{uid}`, and `game_progress/{uid}/engines/{engineType}` are
  currently scoped by role only (`request.auth.token.role == 'teacher'`), not
  by class. TODOs are left in `firestore.rules` at each spot
  (`isTeacherOfClass`). To finish this: add a `classId` field to learner user
  docs (and to the collections above, or join through the user doc), add a
  `classId` custom claim when a teacher is provisioned via
  `functions/src/admin/setUserRole.ts`, and swap the TODO'd `allow read: if
  isTeacher()` lines for `allow read: if isTeacherOfClass(resource.data.classId)`.
