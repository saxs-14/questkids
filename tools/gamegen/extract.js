#!/usr/bin/env node
'use strict';

/**
 * Phase A — parses lib/core/constants/game_catalog.dart and emits
 * tools/gamegen/topics.json, the single source of truth for every topic's
 * grade, subject, engine, CAPS objective, cognitive verb and difficulty.
 *
 * From here on, edit topics.json (or classify.js / difficulty.js) — not
 * game_catalog.dart by hand. generate.js regenerates the Dart file from
 * this JSON.
 */

const fs = require('fs');
const path = require('path');
const { parseCatalog } = require('./parse_catalog');
const { classify, expectedEngines, VERB_LABELS } = require('./classify');
const { bandFor } = require('./difficulty');
const { mechanicReasonFor } = require('./phrasing');

const OUT_PATH = path.join(__dirname, 'topics.json');

// Flat by design: Flutter's asset bundler (at least as of this project's
// Flutter version) does not recurse into subdirectories of a directory
// registered in pubspec.yaml's `assets:` list when running `flutter test`
// — only files directly inside the registered path are found. Catalog
// ids are already globally unique, so assets/content/{id}.json avoids the
// whole nested-directory problem instead of registering every grade/
// subject subfolder in pubspec.yaml by hand.
function contentPackPath(grade, subject, id) {
  return `assets/content/${id}.json`;
}

function main() {
  const rawEntries = parseCatalog();
  const topics = [];
  let fixedCount = 0;

  rawEntries.forEach((e, sourceOrder) => {
    e.sourceOrder = sourceOrder;
  });

  for (const e of rawEntries) {
    const cognitiveVerb = classify(e);
    const allowed = expectedEngines(cognitiveVerb);
    let engine = e.engineType;
    let engineFixed = false;
    let mechanicReason = e.mechanicReason;
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

    topics.push({
      id: e.id,
      title: e.title,
      description: e.description,
      grade: e.grade,
      grades: e.grades,
      subject: e.subject,
      topicId: e.topicId,
      subtopicId: e.subtopicId,
      engine,
      originalEngine: engineFixed ? e.engineType : undefined,
      emoji: e.emoji,
      colorExpr: e.colorExpr,
      capsObjective: e.learningObjective,
      mechanicReason,
      cognitiveVerb,
      difficulty: {
        label: e.difficulty,
        ...bandFor(e.grade),
      },
      xpReward: e.xpReward,
      coinsReward: e.coinsReward,
      isNew: e.isNew,
      isFeatured: e.isFeatured,
      contentPack: contentPackPath(e.grade, e.subject, e.id),
      // Position in the original hand-authored catalog — generate.js uses
      // this (not the sorted array order below) to keep entries grouped by
      // grade band / subject the way a human reading the Dart file expects.
      sourceOrder: e.sourceOrder,
    });
  }

  topics.sort((a, b) => a.id.localeCompare(b.id));

  fs.writeFileSync(OUT_PATH, JSON.stringify(topics, null, 2) + '\n');
  console.log(`\nWrote ${topics.length} topics to ${path.relative(process.cwd(), OUT_PATH)}`);
  console.log(`Fixed ${fixedCount} engine/cognitive-verb mismatch(es).`);
}

main();
