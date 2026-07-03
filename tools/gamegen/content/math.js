'use strict';

/**
 * Procedural arithmetic quiz-item generator, driven entirely by the topic's
 * subtopicId (-> operation) and its grade-band difficulty.numberRange —
 * "keep it procedural but drive its parameters from the manifest
 * difficulty instead of hardcoding" (CLAUDE.md gamegen Phase C §2).
 * Produces {question, options[4], answerIndex, hint, explanation} items.
 */

function rngFor(seed) {
  // xorshift32 — deterministic per-topic so `author.js` output is stable
  // across re-runs (no content churn on every regeneration).
  let x = seed || 1;
  return () => {
    x ^= x << 13;
    x ^= x >>> 17;
    x ^= x << 5;
    x |= 0;
    return ((x < 0 ? x + 4294967296 : x) % 1000000) / 1000000;
  };
}

function seedFromString(s) {
  let h = 2166136261;
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}

function randInt(rng, min, max) {
  return min + Math.floor(rng() * (max - min + 1));
}

function shuffle(rng, arr) {
  const a = [...arr];
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(rng() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

/** Builds a 4-option quiz item from a correct numeric/string answer plus a
 * distractor generator, ensuring no duplicate options. */
function buildOptions(rng, correct, makeDistractor) {
  const options = new Set([String(correct)]);
  let guard = 0;
  while (options.size < 4 && guard++ < 100) {
    options.add(String(makeDistractor()));
  }
  const list = shuffle(rng, [...options]);
  return { options: list, answerIndex: list.indexOf(String(correct)) };
}

const OP_BY_SUBTOPIC = {
  'numbers/counting': 'counting',
  'operations/addition': 'addition',
  'operations/subtraction': 'subtraction',
  'measurement/conversions': 'conversion',
  'decimals/decimal_operations': 'decimal',
  'division/long_division': 'division',
  'multiplication/times_tables': 'multiplication',
  'integers/integer_operations': 'integer',
  'algebra/linear_equations': 'algebra',
  'percentages/percentage_applications': 'percentage',
  'economics/taxation': 'vat',
  'speaking/formal_debate': null,
  'speaking/debate': null,
};

const CONVERSIONS = [
  { from: 'm', to: 'cm', factor: 100 },
  { from: 'km', to: 'm', factor: 1000 },
  { from: 'kg', to: 'g', factor: 1000 },
  { from: 'L', to: 'mL', factor: 1000 },
  { from: 'h', to: 'min', factor: 60 },
  { from: 'min', to: 's', factor: 60 },
];

function generateItem(op, rng, range) {
  const { min, max } = range;
  switch (op) {
    case 'counting': {
      const a = randInt(rng, min, max);
      let b = randInt(rng, min, max);
      while (b === a) b = randInt(rng, min, max);
      const correct = a > b ? a : b;
      const { options, answerIndex } = buildOptions(rng, correct, () =>
        Math.max(min, correct + randInt(rng, -4, 4) || 1)
      );
      return {
        question: `Which number is bigger: ${a} or ${b}?`,
        options,
        answerIndex,
        hint: 'Count up from the smaller number to check.',
        explanation: `${correct} is bigger than ${a === correct ? b : a}.`,
      };
    }
    case 'addition': {
      const a = randInt(rng, min, max);
      const b = randInt(rng, min, max);
      const correct = a + b;
      const { options, answerIndex } = buildOptions(rng, correct, () =>
        Math.max(0, correct + randInt(rng, -5, 5) || 1)
      );
      return {
        question: `${a} + ${b} = ?`,
        options,
        answerIndex,
        hint: `Count on from ${a}.`,
        explanation: `${a} + ${b} = ${correct}.`,
      };
    }
    case 'subtraction': {
      let a = randInt(rng, min, max);
      let b = randInt(rng, min, max);
      if (b > a) [a, b] = [b, a];
      const correct = a - b;
      const { options, answerIndex } = buildOptions(rng, correct, () =>
        Math.max(0, correct + randInt(rng, -5, 5) || 1)
      );
      return {
        question: `${a} - ${b} = ?`,
        options,
        answerIndex,
        hint: `Count back from ${a}.`,
        explanation: `${a} - ${b} = ${correct}.`,
      };
    }
    case 'multiplication': {
      const a = randInt(rng, 2, 12);
      const b = randInt(rng, Math.max(2, Math.min(12, Math.floor(min / 10) || 2)), 12);
      const correct = a * b;
      const { options, answerIndex } = buildOptions(rng, correct, () =>
        Math.max(1, correct + randInt(rng, -1, 1) * randInt(rng, 1, 12))
      );
      return {
        question: `${a} × ${b} = ?`,
        options,
        answerIndex,
        hint: `Think of ${a} groups of ${b}.`,
        explanation: `${a} × ${b} = ${correct}.`,
      };
    }
    case 'division': {
      const b = randInt(rng, 2, 12);
      const q = randInt(rng, 2, Math.max(3, Math.floor(max / 100)) || 12);
      const a = a_times_b(b, q);
      const correct = q;
      const { options, answerIndex } = buildOptions(rng, correct, () =>
        Math.max(1, correct + randInt(rng, -3, 3) || 1)
      );
      return {
        question: `${a} ÷ ${b} = ?`,
        options,
        answerIndex,
        hint: `How many ${b}s fit into ${a}?`,
        explanation: `${a} ÷ ${b} = ${correct} because ${b} × ${correct} = ${a}.`,
      };
    }
    case 'decimal': {
      const a = randInt(rng, 10, 999) / 10;
      const b = randInt(rng, 10, 999) / 10;
      const useAdd = rng() > 0.5;
      const correct = Math.round((useAdd ? a + b : Math.max(a, b) - Math.min(a, b)) * 10) / 10;
      const [x, y] = useAdd ? [a, b] : [Math.max(a, b), Math.min(a, b)];
      const { options, answerIndex } = buildOptions(rng, correct, () =>
        Math.round((correct + (randInt(rng, -20, 20) || 1) / 10) * 10) / 10
      );
      return {
        question: `${x} ${useAdd ? '+' : '-'} ${y} = ?`,
        options,
        answerIndex,
        hint: 'Line up the decimal points.',
        explanation: `${x} ${useAdd ? '+' : '-'} ${y} = ${correct}.`,
      };
    }
    case 'integer': {
      const a = randInt(rng, -max, max);
      const b = randInt(rng, -max, max);
      const useAdd = rng() > 0.5;
      const correct = useAdd ? a + b : a - b;
      const { options, answerIndex } = buildOptions(rng, correct, () => correct + randInt(rng, -6, 6) || 1);
      return {
        question: `${a} ${useAdd ? '+' : '-'} (${b}) = ?`,
        options,
        answerIndex,
        hint: 'Watch the signs — two negatives make a positive when subtracting.',
        explanation: `${a} ${useAdd ? '+' : '-'} (${b}) = ${correct}.`,
      };
    }
    case 'algebra': {
      const x = randInt(rng, 1, Math.max(10, Math.floor(max / 100)));
      const coeff = randInt(rng, 2, 9);
      const bTerm = randInt(rng, 1, 20);
      const result = coeff * x + bTerm;
      const { options, answerIndex } = buildOptions(rng, x, () => x + (randInt(rng, -4, 4) || 1));
      return {
        question: `Solve for x: ${coeff}x + ${bTerm} = ${result}`,
        options,
        answerIndex,
        hint: `Subtract ${bTerm} from both sides, then divide by ${coeff}.`,
        explanation: `${coeff}x = ${result - bTerm}, so x = ${x}.`,
      };
    }
    case 'percentage': {
      const pct = [10, 20, 25, 50, 75][randInt(rng, 0, 4)];
      const base = randInt(rng, 4, Math.max(20, Math.floor(max / 1000))) * 20;
      const correct = Math.round((pct / 100) * base);
      const { options, answerIndex } = buildOptions(rng, correct, () =>
        Math.max(1, correct + randInt(rng, -10, 10) * 2 || 1)
      );
      return {
        question: `What is ${pct}% of R${base}?`,
        options: options.map((o) => `R${o}`),
        answerIndex,
        hint: `${pct}% means ${pct} out of every 100.`,
        explanation: `${pct}% of R${base} is R${correct}.`,
      };
    }
    case 'conversion': {
      const c = CONVERSIONS[randInt(rng, 0, CONVERSIONS.length - 1)];
      const value = randInt(rng, 2, 20);
      const correct = value * c.factor;
      const { options, answerIndex } = buildOptions(rng, correct, () =>
        Math.max(1, correct + randInt(rng, -2, 2) * c.factor || c.factor)
      );
      return {
        question: `${value} ${c.from} = ? ${c.to}`,
        options: options.map((o) => `${o} ${c.to}`),
        answerIndex,
        hint: `1 ${c.from} = ${c.factor} ${c.to}.`,
        explanation: `${value} ${c.from} × ${c.factor} = ${correct} ${c.to}.`,
      };
    }
    case 'vat': {
      const price = randInt(rng, 5, 40) * 20;
      const correct = Math.round(price * 1.15);
      const { options, answerIndex } = buildOptions(rng, correct, () =>
        Math.max(1, correct + randInt(rng, -15, 15) * 2 || 1)
      );
      return {
        question: `An item costs R${price} before VAT. South Africa's VAT rate is 15%. What is the price including VAT?`,
        options: options.map((o) => `R${o}`),
        answerIndex,
        hint: 'VAT-inclusive price = price × 1.15.',
        explanation: `R${price} × 1.15 = R${correct}.`,
      };
    }
    default:
      throw new Error(`no math generator for op "${op}"`);
  }
}

function a_times_b(b, q) {
  return b * q;
}

function opFor(topic) {
  return OP_BY_SUBTOPIC[`${topic.topicId}/${topic.subtopicId}`];
}

function isMathTopic(topic) {
  return Object.prototype.hasOwnProperty.call(OP_BY_SUBTOPIC, `${topic.topicId}/${topic.subtopicId}`) &&
    opFor(topic) !== null;
}

function generateMathItems(topic, count) {
  const op = opFor(topic);
  const rng = rngFor(seedFromString(topic.id));
  const range = topic.difficulty.numberRange;
  const items = [];
  const seen = new Set();
  let guard = 0;
  while (items.length < count && guard++ < count * 20) {
    const item = generateItem(op, rng, range);
    if (seen.has(item.question)) continue;
    seen.add(item.question);
    items.push(item);
  }
  return items;
}

module.exports = { generateMathItems, isMathTopic, opFor, seedFromString, rngFor, randInt, shuffle, buildOptions };
