# Phase 14 — Grade 2 Curriculum Content Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give Grade 2 learners their own CAPS-appropriate difficulty band and 15 dedicated catalog entries (English, Life Skills, Mathematics — the three Foundation Phase subjects), replacing today's silent hand-me-down of Grade 1's exact content/difficulty to Grade 2 via the `grades: ['grade1','grade2','grade3']` catalog filter.

**Architecture:** Follow the existing `tools/gamegen` pipeline exactly (`topics.json` is the single source of truth → `generate.js` builds `lib/core/constants/game_catalog.dart` and content-pack scaffolds → `author.js` fills real content into the scaffolds from per-engine content modules → `validate.js` is the mandatory gate). No changes to `GameEngine`/`GameSession`/`GameRouter` widget code, no new engines — Grade 2 topics reuse the same 9 engines and the same `topicId`/`subtopicId` pairs as their Grade 1 counterparts (CAPS is a spiral curriculum: the same skill areas recur every year at increasing difficulty), so `classify.js`'s existing `BY_TOPIC_KEY` table needs zero changes.

**Tech Stack:** Node 18+ (zero deps) for `tools/gamegen`, Dart/Flutter for the generated catalog and app.

## Global Constraints

- `flutter analyze` → 0 errors before any commit (pre-existing info-lints tolerated).
- `flutter test` → all green.
- `npm run validate` (from `tools/gamegen/`) → 0 invariant failures — this is the content pipeline's own mandatory gate.
- Never hand-edit `lib/core/constants/game_catalog.dart` or `assets/content/*.json` — edit `tools/gamegen/topics.json` (and the relevant `tools/gamegen/content/*.js` module) and regenerate.
- Do not delete or rename any existing `<engine>/` folder or any existing Grade 1/4/7 topic (`CLAUDE.md` §7 DO NOT TOUCH).
- Catalog invariants (`CLAUDE.md` §4) must hold after every `topics.json` edit: every `engineType` has a `GameRouter` arm (unchanged — no new engines), `adventureJourney`+`tugOfWar` ≤ 40% of all entries, every subject uses ≥ 3 distinct engines, every entry has non-empty `learningObjective`-equivalent (`capsObjective`) and `mechanicReason`.
- Child-facing copy: South African context where relevant (e.g. `10111` emergency number, "robot" for traffic light), no profanity, no external links, large-touch-target-friendly short sentences.
- Commit style: `type(scope): summary`, small reviewable commits, `flutter analyze` clean before each.

---

### Task 1: Add Grade 2/3/5/6 difficulty bands

**Files:**
- Modify: `tools/gamegen/difficulty.js`

**Interfaces:**
- Produces: `BANDS.grade2`, `BANDS.grade3`, `BANDS.grade5`, `BANDS.grade6` — consumed by `validate.js`'s `bandFor()` check and by Task 2–4's `topics.json` entries (their `difficulty` object must match the band for their `grade` field exactly, field-for-field, or `validate.js` invariant #9 fails).

Only `grade2` is consumed by this phase; `grade3`/`grade5`/`grade6` are added now (pure data, zero risk to existing entries) so Phases 15–17 can reuse them without touching this file again. Values are a smooth interpolation between the existing `grade1`/`grade4`/`grade7` bands, keeping Foundation Phase (grade1–3) untimed per the existing `grade1` comment ("Foundation Phase learners aren't rushed"):

- [ ] **Step 1: Add the four new bands**

Replace the `BANDS` object in `tools/gamegen/difficulty.js`:

```javascript
'use strict';

/**
 * Difficulty bands, one per grade CAPS band this catalog uses. grade1/4/7
 * are the original representative bands (Foundation / Intermediate /
 * Senior); grade2/3/5/6 fill in the remaining grades with a smooth
 * interpolation between their phase's anchor grades. See CLAUDE.md gamegen
 * Phase A §4 and docs/superpowers/plans/2026-08-01-phase14-grade2-curriculum-content.md.
 */
const BANDS = {
  grade1: {
    numberRange: { min: 1, max: 20 },
    timerSec: null, // none/long — Foundation Phase learners aren't rushed
    steps: { min: 3, max: 4 },
    lives: 5,
    readingLevel: 'emergent',
    fractionsDecimals: false,
  },
  grade2: {
    numberRange: { min: 1, max: 100 },
    timerSec: null, // still untimed — Foundation Phase (grade1-3)
    steps: { min: 4, max: 5 },
    lives: 5,
    readingLevel: 'developing',
    fractionsDecimals: false,
  },
  grade3: {
    numberRange: { min: 1, max: 999 },
    timerSec: null, // still untimed — Foundation Phase (grade1-3)
    steps: { min: 5, max: 6 },
    lives: 4,
    readingLevel: 'developing',
    fractionsDecimals: false,
  },
  grade4: {
    numberRange: { min: 1, max: 1000 },
    timerSec: 20, // moderate
    steps: { min: 5, max: 6 },
    lives: 3,
    readingLevel: 'intermediate',
    fractionsDecimals: false,
  },
  grade5: {
    numberRange: { min: 1, max: 10000 },
    timerSec: 15,
    steps: { min: 6, max: 7 },
    lives: 3,
    readingLevel: 'intermediate',
    fractionsDecimals: true,
  },
  grade6: {
    numberRange: { min: 1, max: 50000 },
    timerSec: 12,
    steps: { min: 6, max: 8 },
    lives: 3,
    readingLevel: 'fluent',
    fractionsDecimals: true,
  },
  grade7: {
    numberRange: { min: 1, max: 100000 },
    timerSec: 10, // tight
    steps: { min: 7, max: 8 },
    lives: 3,
    readingLevel: 'fluent',
    fractionsDecimals: true,
  },
};

function bandFor(grade) {
  const band = BANDS[grade];
  if (!band) throw new Error(`No difficulty band defined for grade "${grade}"`);
  return band;
}

module.exports = { BANDS, bandFor };
```

- [ ] **Step 2: Sanity-check with node**

Run: `node -e "console.log(require('./tools/gamegen/difficulty').bandFor('grade2'))"` from the repo root.
Expected: prints the grade2 band object with no error.

- [ ] **Step 3: Commit**

```bash
git add tools/gamegen/difficulty.js
git commit -m "feat(gamegen): add grade2/3/5/6 difficulty bands"
```

---

### Task 2: Add 5 Grade 2 English topics to `topics.json`

**Files:**
- Modify: `tools/gamegen/topics.json`

**Interfaces:**
- Consumes: `BANDS.grade2` from Task 1 (the `difficulty` object below is that band verbatim).
- Produces: 5 new topic records that Task 6 (`npm run generate`) turns into `game_catalog.dart` entries + content-pack scaffolds, and that Task 7–9 (`author.js` content modules) fill with real content, keyed by these exact `id`s: `eng_g2_alphabet`, `eng_g2_grammar`, `eng_g2_phonics`, `eng_g2_reading`, `eng_g2_words`.

Each mirrors its Grade 1 counterpart's `topicId`/`subtopicId`/`engine`/`cognitiveVerb` exactly (CAPS spiral curriculum — same skill area, harder content), so `classify.js` needs no changes. `sourceOrder` must be assigned after computing the current max — do not hardcode a guess:

- [ ] **Step 1: Compute the next available `sourceOrder`**

Run from `tools/gamegen/`: `node -e "console.log(Math.max(...require('./topics.json').map(t=>t.sourceOrder)))"`
Note the printed value as `MAX`. The 15 new entries across Tasks 2–4 use `MAX+1` through `MAX+15`, assigned in the order the entries appear below (English first, then Life Skills, then Mathematics).

- [ ] **Step 2: Insert the 5 English entries**

Add these 5 objects to the top-level array in `tools/gamegen/topics.json` (anywhere in the array — order doesn't affect `generate.js`, only `sourceOrder` does). Replace `MAX+1`..`MAX+5` with the actual computed integers from Step 1:

```json
{
  "id": "eng_g2_alphabet",
  "title": "Sight Word Safari",
  "description": "Recognise common sight words and blend longer letter sounds!",
  "grade": "grade2",
  "grades": ["grade2"],
  "subject": "English",
  "topicId": "phonics",
  "subtopicId": "alphabet",
  "engine": "adventureJourney",
  "emoji": "🔤",
  "colorExpr": "AppColors.english",
  "capsObjective": "Learners will recognise common sight words and blend longer letter sounds.",
  "mechanicReason": "Making choices through a story connects sight words to real situations you can relate to.",
  "cognitiveVerb": "narrative_comprehension",
  "difficulty": {
    "label": "easy",
    "numberRange": { "min": 1, "max": 100 },
    "timerSec": null,
    "steps": { "min": 4, "max": 5 },
    "lives": 5,
    "readingLevel": "developing",
    "fractionsDecimals": false
  },
  "xpReward": 65,
  "coinsReward": 13,
  "isNew": true,
  "isFeatured": true,
  "contentPack": "assets/content/eng_g2_alphabet.json",
  "sourceOrder": "MAX+1"
},
{
  "id": "eng_g2_grammar",
  "title": "Grammar Garden: Level 2",
  "description": "Plant nouns, verbs, adjectives — and now pronouns too — in the right spot!",
  "grade": "grade2",
  "grades": ["grade2"],
  "subject": "English",
  "topicId": "grammar",
  "subtopicId": "parts_of_speech",
  "engine": "runnerCollector",
  "emoji": "🌻",
  "colorExpr": "AppColors.english",
  "capsObjective": "Learners will plant nouns, verbs, adjectives and pronouns in the sentence.",
  "mechanicReason": "Sorting the right answers on the run trains you to quickly tell parts of speech apart.",
  "cognitiveVerb": "word_classify",
  "difficulty": {
    "label": "medium",
    "numberRange": { "min": 1, "max": 100 },
    "timerSec": null,
    "steps": { "min": 4, "max": 5 },
    "lives": 5,
    "readingLevel": "developing",
    "fractionsDecimals": false
  },
  "xpReward": 90,
  "coinsReward": 18,
  "isNew": true,
  "isFeatured": false,
  "contentPack": "assets/content/eng_g2_grammar.json",
  "sourceOrder": "MAX+2"
},
{
  "id": "eng_g2_phonics",
  "title": "Phonics Fun: Blends & Digraphs",
  "description": "Blend consonant clusters and digraphs to read trickier words!",
  "grade": "grade2",
  "grades": ["grade2"],
  "subject": "English",
  "topicId": "phonics",
  "subtopicId": "blending",
  "engine": "tugOfWar",
  "emoji": "🎵",
  "colorExpr": "AppColors.english",
  "capsObjective": "Learners will blend consonant clusters and digraphs to decode and read words.",
  "mechanicReason": "Answering fast head-to-head builds quick, confident recall of blending.",
  "cognitiveVerb": "rapid_recall",
  "difficulty": {
    "label": "easy",
    "numberRange": { "min": 1, "max": 100 },
    "timerSec": null,
    "steps": { "min": 4, "max": 5 },
    "lives": 5,
    "readingLevel": "developing",
    "fractionsDecimals": false
  },
  "xpReward": 65,
  "coinsReward": 13,
  "isNew": true,
  "isFeatured": false,
  "contentPack": "assets/content/eng_g2_phonics.json",
  "sourceOrder": "MAX+3"
},
{
  "id": "eng_g2_reading",
  "title": "Reading Rainbow: Level 2",
  "description": "Read short paragraphs and answer 'who, what, where, why' questions!",
  "grade": "grade2",
  "grades": ["grade2"],
  "subject": "English",
  "topicId": "reading",
  "subtopicId": "comprehension",
  "engine": "adventureJourney",
  "emoji": "🌈",
  "colorExpr": "AppColors.english",
  "capsObjective": "Learners will read short paragraphs and answer who/what/where/why comprehension questions.",
  "mechanicReason": "Making choices through a story connects comprehension to real situations you can relate to.",
  "cognitiveVerb": "narrative_comprehension",
  "difficulty": {
    "label": "medium",
    "numberRange": { "min": 1, "max": 100 },
    "timerSec": null,
    "steps": { "min": 4, "max": 5 },
    "lives": 5,
    "readingLevel": "developing",
    "fractionsDecimals": false
  },
  "xpReward": 90,
  "coinsReward": 18,
  "isNew": true,
  "isFeatured": false,
  "contentPack": "assets/content/eng_g2_reading.json",
  "sourceOrder": "MAX+4"
},
{
  "id": "eng_g2_words",
  "title": "Word Builder: Level 2",
  "description": "Spell longer CVC and CVCC words by choosing the right letters!",
  "grade": "grade2",
  "grades": ["grade2"],
  "subject": "English",
  "topicId": "spelling",
  "subtopicId": "cvc_words",
  "engine": "sequenceBuilder",
  "emoji": "📝",
  "colorExpr": "AppColors.english",
  "capsObjective": "Learners will spell longer CVC and CVCC words by choosing the right letters.",
  "mechanicReason": "Putting the steps in the right order breaks cvc words into stages you can follow one by one.",
  "cognitiveVerb": "order_sequence",
  "difficulty": {
    "label": "easy",
    "numberRange": { "min": 1, "max": 100 },
    "timerSec": null,
    "steps": { "min": 4, "max": 5 },
    "lives": 5,
    "readingLevel": "developing",
    "fractionsDecimals": false
  },
  "xpReward": 65,
  "coinsReward": 13,
  "isNew": true,
  "isFeatured": false,
  "contentPack": "assets/content/eng_g2_words.json",
  "sourceOrder": "MAX+5"
}
```

- [ ] **Step 3: Validate JSON syntax**

Run: `node -e "JSON.parse(require('fs').readFileSync('tools/gamegen/topics.json','utf8')); console.log('valid json')"` from the repo root.
Expected: `valid json` with no error.

---

### Task 3: Add 5 Grade 2 Life Skills topics to `topics.json`

**Files:**
- Modify: `tools/gamegen/topics.json`

**Interfaces:**
- Consumes: `MAX` from Task 2 Step 1; `BANDS.grade2` from Task 1.
- Produces: 5 records keyed `ls_g2_body`, `ls_g2_community`, `ls_g2_feelings`, `ls_g2_habits`, `ls_g2_safety` — consumed by Task 7 (facts.js), Task 10 (explorer_map.js).

- [ ] **Step 1: Insert the 5 Life Skills entries**

Add to the same array, using `sourceOrder` `MAX+6`..`MAX+10`:

```json
{
  "id": "ls_g2_body",
  "title": "My Body: Level 2",
  "description": "Learn how your body systems work together to keep you healthy!",
  "grade": "grade2",
  "grades": ["grade2"],
  "subject": "Life Skills",
  "topicId": "personal_care",
  "subtopicId": "body_parts",
  "engine": "adventureJourney",
  "emoji": "🧍",
  "colorExpr": "AppColors.lifeSkills",
  "capsObjective": "Learners will learn how their body systems work together to keep them healthy.",
  "mechanicReason": "Making choices through a story connects body systems to real situations you can relate to.",
  "cognitiveVerb": "narrative_comprehension",
  "difficulty": {
    "label": "easy",
    "numberRange": { "min": 1, "max": 100 },
    "timerSec": null,
    "steps": { "min": 4, "max": 5 },
    "lives": 5,
    "readingLevel": "developing",
    "fractionsDecimals": false
  },
  "xpReward": 65,
  "coinsReward": 13,
  "isNew": true,
  "isFeatured": false,
  "contentPack": "assets/content/ls_g2_body.json",
  "sourceOrder": "MAX+6"
},
{
  "id": "ls_g2_community",
  "title": "My Community: Level 2",
  "description": "Discover more community helpers and the tools they use to help us!",
  "grade": "grade2",
  "grades": ["grade2"],
  "subject": "Life Skills",
  "topicId": "beginning_knowledge",
  "subtopicId": "community_helpers",
  "engine": "explorerMap",
  "emoji": "🏘️",
  "colorExpr": "AppColors.lifeSkills",
  "capsObjective": "Learners will discover more community helpers and the tools they use to help us.",
  "mechanicReason": "Exploring a map connects community helpers to real places, so it sticks.",
  "cognitiveVerb": "locate_map",
  "difficulty": {
    "label": "easy",
    "numberRange": { "min": 1, "max": 100 },
    "timerSec": null,
    "steps": { "min": 4, "max": 5 },
    "lives": 5,
    "readingLevel": "developing",
    "fractionsDecimals": false
  },
  "xpReward": 65,
  "coinsReward": 13,
  "isNew": true,
  "isFeatured": false,
  "contentPack": "assets/content/ls_g2_community.json",
  "sourceOrder": "MAX+7"
},
{
  "id": "ls_g2_feelings",
  "title": "Feelings Factory: Level 2",
  "description": "Tell apart more feelings and learn healthy ways to handle each one!",
  "grade": "grade2",
  "grades": ["grade2"],
  "subject": "Life Skills",
  "topicId": "social_skills",
  "subtopicId": "emotions",
  "engine": "runnerCollector",
  "emoji": "😊",
  "colorExpr": "AppColors.lifeSkills",
  "capsObjective": "Learners will tell apart more feelings and learn healthy ways to handle each one.",
  "mechanicReason": "Sorting the right answers on the run trains you to quickly tell emotions apart.",
  "cognitiveVerb": "word_classify",
  "difficulty": {
    "label": "easy",
    "numberRange": { "min": 1, "max": 100 },
    "timerSec": null,
    "steps": { "min": 4, "max": 5 },
    "lives": 5,
    "readingLevel": "developing",
    "fractionsDecimals": false
  },
  "xpReward": 65,
  "coinsReward": 13,
  "isNew": true,
  "isFeatured": false,
  "contentPack": "assets/content/ls_g2_feelings.json",
  "sourceOrder": "MAX+8"
},
{
  "id": "ls_g2_habits",
  "title": "Healthy Habits: Level 2",
  "description": "Build stronger habits around hygiene, nutrition, sleep and exercise!",
  "grade": "grade2",
  "grades": ["grade2"],
  "subject": "Life Skills",
  "topicId": "health",
  "subtopicId": "healthy_habits",
  "engine": "tugOfWar",
  "emoji": "🥗",
  "colorExpr": "AppColors.lifeSkills",
  "capsObjective": "Learners will build stronger habits around hygiene, nutrition, sleep and exercise.",
  "mechanicReason": "Answering fast head-to-head builds quick, confident recall of healthy habits.",
  "cognitiveVerb": "rapid_recall",
  "difficulty": {
    "label": "easy",
    "numberRange": { "min": 1, "max": 100 },
    "timerSec": null,
    "steps": { "min": 4, "max": 5 },
    "lives": 5,
    "readingLevel": "developing",
    "fractionsDecimals": false
  },
  "xpReward": 65,
  "coinsReward": 13,
  "isNew": true,
  "isFeatured": false,
  "contentPack": "assets/content/ls_g2_habits.json",
  "sourceOrder": "MAX+9"
},
{
  "id": "ls_g2_safety",
  "title": "Safety Squad: Level 2",
  "description": "Learn safety rules for the road, water and being home alone!",
  "grade": "grade2",
  "grades": ["grade2"],
  "subject": "Life Skills",
  "topicId": "safety",
  "subtopicId": "personal_safety",
  "engine": "adventureJourney",
  "emoji": "🛡️",
  "colorExpr": "AppColors.lifeSkills",
  "capsObjective": "Learners will learn safety rules for the road, water and being home alone.",
  "mechanicReason": "Making choices through a story connects personal safety to real situations you can relate to.",
  "cognitiveVerb": "narrative_comprehension",
  "difficulty": {
    "label": "easy",
    "numberRange": { "min": 1, "max": 100 },
    "timerSec": null,
    "steps": { "min": 4, "max": 5 },
    "lives": 5,
    "readingLevel": "developing",
    "fractionsDecimals": false
  },
  "xpReward": 65,
  "coinsReward": 13,
  "isNew": true,
  "isFeatured": false,
  "contentPack": "assets/content/ls_g2_safety.json",
  "sourceOrder": "MAX+10"
}
```

- [ ] **Step 2: Validate JSON syntax**

Run: `node -e "JSON.parse(require('fs').readFileSync('tools/gamegen/topics.json','utf8')); console.log('valid json')"`
Expected: `valid json`.

---

### Task 4: Add 5 Grade 2 Mathematics topics to `topics.json`

**Files:**
- Modify: `tools/gamegen/topics.json`

**Interfaces:**
- Consumes: `MAX` from Task 2 Step 1; `BANDS.grade2` from Task 1.
- Produces: 5 records keyed `math_g2_addition`, `math_g2_counting`, `math_g2_mountain`, `math_g2_multiples`, `math_g2_subtraction`. `math_g2_addition`/`math_g2_counting`/`math_g2_subtraction` need **no** new content-module code — `tools/gamegen/content/math.js`'s `isMathTopic()`/`generateMathItems()` derive purely from `topicId`/`subtopicId` (already classified) and `difficulty.numberRange` (set below), so `author.js` generates their items procedurally for free.

- [ ] **Step 1: Insert the 5 Mathematics entries**

Add to the same array, using `sourceOrder` `MAX+11`..`MAX+15`:

```json
{
  "id": "math_g2_addition",
  "title": "Addition Adventure: Level 2",
  "description": "Solve addition sums up to 100 and collect stars!",
  "grade": "grade2",
  "grades": ["grade2"],
  "subject": "Mathematics",
  "topicId": "operations",
  "subtopicId": "addition",
  "engine": "tugOfWar",
  "emoji": "➕",
  "colorExpr": "AppColors.math",
  "capsObjective": "Learners will solve addition sums up to 100 and collect stars.",
  "mechanicReason": "Answering fast head-to-head builds quick, confident recall of addition.",
  "cognitiveVerb": "rapid_recall",
  "difficulty": {
    "label": "easy",
    "numberRange": { "min": 1, "max": 100 },
    "timerSec": null,
    "steps": { "min": 4, "max": 5 },
    "lives": 5,
    "readingLevel": "developing",
    "fractionsDecimals": false
  },
  "xpReward": 65,
  "coinsReward": 13,
  "isNew": true,
  "isFeatured": false,
  "contentPack": "assets/content/math_g2_addition.json",
  "sourceOrder": "MAX+11"
},
{
  "id": "math_g2_counting",
  "title": "Number Counting Duel: Level 2",
  "description": "Count and compare numbers up to 100, and start skip-counting by 2s, 5s and 10s!",
  "grade": "grade2",
  "grades": ["grade2"],
  "subject": "Mathematics",
  "topicId": "numbers",
  "subtopicId": "counting",
  "engine": "numberCountingDuel",
  "emoji": "🔢",
  "colorExpr": "AppColors.math",
  "capsObjective": "Learners will count and compare numbers up to 100 and skip-count by 2s, 5s and 10s.",
  "mechanicReason": "Racing to count and compare builds fast, confident number sense for counting.",
  "cognitiveVerb": "count_compare",
  "difficulty": {
    "label": "easy",
    "numberRange": { "min": 1, "max": 100 },
    "timerSec": null,
    "steps": { "min": 4, "max": 5 },
    "lives": 5,
    "readingLevel": "developing",
    "fractionsDecimals": false
  },
  "xpReward": 65,
  "coinsReward": 13,
  "isNew": true,
  "isFeatured": true,
  "contentPack": "assets/content/math_g2_counting.json",
  "sourceOrder": "MAX+12"
},
{
  "id": "math_g2_mountain",
  "title": "Maths Mountain: Level 2",
  "description": "Climb higher by solving addition, subtraction and early multiplication facts!",
  "grade": "grade2",
  "grades": ["grade2"],
  "subject": "Mathematics",
  "topicId": "operations",
  "subtopicId": "mixed_operations",
  "engine": "sequenceBuilder",
  "emoji": "⛰️",
  "colorExpr": "AppColors.math",
  "capsObjective": "Learners will climb higher by solving addition, subtraction and early multiplication facts.",
  "mechanicReason": "Putting the steps in the right order breaks mixed operations into stages you can follow one by one.",
  "cognitiveVerb": "order_sequence",
  "difficulty": {
    "label": "medium",
    "numberRange": { "min": 1, "max": 100 },
    "timerSec": null,
    "steps": { "min": 4, "max": 5 },
    "lives": 5,
    "readingLevel": "developing",
    "fractionsDecimals": false
  },
  "xpReward": 90,
  "coinsReward": 18,
  "isNew": true,
  "isFeatured": false,
  "contentPack": "assets/content/math_g2_mountain.json",
  "sourceOrder": "MAX+13"
},
{
  "id": "math_g2_multiples",
  "title": "Multiple Chain: Level 2",
  "description": "Link the multiples of 2, 5 and 10 to make a chain — break it and try again!",
  "grade": "grade2",
  "grades": ["grade2"],
  "subject": "Mathematics",
  "topicId": "multiplication",
  "subtopicId": "multiples",
  "engine": "multiplesMerge",
  "emoji": "🔗",
  "colorExpr": "AppColors.math",
  "capsObjective": "Learners will link the multiples of 2, 5 and 10 to make a chain.",
  "mechanicReason": "Matching and merging pairs helps you spot patterns and connections in multiples.",
  "cognitiveVerb": "count_compare",
  "difficulty": {
    "label": "medium",
    "numberRange": { "min": 1, "max": 100 },
    "timerSec": null,
    "steps": { "min": 4, "max": 5 },
    "lives": 5,
    "readingLevel": "developing",
    "fractionsDecimals": false
  },
  "xpReward": 90,
  "coinsReward": 18,
  "isNew": true,
  "isFeatured": false,
  "contentPack": "assets/content/math_g2_multiples.json",
  "sourceOrder": "MAX+14"
},
{
  "id": "math_g2_subtraction",
  "title": "Subtraction Safari: Level 2",
  "description": "Hunt for the missing number in subtraction problems up to 100!",
  "grade": "grade2",
  "grades": ["grade2"],
  "subject": "Mathematics",
  "topicId": "operations",
  "subtopicId": "subtraction",
  "engine": "tugOfWar",
  "emoji": "➖",
  "colorExpr": "AppColors.math",
  "capsObjective": "Learners will hunt for the missing number in subtraction problems up to 100.",
  "mechanicReason": "Answering fast head-to-head builds quick, confident recall of subtraction.",
  "cognitiveVerb": "rapid_recall",
  "difficulty": {
    "label": "easy",
    "numberRange": { "min": 1, "max": 100 },
    "timerSec": null,
    "steps": { "min": 4, "max": 5 },
    "lives": 5,
    "readingLevel": "developing",
    "fractionsDecimals": false
  },
  "xpReward": 65,
  "coinsReward": 13,
  "isNew": true,
  "isFeatured": false,
  "contentPack": "assets/content/math_g2_subtraction.json",
  "sourceOrder": "MAX+15"
}
```

- [ ] **Step 2: Validate JSON syntax**

Run: `node -e "JSON.parse(require('fs').readFileSync('tools/gamegen/topics.json','utf8')); console.log('valid json')"`
Expected: `valid json`.

- [ ] **Step 3: Commit Tasks 2-4**

```bash
git add tools/gamegen/topics.json
git commit -m "feat(gamegen): add 15 Grade 2 topics (English, Life Skills, Mathematics)"
```

---

### Task 5: Narrow the 15 Grade 1 entries' `grades` arrays

**Files:**
- Modify: `tools/gamegen/topics.json`

**Interfaces:**
- Consumes: nothing new.
- Produces: the 15 existing `*_g1_*` records now stop being served to Grade 2 learners (Grade 2 has its own entries from Tasks 2-4) while continuing to be served to Grade 3 learners (unchanged — Grade 3 still gets no dedicated entries until Phase 15, so removing its hand-me-down now would be a regression, not an improvement).

This is a **required companion change** to Tasks 2-4: without it, `lib/core/constants/game_catalog.dart`'s `catalogForGrade()` filter (`e.grades.contains(grade)`) would show a Grade 2 learner **both** the old Grade-1-difficulty entry and the new Grade-2-difficulty entry for the same topic (e.g. two different "Addition Adventure" cards), which is confusing and not what any user asked for.

- [ ] **Step 1: Edit all 15 `grades` arrays**

In `tools/gamegen/topics.json`, for each of these 15 ids, change `"grades": ["grade1", "grade2", "grade3"]` to `"grades": ["grade1", "grade3"]` (drop `"grade2"` only, keep `"grade1"` and `"grade3"`):

```
eng_g1_alphabet, eng_g1_grammar, eng_g1_phonics, eng_g1_reading, eng_g1_words,
ls_g1_body, ls_g1_community, ls_g1_feelings, ls_g1_habits, ls_g1_safety,
math_g1_addition, math_g1_counting, math_g1_mountain, math_g1_multiples, math_g1_subtraction
```

Do not change any other field on these 15 records (title, difficulty, content, xpReward, etc. all stay exactly as-is — Grade 1 and Grade 3 learners' experience must not change).

- [ ] **Step 2: Verify exactly 15 edits landed**

Run: `git diff tools/gamegen/topics.json | grep -c '"grade2",'`
Expected: `0` (every removed `"grade2",` line should be a pure removal, so the diff shows 15 `-      "grade2",` lines and 0 remaining `+` lines containing `"grade2",` inside a `grades` array — spot-check a couple of the 15 entries by eye to confirm `grade3` is still present).

- [ ] **Step 3: Commit**

```bash
git add tools/gamegen/topics.json
git commit -m "fix(gamegen): stop serving Grade 1 content as a Grade 2 hand-me-down"
```

---

### Task 6: Regenerate the catalog and confirm the expected failures ("red" step)

**Files:**
- Modify (generated, do not hand-edit): `lib/core/constants/game_catalog.dart`
- Creates (scaffolds): 15 new files under `assets/content/*_g2_*.json`

**Interfaces:**
- Consumes: `topics.json` from Tasks 2-5.
- Produces: `game_catalog.dart` with 15 new `GameCatalogEntry` objects (consumed by `GameRouter` and every dashboard/grade-filter screen automatically — no Dart code changes needed since `catalogForGrade()` already filters generically by `grades.contains(grade)`).

- [ ] **Step 1: Run generate**

Run: `cd tools/gamegen && npm run generate`
Expected: exits 0, prints how many topics were processed, and reports 15 new scaffold content packs written (or similar — read the actual output).

- [ ] **Step 2: Run validate and confirm it fails for the expected reason**

Run: `cd tools/gamegen && npm run validate`
Expected: **non-zero exit**, with failures specifically about the 15 new content packs still being unauthored scaffolds (`_scaffold: true` warning and/or schema `min items` failures for `eng_g2_*`, `ls_g2_*`, `math_g2_*`) — NOT about duplicate ids, engine/cognitiveVerb mismatches, the 40% reskin cap, or any subject having < 3 engines. If any *other* invariant fails, stop and fix `topics.json` before continuing (it means a Task 2-5 entry has a typo).

This is the plan's "red" checkpoint: it confirms the wiring (ids, engine assignment, difficulty-band matching, catalog structure) is correct *before* any content is authored.

- [ ] **Step 3: flutter analyze on the regenerated catalog**

Run: `flutter analyze lib/core/constants/game_catalog.dart`
Expected: 0 errors (the generated Dart is well-formed).

---

### Task 7: Author the 4 `adventureJourney` Grade 2 content banks

**Files:**
- Modify: `tools/gamegen/content/facts.js`

**Interfaces:**
- Consumes: `t.id` lookups from `author.js`'s `bodyFor()` (`facts.ADVENTURE_JOURNEY[t.id]`), turned into stages via `facts.toJourneyStages(t.id, bank, {emoji, colorHex})`.
- Produces: 4 new `ADVENTURE_JOURNEY` entries, each a `{q, a}` array of 15 items (safe margin above both the 10-item Tier B and 15-item Tier A minimum, regardless of which tier `computeTiers()` assigns these `sourceOrder` values to).

- [ ] **Step 1: Add the 4 entries to the `ADVENTURE_JOURNEY` object**

Find the `ADVENTURE_JOURNEY` object in `tools/gamegen/content/facts.js` (it already contains `ls_g1_body`, `ls_g1_safety`, etc. — add these alongside the existing entries, matching the existing `{ q, a }` shape exactly):

```javascript
  eng_g2_alphabet: [
    { q: 'What word do you get if you blend s-t-o-p?', a: 'stop' },
    { q: "What is a 'sight word'?", a: 'A word you learn to read by memory, not by sounding out' },
    { q: "Read this sight word: 'the'.", a: 'the' },
    { q: "Read this sight word: 'was'.", a: 'was' },
    { q: 'Blend fl-a-g together. What word do you get?', a: 'flag' },
    { q: "What sound do the letters 'sh' make together?", a: '/sh/' },
    { q: "Read this sight word: 'said'.", a: 'said' },
    { q: 'Blend s-t-a-r together. What word do you get?', a: 'star' },
    { q: "What sound do the letters 'ch' make together?", a: '/ch/' },
    { q: "Read this sight word: 'they'.", a: 'they' },
    { q: 'Blend bl-o-ck together. What word do you get?', a: 'block' },
    { q: "What sound do the letters 'th' make together?", a: '/th/' },
    { q: "Read this sight word: 'have'.", a: 'have' },
    { q: 'Blend gr-a-ss together. What word do you get?', a: 'grass' },
    { q: "Read this sight word: 'you'.", a: 'you' },
  ],
  eng_g2_reading: [
    { q: 'In a story about a boy who lost his dog, who is the main character?', a: 'The boy' },
    { q: "If a story says 'Thabo ran to the shop before it closed', where did Thabo go?", a: 'To the shop' },
    { q: "If a story says 'Lindiwe was happy because she won the race', why was Lindiwe happy?", a: 'Because she won the race' },
    { q: 'What do we call the place and time where a story happens?', a: 'The setting' },
    { q: "If a sentence says 'First she packed her bag, then she left for school', what happened first?", a: 'She packed her bag' },
    { q: 'What is the problem in a story usually called?', a: 'The conflict' },
    { q: 'What do we call the people in a story?', a: 'Characters' },
    { q: "What word tells you a story is happening 'yesterday'?", a: "A past-tense clue word like 'yesterday'" },
    { q: "If a character says 'I am scared of the dark', how does the character feel?", a: 'Scared' },
    { q: "If a story says 'The rain stopped and the sun came out', what happened after the rain?", a: 'The sun came out' },
    { q: 'Why do authors write titles for stories?', a: 'To tell readers what the story is about' },
    { q: "If a sentence says 'Because it was cold, she wore a jacket', why did she wear a jacket?", a: 'Because it was cold' },
    { q: 'What is the lesson a story teaches sometimes called?', a: 'The moral' },
    { q: "If a story says 'Sipho finally reached the top of the hill', what did Sipho do?", a: 'He reached the top of the hill' },
    { q: 'What punctuation mark do you read with a question in your voice?', a: 'A question mark' },
  ],
  ls_g2_body: [
    { q: 'Which body system helps you breathe?', a: 'The respiratory system' },
    { q: 'Which organ pumps blood around your body?', a: 'The heart' },
    { q: 'What do we call the tubes that carry blood around your body?', a: 'Blood vessels' },
    { q: 'Which body system helps you digest food?', a: 'The digestive system' },
    { q: 'What happens to food after you chew it?', a: 'It travels down to your stomach' },
    { q: 'Which bones protect your brain?', a: 'Your skull' },
    { q: 'What do muscles help your body do?', a: 'Move' },
    { q: 'Which body part filters waste from your blood?', a: 'Your kidneys' },
    { q: 'What do your lungs fill with when you breathe in?', a: 'Air' },
    { q: 'Which system in your body is made of bones?', a: 'The skeletal system' },
    { q: 'Why do you need to eat healthy food?', a: 'To give your body energy to grow and work' },
    { q: 'What happens to your heart rate when you exercise?', a: 'It beats faster' },
    { q: 'What protects your organs inside your chest?', a: 'Your ribs' },
    { q: 'Why is it important to rest and sleep?', a: 'To let your body and brain recover' },
    { q: 'Which sense organ helps you keep your balance?', a: 'Your ears' },
  ],
  ls_g2_safety: [
    { q: 'What should you do before crossing at a robot (traffic light)?', a: 'Wait for the green man and look both ways' },
    { q: 'What should you always wear when swimming in open water?', a: 'A life jacket' },
    { q: "If you're ever home alone, what should you never do for strangers?", a: 'Open the door' },
    { q: 'What number can you call for help in an emergency in South Africa?', a: '10111' },
    { q: 'What should you do if you smell gas at home?', a: 'Tell an adult and go outside immediately' },
    { q: 'Why should you never swim alone?', a: 'So someone can help you if something goes wrong' },
    { q: 'What should you do if you get separated from your parent in a crowd?', a: 'Stay where you are and look for a helper like a security guard' },
    { q: 'What should you do before getting into a car?', a: 'Put on your seatbelt' },
    { q: 'Is it safe to talk to strangers online without an adult?', a: 'No, always ask a trusted adult first' },
    { q: 'What should you do if a stranger offers you sweets?', a: 'Say no and tell a trusted adult' },
    { q: 'Why should you never play near a pool without an adult watching?', a: 'Because you could fall in and no one would know' },
    { q: 'What should you do if you see a fire at home?', a: 'Get outside immediately and call for help' },
    { q: 'What should you do before you cross a busy road?', a: 'Stop, look both ways, and listen' },
    { q: 'Who should you tell if someone makes you feel unsafe?', a: 'A trusted adult' },
    { q: 'What should you keep away from electrical outlets?', a: 'Water and metal objects' },
  ],
```

- [ ] **Step 2: Commit**

```bash
git add tools/gamegen/content/facts.js
git commit -m "feat(gamegen): author Grade 2 adventureJourney content (alphabet, reading, body, safety)"
```

---

### Task 8: Author the 2 `tugOfWar` (non-math) Grade 2 content banks

**Files:**
- Modify: `tools/gamegen/content/facts.js`

**Interfaces:**
- Consumes: `t.id` lookups from `author.js`'s `bodyFor()` for `tugOfWar`/`numberCountingDuel` where `math.isMathTopic(t)` is false (`facts.TUG_OF_WAR[t.id]`).
- Produces: 2 new `TUG_OF_WAR` entries (`eng_g2_phonics`, `ls_g2_habits`), 15 items each.

- [ ] **Step 1: Add the 2 entries to the `TUG_OF_WAR` object**

Add alongside the existing entries (e.g. `eng_g1_phonics`, `ls_g1_habits`) in `tools/gamegen/content/facts.js`:

```javascript
  eng_g2_phonics: [
    { q: "What sound do the letters 'sh' make in 'ship'?", a: '/sh/' },
    { q: 'Blend st-o-p together. What word do you get?', a: 'stop' },
    { q: "What sound do the letters 'ch' make in 'chip'?", a: '/ch/' },
    { q: 'Blend fl-a-g together. What word do you get?', a: 'flag' },
    { q: "What sound do the letters 'th' make in 'this'?", a: '/th/' },
    { q: 'Blend gr-a-b together. What word do you get?', a: 'grab' },
    { q: "What two letters together make the /sh/ sound?", a: 'sh' },
    { q: 'Blend cr-a-b together. What word do you get?', a: 'crab' },
    { q: "What two letters together make the /ch/ sound?", a: 'ch' },
    { q: 'Blend sw-i-m together. What word do you get?', a: 'swim' },
    { q: "What sound do the letters 'wh' make in 'whale'?", a: '/wh/' },
    { q: 'Blend sp-o-t together. What word do you get?', a: 'spot' },
    { q: "What two letters together make the /th/ sound?", a: 'th' },
    { q: 'Blend dr-u-m together. What word do you get?', a: 'drum' },
    { q: 'Blend tr-ee together. What word do you get?', a: 'tree' },
  ],
  ls_g2_habits: [
    { q: 'How many hours of sleep does a 7-year-old need each night?', a: 'About 10 to 11 hours' },
    { q: 'What should you do before and after using the toilet?', a: 'Wash your hands' },
    { q: 'Why should you limit sugary snacks?', a: 'They can harm your teeth and health' },
    { q: 'What food group helps build strong muscles?', a: 'Protein, like eggs, beans and meat' },
    { q: 'How often should you brush your teeth?', a: 'Twice a day' },
    { q: 'Why is drinking water better than fizzy drinks?', a: 'It keeps you hydrated without added sugar' },
    { q: 'What should you do before eating a meal?', a: 'Wash your hands' },
    { q: 'Why is it important to eat vegetables every day?', a: 'They give your body vitamins to stay healthy' },
    { q: 'What helps protect your skin on a sunny day?', a: 'Sunscreen and a hat' },
    { q: 'Why should you cover your mouth when you sneeze?', a: 'To stop germs from spreading' },
    { q: 'How much physical activity should you get each day?', a: 'At least 60 minutes' },
    { q: 'Why is breakfast important?', a: 'It gives you energy to start the day' },
    { q: 'What should you do if you feel too tired to concentrate at school?', a: 'Get more sleep that night' },
    { q: 'Why should you wash fruit before eating it?', a: 'To remove dirt and germs' },
    { q: 'What helps keep your bones strong?', a: 'Calcium, like milk and cheese, and exercise' },
  ],
```

- [ ] **Step 2: Commit**

```bash
git add tools/gamegen/content/facts.js
git commit -m "feat(gamegen): author Grade 2 tugOfWar content (phonics blends, healthy habits)"
```

---

### Task 9: Author the 2 `runnerCollector` Grade 2 content banks

**Files:**
- Modify: `tools/gamegen/content/runner_collector.js`

**Interfaces:**
- Consumes: `t.id` lookups from `author.js`'s `bodyFor()` (`runnerCollector.BANKS[t.id]`), each `level.targetClass` must be a key present in that same entry's `buckets`.
- Produces: 2 new `BANKS` entries (`eng_g2_grammar`, `ls_g2_feelings`).

- [ ] **Step 1: Add the 2 entries to the `BANKS` object**

Add alongside the existing entries (e.g. `eng_g1_grammar`, `ls_g1_feelings`) in `tools/gamegen/content/runner_collector.js`:

```javascript
  eng_g2_grammar: {
    buckets: {
      noun: ['teacher', 'beach', 'garden', 'bicycle', 'kitchen', 'forest', 'village', 'bridge'],
      verb: ['climb', 'laugh', 'whisper', 'skip', 'build', 'paint', 'dance', 'shout'],
      adjective: ['bright', 'gentle', 'enormous', 'shiny', 'quiet', 'clever'],
      pronoun: ['he', 'she', 'it', 'they', 'we', 'you'],
    },
    levels: [
      { targetClass: 'noun', missionLabel: 'Collect only Nouns! 📦', scrollSpeed: 0.09 },
      { targetClass: 'verb', missionLabel: 'Collect only Verbs! 🏃', scrollSpeed: 0.11 },
      { targetClass: 'adjective', missionLabel: 'Collect only Adjectives! ✨', scrollSpeed: 0.12 },
      { targetClass: 'pronoun', missionLabel: 'Collect only Pronouns! 👤', scrollSpeed: 0.13 },
    ],
  },
  ls_g2_feelings: {
    buckets: {
      happy: ['delighted', 'joyful', 'grateful', 'content', 'thrilled'],
      sad: ['heartbroken', 'discouraged', 'homesick', 'tearful', 'glum'],
      angry: ['irritated', 'outraged', 'resentful', 'fuming', 'impatient'],
      scared: ['terrified', 'uneasy', 'panicked', 'timid', 'startled'],
    },
    levels: [
      { targetClass: 'happy', missionLabel: 'Collect happy feelings! 😄', scrollSpeed: 0.08 },
      { targetClass: 'sad', missionLabel: 'Collect sad feelings! 😢', scrollSpeed: 0.08 },
      { targetClass: 'angry', missionLabel: 'Collect angry feelings! 😠', scrollSpeed: 0.09 },
      { targetClass: 'scared', missionLabel: 'Collect scared feelings! 😟', scrollSpeed: 0.09 },
    ],
  },
```

- [ ] **Step 2: Commit**

```bash
git add tools/gamegen/content/runner_collector.js
git commit -m "feat(gamegen): author Grade 2 runnerCollector content (grammar, feelings)"
```

---

### Task 10: Register `ls_g2_community` in `explorer_map.js`

**Files:**
- Modify: `tools/gamegen/content/explorer_map.js`

**Interfaces:**
- Consumes: `t.id` lookup from `author.js`'s `bodyFor()` (`explorerMap.TOPIC_PINS[t.id]`).
- Produces: a `TOPIC_PINS.ls_g2_community` entry.

Community-helper facts (who they are, what they do) don't need grade-specific content the way number ranges do — reuse the existing, already-validated `COMMUNITY_HELPERS` constant exactly as `ls_g1_community` does, rather than authoring a duplicate set (which `validate.js` invariant #7, same-grade+subject+engine duplicate-pack detection, would flag anyway if copy-pasted verbatim into the wrong grade — reusing the same export for a *different* grade is fine and intended).

- [ ] **Step 1: Add the registration**

In `tools/gamegen/content/explorer_map.js`, in the `TOPIC_PINS` object, add a line next to the existing `ls_g1_community: COMMUNITY_HELPERS,`:

```javascript
  ls_g2_community: COMMUNITY_HELPERS,
```

- [ ] **Step 2: Commit**

```bash
git add tools/gamegen/content/explorer_map.js
git commit -m "feat(gamegen): register Grade 2 community-helpers map (reuses existing pin set)"
```

---

### Task 11: Author the 2 `sequenceBuilder` Grade 2 content banks

**Files:**
- Modify: `tools/gamegen/content/sequence_builder.js`

**Interfaces:**
- Consumes: `t.id` lookup from `author.js`'s `bodyFor()` (`sequenceBuilder.TOPICS[t.id]` → `{sceneType, steps}`; `roundVariants(t.id, steps, min)` is auto-derived, no action needed).
- Produces: 2 new `TOPICS` entries (`eng_g2_words`, `math_g2_mountain`).

Per `docs/DEFERRED.md`, `SequenceBuilderGame` currently always renders the same backdrop regardless of `sceneType` (a known, separately-tracked cosmetic gap) — so `sceneType` values here are forward-looking identifiers, safe to introduce.

- [ ] **Step 1: Add the 2 entries to the `TOPICS` object**

Add alongside the existing entries (e.g. `eng_g1_words`, `math_g1_mountain`) in `tools/gamegen/content/sequence_builder.js`:

```javascript
  eng_g2_words: {
    sceneType: 'cvccWords',
    steps: [
      { id: 'first_sound', label: 'First sound', emoji: '🔤', description: 'Pick the sound you hear first, like s in stop.' },
      { id: 'blend_cluster', label: 'Blend the cluster', emoji: '🔡', description: 'Blend a two-letter cluster, like st or fl.' },
      { id: 'middle_sound', label: 'Middle sound', emoji: '🔠', description: 'Pick the vowel sound in the middle.' },
      { id: 'last_sound', label: 'Last sound', emoji: '🔤', description: 'Pick the sound you hear last.' },
      { id: 'blend_all', label: 'Blend it together', emoji: '🗣️', description: 'Say all the sounds together to read the word.' },
    ],
  },
  math_g2_mountain: {
    sceneType: 'mathsMountainLevel2',
    steps: [
      { id: 'read', label: 'Read', emoji: '👀', description: 'Read the number sentence carefully.' },
      { id: 'choose', label: 'Choose', emoji: '🤔', description: 'Choose which operation to use: +, − or ×.' },
      { id: 'regroup', label: 'Regroup', emoji: '🔄', description: 'Regroup tens and ones if you need to.' },
      { id: 'solve', label: 'Solve', emoji: '✏️', description: 'Work out the answer step by step.' },
      { id: 'check', label: 'Check', emoji: '✅', description: 'Check your answer makes sense.' },
    ],
  },
```

- [ ] **Step 2: Commit**

```bash
git add tools/gamegen/content/sequence_builder.js
git commit -m "feat(gamegen): author Grade 2 sequenceBuilder content (cvcc words, maths mountain)"
```

---

### Task 12: Author the 1 `multiplesMerge` Grade 2 content bank

**Files:**
- Modify: `tools/gamegen/content/multiples_merge.js`

**Interfaces:**
- Consumes: `t.id` lookup from `author.js`'s `bodyFor()` (`multiplesMerge.NUMERIC[t.id]` → `multiplesMerge.numericPack(t.id, min)`).
- Produces: a `NUMERIC.math_g2_multiples` entry.

- [ ] **Step 1: Add the entry to the `NUMERIC` object**

Add alongside the existing entries (e.g. `math_g1_multiples`) in `tools/gamegen/content/multiples_merge.js`:

```javascript
  math_g2_multiples: { tables: [2, 3, 4, 5, 10], gridSize: 4, chainLength: 5 },
```

- [ ] **Step 2: Commit**

```bash
git add tools/gamegen/content/multiples_merge.js
git commit -m "feat(gamegen): author Grade 2 multiplesMerge content"
```

---

### Task 13: Run the full pipeline and reach the "green" gate

**Files:**
- Modify (generated): all 15 `assets/content/*_g2_*.json` files (scaffolds → real content)

**Interfaces:**
- Consumes: Tasks 7-12's content modules + Tasks 2-4's `topics.json` entries.
- Produces: 15 fully authored, schema-valid content packs; a passing `npm run validate`.

- [ ] **Step 1: Run author**

Run: `cd tools/gamegen && npm run author`
Expected: exits 0; console output shows all topics processed with no `INVALID:` lines for the 15 `*_g2_*` ids (existing topics should be unaffected — `author.js` is deterministic/idempotent per its own doc comment, so re-running it must not change any existing Grade 1/4/7 content pack's bytes).

- [ ] **Step 2: Confirm no unintended diff on existing packs**

Run: `git status --short assets/content/ | grep -v '_g2_'`
Expected: empty output (only new `*_g2_*.json` files should appear as untracked/modified — if any existing pack shows as modified, stop and investigate before continuing, per the repo's "never remove/alter existing functionality" rule).

- [ ] **Step 3: Run validate — must fully pass**

Run: `cd tools/gamegen && npm run validate`
Expected: `PASS: 0 invariant violation(s).` and the printed coverage table now shows a `Mathematics`/`English`/`Life Skills` × `grade2` cell of `5t/Ne` (5 topics, N distinct engines) instead of `-`. If any failure remains, read the exact `FAIL:` line — it will name the specific id and rule — and fix that id's `topics.json` entry or content-module entry (do not weaken `validate.js` itself).

- [ ] **Step 4: Commit the generated content packs**

```bash
git add assets/content/*_g2_*.json
git commit -m "chore(gamegen): regenerate Grade 2 content packs (npm run author)"
```

---

### Task 14: Flutter-side verification gate

**Files:** none modified (verification only)

**Interfaces:** none.

- [ ] **Step 1: flutter analyze**

Run: `flutter analyze`
Expected: 0 errors (per `CLAUDE.md` §5/§9 — pre-existing info-lints are the tolerated baseline; no *new* errors or warnings should appear from the regenerated catalog).

- [ ] **Step 2: flutter test**

Run: `flutter test`
Expected: all tests green, including `test/catalog/game_catalog_invariants_test.dart`. If that file asserts a hardcoded total catalog count or a hardcoded Grade 1 entry count, update the expected number to match the new total (121 + 15 = 136) and re-run.

- [ ] **Step 3: Check for any other hardcoded catalog-count assumption**

Run: `grep -rn "121\|GameCatalog.all.length\|catalog.length" test/ lib/ --include=*.dart`
Expected: review each hit; if any test or UI copy hardcodes "121 games" or similar, update it to read the count dynamically or bump the literal — do not leave a stale count.

---

### Task 15: Manual verification in the running app

**Files:** none modified.

**Interfaces:** none.

- [ ] **Step 1: Launch**

Run: `flutter run -d chrome`
Expected: app boots to login with no red screen (per `CLAUDE.md` §9 Definition of Done).

- [ ] **Step 2: Verify Grade 2 sees its own content**

Sign in (or use whatever dev/test-account path this app already provides) as a Grade 2 learner. Confirm the dashboard shows exactly the 15 new Grade 2 games (Sight Word Safari, Grammar Garden: Level 2, Phonics Fun: Blends & Digraphs, Reading Rainbow: Level 2, Word Builder: Level 2, My Body: Level 2, My Community: Level 2, Feelings Factory: Level 2, Healthy Habits: Level 2, Safety Squad: Level 2, Addition Adventure: Level 2, Number Counting Duel: Level 2, Maths Mountain: Level 2, Multiple Chain: Level 2, Subtraction Safari: Level 2) — not the Grade 1 versions, and not a mix of both.

- [ ] **Step 3: Verify Grade 1 and Grade 3 are unaffected/improved**

Confirm a Grade 1 learner still sees their original 15 games unchanged. Confirm a Grade 3 learner still sees the (now Grade-1-difficulty, unchanged) 15 games as an interim — this is expected and tracked as the Phase 15 follow-up, not a regression from before this phase.

- [ ] **Step 4: Play one game through to completion**

Play "Addition Adventure: Level 2" (or any one of the 15) start to finish as a smoke test that the content pack's schema is actually consumable by the real `TugOfWarGame` widget, not just schema-valid on paper.

---

### Task 16: Final commit and phase close-out

**Files:**
- Modify: `docs/DEFERRED.md` (optional but recommended — note that Grade 3/5/6 remain on the hand-me-down pattern, pointing at this plan as the template for Phases 15-17)

- [ ] **Step 1: Add a DEFERRED.md note**

Append to `tools/gamegen`'s section (or a new section) in `docs/DEFERRED.md`:

```markdown
## Curriculum content gap — Grades 3, 5, 6 (Phase 15-17, not yet started)

Phase 14 (2026-08-01) gave Grade 2 its own difficulty band and 15
dedicated catalog entries, replacing the silent Grade-1-difficulty
hand-me-down. Grade 3 still receives Grade 1's entries verbatim
(`grades: ['grade1', 'grade3']`), and Grades 5/6 still receive Grade 4's
entries verbatim (`grades: ['grade4', 'grade5', 'grade6']`).
`tools/gamegen/difficulty.js` already has `BANDS.grade3`/`grade5`/`grade6`
defined (added in Phase 14) — Phases 15-17 just need to repeat Phase 14's
pattern (see `docs/superpowers/plans/2026-08-01-phase14-grade2-curriculum-content.md`)
for each remaining grade: add topics.json entries mirroring the anchor
grade's topicId/subtopicId pairs, narrow the anchor grade's `grades`
array, author the non-procedural content banks, run
`npm run generate && npm run author && npm run validate`.
```

- [ ] **Step 2: Final validate + analyze + test sweep**

Run: `cd tools/gamegen && npm run validate && cd ../.. && flutter analyze && flutter test`
Expected: all three green/passing, confirming nothing regressed across the whole phase.

- [ ] **Step 3: Commit**

```bash
git add docs/DEFERRED.md
git commit -m "docs: track Grade 3/5/6 curriculum content as Phase 15-17 follow-up"
```
