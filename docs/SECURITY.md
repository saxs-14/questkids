# QuestKids — Security Model

QuestKids handles data for children under 18 (POPIA) and ships on Google
Play Families, so security constraints here are non-negotiable — see
[CLAUDE.md](../CLAUDE.md) §6 for the canonical rule list. This page explains
*how* the codebase enforces them.

## Secrets

Never commit: `serviceAccountKey*.json`, `*OAuth*Credentials*.json`, `.env`,
private keys (`.pem`, `.p12`), Android `key.properties`, Gmail app passwords.
These are all covered by `.gitignore`. `firebase_options.dart` and
`google-services.json` are Firebase *client* config and are fine to commit —
they contain no secrets, only project identifiers.

If a secret is accidentally committed: delete it from the tree **and**
revoke it at the source (GCP IAM for service account keys, GCP Credentials
for OAuth client secrets). Deleting the file does not invalidate the
credential and does not remove it from git history — a history purge is a
separate, deliberate step.

## Roles and authorization

Roles (`learner`, `parent`, `teacher`, `admin`) are Firebase Auth **custom
claims**, set only by the `admin/setUserRole` Cloud Function
(`functions/src/admin/setUserRole.ts`), which itself requires the caller to
already hold the `admin` claim. New accounts get a default `learner` claim
via the `assignDefaultRole` `beforeUserCreated` blocking function.

Firestore rules (`firestore.rules`) check `request.auth.token.role`, never a
`role` field read off a Firestore document — a client can write whatever it
wants into its own user doc's `role` field for display purposes, but that
value is never trusted for access control. The rules also block clients
from writing `role`, `xp`, `coins`, `level`, `linkedChildrenUids`, `uid`, or
`email` on their own user document; only Cloud Functions (via the Admin SDK,
which bypasses rules) can change those.

Teacher reads are meant to be scoped to their own class, not all learners.
That requires a `classId` field on learner-owned documents, which the data
model doesn't have yet — see `docs/DEFERRED.md` for the TODOs left in
`firestore.rules` and what finishing this looks like.

AI chat logs (`users/{uid}/chats`) are readable by the child and their
linked parent only — teachers do not have access.

## Gemini / AI proxy

All Gemini calls go through `functions/src/gemini/proxy.ts` — the client
never holds an API key. Every callable:

- Rejects unauthenticated callers (`request.auth` required)
- Can be gated behind Firebase App Check via the `ENFORCE_APP_CHECK` env
  flag (start `false` while App Check is being rolled out on each platform,
  flip to `true` once verified)
- Caps input size (message ≤1000 chars, history ≤20 turns, image ≤4MB)
- Enforces a 50-calls/day/uid quota via a transactional counter at
  `usage_ai/{uid}`
- Applies Gemini safety settings blocking harassment/hate/sexual/dangerous
  content at `BLOCK_LOW_AND_ABOVE`

The Questy system prompt instructs the model to point a child mentioning
self-harm, abuse, or feeling unsafe toward a trusted adult, and to never ask
a child for personal information.

## AI content compliance (Google Play policy)

Every Questy message is labelled as AI-generated in the UI. A long-press
lets a user report a message, which writes to `ai_reports` (readable by
admins only, created by the reporting user only).

## POPIA / children's data

Every learner account requires recorded parent/guardian consent
(`consentGivenBy`, `consentEmail`, `consentAt`, `policyVersion` on the user
doc) captured at registration. No advertising-ID collection — see the
`AD_ID` permission removal and
`google_analytics_adid_collection_enabled=false` meta-data in
`android/app/src/main/AndroidManifest.xml`. Leaderboards show display
name/avatar only, never surnames, emails, or school identifiers.

## Reporting a vulnerability

This is a student project without a formal bug bounty. If you find a
security issue, please open a private report to the maintainer rather than
a public GitHub issue.
