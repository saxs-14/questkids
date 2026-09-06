'use strict';

const { rngFor, seedFromString, randInt, shuffle, buildOptions } = require('./math');

/** SA-context word-problem generator for adventureJourney's math topics —
 * procedural like tugOfWar's math items, but framed as a short narrative
 * stage (question/options/correctOption) instead of a bare equation. */

const NAMES = ['Thabo', 'Naledi', 'Sipho', 'Zanele', 'Aisha', 'Lerato', 'Kagiso', 'Amahle', 'Bongani', 'Nomvula'];
const SHOPS = ['spaza shop', 'school tuck shop', 'market stall', 'grocery store'];
const ITEMS = ['apples', 'oranges', 'notebooks', 'pencils', 'bread rolls', 'sweets'];

function wordProblem(rng, range) {
  const name = NAMES[randInt(rng, 0, NAMES.length - 1)];
  const item = ITEMS[randInt(rng, 0, ITEMS.length - 1)];
  const shop = SHOPS[randInt(rng, 0, SHOPS.length - 1)];
  const kind = randInt(rng, 0, 2);
  if (kind === 0) {
    const price = randInt(rng, 2, Math.max(5, Math.floor(range.max / 100)));
    const qty = randInt(rng, 2, 12);
    const correct = price * qty;
    const { options, answerIndex } = buildOptions(rng, correct, () => Math.max(1, correct + randInt(rng, -10, 10) || 1));
    return {
      question: `${name} buys ${qty} ${item} at the ${shop}, each costing R${price}. How much does ${name} spend in total?`,
      options: options.map((o) => `R${o}`),
      correctOption: `R${correct}`,
    };
  } else if (kind === 1) {
    // Unlike the price/qty and groups branches below, this one has no
    // natural /100-style divisor of its own -- it IS the money amount.
    // Scale off range.max but cap at a realistic pocket-money ceiling
    // instead of letting a grade7 numberRange (up to 100000) produce
    // "Aisha has R31520" style nonsense.
    const start = randInt(rng, 20, Math.min(500, Math.max(30, Math.floor(range.max / 50))));
    const spend = randInt(rng, 5, Math.floor(start / 2));
    const correct = start - spend;
    const { options, answerIndex } = buildOptions(rng, correct, () => Math.max(0, correct + randInt(rng, -8, 8) || 1));
    return {
      question: `${name} has R${start} and spends R${spend} at the ${shop}. How much money is left?`,
      options: options.map((o) => `R${o}`),
      correctOption: `R${correct}`,
    };
  } else {
    const groups = randInt(rng, 2, 8);
    const perGroup = randInt(rng, 2, Math.max(4, Math.floor(range.max / 200)));
    const total = groups * perGroup;
    const { options } = buildOptions(rng, perGroup, () => Math.max(1, perGroup + randInt(rng, -3, 3) || 1));
    return {
      question: `${name} shares ${total} ${item} equally into ${groups} bags. How many ${item} go in each bag?`,
      options,
      correctOption: String(perGroup),
    };
  }
}

function probabilityProblem(rng, range) {
  // No natural "probability range" concept, but scale the bag size (and
  // therefore the fraction's denominator) off the topic's numberRange so
  // 'hard' still means something here instead of a fixed 6-12 always.
  const upper = Math.max(10, Math.min(24, Math.round(range.max / 5000) + 8));
  const total = randInt(rng, 6, upper);
  const favourable = randInt(rng, 1, total - 1);
  const colours = ['red', 'blue', 'green', 'yellow'];
  const colour = colours[randInt(rng, 0, colours.length - 1)];
  const asFraction = `${favourable}/${total}`;
  const distractors = new Set();
  while (distractors.size < 3) {
    const f = randInt(rng, 1, total - 1);
    if (f !== favourable) distractors.add(`${f}/${total}`);
  }
  const options = shuffle(rng, [asFraction, ...distractors]);
  return {
    question: `A bag has ${total} marbles, and ${favourable} of them are ${colour}. What is the probability of picking a ${colour} marble?`,
    options,
    correctOption: asFraction,
  };
}

function generateWordProblemStages(topicId, count, { emoji, colorHex, kind = 'money', range = { min: 1, max: 1000 } }) {
  const rng = rngFor(seedFromString(topicId + '::wp'));
  const stages = [];
  const seen = new Set();
  let guard = 0;
  while (stages.length < count && guard++ < count * 30) {
    const p = kind === 'probability' ? probabilityProblem(rng, range) : wordProblem(rng, range);
    if (seen.has(p.question)) continue;
    seen.add(p.question);
    stages.push({
      id: `${topicId}_${stages.length}`,
      name: `Stage ${stages.length + 1}`,
      emoji,
      themeColorHex: colorHex,
      question: p.question,
      options: p.options,
      correctOption: p.correctOption,
      correctFeedback: `Yes! ${p.correctOption} is right — onward!`,
      wrongFeedback: `Not quite — the answer is ${p.correctOption}.`,
    });
  }
  return stages;
}

module.exports = { generateWordProblemStages };
