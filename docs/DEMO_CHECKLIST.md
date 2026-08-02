# QuestKids — Demo Smoke Checklist

Run through this in order right before the demo. Each step should take under
a minute; if any step fails, see the note under it before improvising.

## 0. Pre-flight

- [ ] `flutter analyze` → 0 errors
- [ ] `flutter test` → all green
- [ ] `cd tools/gamegen && node validate.js` → exit 0 (mandatory gate — checks
      every catalog topic has a matching, schema-valid, sufficiently-authored
      content pack; see tools/gamegen/README.md). If the catalog or any
      content pack was hand-edited instead of going through
      `node tools/gamegen/generate.js` / `author.js`, run the full pipeline
      first: `cd tools/gamegen && npm run all`.
- [ ] `cd functions && npm run build && npm run lint` → clean
- [ ] Manual Phase 0 GCP/Firebase console steps are done (see the security
      notice from this session, or `docs/SECURITY.md`)
- [ ] App is running against the **real** Firebase project, not emulators
      (`flutter run` without `--dart-define=USE_EMULATORS=true`)

## 1. Register a parent + learner (POPIA consent)

1. Open the app → **Create Account** → choose **Parent**.
2. Fill in parent details, tap Next.
3. On the child step, fill in the child's name/grade, **leave the consent
   checkbox unchecked**, and confirm the "Create Accounts" button stays
   disabled.
4. Check the consent box, confirm the button enables, and submit.
   - **Currently expected to fail with a visible error, not redirect to the
     parent dashboard** — see `docs/DEFERRED.md`'s "Linking a child to a
     parent is blocked for every client" entry. The parent and child Auth
     accounts + Firestore docs do get created (that part of the bug this
     entry is about is fixed), but the final child-linking step is rejected
     by `firestore.rules`, so the demo will show an error here until the
     Cloud Function described in that entry exists. Do not demo this step
     as working until it's resolved. There is no pre-existing test account
     in this repo, and no in-app flow creates a standalone learner account
     (every learner is created as a child of a parent, and that path is
     exactly what's broken here) — to reach step 2 anyway, manually seed a
     learner via the Firebase Emulator UI (`localhost:4000`): Authentication
     tab → **Add user**, then use its **Custom Claims** field to set
     `{"role": "learner"}` directly (recent Auth Emulator UI builds expose
     this in the add/edit-user dialog — verify it's present in whatever
     `firebase-tools` version is actually installed, `firebase --version`,
     since this has changed across releases); then Firestore tab → create a
     matching `users/{uid}` doc (same uid as the Auth user) with
     `role: 'learner'` and the other fields `UserModel` expects.

## 2. Play one game per engine family

From the learner account (switch in, or log in directly as the child),
open **Quests** and play one game from each of these engines — the intro
sheet before each game should show a different tagline/icon and a
"You will learn" / "How it teaches" line specific to that game:

- [ ] `tugOfWar` (e.g. Subtraction Safari) — "Race & Recall"
- [ ] `adventureJourney` (e.g. Reading Rainbow) — "Explore & Decide"
- [ ] `runnerCollector` (e.g. any Grammar/classify game) — "Sort on the Run"
- [ ] `explorerMap` (e.g. My Community) — "Find & Discover"
- [ ] `sequenceBuilder` (e.g. Maths Mountain) — "Order & Build"
- [ ] `circuitBuilder` (e.g. Circuit Builder) — "Connect & Power"
- [ ] `budgetBuilder` (e.g. Financial Literacy, Grade 4+) — "Plan & Spend"

Confirm two games in the same subject visibly look/play differently.

## 3. XP applied

- [ ] After finishing a game, XP/coins shown on the result screen match
      what's added to the dashboard header (level progress bar / stats).
      **Known issue (see `docs/DEFERRED.md`):** the underlying reward data
      is correct (verified via Firestore directly), but the header's XP/
      Level numbers currently only refresh on a full page reload, not
      live after returning from a game -- Gold/Badges on the same header
      do update live. If demoing this step, reload the page after the
      game before checking the header, or expect XP/Level to look stale.

## 4. Questy chat, including report flow

1. Open **Questy** (AI tutor). On first open, confirm the "Meet Questy!" AI
   disclosure dialog appears once, then never again on reopen.
2. Send a message, confirm the reply bubble is labelled **"AI · Questy"**.
3. Long-press a Questy reply → **Report this answer** → pick a reason.
   - Expect: confirmation snackbar ("a grown-up will take a look").
   - Verify in Firebase Console → Firestore → `ai_reports` that a document
     was created with `uid`, `messageText`, `reason`, `createdAt`.

## 5. Parent link

**Currently expected to fail** — both sub-flows below hit the same
"linking a child to a parent is blocked for every client" bug as step 1
(see `docs/DEFERRED.md`), just via different `ParentRepository` call sites
(`linkParentToChild` / `approveLinkRequest` instead of `linkChild`). Do not
demo this step as working until the Cloud Function described in that entry
exists.

1. From the parent dashboard, go to **Add or Link a Child**.
2. Either register a second child (consent checkbox required again) or use
   **Link to Existing Child** with a child's link code / QR.
3. Confirm the newly linked child shows up under the parent's children list
   with progress visible.

## 6. Teacher view

1. Register (or log in as) a **Teacher** account.
2. Open the teacher dashboard — confirm class analytics render without
   errors and only show learners scoped to the teacher (not every learner
   in the system — see `docs/DEFERRED.md` for the classId TODO if this
   looks wrong).

## If something breaks mid-demo

- Red screen on a specific game → fall back to a different engine's game
  from the same subject; note the id for a post-demo fix.
- Questy chat errors → check `functions/.env` / Secret Manager has
  `GEMINI_API_KEY` set and `ENFORCE_APP_CHECK` matches what's actually
  registered in Firebase App Check for this platform.
- Leaderboard empty → it only refreshes once a day (scheduled function);
  don't rely on it reflecting same-day play during the demo.
