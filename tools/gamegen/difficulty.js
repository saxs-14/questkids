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
