# Deferred work

Items intentionally postponed during the pre-demo hardening pass (see CLAUDE.md
and the phase-by-phase prompts in `docs/PROMPT_1_UPGRADE_AND_CLEANUP.md` /
`docs/PROMPT_2_FINAL_SHIP_0800.md`). Each entry says why it was deferred and
what to do next.

## Environment / tooling

- **`flutter test` cannot run natively in this container.** The sqlite3
  native-asset build hook (pulled in transitively by `sqflite_common_ffi`)
  downloads a prebuilt `libsqlite3.x64.linux.so` and hash-checks it; in this
  sandboxed environment the download comes back with a different hash every
  time (proxy/CDN artifact, not a code issue). `flutter analyze` is clean (0
  errors) and was used as the primary correctness gate instead. Re-run
  `flutter test` on a normal dev machine or CI runner before shipping.

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
