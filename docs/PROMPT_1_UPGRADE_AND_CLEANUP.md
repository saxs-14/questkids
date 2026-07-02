# CLAUDE CODE PROMPT 1 — QuestKids Overnight Upgrade & Cleanup
# (Run from the questkids repo root. CLAUDE.md must be present at root first.)
# Copy everything below this line into Claude Code.

---

You are upgrading **QuestKids** (Flutter + Firebase, CAPS-aligned learning games for SA Grades 1–7) for a demo/submission to Google at 08:00 tomorrow. Read `CLAUDE.md` at the repo root first and obey its SECURITY and DO-NOT-TOUCH sections over anything else.

Work in FOUR PHASES, in order. Commit at the end of every phase with message `phase-N(<scope>): <summary>`. After every phase run `flutter analyze` and `flutter test` and fix regressions before moving on. If a Phase 2–4 item risks breaking the app and cannot be finished safely, revert that item, log it in `docs/DEFERRED.md`, and continue — a working app at 08:00 beats a complete one.

---

## PHASE 0 — SECURITY EMERGENCY (do this before anything else)

The repo is public and currently contains live credentials.

**0.1 Remove secret files from the working tree**
- `git rm --cached` and delete: `serviceAccountKey.json`, `"Web OAuth Credentials.json"`, root-level `GoogleService-Info.plist` (the iOS copy in `ios/Runner/` stays).
- Append to `.gitignore`:
  ```
  serviceAccountKey*.json
  *serviceAccount*.json
  *OAuth*Credentials*.json
  *.pem
  *.p12
  key.properties
  ```

**0.2 Print this notice for the human and wait for acknowledgement before continuing:**
```
⚠️ MANUAL STEPS ONLY YOU CAN DO (do them NOW in another tab):
1. Google Cloud Console → IAM & Admin → Service Accounts → questkids-mobile
   → firebase-adminsdk key → DELETE the exposed key. Generate a new one ONLY if
   something server-side needs it; store it outside the repo.
2. Google Cloud Console → APIs & Services → Credentials → the Web OAuth client
   → RESET SECRET.
3. Firebase Console → Project Settings → App Check → register the Android app
   (Play Integrity) and Web app (reCAPTCHA v3). Do not enforce yet.
Deleting the files does NOT revoke the keys, and they remain in git history —
revocation is the only real fix. History rewrite (git filter-repo) is scheduled
AFTER the demo; do not force-push tonight.
```

**0.3 Fix the privilege-escalation hole in `firestore.rules`**
Currently any user can update their own `users/{uid}` doc without restriction, so a child can set `role: 'teacher'` — and teachers can read ALL users and their AI chats. Rewrite the rules so that:
- A helper blocks protected fields on self-updates:
  ```
  function noProtectedChanges() {
    return !request.resource.data.diff(resource.data).affectedKeys()
      .hasAny(['role', 'xp', 'coins', 'level', 'linkedChildrenUids', 'uid', 'email']);
  }
  ```
  Apply it to `allow update` on `users/{uid}`. On `create`, force `request.resource.data.role == 'learner'` unless the auth token has an admin claim.
- Replace document-lookup role checks with custom-claims checks: `request.auth.token.role == 'teacher'` etc. (cheaper and un-spoofable).
- Scope teacher reads: teachers may read a learner doc only when `resource.data.classId == request.auth.token.classId` (add TODO where class data model needs it). Remove the blanket "teachers read all users".
- Remove teacher read access to `users/{uid}/chats` — AI chat logs are visible to the child and linked parent only.
- Keep leaderboards, daily_missions, caps_curriculum rules as they are (already server-write-only where needed).

**0.4 Roles as custom claims (Cloud Function)**
In `functions/src/` add `admin/setUserRole.ts`: a callable that (a) requires `request.auth.token.role == 'admin'`, (b) sets `{ role, classId? }` custom claims on a target uid, (c) mirrors the role string into the user doc for UI display only. Add an auth `onCreate` trigger (or extend existing user bootstrap) that sets default claim `role: 'learner'`. Export from `functions/src/index.ts`.

**0.5 Harden the Gemini proxy (`functions/src/gemini/proxy.ts`)**
For EVERY callable (`questyChat`, `analyzeImage`, `getRecommendation`, `explainAnswer`, `generateHint`):
- Reject unauthenticated calls: `if (!request.auth) throw new HttpsError("unauthenticated", "Sign in required");`
- Declare with `{ enforceAppCheck: true }` **behind an env flag** `ENFORCE_APP_CHECK=true` so it can stay off until the human registers App Check (see 0.2).
- Input caps: `message` ≤ 1,000 chars; `history` ≤ 20 turns, each ≤ 1,000 chars; drop any history item whose role is not exactly `user`/`model`; `imageBase64` ≤ 4 MB.
- Per-user quota: 50 AI calls per uid per day via a `usage_ai/{uid}` Firestore doc with a transactional counter that resets on date change; over quota → `resource-exhausted` with a child-friendly message.
- Add Gemini `safetySettings` blocking harassment, hate, sexually explicit, and dangerous content at `BLOCK_LOW_AND_ABOVE` (this is a children's app).
- The `gemini-1.5-flash` model id is deprecated: read the model id from `process.env.GEMINI_MODEL` with a current Flash-class default, and verify the exact current model name in Google's docs before setting it.
- Keep the Questy system prompt; append: "If a child mentions self-harm, abuse, or being unsafe, gently encourage them to talk to a trusted adult or teacher immediately. Never ask a child for personal information (address, phone, school name, passwords)."

**0.6 Storage rules** — in `storage.rules`, restrict `activities/**` writes to `request.auth.token.role in ['teacher','admin']` and add the same image-type/size validation used for avatars.

**0.7 Kill advertising-ID collection (Google Play Families requirement)**
- In `android/app/src/main/AndroidManifest.xml` add inside `<application>`:
  `<meta-data android:name="google_analytics_adid_collection_enabled" android:value="false" />`
  and at manifest level:
  `<uses-permission android:name="com.google.android.gms.permission.AD_ID" tools:node="remove" />`
  (ensure `xmlns:tools` is declared).
- Grep the manifest merger output later to confirm AD_ID is gone.

Commit: `phase-0(security): remove secrets, block role escalation, harden AI proxy, drop AD_ID`.

---

## PHASE 1 — REMOVE UNWANTED THINGS (repo cleanup)

- Delete from git and disk: `build/` (46 MB of committed build artifacts), `learning/` (stale duplicate of `functions/`), `analyze_output.txt`, `.claude/worktrees/`. Add `build/`, `.claude/worktrees/`, `*.log` to `.gitignore`.
- Remove the machine-specific line `org.gradle.java.home=...` from `android/gradle.properties` (breaks every other machine; it belongs in the user's global gradle config). Keep the existing memory settings exactly as they are.
- Consolidate root docs: create `docs/archive/` and move `AUTHENTICATION_README.md`, `AUTHENTICATION_REDIRECT_FIX.md`, `FIREBASE_COLLECTIONS_SETUP.md`, `FIREBASE_SETUP_GUIDE.md`, `FIRESTORE_COLLECTIONS_MANUAL_SETUP.md`, `FIRESTORE_MANUAL_DATA.md`, `IMPLEMENTATION_STATUS.md`, `QUICK_COLLECTIONS_SETUP.md`, `QUICK_START.md`, `SETUP_SUMMARY.md`, `SETUP_FIRESTORE_AUTO.md` into it. Root keeps only `README.md` + `CLAUDE.md`. Write a fresh concise `docs/SETUP.md` (env vars, run commands, functions deploy) and `docs/SECURITY.md` (summarising Phase 0 posture).
- Remove unused dependencies from `pubspec.yaml`: `go_router`, `rive`, `lottie`, `mobile_scanner`, `printing` (verified 0 imports in `lib/`). Run `flutter pub get`, then `flutter analyze` to confirm nothing referenced them via transitive assumptions.
- De-duplicate dashboards: `lib/features/dashboard/screens/learner_dashboard.dart` vs `learner_dashboard_screen.dart` — keep the one wired in `main.dart` routes, port any unique widgets from the other, delete the loser, fix imports.
- Rewrite `README.md`: what QuestKids is, architecture diagram, quickstart, screenshot placeholders, link to docs/. Professional tone — Google will read this.

Commit: `phase-1(cleanup): purge build artifacts, stale dirs, dead deps, duplicate dashboard, consolidate docs`.

---

## PHASE 2 — "EVERY TOPIC OWNS ITS GAME" (engine remap + purpose)

Problem: 126 catalog entries but 92 (73%) run on just two engines (`adventureJourney` 49, `tugOfWar` 43) — most topics are the same quiz reskinned, and the built `runnerCollector` engine (Grammar Hero Run) has ZERO catalog entries so it is unreachable. Learning-game research ("intrinsic integration") says the mechanic itself must embody the skill.

**2.1 Extend the catalog model** — add to `GameCatalogEntry` (with defaults so nothing breaks):
- `learningObjective` (String): CAPS-phrased outcome, e.g. "Count, order and compare whole numbers to 100".
- `mechanicReason` (String): one child-readable sentence on why this mechanic teaches this skill, e.g. "You merge tiles by finding multiples — the maths IS the move."

**2.2 Remap engines by cognitive verb.** Apply this table to every entry; the topic's verb decides the engine:

| Topic's cognitive verb | Engine |
|---|---|
| count / compare quantities | `numberCountingDuel` or `multiplesMerge` |
| order / sequence / stages / cycles (water cycle, life cycles, story order, timelines, instructions) | `sequenceBuilder` |
| locate / map / places (provinces, continents, map skills, communities) | `explorerMap` |
| connect / systems / flows (circuits, food chains/webs, ecosystems, body systems, simple machines) | `circuitBuilder` |
| allocate / budget / money / trade-offs (EMS, financial literacy, needs vs wants) | `budgetBuilder` |
| rapid-recall fluency duels (number bonds, times tables, spelling sprints, quick facts) | `tugOfWar` |
| classify words while moving / grammar categories (nouns-verbs-adjectives, word classes, punctuation choice) | `runnerCollector` |
| read-and-decide narrative / multi-step comprehension / applied word problems | `adventureJourney` |

Hard invariants after the remap (write a test in `test/catalog/game_catalog_invariants_test.dart` that enforces all of these):
1. `adventureJourney` + `tugOfWar` ≤ 40% of entries combined.
2. Every subject uses ≥ 3 distinct engines.
3. `runnerCollector` has ≥ 5 entries (all English/language-structure topics).
4. Every entry has non-empty `learningObjective` and `mechanicReason`.
5. Every `engineType` exists in `app_constants.dart` and `GameRouter`.

**2.3 Per-engine identity** — in `lib/features/games/core/game_theme.dart`, define one visual identity per engine (accent colour, icon, one-line tagline like "Merge & Multiply", "Race & Sort", "Build & Connect"). Consume it in the game cards and intro screens so each engine is visually distinct at a glance.

**2.4 Purpose is user-visible** — build a shared `GameIntroSheet` shown before every game start: game title + emoji, "You will learn: {learningObjective}", "How it teaches: {mechanicReason}", engine tagline chip, difficulty and XP. Wire it into the launch flow in the quests/dashboard screens. This is what makes "each topic shows its own game, functionality and purpose" literally true on screen.

**2.5 Do NOT invent new engines tonight.** Nine engines with correct mapping is enough for the demo. Add wishes (sorting/venn engine, tracing engine, dialogue engine) to `docs/DEFERRED.md`.

Commit: `phase-2(games): cognitive-verb engine remap, purpose metadata, per-engine identity, invariants test`.

---

## PHASE 3 — UI & COMPLIANCE SURFACE

- **AI transparency + reporting (Google Play AI-content policy — mandatory):** in the Questy chat, label assistant bubbles "AI · Questy" and add a long-press/flag action → "Report this answer" → writes `{uid, messageText (truncated 500), reason, createdAt}` to a new `ai_reports` collection (rules: create by the authenticated reporter only, read by admin claim only). Add a one-time first-open notice: "Questy is an AI helper. A grown-up checks reports. Never share personal information."
- **Parental consent gate (POPIA — children are under-18s, consent must come from a parent/guardian):** in learner registration, add a required step capturing parent/guardian full name + email + consent checkbox ("I am the parent/guardian and I consent to my child using QuestKids as described in the Privacy Policy"). Store `{consentGivenBy, consentEmail, consentAt, policyVersion}` on the user doc; block completion without it. Full verified-email consent flow goes to `docs/DEFERRED.md`.
- **Leaderboard privacy:** ensure leaderboard tiles render display name/avatar only — no surnames, emails, or school identifiers. Fix the entry model/UI if needed.
- **Dashboard coherence:** every subject/topic card must show its game's engine icon + tagline chip (from 2.3) so different topics visibly launch different games. Fix any `flutter analyze` layout warnings and yellow-stripe overflows found on the learner dashboard, quests screen, and rewards screen at 360×740.
- **Foundation Phase usability pass on touched screens only:** min 56dp touch targets, no critical text under 14sp.

Commit: `phase-3(ui-compliance): AI labels+reporting, POPIA consent gate, leaderboard privacy, per-topic game identity on dashboards`.

---

## PHASE 4 — VERIFY & BUILD

1. `flutter analyze` → 0 errors.
2. `flutter test` → all green, including the new catalog invariants test.
3. `cd functions && npm ci && npm run build` → compiles; run `firebase emulators:start --only functions,firestore,auth` and smoke-test: unauthenticated `questyChat` call is rejected; a user-doc update changing `role` is rejected by rules.
4. Secret scan: `git grep -l "PRIVATE KEY"; git grep -l "client_secret"` on the working tree → must return nothing.
5. Bump `pubspec.yaml` version to `2.0.0+2`.
6. Release build: `flutter build appbundle --release`. If R8 OOMs, retry once with `--no-shrink` and record which one shipped in `docs/DEFERRED.md`.
7. Write `docs/DEMO_CHECKLIST.md`: 10-step manual smoke script (register learner incl. consent step → play one game per engine family: merge, sequence, map, circuit, budget, duel, tug, runner, adventure → check XP applied → Questy chat incl. report action → parent link → teacher view).
8. Final commit `phase-4(release): v2.0.0+2 demo build` and print a summary table of everything changed, everything deferred, and the two manual console actions from Phase 0.2 if the human has not confirmed them yet.

**Do not `git push --force` anywhere. Do not deploy rules/functions to production without the human saying "deploy".**
