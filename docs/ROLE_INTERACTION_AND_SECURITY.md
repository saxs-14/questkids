# QuestKids Role Interaction, Game Progression and Security

## Product roles

QuestKids has three active product roles:

- **Child (learner)** — plays games, completes quests, earns rewards, views their own progress and presents a secure parent-link code/QR.
- **Parent (parent)** — manages only children who are explicitly linked to the parent account, reviews progress, uses parent tools, and approves or declines requests from additional parents.
- **Admin (admin)** — operates the platform, manages accounts and approved content, reviews safety reports, and handles operational/security administration.

Teacher is not an active product role.

## Parent-child relationship model

A child has one **primary parent** (parentUid) and can have additional approved parents in linkedParentUids.

A parent keeps the reverse relationship in linkedChildrenUids.

The relationship is never granted by a client-side Firestore write.

### Secure linking flow

1. The child displays a short link code/QR.
2. A parent submits the code through a protected callable function.
3. The server verifies that the code belongs to a child account and returns only the minimum preview data.
4. The server creates a pending request using the authenticated parent's UID.
5. Only the child's primary parent can approve or decline the request.
6. Approval is performed in a server-side Firestore transaction.
7. The server atomically updates both sides of the relationship and notifies the requesting parent.
8. A linked parent can later remove their own relationship.
9. A parent cannot self-authorize access to an unrelated child by supplying another UID.

The client cannot directly create, approve, decline, or modify the relationship fields.

## Grade 1 game progression

Grade 1 catalogue games open through a dedicated ten-level progression screen.

- Levels 1–10 are displayed clearly.
- Only the current level is playable.
- A completed level unlocks the next level.
- A failed level remains available for retry.
- Level 10 is the final level.
- Progress is stored under game_level_progress/{uid}/games/{catalogId}.
- Clients can read progress but cannot write it.
- The server advances progress only after recording a valid game session.
- Game score, XP, coins, engine statistics and level completion are server-authoritative.

## Game security

Game sessions are submitted through the recordGameSession callable.

The server:

- authenticates the child account;
- validates score, accuracy and duration ranges;
- validates Grade 1 level sequencing;
- prevents replay of an already-recorded session ID;
- calculates authoritative XP and coins;
- updates game session history;
- updates progress and player statistics;
- updates engine statistics;
- updates rewards;
- advances Grade 1 level progression atomically.

The client cannot directly create or edit game_sessions, player_stats, game_progress, or game_level_progress.

## Admin security

Admin access uses:

- Firebase Authentication;
- a dedicated Admin Portal;
- the admin Firebase custom claim;
- server-side authorization for role changes and account disabling;
- no public admin registration.

The visible admin screen is not the security boundary; Firebase custom claims and backend authorization are.

## App Check

Callable functions are implemented with App Check enforcement support. Production enforcement must only be switched on after the Firebase project has registered the Android/iOS/Web app providers and the release builds are configured to obtain valid App Check tokens.

Current code deliberately keeps the deployment toggle configurable so development/emulator builds are not accidentally locked out.

## Security principle

No client-side UI control is treated as authorization.

The authoritative decisions are made by Firebase Authentication custom claims, Firestore Security Rules, and protected Cloud Functions.
