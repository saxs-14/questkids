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
