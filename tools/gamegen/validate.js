#!/usr/bin/env node
'use strict';

/**
 * Phase B — the mandatory gate (see CLAUDE.md gamegen Phase D §4 / docs/
 * DEMO_CHECKLIST.md). Exits non-zero unless every invariant below holds.
 * Also prints a per-grade x per-subject coverage table.
 */

const fs = require('fs');
const path = require('path');
const { classify, expectedEngines } = require('./classify');
const { validatePack } = require('./schemas');
const { computeTiers, minItemsForTier } = require('./tiers');
const { bandFor } = require('./difficulty');

const ROOT = path.join(__dirname, '../..');
const TOPICS_PATH = path.join(__dirname, 'topics.json');

let failures = 0;
function fail(msg) {
  failures++;
  console.error(`FAIL: ${msg}`);
}
function ok(msg) {
  console.log(`ok:   ${msg}`);
}

function main() {
  const topics = JSON.parse(fs.readFileSync(TOPICS_PATH, 'utf8'));

  // 1. no duplicate ids
  const idCounts = new Map();
  for (const t of topics) idCounts.set(t.id, (idCounts.get(t.id) || 0) + 1);
  const dupes = [...idCounts.entries()].filter(([, n]) => n > 1);
  if (dupes.length) fail(`duplicate ids: ${dupes.map(([id]) => id).join(', ')}`);
  else ok('no duplicate ids');

  // 2. exactly one catalog entry per topic per grade it covers.
  //    (topics.json is already one-record-per-grade, so this just re-checks
  //    id uniqueness combined with grade — kept as an explicit, separate
  //    invariant per the Phase B spec rather than folded into check 1.)
  const idGradeCounts = new Map();
  for (const t of topics) {
    const key = `${t.id}::${t.grade}`;
    idGradeCounts.set(key, (idGradeCounts.get(key) || 0) + 1);
  }
  const gradeDupes = [...idGradeCounts.entries()].filter(([, n]) => n > 1);
  if (gradeDupes.length) fail(`duplicate id+grade pairs: ${gradeDupes.map(([k]) => k).join(', ')}`);
  else ok('exactly one catalog entry per topic per grade');

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

  // 4. adventureJourney + tugOfWar <= 40% combined
  const reskin = topics.filter((t) => t.engine === 'adventureJourney' || t.engine === 'tugOfWar').length;
  const ratio = reskin / topics.length;
  if (ratio > 0.4) {
    fail(`adventureJourney+tugOfWar is ${reskin}/${topics.length} (${(ratio * 100).toFixed(1)}%) > 40%`);
  } else {
    ok(`adventureJourney+tugOfWar is ${reskin}/${topics.length} (${(ratio * 100).toFixed(1)}%) <= 40%`);
  }

  // 5. every subject uses >= 3 distinct engines
  const enginesBySubject = new Map();
  for (const t of topics) {
    if (!enginesBySubject.has(t.subject)) enginesBySubject.set(t.subject, new Set());
    enginesBySubject.get(t.subject).add(t.engine);
  }
  for (const [subject, engines] of enginesBySubject) {
    if (engines.size < 3) fail(`${subject} only uses ${engines.size} distinct engine(s): ${[...engines]}`);
    else ok(`${subject} uses ${engines.size} distinct engines`);
  }

  // 6. runnerCollector >= 5 entries
  const runnerCount = topics.filter((t) => t.engine === 'runnerCollector').length;
  if (runnerCount < 5) fail(`runnerCollector has only ${runnerCount} entries (need >= 5)`);
  else ok(`runnerCollector has ${runnerCount} entries (>= 5)`);

  // 7. no two topics in the same grade+subject share (engine + identical content pack)
  const packSignature = new Map(); // `${grade}::${subject}::${engine}` -> Set of JSON signatures
  for (const t of topics) {
    const packPath = path.join(ROOT, t.contentPack);
    if (!fs.existsSync(packPath)) continue; // reported separately below
    const raw = fs.readFileSync(packPath, 'utf8');
    let pack;
    try {
      pack = JSON.parse(raw);
    } catch (e) {
      fail(`${t.id}: content pack is not valid JSON (${e.message})`);
      continue;
    }
    // Compare ignoring the identifying header fields (id/title/tagline/etc.)
    // so two packs with different flavour text but literally copy-pasted
    // game content still get caught.
    const { id, title, tagline, ...rest } = pack;
    const sig = JSON.stringify(rest);
    const key = `${t.grade}::${t.subject}::${t.engine}`;
    if (!packSignature.has(key)) packSignature.set(key, new Map());
    const seen = packSignature.get(key);
    if (seen.has(sig)) {
      fail(`${t.id} and ${seen.get(sig)} (${key}) share identical content-pack bodies`);
    } else {
      seen.set(sig, t.id);
    }
  }
  ok('checked content packs for same-grade+subject+engine duplicates');

  // 8 & 9. every content pack passes its schema, has enough items, and difficulty matches grade band
  const tierOf = computeTiers(topics);
  let schemaFailures = 0;
  let missingPacks = 0;
  let scaffoldsRemaining = 0;
  for (const t of topics) {
    const packPath = path.join(ROOT, t.contentPack);
    if (!fs.existsSync(packPath)) {
      fail(`${t.id}: content pack missing at ${t.contentPack}`);
      missingPacks++;
      continue;
    }
    const pack = JSON.parse(fs.readFileSync(packPath, 'utf8'));
    if (pack._scaffold) scaffoldsRemaining++;
    const tier = tierOf.get(t.id);
    const min = minItemsForTier(tier);
    const errors = validatePack(t.engine, pack, { min });
    if (errors.length) {
      schemaFailures++;
      for (const e of errors) fail(`${t.id} [${t.engine}, tier ${tier}, min ${min}]: ${e}`);
    }

    // difficulty matches the grade band (re-derive from difficulty.js and
    // compare — catches topics.json edits that drifted from the band)
    const band = bandFor(t.grade);
    for (const f of Object.keys(band)) {
      if (JSON.stringify(t.difficulty[f]) !== JSON.stringify(band[f])) {
        fail(`${t.id}: difficulty.${f} is ${JSON.stringify(t.difficulty[f])}, grade band ${t.grade} says ${JSON.stringify(band[f])}`);
      }
    }
  }
  if (schemaFailures === 0 && missingPacks === 0) {
    ok(`all ${topics.length} content packs exist and pass their engine schema`);
  }
  if (scaffoldsRemaining > 0) {
    console.warn(
      `warn: ${scaffoldsRemaining}/${topics.length} content packs are still unauthored scaffolds ` +
        `(_scaffold: true) — run tools/gamegen/author.js`
    );
  }

  // Coverage table
  printCoverageTable(topics);

  console.log(`\n${failures === 0 ? 'PASS' : 'FAIL'}: ${failures} invariant violation(s).`);
  process.exit(failures === 0 ? 0 : 1);
}

function printCoverageTable(topics) {
  const grades = [...new Set(topics.map((t) => t.grade))].sort();
  const subjects = [...new Set(topics.map((t) => t.subject))].sort();
  console.log('\nCoverage (topics / distinct engines) — grade x subject:');
  const gradeHeader = grades.map((g) => g.padStart(14)).join('');
  console.log(''.padEnd(18) + gradeHeader);
  for (const subject of subjects) {
    let row = subject.padEnd(18);
    for (const grade of grades) {
      const inCell = topics.filter((t) => t.grade === grade && t.subject === subject);
      const engines = new Set(inCell.map((t) => t.engine));
      const cell = inCell.length ? `${inCell.length}t/${engines.size}e` : '-';
      row += cell.padStart(14);
    }
    console.log(row);
  }
}

main();
