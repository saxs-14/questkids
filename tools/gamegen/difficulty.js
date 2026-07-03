'use strict';

/**
 * Difficulty bands, one per grade CAPS band this catalog uses (grade1,
 * grade4, grade7 — Foundation / Intermediate / Senior representative
 * grades). See CLAUDE.md gamegen Phase A §4.
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
  grade4: {
    numberRange: { min: 1, max: 1000 },
    timerSec: 20, // moderate
    steps: { min: 5, max: 6 },
    lives: 3,
    readingLevel: 'intermediate',
    fractionsDecimals: false,
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
