'use strict';

/**
 * Per-engine "why this mechanic teaches this skill" sentence templates.
 * Keeping this derived from `engine` (not hand-typed per entry) means the
 * copy can never go stale when generate.js reassigns an engine.
 */
const TEMPLATES = {
  tugOfWar: (label) =>
    `Answering fast head-to-head builds quick, confident recall of ${label}.`,
  adventureJourney: (label) =>
    `Making choices through a story connects ${label} to real situations you can relate to.`,
  runnerCollector: (label) =>
    `Sorting the right answers on the run trains you to quickly tell ${label} apart.`,
  sequenceBuilder: (label) =>
    `Putting the steps in the right order breaks ${label} into stages you can follow one by one.`,
  multiplesMerge: (label) =>
    `Matching and merging pairs helps you spot patterns and connections in ${label}.`,
  explorerMap: (label) =>
    `Exploring a map connects ${label} to real places, so it sticks.`,
  circuitBuilder: (label) =>
    `Connecting the pieces correctly turns ${label} into a system you can see and build.`,
  budgetBuilder: (label) =>
    `Allocating a limited amount teaches real trade-offs in ${label}.`,
  numberCountingDuel: (label) =>
    `Racing to count and compare builds fast, confident number sense for ${label}.`,
};

function labelFromSubtopic(subtopicId) {
  return subtopicId.replace(/_/g, ' ');
}

function mechanicReasonFor(engine, subtopicId) {
  const template = TEMPLATES[engine];
  if (!template) throw new Error(`No mechanicReason template for engine "${engine}"`);
  return template(labelFromSubtopic(subtopicId));
}

module.exports = { mechanicReasonFor, labelFromSubtopic };
