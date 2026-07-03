'use strict';

/**
 * One JSON-shape validator per engine, matching what each engine's Dart
 * code actually consumes (lib/features/games/<engine>/*_engine.dart /
 * *_config.dart) — not an idealized abstract shape. Every pack additionally
 * carries the common header fields checked by validateCommon().
 *
 * Each validator returns a (possibly empty) array of human-readable error
 * strings; an empty array means the pack is valid.
 */

function isNonEmptyString(v) {
  return typeof v === 'string' && v.trim().length > 0;
}
function isNumber(v) {
  return typeof v === 'number' && Number.isFinite(v);
}
function isHexColor(v) {
  return typeof v === 'string' && /^#[0-9A-Fa-f]{6,8}$/.test(v);
}

function validateCommon(pack) {
  const errors = [];
  for (const field of ['id', 'engine', 'grade', 'subject', 'title', 'tagline', 'emoji']) {
    if (!isNonEmptyString(pack[field])) errors.push(`missing/empty "${field}"`);
  }
  if (!isHexColor(pack.accentColorHex)) errors.push('accentColorHex must be a #RRGGBB(AA) hex string');
  return errors;
}

function validateQuizItems(pack, { min }) {
  const errors = [];
  const items = pack.items;
  if (!Array.isArray(items)) return ['"items" must be an array'];
  if (items.length < min) errors.push(`needs >= ${min} items, has ${items.length}`);
  items.forEach((it, i) => {
    if (!isNonEmptyString(it.question)) errors.push(`items[${i}].question missing`);
    if (!Array.isArray(it.options) || it.options.length !== 4) {
      errors.push(`items[${i}].options must have exactly 4 entries`);
    } else if (!it.options.every(isNonEmptyString)) {
      errors.push(`items[${i}].options must all be non-empty strings`);
    }
    if (!Number.isInteger(it.answerIndex) || it.answerIndex < 0 || it.answerIndex > 3) {
      errors.push(`items[${i}].answerIndex must be an integer 0-3`);
    }
    if (!isNonEmptyString(it.hint)) errors.push(`items[${i}].hint missing`);
    if (!isNonEmptyString(it.explanation)) errors.push(`items[${i}].explanation missing`);
  });
  return errors;
}

function validateSequenceBuilder(pack, { min }) {
  const errors = [];
  if (!isNonEmptyString(pack.sceneType)) errors.push('sceneType missing');
  const steps = pack.steps;
  if (!Array.isArray(steps)) return ['"steps" must be an array'];
  if (steps.length < 3) errors.push(`needs >= 3 steps, has ${steps.length}`);
  steps.forEach((s, i) => {
    if (!isNonEmptyString(s.id)) errors.push(`steps[${i}].id missing`);
    if (!isNonEmptyString(s.label)) errors.push(`steps[${i}].label missing`);
    if (!isNonEmptyString(s.emoji)) errors.push(`steps[${i}].emoji missing`);
    if (!isNonEmptyString(s.description)) errors.push(`steps[${i}].description missing`);
  });
  // sequenceBuilder is replayed `rounds` times over the SAME ordered steps,
  // so its item-count floor is measured in alternate step sets, not steps.
  const variants = pack.roundVariants;
  if (!Array.isArray(variants) || variants.length < min) {
    errors.push(`needs >= ${min} roundVariants (alternate step orderings), has ${variants ? variants.length : 0}`);
  }
  return errors;
}

function validateExplorerMap(pack, { min }) {
  const errors = [];
  const pins = pack.pins;
  if (!Array.isArray(pins) || pins.length < 4) errors.push('needs >= 4 pins');
  else {
    pins.forEach((p, i) => {
      if (!isNonEmptyString(p.id)) errors.push(`pins[${i}].id missing`);
      if (!isNonEmptyString(p.name)) errors.push(`pins[${i}].name missing`);
      if (!isNumber(p.x) || p.x < 0 || p.x > 1) errors.push(`pins[${i}].x must be 0-1`);
      if (!isNumber(p.y) || p.y < 0 || p.y > 1) errors.push(`pins[${i}].y must be 0-1`);
      if (!Array.isArray(p.facts) || !p.facts.every(isNonEmptyString) || p.facts.length === 0) {
        errors.push(`pins[${i}].facts must be a non-empty string array`);
      }
    });
  }
  const questions = pack.questions;
  if (!Array.isArray(questions)) return errors.concat('"questions" must be an array');
  if (questions.length < min) errors.push(`needs >= ${min} questions, has ${questions.length}`);
  const pinIds = new Set((pins || []).map((p) => p.id));
  questions.forEach((q, i) => {
    if (!isNonEmptyString(q.question)) errors.push(`questions[${i}].question missing`);
    if (!pinIds.has(q.correctId)) errors.push(`questions[${i}].correctId not in pins`);
    if (!Array.isArray(q.optionIds) || q.optionIds.length < 2 || !q.optionIds.includes(q.correctId)) {
      errors.push(`questions[${i}].optionIds must include correctId and have >= 2 entries`);
    }
    if (!isNonEmptyString(q.feedbackFact)) errors.push(`questions[${i}].feedbackFact missing`);
  });
  return errors;
}

function validateCircuitBuilder(pack, { min }) {
  const errors = [];
  const circuits = pack.circuits;
  if (!Array.isArray(circuits)) return ['"circuits" must be an array'];
  if (circuits.length < min) errors.push(`needs >= ${min} circuits, has ${circuits.length}`);
  circuits.forEach((c, i) => {
    if (!isNonEmptyString(c.id)) errors.push(`circuits[${i}].id missing`);
    if (!isNonEmptyString(c.description)) errors.push(`circuits[${i}].description missing`);
    if (!isNonEmptyString(c.layout)) errors.push(`circuits[${i}].layout missing`);
    if (!Array.isArray(c.blanks) || c.blanks.length === 0) {
      errors.push(`circuits[${i}].blanks must be a non-empty array`);
    } else {
      const bank = new Set(c.bank || []);
      c.blanks.forEach((b, j) => {
        if (!Number.isInteger(b.position)) errors.push(`circuits[${i}].blanks[${j}].position missing`);
        if (!bank.has(b.correctComponent)) {
          errors.push(`circuits[${i}].blanks[${j}].correctComponent not present in bank`);
        }
      });
    }
    if (!Array.isArray(c.bank) || c.bank.length < 2) errors.push(`circuits[${i}].bank needs >= 2 components`);
    if (typeof c.labels !== 'object' || c.labels === null) errors.push(`circuits[${i}].labels missing`);
  });
  return errors;
}

function validateBudgetBuilder(pack, { min }) {
  const errors = [];
  const scenarios = pack.scenarios;
  if (!Array.isArray(scenarios)) return ['"scenarios" must be an array'];
  if (scenarios.length < min) errors.push(`needs >= ${min} scenarios, has ${scenarios.length}`);
  scenarios.forEach((s, i) => {
    if (!isNumber(s.budget) || s.budget <= 0) errors.push(`scenarios[${i}].budget must be > 0`);
    if (!isNonEmptyString(s.scenario)) errors.push(`scenarios[${i}].scenario missing`);
    if (!Array.isArray(s.items) || s.items.length < 3) {
      errors.push(`scenarios[${i}].items needs >= 3 entries`);
    } else {
      s.items.forEach((it, j) => {
        if (!isNonEmptyString(it.name)) errors.push(`scenarios[${i}].items[${j}].name missing`);
        if (!isNumber(it.cost) || it.cost <= 0) errors.push(`scenarios[${i}].items[${j}].cost must be > 0`);
        if (!['need', 'want', 'skip'].includes(it.category)) {
          errors.push(`scenarios[${i}].items[${j}].category must be need|want|skip`);
        }
        if (!isNonEmptyString(it.emoji)) errors.push(`scenarios[${i}].items[${j}].emoji missing`);
      });
    }
  });
  return errors;
}

function validateRunnerCollector(pack, { min }) {
  const errors = [];
  const levels = pack.levels;
  if (!Array.isArray(levels)) return ['"levels" must be an array'];
  if (levels.length < 3) errors.push(`needs >= 3 levels, has ${levels.length}`);
  let totalWords = 0;
  levels.forEach((lvl, i) => {
    if (!isNonEmptyString(lvl.targetClass)) errors.push(`levels[${i}].targetClass missing`);
    if (!isNonEmptyString(lvl.missionLabel)) errors.push(`levels[${i}].missionLabel missing`);
    if (!isNumber(lvl.scrollSpeed) || lvl.scrollSpeed <= 0) errors.push(`levels[${i}].scrollSpeed must be > 0`);
    if (typeof lvl.buckets !== 'object' || lvl.buckets === null) {
      errors.push(`levels[${i}].buckets missing`);
    } else {
      for (const [bucket, words] of Object.entries(lvl.buckets)) {
        if (!Array.isArray(words) || !words.every(isNonEmptyString)) {
          errors.push(`levels[${i}].buckets.${bucket} must be a string array`);
        } else {
          totalWords += words.length;
        }
      }
      if (!Object.prototype.hasOwnProperty.call(lvl.buckets, lvl.targetClass)) {
        errors.push(`levels[${i}].targetClass "${lvl.targetClass}" has no matching bucket`);
      }
    }
  });
  if (totalWords < min) errors.push(`needs >= ${min} total words across all buckets, has ${totalWords}`);
  return errors;
}

function validateAdventureJourney(pack, { min }) {
  const errors = [];
  if (!isNonEmptyString(pack.characterEmoji)) errors.push('characterEmoji missing');
  const stages = pack.stages;
  if (!Array.isArray(stages)) return ['"stages" must be an array'];
  if (stages.length < min) errors.push(`needs >= ${min} stages, has ${stages.length}`);
  stages.forEach((s, i) => {
    if (!isNonEmptyString(s.id)) errors.push(`stages[${i}].id missing`);
    if (!isNonEmptyString(s.name)) errors.push(`stages[${i}].name missing`);
    if (!isNonEmptyString(s.emoji)) errors.push(`stages[${i}].emoji missing`);
    if (!isHexColor(s.themeColorHex)) errors.push(`stages[${i}].themeColorHex invalid`);
    if (!isNonEmptyString(s.question)) errors.push(`stages[${i}].question missing`);
    if (!Array.isArray(s.options) || s.options.length !== 4) {
      errors.push(`stages[${i}].options must have exactly 4 entries`);
    } else if (!s.options.includes(s.correctOption)) {
      errors.push(`stages[${i}].correctOption not present in options`);
    }
    if (!isNonEmptyString(s.correctFeedback)) errors.push(`stages[${i}].correctFeedback missing`);
    if (!isNonEmptyString(s.wrongFeedback)) errors.push(`stages[${i}].wrongFeedback missing`);
  });
  return errors;
}

function validateMultiplesMerge(pack, { min }) {
  const errors = [];
  if (!['numeric', 'pairs'].includes(pack.mode)) errors.push('mode must be "numeric" or "pairs"');
  if (!Number.isInteger(pack.gridSize) || pack.gridSize < 3) errors.push('gridSize must be an integer >= 3');
  if (!Number.isInteger(pack.chainLength) || pack.chainLength < 2) errors.push('chainLength must be an integer >= 2');
  if (pack.mode === 'numeric') {
    if (!Array.isArray(pack.tables) || pack.tables.length < min) {
      errors.push(`needs >= ${min} tables for numeric mode, has ${pack.tables ? pack.tables.length : 0}`);
    }
  } else if (pack.mode === 'pairs') {
    if (!Array.isArray(pack.tokenGroups) || pack.tokenGroups.length < min) {
      errors.push(`needs >= ${min} tokenGroups for pairs mode, has ${pack.tokenGroups ? pack.tokenGroups.length : 0}`);
    } else {
      pack.tokenGroups.forEach((g, i) => {
        if (!Array.isArray(g) || g.length < 2 || !g.every(isNonEmptyString)) {
          errors.push(`tokenGroups[${i}] must be an array of >= 2 strings`);
        }
      });
    }
  }
  return errors;
}

function validateProceduralParams(pack) {
  const errors = [];
  if (!isNonEmptyString(pack.questionType)) errors.push('questionType missing');
  if (!Array.isArray(pack.sampleItems) || pack.sampleItems.length === 0) {
    errors.push('sampleItems must be a non-empty array (used as the offline/preview question bank)');
  } else {
    return errors.concat(validateQuizItems(pack, { min: 0 }).map((e) => `sampleItems.${e}`));
  }
  return errors;
}

// engine -> { validate(pack, {min}) -> string[], itemCountOf(pack) -> number }
const SCHEMAS = {
  tugOfWar: {
    validate: (pack, opts) => validateProceduralParams(pack),
    itemCountOf: (pack) => (pack.sampleItems || []).length,
  },
  numberCountingDuel: {
    validate: (pack, opts) => validateProceduralParams(pack),
    itemCountOf: (pack) => (pack.sampleItems || []).length,
  },
  adventureJourney: {
    validate: validateAdventureJourney,
    itemCountOf: (pack) => (pack.stages || []).length,
  },
  runnerCollector: {
    validate: validateRunnerCollector,
    itemCountOf: (pack) =>
      (pack.levels || []).reduce(
        (n, l) => n + Object.values(l.buckets || {}).reduce((m, w) => m + w.length, 0),
        0
      ),
  },
  explorerMap: {
    validate: validateExplorerMap,
    itemCountOf: (pack) => (pack.questions || []).length,
  },
  sequenceBuilder: {
    validate: validateSequenceBuilder,
    itemCountOf: (pack) => (pack.roundVariants || []).length,
  },
  circuitBuilder: {
    validate: validateCircuitBuilder,
    itemCountOf: (pack) => (pack.circuits || []).length,
  },
  budgetBuilder: {
    validate: validateBudgetBuilder,
    itemCountOf: (pack) => (pack.scenarios || []).length,
  },
  multiplesMerge: {
    validate: validateMultiplesMerge,
    itemCountOf: (pack) => (pack.tables || pack.tokenGroups || []).length,
  },
};

/**
 * @param {string} engine
 * @param {object} pack
 * @param {{min: number}} opts minimum item-count for this tier (Tier A: 15, Tier B: 10)
 * @returns {string[]} validation errors (empty = valid)
 */
function validatePack(engine, pack, opts) {
  const schema = SCHEMAS[engine];
  if (!schema) return [`no schema registered for engine "${engine}"`];
  return validateCommon(pack).concat(schema.validate(pack, opts));
}

function itemCount(engine, pack) {
  const schema = SCHEMAS[engine];
  return schema ? schema.itemCountOf(pack) : 0;
}

module.exports = { validatePack, itemCount, SCHEMAS, validateCommon };
