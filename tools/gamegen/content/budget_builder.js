'use strict';

const { rngFor, seedFromString, shuffle, randInt } = require('./math');

/**
 * budgetBuilder packs: scenario-based needs/wants/skip budgeting rounds,
 * matching the engine's real data contract (budget, scenario, items[]).
 * Each topic gets its own scenario framing + item pool so a "budgeting"
 * game feels different from a "banking" or "profit & loss" game even
 * though the underlying need/want/skip mechanic is shared.
 */

const NEEDS = [
  ['Bread and milk', 60, '🍞', 'Food is essential for survival'],
  ['School uniform', 150, '👕', 'Required for school'],
  ['Bus fare for the week', 80, '🚌', 'Transport to school is essential'],
  ['Electricity top-up', 120, '💡', 'Essential service — no lights without it'],
  ['Stationery for school', 60, '✏️', 'Needed for learning'],
  ['Groceries', 250, '🛒', 'Food for the family is a need'],
  ['Water and rates bill', 150, '💧', 'Clean water is a basic need'],
  ['Medical prescription', 90, '💊', 'Health is a priority'],
  ['Rent contribution', 400, '🏠', 'Shelter is a basic need'],
  ['School shoes', 180, '👞', 'Needed for school every day'],
];

const WANTS = [
  ['Movie ticket', 80, '🎬', 'Fun but not essential'],
  ['Sweets and chips', 50, '🍬', 'Nice to have, not necessary'],
  ['Takeaway dinner', 120, '🍔', 'Can cook at home instead'],
  ['Comic book', 40, '📚', 'Fun reading, not essential'],
  ['New sneakers (extra pair)', 280, '👟', 'Already has school shoes'],
  ['Pet grooming', 200, '🐕', 'Nice for pet, not critical this month'],
  ['Weekend concert tickets', 350, '🎵', 'Entertainment, not essential'],
  ['Fancy restaurant lunch', 180, '🍽️', 'Pack a lunch instead'],
  ['New phone case', 90, '📱', 'Current one still works'],
  ['Gift shop toy', 120, '🧸', 'Fun but not needed'],
];

const SKIPS = [
  ['Video game console', 3000, '🎮', 'Far too expensive this month'],
  ['Limited edition sneakers', 1200, '👟', 'Way over budget'],
  ['New TV', 4500, '📺', 'Exceeds the budget by a lot'],
  ['Designer jacket', 1800, '🧥', 'Not affordable this month'],
  ['Latest smartphone', 9000, '📱', 'Far more than the whole budget'],
  ['Overseas holiday deposit', 5000, '✈️', 'Not possible on this budget'],
];

function scenario(rng, intro, budget) {
  const items = [];
  const needCount = randInt(rng, 2, 3);
  const wantCount = randInt(rng, 1, 2);
  const pickedNeeds = shuffle(rng, NEEDS).slice(0, needCount);
  const pickedWants = shuffle(rng, WANTS).slice(0, wantCount);
  const pickedSkip = shuffle(rng, SKIPS)[0];
  for (const [name, cost, emoji, reason] of pickedNeeds) items.push({ name, cost, category: 'need', emoji, reason });
  for (const [name, cost, emoji, reason] of pickedWants) items.push({ name, cost, category: 'want', emoji, reason });
  items.push({ name: pickedSkip[0], cost: pickedSkip[1], category: 'skip', emoji: pickedSkip[2], reason: pickedSkip[3] });
  return { budget, scenario: intro, items: shuffle(rng, items) };
}

function generateScenarios(topicId, introTemplates, count) {
  const rng = rngFor(seedFromString(topicId + '::budget'));
  const scenarios = [];
  for (let i = 0; i < count; i++) {
    const template = introTemplates[i % introTemplates.length];
    const budget = template.budget(rng, i);
    scenarios.push(scenario(rng, template.text(budget, i), budget));
  }
  return scenarios;
}

const TOPIC_TEMPLATES = {
  ems_g7_banking: [
    { budget: (rng) => randInt(rng, 3, 12) * 100, text: (b) => `Your bank account has R${b} to cover this month's expenses.` },
    { budget: (rng) => randInt(rng, 2, 8) * 100, text: (b) => `You received R${b} in a bank transfer — plan how to use it.` },
  ],
  ems_g7_budget: [
    { budget: (rng) => randInt(rng, 3, 10) * 100, text: (b) => `Your household budget for the month is R${b}.` },
    { budget: (rng) => randInt(rng, 2, 6) * 100, text: (b) => `You have R${b} left after paying rent — budget the rest.` },
  ],
  ems_g7_economics: [
    { budget: (rng) => randInt(rng, 4, 15) * 100, text: (b) => `A small community project has R${b} to spend wisely.` },
    { budget: (rng) => randInt(rng, 3, 10) * 100, text: (b) => `Your family's monthly income is R${b} — allocate it between needs and wants.` },
  ],
  ems_g7_profit: [
    { budget: (rng) => randInt(rng, 5, 15) * 100, text: (b) => `Your small business earned R${b} in revenue this month.` },
    { budget: (rng) => randInt(rng, 4, 12) * 100, text: (b) => `After sales, your stall has R${b} to reinvest and spend.` },
  ],
  ems_g7_savings: [
    { budget: (rng) => randInt(rng, 2, 8) * 100, text: (b) => `You saved R${b} — decide what to prioritise before spending more.` },
    { budget: (rng) => randInt(rng, 3, 9) * 100, text: (b) => `Your savings goal fund currently has R${b} available.` },
  ],
  ls_g4_finance: [
    { budget: (rng) => randInt(rng, 2, 6) * 100, text: (b) => `Your pocket money and chores earned you R${b} this month.` },
    { budget: (rng) => randInt(rng, 1, 5) * 100, text: (b) => `You have R${b} saved up from your birthday money.` },
  ],
};

module.exports = { TOPIC_TEMPLATES, generateScenarios };
