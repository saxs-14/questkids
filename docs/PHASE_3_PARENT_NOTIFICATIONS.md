# Phase 3 — Parent activity notifications

## Scope
- Create an in-app notification for each linked parent when a learner's recorded game session is created.
- Include the game/catalog name and score when available.
- Deliver push notifications through the existing `notifications/{notificationId}` trigger; no new FCM sending path is introduced.
- Send parent inactivity alerts after 3 days and a second reminder after 7 days without a recorded game.
- Avoid alerting registration-only accounts with no recorded game activity.
- Reset the inactivity threshold when a new game session is recorded so a later inactive period can trigger new alerts.

## Trust and privacy
- Game sessions are recorded by the existing authenticated `recordGameSession` callable.
- Before writing a parent's notification, the functions verify the parent account has role `parent` and its `linkedChildrenUids` contains the learner UID.
- Inactivity alerts are sent only to verified linked parents.
- The existing notification-create trigger remains the single FCM delivery point.

## Known scope boundary
QuestKids currently persists completed/recorded game sessions, not a separate game-start event. This phase therefore notifies parents when a session is recorded; it does not claim to notify at the moment a game is opened. Adding start notifications requires a deliberate start-event model and client integration.

## Verification checklist
- [ ] GitHub Actions Functions build and lint pass.
- [ ] Flutter analysis/tests remain green (Phase 2 is included as the base branch).
- [ ] Emulator or staging test: recorded session notifies only linked parent(s) and includes score.
- [ ] Emulator or staging test: no alert for never-played learners.
- [ ] Emulator or staging test: one 3-day alert, one 7-day reminder, no daily duplicates, then reset after activity.
- [ ] Verify FCM delivery on a device with a registered token.
- [ ] Merge Phase 2 first, then retarget/merge this stacked PR.
- [ ] Deploy Cloud Functions only after staging checks and configuration review.
