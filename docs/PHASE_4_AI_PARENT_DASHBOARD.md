# Phase 4 — AI Parent Learning Insights

## Goal

Give a verified parent practical, encouraging suggestions grounded in the linked learner's recorded QuestKids game sessions.

## Implemented on this branch

- Adds the authenticated callable `getParentLearningInsights`.
- The callable accepts only a child UID. It reads the learner profile and up to 30 recent scored game sessions from Firestore on the server; clients cannot submit replacement scores or subject summaries.
- Requires a parent custom claim and parent profile, a learner profile, and reciprocal relationship evidence: the parent's `linkedChildrenUids` must include the learner, and the learner must reference the parent through `parentUid` or `linkedParentUids`.
- Applies a transactional daily quota of 10 requests per parent in `usage_parent_ai/{parentUid}`.
- Calls Gemini through the Cloud Functions runtime and returns a structured summary, strengths, focus areas, three practical actions, and a disclaimer.
- Adds a **Get AI learning insights** action and results card to the existing child analytics screen. The existing weekly AI report remains in place.
- Keeps AI credentials on the server. The client sends only the linked learner UID.

## Child privacy and responsible AI

- Do not expose a learner's insights to an unlinked parent.
- Use only the learner's first name in the model prompt; do not send surname, email, or other account identifiers.
- Treat the result as learning guidance, not a formal school assessment. The prompt forbids diagnoses and medical/psychological claims.
- The screen must remain usable if generation fails; errors are shown as a short message and the rest of analytics remains available.
- The callable uses the repository's existing App Check enforcement setting. Production App Check enforcement remains a deployment configuration concern.

## Verification checklist

- [ ] `cd functions && npm ci && npm run build && npm run lint`
- [ ] `flutter pub get && flutter analyze && flutter test`
- [ ] Signed-in parent can request insights for a reciprocally linked learner.
- [ ] Unauthenticated users, learner-role users, and unlinked parents are rejected.
- [ ] The callable ignores client-supplied scores and uses server-read game sessions only.
- [ ] A parent with no scored sessions receives a cautious, no-data explanation rather than invented trends.
- [ ] Quota rejects the 11th daily request and resets on the next UTC date.
- [ ] Flutter Web and mobile UI handle loading, success, callable errors, and empty result lists.
- [ ] Verify the required Firestore composite index for `game_sessions(uid, completedAt desc)` in staging if Firebase requests one.

## Release status

This branch is a draft stacked on Phase 3, which itself depends on Phase 2. It has not been merged or deployed. Do not release until automated checks and staging authorization tests pass. Merge in order: Phase 2, Phase 3, then Phase 4 (and resolve Phase 1 security gaps before production rollout).
