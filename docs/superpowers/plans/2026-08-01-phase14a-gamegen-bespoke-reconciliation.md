# Phase 14a — Reconcile gamegen Pipeline With the Grade 1/4 Bespoke-Engine Migration

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring `tools/gamegen/topics.json` back in sync with the current, hand-authored `lib/core/constants/game_catalog.dart` — which already migrated Grade 1 (9 of 10 topics) and all 45 Grade 4 topics to bespoke, self-contained per-topic engines — without reverting any of that hand-authored work, and without breaking the shared-engine model that Grade 7 (and 1 remaining Grade 1 topic) still uses. This is a **prerequisite** to `docs/superpowers/plans/2026-08-01-phase14-grade2-curriculum-content.md`: that plan's Task 6 (`npm run generate`) is unsafe to run until this reconciliation lands, because right now it would silently delete the bespoke migration.

**Architecture:** Add a `SHARED_ENGINES` set to `classify.js` (derived from `VERB_TO_ENGINES`, the closed list of the 9 original shared engines). Any topic whose `engineType` is not in that set is bespoke by construction — `extract.js` stops routing it through `classify()`/the auto-fix step (which currently force-reverts bespoke `engineType` and `mechanicReason` back to old shared-engine values), and `validate.js` stops requiring it to match a registered per-engine content-pack schema (bespoke widgets are fully self-contained and don't read content packs — confirmed by inspecting 3 of them). Bespoke topics still must have an existing, valid-JSON content pack (the Dart smoke test already enforces this) and still must satisfy the grade's difficulty band. One genuinely new topic (`ss_g7_neighbours`, unrelated to the bespoke migration) needs a real `classify.js` entry. Five Grade 1 Life Skills topics were deleted from `game_catalog.dart` during the migration but are still intact in `topics.json`; regenerating from a fixed `topics.json` restores them (per the project's "nothing should disappear" rule) with no manual re-authoring needed.

**Tech Stack:** Node 18+ (zero deps) for `tools/gamegen`.

## Global Constraints

- `npm run validate` (from `tools/gamegen/`) → 0 invariant failures.
- `flutter analyze` → 0 new errors.
- `flutter test` → all green, including `test/catalog/game_catalog_invariants_test.dart` and `test/games/all_topics_smoke_test.dart`.
- Do not hand-edit `lib/core/constants/game_catalog.dart` — every change flows through `topics.json` + `npm run generate`.
- Do not alter any bespoke engine's `engineType`, `description`, `emoji`, `learningObjective`/`capsObjective`, or `mechanicReason` from what is currently live in `game_catalog.dart` — this reconciliation must be lossless for the 54 already-migrated topics.
- Do not delete any `<engine>/` folder or any existing topic (`CLAUDE.md` §7). The 5 orphaned Life Skills topics must be restored, not dropped from `topics.json`.
- Leave Grade 7 on the shared-engine model — this plan does not migrate any Grade 7 topic to a bespoke engine.

---

### Task 1: Add `SHARED_ENGINES` and the one legitimate missing `classify.js` entry

**Files:**
- Modify: `tools/gamegen/classify.js`

**Interfaces:**
- Produces: `SHARED_ENGINES` (a `Set<string>`), exported for Task 2 (`extract.js`) and Task 4 (`validate.js`) to gate bespoke-vs-shared behavior.
- Produces: a `BY_TOPIC_KEY['geography/neighbouring_countries']` entry so `ss_g7_neighbours` (a genuine, unrelated pre-existing gap — its engine `explorerMap` **is** a real shared engine) stops crashing `classify()`.

- [ ] **Step 1: Add `SHARED_ENGINES` and export it**

In `tools/gamegen/classify.js`, after the `VERB_TO_ENGINES` object (currently ends at line 22), add:

```javascript
const SHARED_ENGINES = new Set(Object.values(VERB_TO_ENGINES).flat());
```

Update the final `module.exports` line (currently `module.exports = { classify, VERB_TO_ENGINES, VERB_LABELS, expectedEngines };`) to also export it:

```javascript
module.exports = { classify, VERB_TO_ENGINES, VERB_LABELS, expectedEngines, SHARED_ENGINES };
```

- [ ] **Step 2: Add the missing `ss_g7_neighbours` classification**

In the `BY_TOPIC_KEY` object's Social Sciences section (near the other `geography/*` keys, e.g. after `'geography/rivers': 'locate_map',`), add:

```javascript
  'geography/neighbouring_countries': 'locate_map',
```

(Matches its actual engine, `explorerMap`, which is only valid for `locate_map` per `VERB_TO_ENGINES` — consistent with the existing `geography/map_skills`/`geography/sa_provinces`/`geography/rivers`/`geography/biomes` entries all being `locate_map`.)

- [ ] **Step 3: Sanity check**

Run: `node -e "const c = require('./tools/gamegen/classify'); console.log(c.SHARED_ENGINES.size, c.SHARED_ENGINES.has('tugOfWar'), c.SHARED_ENGINES.has('additionAdventure'))"` from the repo root.
Expected: `9 true false`.

- [ ] **Step 4: Commit**

```bash
git add tools/gamegen/classify.js
git commit -m "feat(gamegen): add SHARED_ENGINES set and missing neighbouring_countries classification"
```

---

### Task 2: Make `extract.js` bespoke-aware (stop the destructive auto-fix)

**Files:**
- Modify: `tools/gamegen/extract.js`

**Interfaces:**
- Consumes: `SHARED_ENGINES` from Task 1.
- Produces: `topics.json` entries for bespoke topics now carry a `bespoke: true` field, `cognitiveVerb: null`, and their real `engine`/`mechanicReason` values verbatim from `game_catalog.dart` (currently they'd be silently reverted to shared-engine defaults). Shared-engine topics get `bespoke: false` and are otherwise unaffected — behavior identical to today.

- [ ] **Step 1: Update the import line**

`tools/gamegen/extract.js` currently imports (line 12): `const { classify, expectedEngines, VERB_LABELS } = require('./classify');`. Change to:

```javascript
const { classify, expectedEngines, VERB_LABELS, SHARED_ENGINES } = require('./classify');
```

- [ ] **Step 2: Gate the classify/auto-fix block on `SHARED_ENGINES`**

Replace lines 43–58 (the block starting `for (const e of rawEntries) {` through the closing of the `if (!allowed.includes(engine))` block) with:

```javascript
  for (const e of rawEntries) {
    const bespoke = !SHARED_ENGINES.has(e.engineType);
    let cognitiveVerb = null;
    let engine = e.engineType;
    let engineFixed = false;
    let mechanicReason = e.mechanicReason;
    if (!bespoke) {
      cognitiveVerb = classify(e);
      const allowed = expectedEngines(cognitiveVerb);
      if (!allowed.includes(engine)) {
        engine = allowed[0];
        engineFixed = true;
        fixedCount++;
        mechanicReason = mechanicReasonFor(engine, e.subtopicId);
        console.log(
          `fix: ${e.id} engine ${e.engineType} -> ${engine} ` +
            `(cognitiveVerb=${cognitiveVerb}: ${VERB_LABELS[cognitiveVerb]})`
        );
      }
    }
```

This preserves the exact existing behavior for shared-engine topics (still classified, still auto-fixed if drifted) and skips `classify()`/the fix entirely for bespoke topics — so a bespoke topic's real `engineType`, `mechanicReason`, and `topicId`/`subtopicId` (untouched either way — `topicId`/`subtopicId` were never part of the fix logic) all pass through as-is from the parsed Dart source.

- [ ] **Step 3: Persist `bespoke` and the (possibly null) `cognitiveVerb` in the emitted topic object**

Find where `extract.js` builds each output topic object (the block using `engine`, `engineFixed`, `mechanicReason`, `cognitiveVerb` to construct the record written to `topics.json` — search for where `cognitiveVerb,` appears in an object literal being pushed/returned). Add a `bespoke,` field next to it, e.g.:

```javascript
      cognitiveVerb,
      bespoke,
```

(Exact surrounding object-literal keys must stay as they are today — only add the one new `bespoke` key. If `engineFixed`/`originalEngine` are conditionally included only when `engineFixed` is true, leave that logic untouched — it still only applies to the non-bespoke branch since `engineFixed` can only become `true` inside the `if (!bespoke)` block now.)

- [ ] **Step 4: Commit**

```bash
git add tools/gamegen/extract.js
git commit -m "fix(gamegen): stop extract.js from reverting bespoke engines back to shared ones"
```

---

### Task 3: Run extract.js and verify the output

**Files:**
- Modify (generated): `tools/gamegen/topics.json`

**Interfaces:**
- Consumes: Tasks 1–2.
- Produces: an accurate `topics.json` reflecting the real current `game_catalog.dart` — 54 bespoke entries with `bespoke: true` and their real engine names, all pre-existing shared-engine entries (including the 5 orphaned Grade 1 Life Skills topics and all 61 Grade 7 topics) untouched.

- [ ] **Step 1: Run extract**

Run: `cd tools/gamegen && node extract.js`
Expected: completes with exit code 0, **no crash**, and **no `fix:` lines for any bespoke topic** (the 9 Grade 1 + 45 Grade 4 bespoke ids must not appear in any `fix:` output line — only genuine shared-engine drift, if any exists elsewhere in the catalog, should still print a `fix:` line).

- [ ] **Step 2: Verify the 54 bespoke entries came through correctly**

Run: `node -e "const t = require('./tools/gamegen/topics.json'); const b = t.filter(x => x.bespoke); console.log(b.length); console.log(b.find(x => x.id === 'math_g1_addition').engine, b.find(x => x.id === 'math_g1_addition').mechanicReason)"` from the repo root.
Expected: `54` then `additionAdventure Merging two coin piles into a chest makes the two addends and their total visible, not abstract.` (the real hand-authored copy, not the old generic "Answering fast head-to-head..." template).

- [ ] **Step 3: Verify the 5 orphaned Life Skills topics are still present**

Run: `node -e "const t = require('./tools/gamegen/topics.json'); console.log(['ls_g1_body','ls_g1_feelings','ls_g1_safety','ls_g1_community','ls_g1_habits'].map(id => t.some(x => x.id === id)))"`
Expected: `[ true, true, true, true, true ]`.

- [ ] **Step 4: Verify `ss_g7_neighbours` resolved and no other classify.js gaps remain**

Confirmed already by Step 1's clean exit (any remaining gap would have thrown). No separate check needed.

- [ ] **Step 5: Diff-review, don't commit yet**

Run: `git diff --stat tools/gamegen/topics.json`
Expected: a real diff touching the 54 bespoke ids (adding `bespoke`/updated `engine`/`mechanicReason`/`cognitiveVerb`) and `ss_g7_neighbours` (adding `cognitiveVerb`). Do not commit yet — Task 4 needs to run first so `validate.js` can be checked against this output before it's locked in.

---

### Task 4: Make `validate.js` bespoke-aware

**Files:**
- Modify: `tools/gamegen/validate.js`

**Interfaces:**
- Consumes: `SHARED_ENGINES` from Task 1, `t.bespoke` from Task 2/3's `topics.json` output.
- Produces: invariant 3 (engine matches cognitiveVerb) skips bespoke topics; invariant 8's per-engine schema check is replaced, for bespoke topics only, with the same "file exists and parses as a JSON object" check `test/games/all_topics_smoke_test.dart` already enforces on the Dart side. Invariant 9 (difficulty matches grade band) is unchanged and still runs for bespoke topics.

- [ ] **Step 1: Update the import line**

`tools/gamegen/validate.js` currently imports (line 12): `const { classify, expectedEngines } = require('./classify');`. Change to:

```javascript
const { classify, expectedEngines, SHARED_ENGINES } = require('./classify');
```

- [ ] **Step 2: Gate invariant 3 (engine matches cognitiveVerb) on `t.bespoke`**

Find the block (currently lines 52–66):

```javascript
  // 3. engine matches the cognitiveVerb table
  let verbMismatches = 0;
  for (const t of topics) {
    const verb = classify(t);
    if (verb !== t.cognitiveVerb) {
      fail(`${t.id}: stored cognitiveVerb "${t.cognitiveVerb}" != re-derived "${verb}"`);
      verbMismatches++;
    }
    const allowed = expectedEngines(verb);
    if (!allowed.includes(t.engine)) {
      fail(`${t.id}: engine "${t.engine}" not in allowed set [${allowed}] for cognitiveVerb "${verb}"`);
      verbMismatches++;
    }
  }
  if (verbMismatches === 0) ok('every engine matches its cognitiveVerb table entry');
```

Replace with:

```javascript
  // 3. engine matches the cognitiveVerb table (shared-engine topics only —
  //    bespoke topics have a 1:1 unique engine by construction, so the
  //    shared-pool match doesn't apply to them)
  let verbMismatches = 0;
  let bespokeCount = 0;
  for (const t of topics) {
    if (t.bespoke) {
      bespokeCount++;
      if (SHARED_ENGINES.has(t.engine)) {
        fail(`${t.id}: marked bespoke but engine "${t.engine}" is a shared engine`);
        verbMismatches++;
      }
      continue;
    }
    const verb = classify(t);
    if (verb !== t.cognitiveVerb) {
      fail(`${t.id}: stored cognitiveVerb "${t.cognitiveVerb}" != re-derived "${verb}"`);
      verbMismatches++;
    }
    const allowed = expectedEngines(verb);
    if (!allowed.includes(t.engine)) {
      fail(`${t.id}: engine "${t.engine}" not in allowed set [${allowed}] for cognitiveVerb "${verb}"`);
      verbMismatches++;
    }
  }
  if (verbMismatches === 0) ok(`every shared-engine topic matches its cognitiveVerb table entry (${bespokeCount} bespoke topics exempt)`);
```

- [ ] **Step 3: Relax the schema check (invariant 8) for bespoke topics**

Find the per-topic loop building `errors`/`schemaFailures` (currently around lines 127–152, using `validatePack(t.engine, pack, { min })`). Locate this specific line:

```javascript
    const errors = validatePack(t.engine, pack, { min });
```

Replace it with:

```javascript
    const errors = t.bespoke ? validateBespokePack(pack) : validatePack(t.engine, pack, { min });
```

Then add this helper function near the top of the file, after the existing `require`s:

```javascript
function validateBespokePack(pack) {
  // Bespoke engines are fully self-contained (no content-pack-driven
  // rendering) — the Dart smoke test (test/games/all_topics_smoke_test.dart)
  // only requires the pack file to exist and parse as a JSON object, so
  // that's all this checks too.
  if (typeof pack !== 'object' || pack === null || Array.isArray(pack)) {
    return ['bespoke content pack must parse to a JSON object'];
  }
  return [];
}
```

Leave the surrounding tier/min-items logic (`tierOf.get(t.id)`, `minItemsForTier(tier)`) and the `scaffoldsRemaining`/`_scaffold` check as-is — they still run but are harmless no-ops for bespoke packs (which are never scaffolds).

- [ ] **Step 4: Run validate**

Run: `cd tools/gamegen && npm run validate`
Expected: review the output carefully.
- If it now passes (`PASS: 0 invariant violation(s).`) — proceed to Task 5.
- If it fails on something **other than** the bespoke topics or `ss_g7_neighbours` (e.g. an unrelated pre-existing invariant violation) — read the exact `FAIL:` line; if it's clearly pre-existing and unrelated to this reconciliation, note it and continue (do not silently weaken an unrelated invariant to make it pass). If it's related to this reconciliation, fix the root cause in Tasks 1–4 above before continuing.

- [ ] **Step 5: Commit topics.json and validate.js together**

```bash
git add tools/gamegen/topics.json tools/gamegen/validate.js
git commit -m "fix(gamegen): reconcile topics.json with bespoke engines, add bespoke-aware validation"
```

---

### Task 5: Regenerate the catalog and verify it's lossless

**Files:**
- Modify (generated): `lib/core/constants/game_catalog.dart`

**Interfaces:**
- Consumes: the reconciled `topics.json` from Task 4.
- Produces: a `game_catalog.dart` that (a) is byte-for-byte equivalent to the current one for all 54 bespoke topics and all Grade 7 topics, and (b) additionally contains the 5 restored Grade 1 Life Skills entries.

This is the critical safety check for the whole reconciliation — it proves the fix is lossless before anything downstream (like the Phase 14 Grade 2 plan) builds on top of it.

- [ ] **Step 1: Snapshot the current catalog for comparison**

Run: `cp lib/core/constants/game_catalog.dart /tmp/game_catalog_before.dart` (or, on Windows/PowerShell semantics via the Bash tool's POSIX shell, `cp` works as shown — the repo is accessed through a Bash tool with a POSIX shell per this project's tooling).

- [ ] **Step 2: Regenerate**

Run: `cd tools/gamegen && npm run generate`
Expected: exits 0.

- [ ] **Step 3: Diff and verify**

Run: `diff /tmp/game_catalog_before.dart lib/core/constants/game_catalog.dart | head -200`
Expected: the **only** differences are (a) 5 new `GameCatalogEntry(...)` blocks for `ls_g1_body`, `ls_g1_feelings`, `ls_g1_safety`, `ls_g1_community`, `ls_g1_habits` appearing (restored), and (b) possibly harmless formatting/ordering differences from `generate.js`'s own formatter. There must be **no** changes to any `engineType:`, `description:`, `learningObjective:`, or `mechanicReason:` line for any of the 54 bespoke topics or any of the 61 Grade 7 topics. If any such change appears, stop — it means Task 2 or Task 4's gating logic has a gap — and fix it before proceeding (do not proceed with a lossy regeneration).

- [ ] **Step 4: Confirm the 5 restored entries are wired correctly**

Run: `grep -A5 "id: 'ls_g1_body'" lib/core/constants/game_catalog.dart`
Expected: shows `grade: 'grade1'`, `grades: ['grade1', 'grade2', 'grade3']`, `subject: 'Life Skills'`, `engineType: 'adventureJourney'` — i.e. restored exactly as it existed before the migration deleted it (this is Task 5 of the separate Grade 2 content plan's concern for narrowing `grade2` out of this array — not this plan's job; leave it as `['grade1','grade2','grade3']` here).

- [ ] **Step 5: Commit**

```bash
git add lib/core/constants/game_catalog.dart
git commit -m "chore(gamegen): regenerate catalog — restores 5 orphaned Grade 1 Life Skills topics"
```

---

### Task 6: Flutter-side verification

**Files:** none modified (verification only).

- [ ] **Step 1: flutter analyze**

Run: `flutter analyze`
Expected: 0 errors.

- [ ] **Step 2: flutter test**

Run: `flutter test`
Expected: all green, specifically including `test/catalog/game_catalog_invariants_test.dart` (checks the 40%/≥3-engines/≥5-runnerCollector/registered-engine invariants against the regenerated `GameCatalog.all` — should still pass since the bespoke topics' `engineType` values are unchanged from before regeneration) and `test/games/all_topics_smoke_test.dart` (checks every topic's content pack exists and parses — the 5 restored Life Skills topics use the shared `adventureJourney`/`explorerMap`/`runnerCollector`/`tugOfWar` engines and go through that test's normal, non-bespoke-carve-out path, exactly as they did before the migration deleted them).

- [ ] **Step 3: If Task 6 Step 2 fails**

Read the exact failure. If it's in `all_topics_smoke_test.dart` for one of the 5 restored Life Skills topics, check whether its `assets/content/ls_g1_*.json` pack still exists and is schema-valid for its engine (it was never deleted — only the catalog entry was — so it should still pass unmodified). If it fails elsewhere, treat it as a signal that something in Tasks 1-5 has a gap and fix the root cause rather than adjusting the test.

---

### Task 7: Manual verification in the running app

- [ ] **Step 1: Launch**

Run: `flutter run -d chrome`
Expected: boots to login with no red screen.

- [ ] **Step 2: Verify Grade 1**

Sign in as a Grade 1 learner. Confirm all 10 original Mathematics/English games still work (bespoke ones: Addition Adventure, Subtraction Safari, Maths Mountain, Multiple Chain, Alphabet Explorer, Word Builder, Phonics Fun, Reading Rainbow, Grammar Garden; shared: Number Counting Duel) **and** all 5 Life Skills games are back (My Body, My Community, Feelings Factory, Healthy Habits, Safety Squad).

- [ ] **Step 3: Verify Grade 4 and Grade 7 unaffected**

Spot-check 2-3 Grade 4 bespoke games (e.g. Fraction Forest, Debate Duel) and 2-3 Grade 7 shared-engine games (e.g. Apartheid Era, one EMS budgeting game) — all should play exactly as they did before this reconciliation.

---

### Task 8: Update DEFERRED.md and close out

**Files:**
- Modify: `docs/DEFERRED.md`

- [ ] **Step 1: Add a note documenting the stale bespoke content packs**

Append a section noting that `assets/content/*.json` packs for the 54 bespoke topics are stale leftovers from before the migration (unread by the bespoke widgets, kept only because the Dart smoke test requires the file to exist and parse) — future cleanup could either delete their now-unused engine-specific fields down to a minimal stub, or repurpose them as designed data if the bespoke widgets are ever refactored to read from packs. Not required for this phase; noted for future reference so nobody is confused finding a `"engine": "tugOfWar"` pack backing an `additionAdventure` topic.

- [ ] **Step 2: Final full verification sweep**

Run: `cd tools/gamegen && npm run validate && cd ../.. && flutter analyze && flutter test`
Expected: all green.

- [ ] **Step 3: Commit**

```bash
git add docs/DEFERRED.md
git commit -m "docs: note stale bespoke content packs as a future cleanup item"
```

---

## Note for Phase 14 (Grade 2 content plan)

Once this plan's Task 5 is complete, `docs/superpowers/plans/2026-08-01-phase14-grade2-curriculum-content.md` is safe to execute as originally written — it only ever adds new Grade 2 entries and narrows the existing Grade 1 `grades` arrays for the 10 topics that are still classify.js-visible shared-model or bespoke topics (its Task 5 touches all 15 original Grade 1 ids by id, including the 5 restored Life Skills ones — cross-check that plan's Task 5 ids against this plan's Task 5 Step 4 output once both are done, since that plan was written assuming all 15 Grade 1 topics were still present).
