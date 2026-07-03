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
    const start = randInt(rng, 20, Math.max(30, range.max));
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

function probabilityProblem(rng) {
  const total = randInt(rng, 6, 12);
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

function generateWordProblemStages(topicId, count, { emoji, colorHex, kind = 'money' }) {
  const rng = rngFor(seedFromString(topicId + '::wp'));
  const stages = [];
  const seen = new Set();
  let guard = 0;
  while (stages.length < count && guard++ < count * 30) {
    const p = kind === 'probability' ? probabilityProblem(rng) : wordProblem(rng, { max: 1000 });
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
