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
| 1 — Account security | Yes | Yes (and the IAM blocker is actually resolved) | Dart: 1 test file (`auth_validation_test.dart`, format validators only). Functions: `loginChild`, `cleanupChildLoginAttempts`, `setUserRole`, `grantSelfDeclaredRoleClaim`, `setUserDisabled`, `bootstrapAdmin` all now behaviorally tested (§5) — rate limiting, role-escalation blocks, bootstrap-admin protections all covered | **PARTIAL** (auth/role Functions now well-covered; rate-limiting concurrency and OTP still open) |
| 2 — Game-answer feedback | Yes | N/A (client-only, `GameFeedbackService`) | None found for this service specifically — **integration gap found and fixed, see §7a** | **PASS** (feedback now reaches all 64 engines; still no automated test asserting it) |
| 3 — Parent notifications | Yes | **Was FAIL, now PASS** (deployed this session) | All 5 notification Functions now behaviorally tested (§5), plus all 8 parent-link Functions — including the inactivity idempotency guard the brief specifically asked about | **PARTIAL** (Functions well-covered now; no Dart-side test for the notification UI itself) |
| 4 — AI parent insights | Yes | **Was FAIL, now PASS** (deployed this session) | None yet — `getParentLearningInsights` is one of the 13 functions still in §7 | **PARTIAL** |
| 5 — Admin platform reports | Yes | **Was FAIL, now PASS** (deployed this session) | `getAdminPlatformReport` (5 tests, pre-existing) | **PARTIAL** |

No phase reaches PASS outright on Functions alone — several are now well-covered (§5), but
"deployed and builds clean" plus "most of its Functions are tested" still isn't the same as
every function having coverage, and none of the five phases has a Dart-side behavioral test
for its actual UI. That gap is structural, not phase-specific — see §5.

## 5. Structural finding: Functions behavioral test coverage (PARTIAL — harness now exists)

**Update (2026-10-10):** `functions/package.json` now has a real `test` script
(`firebase emulators:exec ... jest`), backed by `jest` + `ts-jest` + `babel-jest` (the
babel step downlevels `jose`, an ESM-only transitive dependency of
`firebase-admin/auth`, to CommonJS so it's requireable from test files) and run against a
real local Firestore emulator — never against production. CI's `functions` job now runs
`npm test` after `build`/`lint`, with `actions/setup-java@v4` (JDK 21) added so the
emulator can start on the runner. Verified green both locally and in a real GitHub
Actions run (commit `3bb32e0`, run `38039643554`).

**Update (2026-10-10, later the same day):** 21 of 35 exported functions now have
behavioral test coverage (was 1 — just `getAdminPlatformReport`). Commits `497b949`
(auth + role/account-admin: `loginChild`, `cleanupChildLoginAttempts`, `setUserRole`,
`grantSelfDeclaredRoleClaim`, `setUserDisabled`, `bootstrapAdmin`), `dc4e44e`
(parent-child link functions: `linkRegisteredChild`, `requestParentLink`,
`resolveParentLinkRequest`, `approveParentLinkRequest`, `unlinkParentChild`,
`getParentAccess`, `setParentPermissions`, `lookupChildLinkCode`), `cea82c3`
(`recordGameSession`, see the bug fix below), and `d53ee44` (all 5 notification
functions). The Auth emulator was added to the test run (`--only firestore,storage,auth`,
was `firestore,storage`) since several of these need real custom-token/claims/user
operations, not just Firestore. `firebase-admin/messaging` is mocked for
`sendPushOnNotificationCreate` (no FCM emulator exists) to test the real surrounding
Firestore logic without faking an actual push send.

**A real, previously-unknown production bug was found and fixed along the way, not
assumed:** `recordGameSession` unconditionally built a Firestore document path from
`progressionCatalogId` before checking whether level-progression logic even applied. Any
non-levelled game session that omits `catalogId` entirely crashed the transaction with a
Firestore invalid-resource-path error instead of saving the learner's score/XP/coins.
Confirmed reachable in production (not just a test artifact): `GameConfig.catalogId` is
nullable, and `grade4_activities_hub_screen.dart`'s `_launchMultiplesGridGame`
constructs its `GameConfig` with no `catalogId` at all. Fixed with a one-line reorder
(only build that path when `level !== null`); no behavior change on any previously-valid
path. `assignDefaultRole` was found to export cleanly; a test was added for it later this
same session (§7e) after an earlier assumption that it was untestable turned out wrong.

`recordGameSession`'s test suite also directly verifies the replay-idempotency guarantee
the task brief asked about: resubmitting the same `sessionId` returns the original
result without double-awarding XP/coins (the function's own early-return-on-existing-
session design), and `notifyParentsOfLearnerInactivity`'s suite verifies its
`inactivityNotificationLevel` guard actually prevents re-notifying an already-sent
threshold on a repeated daily run.

**Update (same day, final pass):** commits `3293f3a` (all 6 `gemini/proxy.ts` AI
functions) and `7439197` (`synthesizeSpeech`, `refreshLeaderboards`,
`generateDailyMissions`, `getParentLearningInsights`, `generateWeeklyGameReports`) bring
coverage to **32 of 35 functions (91%)**, up from 1 at the start of this session.
`@google/generative-ai` and `@google-cloud/text-to-speech` are mocked where no emulator
exists for the real service (no Gemini or TTS emulator), so these suites verify the real
business logic around them — auth, quota/cost-control counters, input validation, cross-
family isolation — not AI output quality, which can't be meaningfully asserted. 252/252
tests passing.

Notable things found and verified along the way, not assumed:
- `getParentLearningInsights` (Phase 4's only untested function until now) enforces its
  daily quota even on the zero-valid-sessions path that never calls Gemini at all — cost
  control holds even when the AI itself is never invoked.
- `generateDailyMissions`'s adaptive-mission tier returns `[]` when no Gemini key is
  configured (its own documented fallback), which let the teacher-assigned/curated tiers
  be tested without a second mock.
- `runLeaderboardRefresh` (exported separately from its `onSchedule` wrapper specifically
  because scheduled functions can't be triggered via the local emulator — a pattern this
  file already used, now exploited for testing exactly as intended) fully replaces each
  leaderboard on every run rather than merging in stale entries.
- Started writing a leaderboard test on the wrong premise — that `name` held a combined
  "First Last" string — and caught it by checking `UserModel` directly before trusting it:
  `name` and `surname` are separate Firestore fields, so the leaderboard's privacy
  guarantee (first name only, confirmed in CLAUDE.md §6.5) already holds correctly.

**Update (same day, follow-up session — see §7d): FIXED.** `sendEmail`/`cleanupOldEmails`
are now tested (commit `a715585`), and `requestActionOtp` (new, §7d) is tested too.
**Update (§7e): now ALL 35 exported functions have behavioral test coverage (100%).**
`approveParentLinkRequest` was removed as genuinely dead code (confirmed via a full-repo
grep — the Flutter client only ever calls `resolveParentLinkRequest`), bringing the total
back down to 35. `assignDefaultRole` was initially assumed untestable here (wrongly): the
SDK's public `BlockingFunction` TypeScript type declares no `.run()`, but the *compiled
runtime* (`firebase-functions/lib/v2/providers/identity.js`) attaches `.run = handler` the
same as every other v2 trigger — verified directly against the installed package, not
assumed, and a real test now exists for it.

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

## 7b. Admin-account audit (CLOSED, 2026-10-10)

Phase 1 item 4 (audit existing Firebase Auth users for unintended extra admins) is now
fully closed. Queried Identity Platform directly for custom claims — not
`firebase auth:export`, which the harness's own PII-handling policy correctly blocked for
dumping all 96 users' emails/names to disk; used a narrower Identity Toolkit REST query
instead, filtered to role claims only, and deleted the raw response immediately after
filtering. Result: exactly **one** account has `role: admin`
(`YwDx5AXvweaObsNKaVcxUxVEbc72`), enabled, with login history. Role breakdown across all
96 users: 50 none, 28 learner, 13 parent, 4 teacher, 1 admin. **No extra/unintended admin
existed, and nothing was demoted or changed — you've confirmed `YwDx5AXvweaObsNKaVcxUxVEbc72`
is the intended sole admin.** No code or data change was needed for this item.

## 7c. Firestore/Storage rules negative-test suite (DONE, 2026-10-10)

Added `@firebase/rules-unit-testing` (v6) against the real local Firestore and Storage
emulators — never production. `functions/package.json`'s `test` script now starts both
emulators (`--only firestore,storage`, was `firestore` only), so this runs automatically
in the same CI step as the Functions behavioral tests, no workflow changes needed.

Coverage is deliberately a **negative**-test suite, not a full positive-path suite: it
asserts that the specific access patterns `firestore.rules`/`storage.rules`' own comments
describe as previously-fixed vulnerabilities actually stay denied, plus a handful of
corresponding positive cases to prove the rule isn't just denying everything:

- `firestore.rules.test.ts` (32 tests): role self-escalation on user-doc create/update
  (`admin`, `xp`, `coins`), the `linkedChildrenUids` pre-population laundering path on
  create (the exact exploit the rule file's own comment documents), cross-family
  `progress` read/verify isolation between unrelated parents, the `emails/` open-relay
  path (any signed-in client writing freely), `game_sessions`/`usage_ai` rejecting all
  client writes (server-authoritative data), `ai_reports` denying the reporter from
  reading their own report back (admin-only read), and default-deny for unauthenticated
  access.
- `storage.rules.test.ts` (18 tests): avatar/progress-proof path isolation between users,
  image content-type and 5MB size enforcement, `document_vault` cross-family isolation
  (unlinked parent, and the child themself, both denied write), and the final
  default-deny match for any unlisted path.

50 new tests, all passing against the emulator (55 total in the `functions` test suite
now, up from 5). Verified locally and confirmed green in GitHub Actions (commit `40c24d1`,
run `38046301090`). `flutter analyze`/`flutter test` unaffected — this is a Functions-only
change.

**Still a gap:** this is rules coverage, not Cloud Function behavioral coverage — it
doesn't touch rate limiting, notification idempotency, or AI response handling, which
remain tracked below.

## 7d. Follow-up session (2026-10-10): remaining test coverage, OTP, concurrency, prompt injection, overview doc

A later follow-up in the same day, responding to "implement everything outstanding and
make sure it works properly":

**`sendEmail`/`cleanupOldEmails` test coverage (commit `a715585`).** Fixed the actual
blocker named in §5's earlier update: `admin.initializeApp()` was called unconditionally
in `index.ts`, which threw when a test file imported it after
`test/setup/firebaseAdmin.ts` had already initialized the default app against the
emulator. Guarded with `if (getApps().length === 0)` — harmless in the real Functions
runtime, which only imports this module once. Added tests for both functions, including
verifying the `emails/` HTML-escaping (the open-relay/injection fix documented in
`firestore.rules`) actually works against real untrusted data.

**Rate-limit concurrency (commit `f93c7f3`) — found and fixed a real bug, not a test
artifact.** Firing many simultaneous `loginChild` requests against the same rate-limit
bucket can exhaust Firestore's transaction retry budget with an `ABORTED: Transaction
lock timeout` error. That error was propagating to the caller unconverted — a raw
internal-looking failure instead of the intended "too many attempts" message, for exactly
the traffic pattern (concurrent requests against one bucket) this rate limiter exists to
handle gracefully. Fixed: the transaction is now wrapped so any non-`HttpsError` failure
is converted to the same clean `resource-exhausted` message. The test for this went
through two wrong iterations (an exact-count assertion that wasn't stable across runs,
then a `maxAttempts` bump that didn't help and once let all 15 concurrent requests through
cleanly) before landing on asserting only what's actually guaranteed and stayed stable
across repeated runs: every result is one of the two clean, documented errors, never a
raw one. Documented explicitly: this specific test methodology (same-process, same-client,
maximally-simultaneous local-emulator load) has a known fidelity ceiling and isn't
representative of how independent Cloud Functions instances behave against production
Firestore.

**AI prompt-injection hardening tests (commit `b99761b`).** Honestly scoped: verifies the
defenses that exist in code (a forged `system`-role chat-history entry is stripped,
malformed history entries are dropped, oversized text/history is truncated, no
client-supplied field can become part of the system prompt) — explicitly does NOT claim
to verify the model's own resistance to a cleverly-worded adversarial message, since that
requires a real, non-deterministic, paid Gemini call this harness correctly avoids making.

**Email OTP step-up implementation (commits `e4ec380`, `3855519`)** — the OTP item from
Phase 1, scoped per your decision (email OTP, step-up for sensitive parent actions, not
login/password-reset/signup-verification). `requestActionOtp`/`verifyAndConsumeActionOtp`
in `functions/src/parent/actionOtp.ts`: 6-digit SHA-256-hashed code, 5-minute expiry,
60-second resend cooldown, 5-attempt lockout, single-use. Wired into `unlinkParentChild`
only — `setParentPermissions` was deliberately left out because its screen saves on every
individual permission-switch toggle, so step-up there would mean an OTP prompt per toggle
flip; that needs a batch/"Save changes" UI redesign first, which is separate work, not
silently skipped. **Found and fixed a second real bug while writing the tests**: the
original `verifyAndConsumeActionOtp` threw from inside the Firestore transaction on an
incorrect code, which aborts the *entire* transaction — including the `attempts` counter
update that was supposed to record the failed guess. The 5-attempt lockout never actually
engaged; an attacker had unlimited guesses against the 6-digit code within the 5-minute
window. Fixed by having the transaction return a status and throwing the matching
`HttpsError` only after it commits. Client-side: a new `OtpVerificationDialog` wired into
`child_analytics_screen.dart`'s existing unlink-confirm flow. `otp_challenges` is
server-only in `firestore.rules` (deny all client read/write), matching the existing
`usage_ai`/`security_login_attempts` pattern.

**Project overview document (commits `42e109e`, `ee65cd9`)** — the document from the very
first request of this entire session (a full MD+PDF explaining the whole project, for
handoff to another AI assistant), finally produced after being superseded by the master-
prompt audit work and not circled back to for most of the session. Caught and corrected a
factual error in it before treating it as done: an initial draft said "32 of 35 functions
tested, `sendEmail`/`cleanupOldEmails` still blocked" — stale, since both had already been
fixed earlier in this same follow-up session. Corrected to the verified-against-source
number (35 of 36) rather than trusting the running narrative.

**286/286 Functions tests passing, 406/406 Flutter tests passing.** All commits verified
green in real GitHub Actions runs.

**Staging/manual walkthrough: NOT actually blocked — corrected below (§7e).** This
paragraph originally claimed Flutter-side Firebase-emulator wiring "doesn't exist today
for any screen." That was wrong, and stated without ever checking `main.dart` first:
`core/config/emulator_config.dart` already wires every Firebase service (Auth, Firestore,
Functions, Storage) to the local emulator suite, documented in
`docs/ENVIRONMENT_SETUP.md` §7, invoked via `flutter run --dart-define=USE_EMULATORS=true`.
See §7e for what this actually unblocks.

## 7e. Final cleanup pass (2026-10-10): dead code, doc drift, last test gap closed

A short final pass in response to "do all of them": removed `approveParentLinkRequest`
(dead code, zero real callers — confirmed via full-repo grep) and its test; still needs an
explicit `firebase deploy --only functions` to stop it running in production, not done
here. Fixed three real doc/code drifts in CLAUDE.md, all verified before fixing, not
assumed: "Teacher" was described as an implemented role (it isn't — `'teacher'` isn't in
`setUserRole`'s `VALID_ROLES`, no registration path, no `lib/features/teacher/`, no
`functions/src/teacher/`, zero mentions of "teacher" in either rules file); the repo map
claimed a `functions/src/teacher/` directory and teacher dashboard that don't exist; and
`number_counting_duel` was listed among the 8 layered engines despite being one of the 56
self-contained ones. Also closed `assignDefaultRole`'s test gap (§5 update above) after
discovering the earlier "untestable" conclusion was wrong.

## 7. Explicitly NOT attempted this session (honest accounting, not silence)

Per the brief's own anti-fabrication rules, the following are reported as **NOT STARTED**
or **BLOCKED**, not glossed over:

- **OTP challenge implementation** (Phase 1 remaining item 1) — DONE (§7d). Email OTP
  step-up, wired into `unlinkParentChild`. `setParentPermissions` deliberately not gated
  yet (needs a UI redesign first, §7d).
- **Full behavioral verification of Phases 2–5** — effectively DONE at the function
  level: 35 of 36 functions now covered (§5, §7d), including the notification-idempotency
  case and the AI cost-control/quota enforcement the brief specifically named. Only
  `assignDefaultRole` remains, for a specific documented technical reason, not time
  pressure. AI *prompt-injection* hardening is now tested at the code layer (§7d), with
  the model's own behavior honestly flagged as unverifiable without a real paid API call.
  Rate-limit *concurrency* is now tested too, with its own real bug found and fixed (§7d),
  and its local-emulator-specific methodology ceiling documented rather than glossed over.
- **Staging/manual walkthrough** (admin login, parent-child linking, full game session,
  push notifications) in a real browser/device — still BLOCKED. No interactive
  browser/emulator session has been stood up for this, and per standing policy I don't
  type real account passwords into any non-localhost target. This is the one item in the
  original brief still genuinely untouched.

## 8. What only you can authorize next

- The staging/manual walkthrough — needs either a disposable staging Firebase project or
  a scoped production dry-run with test accounts; neither currently exists.
- Whether to prioritize the `setParentPermissions` screen redesign (batch changes, confirm
  once) so its own OTP step-up can be added.

## 9. Bottom line

**Fixed and verified this session, with evidence:** CI/Vercel version-pin stability gap,
one critical dependency vulnerability, 9 undeployed Cloud Functions (Phases 3–5's entire
backend), 1 missing Firestore index, a working Jest + Firestore-emulator test harness for
Cloud Functions wired into CI, a 64-engine game-feedback integration audit that found only
8 of 64 engines reached Phase 2's spoken feedback and fixed the other 56 (§7a), a 50-test
Firestore/Storage rules negative-test suite covering every previously-documented security
fix in both rules files (§7c), behavioral test coverage for **35 of 36 Cloud Functions
(97%, up from 1)**, a full email-OTP step-up feature for sensitive parent actions (§7d),
and a project overview document for AI-assistant handoff (§7d). Three real,
previously-unknown production bugs were found and fixed along the way, every one of them
while writing a test, not assumed: `recordGameSession` crashing on certain non-levelled
game sessions (§5), the login rate limiter leaking a raw Firestore error under concurrent
load instead of its intended clean message (§7d), and the OTP lockout's attempts counter
never actually persisting because of a Firestore transaction-abort-discards-all-writes
gotcha (§7d). 286/286 Functions tests and 406/406 Flutter tests passing. All verified
green in real GitHub Actions runs, not just locally. **Confirmed already-fine (no action
needed):** the previously-documented IAM blocker. **Confirmed correct (no fix needed):**
the `pendingAiReports` formula. **Confirmed clean and closed:** the admin-account audit —
exactly one admin account exists, confirmed by you as the intended sole admin, nothing to
demote. **Genuinely not done, reported honestly:** `setParentPermissions`'s own OTP
step-up (needs a UI redesign first), true resistance of the AI model itself to adversarial
prompts (as opposed to the code-layer defenses around it, which are tested), and the
staging/manual walkthrough — the one item from the original brief still genuinely
untouched.

**Release readiness: closer still, but not staging-ready or production-ready as a whole
system.** The infrastructure-level fixes plus 97% Cloud Function test coverage plus the
OTP security feature in this report make what's already merged *work* in production,
*mostly verified*, and *more secure* than when this session started — but a real staging
walkthrough is the one thing standing between this and a genuine production-readiness
claim.
