# Phase 5 — Admin & Platform Reports

## Goal

Provide administrators with a protected, live aggregate report of QuestKids usage and moderation workload without exporting learner-identifying information.

## Implemented on this branch

- Adds the authenticated callable `getAdminPlatformReport`.
- Requires an authenticated Firebase ID token with the `admin` custom claim. Client-side role fields are not used for authorization.
- Reads Firestore aggregate counts for total users, learner/parent/admin accounts, activities, game sessions, game sessions in the last seven days, AI safety reports, resolved/pending AI reports, and generated weekly reports.
- Returns counts and a generation timestamp only; no learner names, email addresses, or individual scores are returned.
- Adds a Reports destination to the existing administrator dashboard and loads the metrics from the callable.
- Keeps existing user management and AI safety review flows in place.

## Privacy and reliability

- The callable is read-only and does not accept collection names or query expressions from the client.
- A non-admin or unauthenticated caller is rejected.
- Aggregate counts depend on the deployed Firestore data and indexes; they are not a guarantee that scheduled reports or push notifications are configured correctly.
- The reports screen must show loading, error, and empty/zero states honestly.
- This phase does not create downloadable CSV/PDF exports or change user roles, accounts, or report records.

## Verification checklist

- [ ] Functions build and lint pass.
- [ ] Flutter analysis and tests pass.
- [ ] Admin can load the reports screen and refresh the data.
- [ ] Unauthenticated and non-admin callable requests are denied.
- [ ] Counts match the Firebase Emulator or staging dataset.
- [ ] Seven-day session count respects `completedAt` and the server's current time.
- [ ] Confirm Firestore aggregate-query support and any required indexes in the target project.
- [ ] Test dashboard layout on Flutter Web and a mobile viewport.

## Release status

This is a draft stacked on Phase 4, which depends on Phase 3 and Phase 2. It has not been merged or deployed. Merge and verify earlier phases in order before release, and resolve the outstanding Phase 1 security gaps before production rollout.
