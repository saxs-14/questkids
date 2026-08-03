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
   - **Fixed 2026-08-03** — confirmed working end-to-end against the
     Firebase emulator: submitting lands on the parent dashboard. See
     `docs/DEFERRED.md`'s items 1 and 2 for what was actually broken (a
     missing claim-upgrade Cloud Function, a stale client token that
     never refreshed, and a missing Cloud Function to complete the
     parent↔child link) and what was fixed.
   - **One remaining rough edge, not yet fixed:** immediately after
     submitting, in that same browser session, the parent dashboard may
     still show "No child selected" until the page is reloaded once —
     the child *is* correctly linked server-side by this point, it's a
     client-side token-propagation delay (see `docs/DEFERRED.md` item 1's
     last bullet). If demoing, do one reload after registration completes
     and before showing the parent dashboard, or set expectations that a
     refresh may be needed.

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

As of 2026-08-03, both sub-flows below should work — see
`docs/DEFERRED.md` items 1/2 for what was fixed and how each was tested:

- **Registering a second child** goes through `createChildForParent`,
  which uses the same `UserRepository.linkChild()` fixed alongside step 1
  — should work (not yet explicitly re-tested for the *second*-child case
  specifically, only the first-child-at-registration case).
- **"Link to Existing Child"** (code / name+email / QR — all three tabs
  in `link_child_screen.dart`) creates a *pending request*
  (`sendLinkRequest`), not an instant link — this is by design (an
  instant link without the primary parent's consent would be a security
  hole), not a bug. The child's **primary parent** then needs to approve
  it from **Link Requests** on their own Profile tab before the new
  parent sees the child. `approveParentLinkRequest` (the Cloud Function
  behind that approval) is fixed and deployed, tested directly against
  the emulator with a seeded two-parent scenario.

1. From the parent dashboard, go to **Add or Link a Child**.
2. Either register a second child (consent checkbox required again) or use
   **Link to Existing Child** with a child's link code / QR — this only
   sends a request; note that a demo needs a *second* parent account
   (the child's primary parent) signed in separately to approve it from
   their **Profile → Link Requests**.
3. Confirm the newly linked child shows up under the parent's children list
   with progress visible.

## 5b. Unlink a child

New as of 2026-08-03. From a parent's **Profile → My Children**, tap a
child to open their analytics screen, then tap the red link-off icon next
to the PDF button (top right). Confirm the dialog, confirm a success
snackbar appears and the screen returns to the dashboard, and confirm the
child no longer appears under **My Children**. This only removes *your*
access — the child's own account and data are untouched, and any other
linked parent (if one exists) keeps their own access.

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
