# CLAUDE.md — QuestKids Repository Guide for Claude Code

> Place this file at the ROOT of the questkids repo. Claude Code reads it automatically
> at the start of every session. It is the source of truth for architecture, conventions,
> commands, and hard rules. When any instruction in a prompt conflicts with the
> SECURITY or DO-NOT-TOUCH sections below, this file wins.

---

## 1. What this project is

QuestKids is a Flutter + Firebase gamified learning platform for South African primary
school learners (Grades 1–7), aligned to the CAPS curriculum. Three user roles:

- **Learner** — plays curriculum games, earns XP/coins/badges, chats with "Questy" (Gemini AI tutor)
- **Parent** — links children via QR code, views analytics, verifies progress (POPIA "competent person")
- **Teacher** — class analytics, assigns missions, verifies progress

Target platforms: Android (primary), Web, iOS. Built by a solo student developer on a
**memory-constrained Windows machine (~8GB RAM)** — never assume large heap builds work.

## 2. Tech stack

| Layer | Tech |
|---|---|
| App | Flutter (Dart SDK ≥3.4), Material 3 |
| State | Provider (`ChangeNotifierProvider` in `lib/main.dart`) |
| Navigation | Classic `Navigator` named routes in `main.dart` (go_router is NOT used) |
| Backend | Firebase: Auth, Firestore, Storage, Messaging, Analytics, **Cloud Functions (TypeScript, `functions/src/`)** |
| AI | Gemini via Cloud Functions proxy only (`functions/src/gemini/proxy.ts`). **No AI keys in the client. Ever.** |
| Offline | sqflite (+ sqflite_common_ffi for desktop) via `lib/core/services/offline_service.dart` and `db_bootstrap*.dart` |
| Charts | fl_chart |

## 3. Repository map (the parts that matter)

```
lib/
├── main.dart                      # entry, providers, routes
├── firebase_options.dart          # FlutterFire generated — DO NOT hand-edit
├── core/
│   ├── constants/app_constants.dart   # engine name constants (engineTugOfWar, ...)
│   ├── constants/game_catalog.dart    # THE catalog: 126 GameCatalogEntry items (grade/subject/topic → engine)
│   ├── services/                      # auth, firestore, gemini (CF proxy), offline, rewards, quiz...
│   └── theme/                         # app_colors, app_theme, text styles
├── data/
│   ├── models/                        # user, progress, game_session, reward, ...
│   └── repositories/                  # one repository per collection/domain
├── features/
│   ├── auth/           # splash, login, register, parent-child setup
│   ├── dashboard/      # learner / parent / teacher dashboards
│   ├── games/
│   │   ├── core/       # GameEngine (abstract), GameSessionState, GameRouter, GameConfig, GameTheme
│   │   ├── tug_of_war/ adventure_journey/ runner_collector/ explorer_map/
│   │   ├── multiples_merge/ sequence_builder/ circuit_builder/ budget_builder/
│   │   └── number_counting_duel/
│   ├── ai_tutor/       # Questy chat UI
│   ├── quests/ rewards/ parent/ teacher/ profile/ notifications/ offline/
functions/src/          # Cloud Functions: gemini/, leaderboard/, missions/, teacher/, index.ts
firestore.rules         # Firestore security rules
storage.rules           # Storage security rules
android/ ios/ web/      # platform shells
test/                   # only 4 test files exist — expand when touching engines
```

## 4. Game engine architecture (STRICT — do not violate layering)

```
GameRouter  →  <Engine>Game (widget)  →  <Engine>Session (state)  →  <Engine>Engine (pure rules)
```

- `GameEngine` subclasses are **pure Dart**: no Flutter/widget imports. They implement
  `generateQuestions()`, `checkAnswer()`, `buildResult()`.
- All mutable session state lives in the Session class, not the engine.
- New engines are registered in exactly two places:
  1. constant in `lib/core/constants/app_constants.dart`
  2. `switch` arm in `lib/features/games/core/game_router.dart`
- Games become visible ONLY via entries in `lib/core/constants/game_catalog.dart`.
  An engine with no catalog entry is invisible (this happened to `runnerCollector` / Grammar Hero Run).

### Catalog invariants (enforce these whenever `game_catalog.dart` is edited)
1. Every `engineType` string must match a constant in `app_constants.dart` and a `GameRouter` arm.
2. `adventureJourney` + `tugOfWar` combined must be **≤ 40%** of all entries (they were 73% — that is the bug we are fixing: every topic must feel like its own game).
3. Every subject must use **≥ 3 distinct engines**.
4. Every entry must have non-empty `learningObjective` and `mechanicReason` fields (added in the upgrade). Purpose is user-visible.
5. Engine choice must match the topic's cognitive verb (see mapping table in the upgrade prompt).

## 5. Commands

```bash
# Flutter
flutter pub get
flutter analyze                      # must be CLEAN (0 errors) before any commit
flutter test                         # all tests must pass
flutter run -d chrome                # fastest local check
flutter build appbundle --release    # release (see R8 note below)

# Cloud Functions (TypeScript)
cd functions && npm ci && npm run build
firebase emulators:start --only functions,firestore,auth   # test locally FIRST
firebase deploy --only functions
firebase deploy --only firestore:rules,storage:rules
```

### R8 / release-build memory (known failure mode on the dev machine)
Release builds have OOM-killed the R8 minifier before. Rules:
- `android/gradle.properties` must keep `org.gradle.jvmargs=-Xmx3G -XX:MaxMetaspaceSize=512m`, `org.gradle.daemon=false`, `org.gradle.workers.max=4` (do not raise Xmx above 4G).
- **Never commit `org.gradle.java.home`** (machine-specific path) — it belongs in the user's global `~/.gradle/gradle.properties`.
- If R8 still OOMs, fallback: `flutter build appbundle --release --no-shrink` and note it in the PR description.

## 6. SECURITY RULES (non-negotiable)

1. **No secrets in the repo.** Forbidden files/patterns: `serviceAccountKey*.json`, `*OAuth*Credentials*.json`, `.env`, private keys, Gmail app passwords. All must be in `.gitignore`. `firebase_options.dart` and `google-services.json` are Firebase *client* config (allowed), but everything with a `private_key` or `client_secret` is not.
2. **All Gemini/AI calls go through Cloud Functions.** Every callable must check `request.auth` and (once enabled) App Check, and enforce a per-user daily quota.
3. **Roles are custom claims** (`request.auth.token.role`), set only by an admin Cloud Function. Clients must NEVER be able to write `role`, `xp`, `coins`, `level`, or `linkedChildrenUids` on their own user document — Firestore rules must reject those field changes.
4. **Teachers do not get global read access.** Teacher reads are scoped to their own class (`classId`/`teacherId` match). AI chat logs (`users/{uid}/chats`) are readable by the child and their linked parent only.
5. **Children's data (POPIA + Google Play Families):** every learner account requires recorded parent/guardian consent; no advertising-ID collection (AD_ID permission removed, analytics ad-id disabled); leaderboards show display names/avatars only — never surnames, emails, or school identifiers across schools.
6. **AI content compliance:** every Questy message is labelled as AI-generated and carries a report/flag action that writes to the `ai_reports` collection (Google Play AI-Generated Content policy requirement).

## 7. DO NOT TOUCH (without explicit human approval in the session)

- `lib/firebase_options.dart` (regenerate with FlutterFire CLI only)
- Anything that force-pushes or rewrites git history — **STOP and ask the human first**
- `db_bootstrap_io.dart` / `db_bootstrap_stub.dart` conditional-import pattern (keeps web builds working — sqflite ffi must not leak into web)
- Firebase project IDs, bundle ID `com.questkids.questkids`
- Deleting any `<engine>/` folder — engines are assets even when temporarily uncatalogued

## 8. Conventions

- Feature-first folders (`lib/features/<feature>/screens|widgets`), services in `core/services`, one repository per Firestore collection.
- Providers registered in `main.dart` `MultiProvider`; screens consume via `Provider.of` / `Consumer`.
- Child-facing UI: large touch targets (min 56dp for Foundation Phase), short sentences, emoji-friendly, TTS support via `flutter_tts` where reading is required, South African context in examples (rand, provinces, local names).
- Strings: no profanity, no external links reachable by children, no dark patterns.
- Commit style: `type(scope): summary` e.g. `fix(rules): block role self-escalation`. Small, reviewable commits; run `flutter analyze` before each.

## 9. Definition of Done for any task

1. `flutter analyze` → 0 errors (warnings only if pre-existing)
2. `flutter test` → green (add/adjust tests for any engine or rules-adjacent change)
3. App boots to login on `flutter run -d chrome` with no red screen
4. No new files matching the forbidden-secrets patterns (`git status` reviewed)
5. Catalog invariants (§4) hold if `game_catalog.dart` was touched
6. Rules changes validated in the Firebase emulator before deploy
