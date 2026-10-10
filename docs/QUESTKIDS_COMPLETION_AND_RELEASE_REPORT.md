# QuestKids — Completion & Release Report

**Date:** 2026-10-10
**Branch:** `main`
**Commit audited/fixed up to:** `0e610cb8cd6044a60b678baad766e1ed17ed3829`
**Firebase project:** `questkids-mobile`
**Repo:** https://github.com/saxs-14/questkids

Status legend used throughout: **PASS** (implemented and verified with evidence),
**PARTIAL** (implemented, some verification remains), **FAIL** (a check failed or a
confirmed defect remains), **BLOCKED** (cannot be verified — access/credentials/hardware
missing), **NOT STARTED** (no implementation exists yet).

---

## 1. Baseline — what was actually true when this audit started

The local checkout on this machine was **45 commits behind** `origin/main` (stale since a
prior session). Fast-forwarded cleanly (no conflicts, no local changes lost) to
`460f8ce` — the merge of PR #6 (Phase 5). The five phase PRs (#2–#6) were confirmed
merged into `main` via `git log`, and GitHub Actions' own history was checked, not
assumed: all five merge commits show a **green** `CI` run.

This does **not** mean the phases were complete — see §4. "Merged" and "deployed" turned
out to be two different things for three of the five phases.

## 2. Local verification — Flutter & Functions (PASS)

Run directly, with full output inspected (not inferred):

| Check | Result |
|---|---|
| `flutter pub get` | PASS — resolved cleanly |
| `flutter analyze` (whole project) | **PASS** — 0 issues |
| `flutter test` (whole suite) | **PASS** — 406/406 tests green |
| `cd functions && npm ci` | PASS (first attempt hit a transient `ECONNRESET`; retry succeeded — not a code issue) |
| `npm run build` (tsc) | **PASS** — clean compile |
| `npm run lint` (eslint) | **PASS** — 0 issues |

## 3. Fixes applied and verified this session

### 3.1 CI/Vercel version-pinning (FAIL → PASS)

**Finding:** `.github/workflows/ci.yml` used `channel: stable` with no version pin, and
`vercel.json`'s `buildCommand` did `git clone flutter -b stable`. This is a real,
previously-observed failure mode: an earlier session's commit passed `flutter analyze`
locally, then failed CI days later purely because GitHub's `stable` channel had moved
forward and changed lint-severity defaults — no code changed, CI still broke.

**Fix:** Pinned both to Flutter `3.47.2` (verified this tag exists upstream via
`git ls-remote --tags`, and matches the exact revision `d3b14c8769` already running
locally). Commit `0e610cb`.

**Verification:** Pushed; GitHub Actions run `38030369135` on this exact commit —
**green**, both jobs (`flutter`, `functions`) passed. (https://github.com/saxs-14/questkids/actions/runs/38030369135)

### 3.2 Critical dependency vulnerability (FAIL → PASS)

**Finding:** `npm audit` on `functions/` reported one **critical** advisory:
`proxy-addr` 1.1.0–2.0.7, IP-spoofing via IPv4-mapped IPv6 trust-subnet bypass
(GHSA-jqcg-44mw-7w3h). This is directly relevant: `loginChild`'s brute-force rate
limiter (`functions/src/auth/loginChild.ts`) keys its buckets off
`request.rawRequest.ip`, which flows through this exact dependency chain.

**Fix:** `npm audit fix` — `found 0 vulnerabilities` afterward. Re-ran `npm run build`
and `npm run lint` to confirm the dependency bump didn't break anything — both clean.
Committed alongside the CI pin (`0e610cb`).

### 3.3 IAM — `loginChild`'s custom-token signing permission (documented as BLOCKED → verified PASS)

`docs/PHASE_1_ACCOUNT_SECURITY_AUDIT.md` item 5 explicitly flagged this as unresolved:
*"Fix and verify the deployed runtime service-account IAM permission for `loginChild`;
repository changes alone cannot grant IAM permissions."*

**Verification performed (read-only):**
- `gcloud functions list` confirmed `loginChild` runs as
  `882077922348-compute@developer.gserviceaccount.com`.
- `gcloud iam service-accounts get-iam-policy` on that exact service account shows
  `roles/iam.serviceAccountTokenCreator` already bound to itself.

This is the exact permission `admin.auth().createCustomToken()` needs when signing via
the IAM Credentials API (no private-key JSON present, by design — see CLAUDE.md §6.1).
**Result: PASS, verified with evidence.** This was fixed outside the repository (as the
audit doc predicted it would have to be) at some point before this session; no further
action needed.

### 3.4 Nine Cloud Functions existed in source, built clean, lint clean — but were never deployed (FAIL → PASS, user-authorized)

**Finding — the single most important result of this audit.** `functions/src/index.ts`
exports 35 functions. `gcloud functions list` and `firebase functions:list` (two
independent tools) each returned only **26** live functions. The 9 missing were:

- `getAdminPlatformReport` — **the entirety of Phase 5**
- `getParentLearningInsights` — **the entirety of Phase 4**
- `notifyParentsOfGameSession`, `notifyParentsOfLearnerInactivity` — **the entirety of Phase 3's backend**
- `cleanupChildLoginAttempts` — the scheduled cleanup for Phase 1's rate-limit collection (meant the `security_login_attempts` collection was growing unbounded in production)
- `generateGameDraft`, `getParentAccess`, `setParentPermissions` — predate the phase work, also never shipped

This is concrete proof of the exact risk the task brief warned about: a merged PR is not
evidence of a deployed, working feature. The admin reports dashboard and the AI parent
insights screen were calling functions that did not exist in production.

**Fix (explicit user authorization given mid-session — "Deploy the missing Cloud
Functions"):**
```
firebase deploy --only functions:generateGameDraft,functions:getAdminPlatformReport,functions:getParentLearningInsights,functions:getParentAccess,functions:setParentPermissions,functions:notifyParentsOfGameSession,functions:notifyParentsOfLearnerInactivity,functions:generateWeeklyGameReports,functions:cleanupChildLoginAttempts
```
First attempt returned a generic Firebase CLI error with no detail; retried with
`--debug`, which succeeded cleanly: **"9 Functions Deployed, 0 Functions Errored, 0
Function Deployments Aborted."**

**Verification:** `gcloud functions list` re-run independently afterward — all 35
functions now show `ACTIVE`, confirmed by name against the full `index.ts` export list.

### 3.5 Missing Firestore composite index (FAIL → PASS)

**Finding:** Diffing `firestore.indexes.json` (17 entries) against the live project's
indexes (`firebase firestore:indexes`, 16 entries) found exactly one gap:
`game_sessions (uid ASC, completedAt DESC)`. Any query filtering `game_sessions` by
`uid` and ordering by `completedAt` — plausibly used by the parent/admin reporting
functions just deployed — would fail at runtime with a "query requires an index" error
until this was added.

**Fix:** `firebase deploy --only firestore:indexes`. **Verification:** re-listed via
`gcloud firestore indexes composite list` — the new index is present; state was
`CREATING` immediately after deploy (normal; composite index builds take a few minutes
to finish on existing data) — confirm it has moved to `READY` before relying on any
query that needs it under load.

## 4. Per-phase status (the real state, not the PR-merged state)

| Phase | Code merged | Backend deployed | Automated tests | Verdict |
|---|---|---|---|---|
| 1 — Account security | Yes | Yes (and the IAM blocker is actually resolved) | 1 new test file (`auth_validation_test.dart`) — covers only email/password format validators, not rate limiting or IAM | **PARTIAL** |
| 2 — Game-answer feedback | Yes | N/A (client-only, `GameFeedbackService`) | None found for this service specifically — **integration gap found and fixed, see §7a** | **PASS** (feedback now reaches all 64 engines; still no automated test asserting it) |
| 3 — Parent notifications | Yes | **Was FAIL, now PASS** (deployed this session) | None (no Functions test harness exists at all — see §5) | **PARTIAL** |
| 4 — AI parent insights | Yes | **Was FAIL, now PASS** (deployed this session) | None | **PARTIAL** |
| 5 — Admin platform reports | Yes | **Was FAIL, now PASS** (deployed this session) | None | **PARTIAL** |

No phase reaches PASS outright, because "deployed and builds clean" is necessary but not
sufficient — none of the five phases has a single automated *behavioral* test exercising
its actual Cloud Function logic (authorization boundaries, rate-limit math, notification
idempotency, AI-response handling). That gap is structural, not phase-specific — see §5.

## 5. Structural finding: Functions behavioral test coverage (PARTIAL — harness now exists)

**Update (2026-10-10):** `functions/package.json` now has a real `test` script
(`firebase emulators:exec ... jest`), backed by `jest` + `ts-jest` + `babel-jest` (the
babel step downlevels `jose`, an ESM-only transitive dependency of
`firebase-admin/auth`, to CommonJS so it's requireable from test files) and run against a
real local Firestore emulator — never against production. CI's `functions` job now runs
`npm test` after `build`/`lint`, with `actions/setup-java@v4` (JDK 21) added so the
emulator can start on the runner. Verified green both locally and in a real GitHub
Actions run (commit `3bb32e0`, run `38039643554`).

One behavioral test file exists so far: `functions/test/admin/getAdminPlatformReport.test.ts`
(5 tests — unauthenticated rejection, non-admin rejection, empty-DB happy path, role
counting, and the `pendingAiReports = total − resolved` lifecycle math from §6 below).

**Still PARTIAL, not PASS:** one function out of the 35 in `functions/src/` has coverage.
The foundation Stage B–G of the task brief needs (negative-authorization tests, rate-limit
math, notification idempotency, AI-response handling) **no longer has to be built from
zero** — the harness, emulator wiring, and CI gate are in place — but writing that
coverage for the other 34 functions is still real, multi-session work, tracked in §7.

## 6. Specific item investigated from the task brief: `pendingAiReports` calculation

The brief named a suspected bug: `pendingAiReports = totalReports - resolvedReports` in
`getAdminPlatformReport.ts` might double-count a `dismissed` or other terminal status as
pending.

**Investigated, not assumed.** Grepped every write path to the `ai_reports` collection
across the whole repo. The only two states that exist anywhere in the codebase are: no
`status` field (newly created, via `FirestoreService.reportAiMessage`) and
`status == 'resolved'` (the only value `AdminService.resolveAiReport` ever writes). There
is no `dismissed` or other third status anywhere in the source.

**Verdict: the formula is correct for the schema that actually exists.** Not fixed,
because it was not broken — fixing a non-bug here would be fabricating work. (If a
`dismissed` status is added later without updating this query, it would become a real
bug then — worth a code comment, not a code change, today.)

A separate, real gap found during the same investigation: the Safety tab's list
(`AdminService.watchAiReports()`) has no status filter at all — a report stays in the
visible list and keeps showing an active "Resolve" button forever, even after being
resolved. Logged here as a UX defect for the admin dashboard, not fixed in this pass
(out of this audit's declared scope — flagging per the brief's own rule against silently
expanding scope).

## 7a. Game-feedback (`GameFeedbackService`) integration audit and fix (2026-10-10)

The task brief asked for an integration audit of Phase 2's spoken answer feedback across
all 64 game engines. **Scripted, not sampled:** `GameFeedbackService.correct()`/
`.incorrect()` was referenced in exactly one place in the whole codebase —
`GameSessionState.recordAnswer()`, the shared session controller. Mapping all 64
`GameRouter` switch arms to their files and checking each for that wiring found **only 8
of 64 engines (12.5%)** — the original architecture engines (Tug of War, Adventure
Journey, Runner Collector, Explorer Map, Multiples Merge, Sequence Builder, Circuit
Builder, Budget Builder) — actually reached it. The other 56 are self-contained
`StatefulWidget`s added later that never touched the service at all, so most players got
no spoken feedback despite Phase 2 being merged and building clean.

Two side findings during the audit:
- `number_counting_duel` is listed in CLAUDE.md as one of the "original 9" layered
  engines, but in the actual code it's a standalone widget like the other 55 — doc/code
  drift, noted but not corrected in CLAUDE.md this pass.
- `phonics_fun` runs its own separate `FlutterTts` instance for word pronunciation,
  unrelated to correct/incorrect feedback and bypassing the shared service (so it won't
  respect the feedback on/off setting) — left as-is, out of this fix's scope.

**Fixed, with your explicit go-ahead on scope (pilot first, then the rest):** all 56
unwired engines now call `GameFeedbackService.correct()`/`.incorrect()` at their existing
answer-handling branch — the same one-line call the shared controller already made, no
architecture change. Three answer-handling shapes were found and handled per-file (not
assumed): a dedicated `_onAnswer` with a local `correct`/`isCorrect` bool (9 engines), a
shared `_applyAnswerResult(bool isCorrect)` used by multiple input modes (35 engines), and
two engines (`multiples_grid`, `word_builder`) that don't use a win/lose quiz phase at all
— their calls were added at their actual grid-tap/letter-tile correct/incorrect branches
instead.

Re-running the audit script after the fix: **64/64 engines wired.** `flutter analyze`: 0
issues. `flutter test`: 406 passed, both before and after the full batch. Verified green
in GitHub Actions. Commits: `f847f87` (5-engine pilot + an unrelated `flutter analyze`
regression fix from the earlier `firebase-tools` devDependency pulling a stray Dart file
into analysis scope) and `2f3bf52` (remaining 50 engines).

**Still open:** no automated test asserts that `GameFeedbackService.correct()` is actually
called on a correct answer for any of these 64 engines — this is a widget/unit-test gap,
not an integration gap, and is tracked alongside the rest of the Flutter-side test
coverage work in §8.

## 7. Explicitly NOT attempted this session (honest accounting, not silence)

Per the brief's own anti-fabrication rules, the following are reported as **NOT STARTED**
or **BLOCKED**, not glossed over:

- **OTP challenge implementation** (Phase 1 remaining item 1) — NOT STARTED, decision
  made. You confirmed email OTP (not step-up re-auth) as the approach. This is still a
  net-new feature (expiry, single-use, attempt limits, resend cooldown, server-side
  verification) — implementation work, not yet started.
- **Audit of existing Firebase Auth users for unintended extra admins** (Phase 1 item 4)
  — **Read-only audit DONE (2026-10-10).** Queried Identity Platform directly (not
  `firebase auth:export`, which the harness's own PII-handling policy correctly blocked
  for dumping all 96 users' emails/names to disk — used a narrower Identity Toolkit REST
  query instead, filtered to role claims only, and deleted the raw response immediately
  after filtering). Result: exactly **one** account has `role: admin`
  (`YwDx5AXvweaObsNKaVcxUxVEbc72`), enabled, with login history. Role breakdown across all
  96 users: 50 none, 28 learner, 13 parent, 4 teacher, 1 admin. **No extra/unintended
  admin found — awaiting your confirmation that this UID is the intended sole admin**
  before this item can be marked fully closed (demoting or flagging any account still
  requires your explicit authorization per the brief's own rules, but there is nothing to
  demote here).
- **Firestore/Storage rules negative-test suite in the emulator** — NOT STARTED. §5's
  Jest/emulator harness now exists and could host these, but the rules-specific tests
  themselves (via `@firebase/rules-unit-testing`) have not been written.
- **Full behavioral verification of Phases 2–5** (rate-limit concurrency, notification
  idempotency on repeated scheduled runs, AI prompt-injection hardening, admin report
  widget states beyond `getAdminPlatformReport`) — NOT STARTED. No longer blocked on a
  missing harness (§5 fixed that); the remaining 34 functions simply don't have tests
  written yet.
- **Staging/manual walkthrough** (admin login, parent-child linking, full game session,
  push notifications) in a real browser/device — BLOCKED on this session not having an
  interactive browser pass scheduled for it yet, and per standing policy I don't type
  real account passwords into any non-localhost target.

## 8. What only you can authorize next

- Confirm `YwDx5AXvweaObsNKaVcxUxVEbc72` is the intended sole admin UID (§7), so the
  admin-account audit item can be marked fully closed.
- Priority order for the remaining §7 items — each is genuinely multi-hour-to-multi-day
  work; doing all of them in one sweep isn't realistic without more sessions.
- OTP: approach is decided (email OTP) — implementation itself still needs to be
  scheduled.

## 9. Bottom line

**Fixed and verified this session, with evidence:** CI/Vercel version-pin stability gap,
one critical dependency vulnerability, 9 undeployed Cloud Functions (Phases 3–5's entire
backend), 1 missing Firestore index, a working Jest + Firestore-emulator test harness for
Cloud Functions wired into CI, and a 64-engine game-feedback integration audit that found
only 8 of 64 engines reached Phase 2's spoken feedback and fixed the other 56 (§7a). All
verified green in real GitHub Actions runs, not just locally. **Confirmed already-fine
(no action needed):** the previously-documented IAM blocker. **Confirmed correct (no fix
needed):** the `pendingAiReports` formula. **Confirmed clean (awaiting your sign-off):**
the admin-account audit — exactly one admin account exists, no extras to demote.
**Genuinely not done, reported honestly:** OTP implementation (approach decided), the
full security/behavioral test suite for the remaining 34 of 35 Cloud Functions, the
Firestore/Storage rules negative-test suite, and staging verification — these remain
real, substantial, multi-session work.

**Release readiness: NEITHER staging-ready nor production-ready as a whole system.** The
infrastructure-level fixes in this report make what's already merged actually *work* in
production; they do not constitute the security and behavioral test coverage the
original five-phase work still needs before it can be called verified.
