'use strict';

const fs = require('fs');

const CATALOG_PATH = require('path').join(
  __dirname,
  '../../lib/core/constants/game_catalog.dart'
);

function grabString(block, key) {
  // Matches key: 'single quoted' or key: "double quoted" (handles escaped
  // apostrophes inside double-quoted Dart strings, e.g. "South Africa's").
  const single = block.match(new RegExp(`${key}:\\s*'((?:[^'\\\\]|\\\\.)*)'`));
  if (single) return single[1].replace(/\\'/g, "'");
  const dbl = block.match(new RegExp(`${key}:\\s*"((?:[^"\\\\]|\\\\.)*)"`));
  if (dbl) return dbl[1].replace(/\\"/g, '"');
  return null;
}

function grabList(block, key) {
  const m = block.match(new RegExp(`${key}:\\s*\\[([^\\]]*)\\]`));
  if (!m) return [];
  return m[1]
    .split(',')
    .map((s) => s.trim().replace(/^'|'$/g, ''))
    .filter(Boolean);
}

function grabInt(block, key) {
  const m = block.match(new RegExp(`${key}:\\s*(\\d+)`));
  return m ? parseInt(m[1], 10) : null;
}

function grabBool(block, key) {
  const m = block.match(new RegExp(`${key}:\\s*(true|false)`));
  return m ? m[1] === 'true' : false;
}

function grabColorExpr(block) {
  const m = block.match(/color:\s*(AppColors\.\w+|Color\(0x[0-9A-Fa-f]+\))/);
  if (!m) throw new Error('entry missing a `color:` expression');
  return m[1];
}

/** Parses lib/core/constants/game_catalog.dart into an array of plain entry objects. */
function parseCatalog(catalogPath = CATALOG_PATH) {
  const text = fs.readFileSync(catalogPath, 'utf8');
  const blocks = text.split('GameCatalogEntry(').slice(1);
  const entries = [];
  for (const raw of blocks) {
    const id = grabString(raw, 'id');
    if (!id) continue; // the class's own `const GameCatalogEntry({...})` ctor block
    // Trim block to just this entry (up to the matching top-level close —
    // approximate by cutting at the next top-level "),\n    GameCatalogEntry("
    // boundary is unnecessary since all our regexes are anchored to unique
    // keys that only appear once per entry).
    entries.push({
      id,
      title: grabString(raw, 'title'),
      description: grabString(raw, 'description'),
      grade: grabString(raw, 'grade'),
      grades: grabList(raw, 'grades'),
      subject: grabString(raw, 'subject'),
      topicId: grabString(raw, 'topicId'),
      subtopicId: grabString(raw, 'subtopicId'),
      engineType: grabString(raw, 'engineType'),
      emoji: grabString(raw, 'emoji'),
      colorExpr: grabColorExpr(raw),
      learningObjective: grabString(raw, 'learningObjective'),
      mechanicReason: grabString(raw, 'mechanicReason'),
      difficulty: grabString(raw, 'difficulty'),
      xpReward: grabInt(raw, 'xpReward'),
      coinsReward: grabInt(raw, 'coinsReward'),
      isNew: grabBool(raw, 'isNew'),
      isFeatured: grabBool(raw, 'isFeatured'),
    });
  }
  return entries;
}

module.exports = { parseCatalog, CATALOG_PATH };
