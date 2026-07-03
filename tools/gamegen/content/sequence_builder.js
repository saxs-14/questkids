'use strict';

const { rngFor, seedFromString, shuffle } = require('./math');

/**
 * sequenceBuilder packs: one real, fact-accurate ordered `steps` list per
 * topic (5-8 steps depending on grade band), plus `roundVariants` —
 * distinct-length ordered sub-sequences of `steps`, procedurally derived so
 * every round is still 100% factually correct (never a fabricated order)
 * while giving >= 10/15 replayable variants.
 */

const TOPICS = {
  eng_g1_words: {
    sceneType: 'cvcWords',
    steps: [
      { id: 'first_sound', label: 'First sound', emoji: '🔤', description: 'Pick the sound you hear first, like c in cat.' },
      { id: 'middle_sound', label: 'Middle sound', emoji: '🔡', description: 'Pick the vowel sound in the middle, like a in cat.' },
      { id: 'last_sound', label: 'Last sound', emoji: '🔠', description: 'Pick the sound you hear last, like t in cat.' },
      { id: 'blend', label: 'Blend it together', emoji: '🗣️', description: 'Say all three sounds together to read the word.' },
    ],
  },
  eng_g4_writing: {
    sceneType: 'storyStructure',
    steps: [
      { id: 'introduction', label: 'Introduction', emoji: '📖', description: 'Introduce the characters and setting.' },
      { id: 'complication', label: 'Complication', emoji: '❗', description: 'Introduce a problem the characters must solve.' },
      { id: 'rising_action', label: 'Rising Action', emoji: '📈', description: 'Build tension as characters try to solve the problem.' },
      { id: 'climax', label: 'Climax', emoji: '🎬', description: 'Reach the most exciting turning point of the story.' },
      { id: 'resolution', label: 'Resolution', emoji: '🧩', description: 'Show how the problem is solved.' },
      { id: 'conclusion', label: 'Conclusion', emoji: '🏁', description: "Wrap up the story and its message." },
    ],
  },
  eng_g7_essay: {
    sceneType: 'essayStructure',
    steps: [
      { id: 'hook', label: 'Hook', emoji: '🎣', description: 'Open with an interesting hook to grab the reader.' },
      { id: 'thesis', label: 'Thesis', emoji: '🎯', description: 'State your main argument or thesis.' },
      { id: 'point1', label: 'First Point', emoji: '1️⃣', description: 'Present your first supporting point with evidence.' },
      { id: 'point2', label: 'Second Point', emoji: '2️⃣', description: 'Present your second supporting point with evidence.' },
      { id: 'counter', label: 'Counter-Argument', emoji: '↩️', description: 'Address a counter-argument.' },
      { id: 'conclusion', label: 'Conclusion', emoji: '🏁', description: 'Restate your thesis and conclude with impact.' },
    ],
  },
  eng_g7_oral: {
    sceneType: 'oralPresentation',
    steps: [
      { id: 'greeting', label: 'Greeting', emoji: '👋', description: 'Greet your audience and introduce your topic.' },
      { id: 'hook', label: 'Hook', emoji: '❓', description: 'Capture attention with an interesting fact or question.' },
      { id: 'main_points', label: 'Main Points', emoji: '📝', description: 'Present your main points clearly.' },
      { id: 'evidence', label: 'Evidence', emoji: '📊', description: 'Support your points with examples or evidence.' },
      { id: 'summary', label: 'Summary', emoji: '🔁', description: 'Summarise your key points.' },
      { id: 'thanks', label: 'Thanks', emoji: '🙏', description: 'Thank your audience and invite questions.' },
    ],
  },
  math_g1_mountain: {
    sceneType: 'mathsMountain',
    steps: [
      { id: 'read', label: 'Read', emoji: '👀', description: 'Read the number sentence carefully.' },
      { id: 'choose', label: 'Choose', emoji: '🤔', description: 'Choose which operation to use: + or −.' },
      { id: 'solve', label: 'Solve', emoji: '✏️', description: 'Work out the answer step by step.' },
      { id: 'check', label: 'Check', emoji: '✅', description: 'Check your answer makes sense.' },
    ],
  },
  math_g4_multiplication: {
    sceneType: 'multiDigitMultiplication',
    steps: [
      { id: 'setup', label: 'Set Up', emoji: '📐', description: 'Write the numbers lined up by place value.' },
      { id: 'ones', label: 'Ones', emoji: '1️⃣', description: 'Multiply the ones digit first.' },
      { id: 'tens', label: 'Tens', emoji: '🔟', description: 'Multiply the tens digit next.' },
      { id: 'carry', label: 'Carry', emoji: '➕', description: 'Carry over any extra tens.' },
      { id: 'add', label: 'Add', emoji: '🧮', description: 'Add the partial products together.' },
      { id: 'check', label: 'Check', emoji: '✅', description: 'Check your answer with estimation.' },
    ],
  },
  math_g4_patterns: {
    sceneType: 'numberPatterns',
    steps: [
      { id: 'look', label: 'Look', emoji: '👀', description: 'Look at the numbers given in the pattern.' },
      { id: 'difference', label: 'Difference', emoji: '➖', description: 'Find the difference between each pair of numbers.' },
      { id: 'rule', label: 'Rule', emoji: '📏', description: "Work out the pattern's rule." },
      { id: 'apply', label: 'Apply', emoji: '🔁', description: 'Apply the rule to find the next number.' },
      { id: 'predict', label: 'Predict', emoji: '🔮', description: 'Predict several more numbers in the pattern.' },
      { id: 'check', label: 'Check', emoji: '✅', description: 'Check the rule works for the whole sequence.' },
    ],
  },
  math_g7_geometry: {
    sceneType: 'geometricConstructions',
    steps: [
      { id: 'tools', label: 'Tools', emoji: '🧰', description: 'Gather your ruler, compass and protractor.' },
      { id: 'baseline', label: 'Baseline', emoji: '📏', description: 'Draw a straight baseline of the given length.' },
      { id: 'arcs', label: 'Arcs', emoji: '⌒', description: 'Use the compass to draw arcs from each endpoint.' },
      { id: 'intersect', label: 'Intersect', emoji: '✖️', description: 'Mark where the arcs intersect.' },
      { id: 'connect', label: 'Connect', emoji: '📐', description: 'Connect the intersection point to complete the shape.' },
      { id: 'angles', label: 'Angles', emoji: '📐', description: 'Measure the angles with a protractor.' },
      { id: 'label', label: 'Label', emoji: '🏷️', description: 'Label all sides and angles.' },
      { id: 'check', label: 'Check', emoji: '✅', description: 'Check the construction matches the instructions.' },
    ],
  },
  math_g7_patterns: {
    sceneType: 'sequenceFormulas',
    steps: [
      { id: 'identify', label: 'Identify', emoji: '🔍', description: 'Identify the type of sequence (arithmetic or geometric).' },
      { id: 'difference', label: 'Difference/Ratio', emoji: '➗', description: 'Calculate the common difference or ratio.' },
      { id: 'formula', label: 'Formula', emoji: '🧮', description: 'Write a general formula (nth term rule).' },
      { id: 'test', label: 'Test', emoji: '🧪', description: 'Test the formula on known terms.' },
      { id: 'extend', label: 'Extend', emoji: '🔁', description: 'Extend the sequence using the formula.' },
      { id: 'verify', label: 'Verify', emoji: '✅', description: 'Verify your extended terms are correct.' },
      { id: 'graph', label: 'Graph', emoji: '📈', description: 'Represent the pattern on a number line or graph.' },
      { id: 'conclude', label: 'Conclude', emoji: '🏁', description: 'State the rule in words.' },
    ],
  },
  ns_g4_lifecycle: {
    sceneType: 'lifeCycle',
    steps: [
      { id: 'egg', label: 'Egg', emoji: '🥚', description: 'The life cycle begins as an egg.' },
      { id: 'larva', label: 'Larva', emoji: '🐛', description: 'The egg hatches into a larva that eats and grows.' },
      { id: 'growth', label: 'Growth', emoji: '📏', description: 'The larva grows and moults its skin several times.' },
      { id: 'pupa', label: 'Pupa', emoji: '🛡️', description: 'The larva forms a pupa (chrysalis or cocoon).' },
      { id: 'adult', label: 'Adult', emoji: '🦋', description: 'An adult emerges from the pupa, fully formed.' },
      { id: 'reproduce', label: 'Reproduce', emoji: '🔁', description: 'The adult reproduces, and the cycle begins again.' },
    ],
  },
  sci_g7_energy: {
    sceneType: 'energyTransformations',
    steps: [
      { id: 'chemical', label: 'Chemical', emoji: '🧪', description: 'Chemical energy is stored in food or fuel.' },
      { id: 'release', label: 'Release', emoji: '💥', description: 'The chemical energy is released through a reaction.' },
      { id: 'heat', label: 'Heat', emoji: '🔥', description: 'Some energy transforms into heat energy.' },
      { id: 'kinetic', label: 'Kinetic', emoji: '🏃', description: 'Some energy transforms into kinetic (movement) energy.' },
      { id: 'sound', label: 'Sound', emoji: '🔊', description: 'Some energy is lost as sound energy.' },
      { id: 'electrical', label: 'Electrical', emoji: '⚡', description: 'In a generator, kinetic energy transforms into electrical energy.' },
      { id: 'light', label: 'Light', emoji: '💡', description: 'Electrical energy can transform into light energy.' },
      { id: 'loss', label: 'Loss', emoji: '🌫️', description: 'Some energy is always lost to the surroundings as heat.' },
    ],
  },
  sci_g7_mixtures: {
    sceneType: 'separatingMixtures',
    steps: [
      { id: 'identify', label: 'Identify', emoji: '🔍', description: 'Identify the substances in the mixture.' },
      { id: 'method', label: 'Choose Method', emoji: '🧰', description: 'Choose a separation method (filtration, evaporation, etc).' },
      { id: 'filter', label: 'Filter', emoji: '🧻', description: 'Filter out any solid particles from the liquid.' },
      { id: 'evaporate', label: 'Evaporate', emoji: '♨️', description: 'Evaporate the liquid to leave the dissolved solid behind.' },
      { id: 'condense', label: 'Condense', emoji: '💧', description: 'Condense any vapour back into a pure liquid.' },
      { id: 'collect', label: 'Collect', emoji: '🧪', description: 'Collect each separated substance.' },
      { id: 'dry', label: 'Dry', emoji: '☀️', description: 'Dry the separated solid completely.' },
      { id: 'check', label: 'Check Purity', emoji: '✅', description: 'Check the purity of each separated substance.' },
    ],
  },
  ss_g4_colonial: {
    sceneType: 'colonialEra',
    steps: [
      { id: 'arrival', label: 'Arrival', emoji: '⛵', description: 'European settlers arrive at the Cape in 1652.' },
      { id: 'expansion', label: 'Expansion', emoji: '🗺️', description: 'Settlers expand inland, taking more land.' },
      { id: 'conflict', label: 'Conflict', emoji: '⚔️', description: 'Conflict grows between settlers and indigenous groups.' },
      { id: 'british', label: 'British Rule', emoji: '🇬🇧', description: 'British rule replaces Dutch rule at the Cape.' },
      { id: 'trekboers', label: 'Trekboers', emoji: '🐂', description: 'Trekboers and Voortrekkers move further inland.' },
      { id: 'colonies', label: 'Colonies Form', emoji: '🏛️', description: 'Separate colonies form across southern Africa.' },
    ],
  },
  ss_g4_water: {
    sceneType: 'waterCycle',
    steps: [
      { id: 'evaporation', label: 'Evaporation', emoji: '☀️', description: 'The sun heats water and it evaporates into vapour.' },
      { id: 'condensation', label: 'Condensation', emoji: '☁️', description: 'Water vapour cools and condenses into clouds.' },
      { id: 'precipitation', label: 'Precipitation', emoji: '🌧️', description: 'Water falls back to Earth as rain, hail or snow.' },
      { id: 'collection', label: 'Collection', emoji: '🌊', description: 'Water collects in rivers, lakes and oceans.' },
      { id: 'infiltration', label: 'Infiltration', emoji: '🕳️', description: 'Some water soaks into the ground as groundwater.' },
      { id: 'runoff', label: 'Runoff', emoji: '🏞️', description: 'Water flows over land back to rivers and the sea.' },
    ],
  },
  ss_g7_timeline: {
    sceneType: 'saHistoryTimeline',
    steps: [
      { id: 'union', label: '1910', emoji: '🏛️', description: '1910: Union of South Africa is formed.' },
      { id: 'land_act', label: '1913', emoji: '📜', description: '1913: The Natives Land Act restricts land ownership.' },
      { id: 'apartheid', label: '1948', emoji: '⛔', description: '1948: The National Party introduces apartheid.' },
      { id: 'sharpeville', label: '1960', emoji: '✊', description: '1960: The Sharpeville Massacre shocks the world.' },
      { id: 'rivonia', label: '1964', emoji: '⚖️', description: '1964: Nelson Mandela is sentenced at the Rivonia Trial.' },
      { id: 'soweto', label: '1976', emoji: '📢', description: '1976: The Soweto Uprising sparks global protest.' },
      { id: 'release', label: '1990', emoji: '🔓', description: '1990: Nelson Mandela is released from prison.' },
      { id: 'democracy', label: '1994', emoji: '🗳️', description: '1994: South Africa holds its first democratic election.' },
    ],
  },
  tech_g4_coding: {
    sceneType: 'codingBasics',
    steps: [
      { id: 'problem', label: 'Problem', emoji: '❓', description: 'Understand the problem you want to solve.' },
      { id: 'plan', label: 'Plan', emoji: '🗺️', description: 'Plan the steps needed to solve it (an algorithm).' },
      { id: 'code', label: 'Code', emoji: '💻', description: 'Write the code using the planned steps.' },
      { id: 'run', label: 'Run', emoji: '▶️', description: 'Run the program to see what happens.' },
      { id: 'debug', label: 'Debug', emoji: '🐛', description: 'Find and fix any errors (bugs).' },
      { id: 'test', label: 'Test', emoji: '✅', description: 'Test the program to make sure it works.' },
    ],
  },
  tech_g7_design: {
    sceneType: 'designProcess',
    steps: [
      { id: 'identify', label: 'Identify', emoji: '❓', description: 'Identify the problem that needs solving.' },
      { id: 'research', label: 'Research', emoji: '🔍', description: 'Research existing solutions and gather information.' },
      { id: 'brainstorm', label: 'Brainstorm', emoji: '💡', description: 'Brainstorm several possible ideas.' },
      { id: 'select', label: 'Select', emoji: '🎯', description: 'Select the best idea to develop.' },
      { id: 'prototype', label: 'Prototype', emoji: '🛠️', description: 'Build a prototype of the design.' },
      { id: 'test', label: 'Test', emoji: '🧪', description: 'Test the prototype and gather feedback.' },
      { id: 'improve', label: 'Improve', emoji: '🔁', description: 'Improve the design based on feedback.' },
      { id: 'finalise', label: 'Finalise', emoji: '🏁', description: 'Finalise and present the completed design.' },
    ],
  },
  tech_g7_systems: {
    sceneType: 'inputProcessOutput',
    steps: [
      { id: 'input', label: 'Input', emoji: '⌨️', description: 'Input: data or material enters the system.' },
      { id: 'sense', label: 'Sense', emoji: '📡', description: 'Sensors or controls detect the input.' },
      { id: 'process', label: 'Process', emoji: '⚙️', description: 'The system processes the input using set rules.' },
      { id: 'decide', label: 'Decide', emoji: '🤔', description: 'The system decides on the correct response.' },
      { id: 'actuate', label: 'Actuate', emoji: '🦾', description: 'Actuators or outputs are triggered.' },
      { id: 'output', label: 'Output', emoji: '📤', description: 'Output: the system produces a result.' },
      { id: 'feedback', label: 'Feedback', emoji: '🔄', description: 'Feedback is captured about the result.' },
      { id: 'adjust', label: 'Adjust', emoji: '🎛️', description: 'The system adjusts based on the feedback.' },
    ],
  },
};

/** All ordered sub-sequences of `steps` with length >= 3, deterministically
 * shuffled and capped at `count` — never reorders steps, only varies which
 * contiguous/evenly-spaced subset a round uses. */
/** All index combinations of size k from [0, n), order preserved. */
function combinations(n, k) {
  const out = [];
  const combo = [];
  function go(start) {
    if (combo.length === k) {
      out.push([...combo]);
      return;
    }
    for (let i = start; i < n; i++) {
      combo.push(i);
      go(i + 1);
      combo.pop();
    }
  }
  go(0);
  return out;
}

function roundVariants(topicId, steps, count) {
  const rng = rngFor(seedFromString(topicId + '::rounds'));
  const n = steps.length;
  const variants = [];
  for (let len = 3; len <= n; len++) {
    for (const idxs of combinations(n, len)) {
      variants.push(idxs.map((i) => steps[i].id));
    }
  }
  return shuffle(rng, variants).slice(0, count);
}

module.exports = { TOPICS, roundVariants };
