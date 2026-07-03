#!/usr/bin/env node
'use strict';

/**
 * Phase C — authors full content for every topic's pack (Tier A >= 15
 * items, Tier B >= 10 items), overwriting the Phase B scaffolds. Safe to
 * re-run: generation is deterministic (seeded by topic id), so output is
 * stable across runs and only changes when a content module or topics.json
 * changes.
 */

const fs = require('fs');
const path = require('path');

const topicsList = require('./topics.json');
const { computeTiers, minItemsForTier } = require('./tiers');
const { validatePack } = require('./schemas');
const { resolveColorHex } = require('./color_resolve');

const math = require('./content/math');
const facts = require('./content/facts');
const runnerCollector = require('./content/runner_collector');
const explorerMap = require('./content/explorer_map');
const sequenceBuilder = require('./content/sequence_builder');
const circuitBuilder = require('./content/circuit_builder');
const budgetBuilder = require('./content/budget_builder');
const multiplesMerge = require('./content/multiples_merge');
const { generateWordProblemStages } = require('./content/word_problems');

const ROOT = path.join(__dirname, '../..');

const WORD_PROBLEM_TOPICS = {
  math_g4_problems: 'money',
  math_g7_wordproblems: 'money',
  math_g7_probability: 'probability',
};

function commonHeader(t) {
  return {
    id: t.id,
    engine: t.engine,
    grade: t.grade,
    subject: t.subject,
    title: t.title,
    tagline: t.description,
    accentColorHex: resolveColorHex(t.colorExpr),
    emoji: t.emoji,
  };
}

function bodyFor(t, min) {
  switch (t.engine) {
    case 'tugOfWar':
    case 'numberCountingDuel': {
      const items = math.isMathTopic(t)
        ? math.generateMathItems(t, min)
        : facts.toQuizItems(t.id, facts.TUG_OF_WAR[t.id]);
      const questionType = math.isMathTopic(t) ? math.opFor(t) : 'general-knowledge';
      return { questionType, sampleItems: items };
    }
    case 'adventureJourney': {
      if (WORD_PROBLEM_TOPICS[t.id]) {
        const stages = generateWordProblemStages(t.id, min, {
          emoji: t.emoji,
          colorHex: resolveColorHex(t.colorExpr),
          kind: WORD_PROBLEM_TOPICS[t.id],
        });
        return { characterEmoji: t.emoji, stages };
      }
      const bank = facts.ADVENTURE_JOURNEY[t.id];
      if (!bank) throw new Error(`no adventureJourney fact bank for "${t.id}"`);
      const stages = facts.toJourneyStages(t.id, bank, { emoji: t.emoji, colorHex: resolveColorHex(t.colorExpr) });
      return { characterEmoji: t.emoji, stages };
    }
    case 'runnerCollector': {
      const bank = runnerCollector.BANKS[t.id];
      if (!bank) throw new Error(`no runnerCollector bank for "${t.id}"`);
      const levels = bank.levels.map((l) => ({ ...l, buckets: bank.buckets }));
      return { levels };
    }
    case 'explorerMap': {
      const pins = explorerMap.TOPIC_PINS[t.id];
      if (!pins) throw new Error(`no explorerMap pins for "${t.id}"`);
      return explorerMap.pack(explorerMap.withColors(pins), min);
    }
    case 'sequenceBuilder': {
      const spec = sequenceBuilder.TOPICS[t.id];
      if (!spec) throw new Error(`no sequenceBuilder steps for "${t.id}"`);
      return {
        sceneType: spec.sceneType,
        steps: spec.steps,
        roundVariants: sequenceBuilder.roundVariants(t.id, spec.steps, min),
      };
    }
    case 'circuitBuilder': {
      const spec = circuitBuilder.TOPICS[t.id];
      if (!spec) throw new Error(`no circuitBuilder circuits for "${t.id}"`);
      return { circuits: spec.circuits };
    }
    case 'budgetBuilder': {
      const templates = budgetBuilder.TOPIC_TEMPLATES[t.id];
      if (!templates) throw new Error(`no budgetBuilder templates for "${t.id}"`);
      return { scenarios: budgetBuilder.generateScenarios(t.id, templates, min) };
    }
    case 'multiplesMerge': {
      if (multiplesMerge.NUMERIC[t.id]) return multiplesMerge.numericPack(t.id, min);
      if (multiplesMerge.PAIRS[t.id]) return multiplesMerge.pairsPack(t.id);
      throw new Error(`no multiplesMerge content for "${t.id}"`);
    }
    default:
      throw new Error(`author.js: no content generator for engine "${t.engine}"`);
  }
}

function main() {
  const tierOf = computeTiers(topicsList);
  let written = 0;
  let failed = 0;

  for (const t of topicsList) {
    const tier = tierOf.get(t.id);
    const min = minItemsForTier(tier);
    const pack = { ...commonHeader(t), ...bodyFor(t, min) };

    const errors = validatePack(t.engine, pack, { min });
    if (errors.length) {
      failed++;
      console.error(`INVALID: ${t.id} (${t.engine}, tier ${tier}):`);
      for (const e of errors) console.error(`  - ${e}`);
      continue;
    }

    const outPath = path.join(ROOT, t.contentPack);
    fs.mkdirSync(path.dirname(outPath), { recursive: true });
    fs.writeFileSync(outPath, JSON.stringify(pack, null, 2) + '\n');
    written++;
  }

  console.log(`Authored ${written}/${topicsList.length} content packs.`);
  if (failed) {
    console.error(`${failed} pack(s) failed schema validation — see above.`);
    process.exit(1);
  }
}

main();
