# gamegen

Content generation pipeline for the QuestKids game catalog. Plain Node 18+,
zero dependencies.

`topics.json` is the single source of truth. Don't hand-edit
`lib/core/constants/game_catalog.dart` or `assets/content/**/*.json` —
edit `topics.json` (or `classify.js` / `difficulty.js` / `phrasing.js` for
the rules that derive fields) and regenerate.

## Pipeline

```
extract.js   game_catalog.dart -> topics.json   (one-time / re-sync after a manual catalog edit)
generate.js  topics.json -> game_catalog.dart + assets/content/**/*.json scaffolds
author.js    topics.json -> assets/content/**/*.json (full Tier A/B content, overwrites scaffolds)
validate.js  topics.json + assets/content/**/*.json -> pass/fail + coverage table
```

```bash
cd tools/gamegen
npm run extract    # parse the Dart catalog into topics.json (only needed if you hand-edited the Dart file)
npm run generate    # regenerate game_catalog.dart + scaffold any missing content packs
npm run author      # (re)generate full content for every topic's pack
npm run validate     # the mandatory gate — see docs/DEMO_CHECKLIST.md
npm run all          # extract -> generate -> author -> validate
```

## Modules

- `parse_catalog.js` — regex parser for the hand-authored-then-generated
  Dart catalog format.
- `classify.js` — the cognitiveVerb -> engine table (CLAUDE.md gamegen
  Phase A §3), plus a per-topic classification built from a curriculum
  pass over every catalog entry. `validate.js` re-derives each topic's
  cognitiveVerb from this module and checks it against the stored engine,
  so the check is a real gate, not a tautology against whatever the
  catalog already says.
- `difficulty.js` — the three grade-band difficulty presets (grade1/4/7).
- `phrasing.js` — per-engine "why this mechanic teaches this skill"
  sentence templates, so `mechanicReason` can never go stale after an
  engine reassignment.
- `tiers.js` — Tier A (first 2 topics per subject per grade, >=15 items)
  vs Tier B (everything else, >=10 items).
- `schemas/index.js` — one content-pack validator per engine, matching
  what each engine's Dart code actually consumes (not an idealized
  abstract shape — see the comment at the top of that file for why
  `circuitBuilder`'s schema is a fill-in-the-blank layout rather than a
  generic node/edge graph, and why `multiplesMerge` supports both a
  `numeric` and a `pairs` content mode).

## Content packs

`assets/content/{grade}/{subject_slug}/{topicId}.json`, registered as a
Flutter asset directory in `pubspec.yaml`. Every pack has a common header
(`id`, `engine`, `grade`, `subject`, `title`, `tagline`, `accentColorHex`,
`emoji`) plus engine-specific fields — see `schemas/index.js`.

Procedural-math engines (`tugOfWar`, `numberCountingDuel`, and
`multiplesMerge` in `numeric` mode) still generate questions at runtime
from `GameConfig.extras`/`difficulty`, not from the pack's item list —
per CLAUDE.md gamegen Phase C §2, "where an engine already generates
maths procedurally, keep it procedural but drive its parameters from the
manifest difficulty." Their packs carry `sampleItems` (a themed quiz-shape
question bank) mainly so every topic still has an inspectable, schema-
validated, non-empty content pack, and so the intro sheet / offline
preview has real question text to show instead of nothing.
