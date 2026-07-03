'use strict';

/**
 * Hand-authored CAPS-accurate {q, a} fact banks for topics whose engine
 * needs quiz-shaped content but isn't arithmetic (see math.js for that).
 * Distractors are generated automatically (see autoDistractors below) so
 * authoring only needs the question and the correct answer.
 */

const { shuffle, rngFor, seedFromString } = require('./math');

const LETTERS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('');

function autoDistractors(rng, answer, siblingAnswers) {
  if (/^\d+$/.test(answer)) {
    const n = parseInt(answer, 10);
    const deltas = shuffle(rng, [1, -1, 2, -2, 3, -3, 5, -5, 10, -10]);
    const out = new Set();
    for (const d of deltas) {
      if (out.size >= 3) break;
      const v = n + d;
      if (v >= 0 && String(v) !== answer) out.add(String(v));
    }
    return [...out].slice(0, 3);
  }
  if (/^[A-Za-z]$/.test(answer)) {
    const pool = LETTERS.filter((l) => l.toUpperCase() !== answer.toUpperCase());
    return shuffle(rng, pool).slice(0, 3);
  }
  if (answer === 'Vowel' || answer === 'Consonant') {
    return ['Vowel', 'Consonant', 'Number', 'Symbol'].filter((o) => o !== answer).slice(0, 3);
  }
  const candidates = siblingAnswers.filter(
    (a) => a !== answer && !/^\d+$/.test(a) && !/^[A-Za-z]$/.test(a) && a !== 'Vowel' && a !== 'Consonant'
  );
  const distinct = [...new Set(candidates)];
  return shuffle(rng, distinct).slice(0, 3);
}

/** {q,a}[] -> {question, options[4], answerIndex, hint, explanation}[] (tugOfWar/numberCountingDuel sampleItems) */
function toQuizItems(topicId, bank) {
  const rng = rngFor(seedFromString(topicId));
  const allAnswers = bank.map((b) => b.a);
  return bank.map(({ q, a }) => {
    const wrong = autoDistractors(rng, a, allAnswers);
    if (wrong.length < 3) {
      throw new Error(`facts.js: not enough distractor candidates for "${topicId}" answer "${a}"`);
    }
    const options = shuffle(rng, [a, ...wrong]);
    return {
      question: q,
      options,
      answerIndex: options.indexOf(a),
      hint: `Think back to what you learned about this topic.`,
      explanation: `${a} — that's correct!`,
    };
  });
}

/** {q,a}[] -> AdventureJourneyConfig-shaped stages[] */
function toJourneyStages(topicId, bank, { emoji, colorHex }) {
  const rng = rngFor(seedFromString(topicId + '::journey'));
  const allAnswers = bank.map((b) => b.a);
  return bank.map(({ q, a }, i) => {
    const wrong = autoDistractors(rng, a, allAnswers);
    const options = shuffle(rng, [a, ...wrong]);
    return {
      id: `${topicId}_${i}`,
      name: `Stage ${i + 1}`,
      emoji,
      themeColorHex: colorHex,
      question: q,
      options,
      correctOption: a,
      correctFeedback: `Yes! ${a} is right — onward!`,
      wrongFeedback: `Not quite — the answer is ${a}.`,
    };
  });
}

// ── tugOfWar fact banks ─────────────────────────────────────────────────

const TUG_OF_WAR = {
  eng_g1_phonics: [
    { q: "What sound do you hear first in 'cat'?", a: '/c/' },
    { q: "Blend c-a-t together. What word do you get?", a: 'cat' },
    { q: "What sound do you hear first in 'sun'?", a: '/s/' },
    { q: "Blend s-u-n together. What word do you get?", a: 'sun' },
    { q: "What sound do you hear last in 'dog'?", a: '/g/' },
    { q: "Blend d-o-g together. What word do you get?", a: 'dog' },
    { q: "What sound do you hear first in 'map'?", a: '/m/' },
    { q: "Blend m-a-p together. What word do you get?", a: 'map' },
    { q: "What sound do you hear first in 'pig'?", a: '/p/' },
    { q: "Blend p-i-g together. What word do you get?", a: 'pig' },
    { q: "What sound do you hear first in 'bed'?", a: '/b/' },
    { q: "Blend b-e-d together. What word do you get?", a: 'bed' },
  ],
  eng_g4_debate: [
    { q: "What is the purpose of an opening statement in a debate?", a: "To introduce your team's position" },
    { q: 'What should you do when the other team makes a point?', a: 'Listen carefully and prepare a response' },
    { q: "What is a 'rebuttal'?", a: "A response that argues against the other side's point" },
    { q: 'Why is eye contact important in a debate?', a: 'It shows confidence and engages the audience' },
    { q: "What is the 'motion' in a debate?", a: 'The statement being argued for or against' },
    { q: 'Who usually gives the closing argument?', a: 'The last speaker on each team' },
    { q: 'What should evidence in a debate be?', a: 'Accurate and relevant to the point' },
    { q: 'What tone should a debater use?', a: 'Calm, clear and respectful' },
    { q: 'What is it called when you support your argument with facts?', a: 'Substantiation' },
    { q: 'Why should you avoid interrupting?', a: 'It is disrespectful and breaks debate rules' },
  ],
  eng_g4_spelling: [
    { q: "Spell: a place where you learn.", a: 'school' },
    { q: 'Spell: the day after today.', a: 'tomorrow' },
    { q: 'Spell: a person who teaches.', a: 'teacher' },
    { q: 'Spell: feeling thankful.', a: 'grateful' },
    { q: 'Spell: not the same.', a: 'different' },
    { q: 'Spell: liked the most.', a: 'favourite' },
    { q: 'Spell: very pretty.', a: 'beautiful' },
    { q: 'Spell: needed or significant.', a: 'important' },
    { q: 'Spell: used to give a reason.', a: 'because' },
    { q: 'Spell: someone you like and trust.', a: 'friend' },
  ],
  eng_g7_debate: [
    { q: "What is a 'point of information'?", a: 'A brief interruption to ask or offer a fact' },
    { q: "What does 'burden of proof' mean?", a: 'The responsibility to prove your claim' },
    { q: 'What is a logical fallacy?', a: 'A flaw in reasoning that weakens an argument' },
    { q: "What is an 'ad hominem' attack?", a: "Attacking the person instead of their argument" },
    { q: 'Why do debaters use statistics?', a: 'To support claims with credible evidence' },
    { q: "What is 'rebuttal time' used for?", a: "Directly countering the opposing team's arguments" },
    { q: "What makes an argument 'persuasive'?", a: 'Clear reasoning backed by evidence' },
    { q: 'What is the role of the adjudicator?', a: 'To judge and score the debate' },
    { q: 'What is a counter-argument?', a: 'An argument that opposes the original point' },
    { q: 'Why is structure important in a speech?', a: 'It helps the audience follow your argument' },
  ],
  eng_g7_spelling: [
    { q: 'Spell: needed; required.', a: 'necessary' },
    { q: 'Spell: without doubt.', a: 'definitely' },
    { q: 'Spell: to make someone feel shy or ashamed.', a: 'embarrass' },
    { q: 'Spell: a regular repeated pattern of sound.', a: 'rhythm' },
    { q: 'Spell: your inner sense of right and wrong.', a: 'conscience' },
    { q: 'Spell: a special right or advantage.', a: 'privilege' },
    { q: 'Spell: the group that governs a country.', a: 'government' },
    { q: 'Spell: right away, without delay.', a: 'immediately' },
    { q: 'Spell: a set of questions for a survey.', a: 'questionnaire' },
    { q: 'Spell: to provide space or make room for.', a: 'accommodate' },
  ],
  ls_g1_habits: [
    { q: 'How many times a day should you brush your teeth?', a: 'Twice' },
    { q: 'What should you do before eating?', a: 'Wash your hands' },
    { q: 'What should your body get plenty of every day?', a: 'Water' },
    { q: 'What helps your body grow strong?', a: 'Healthy food and exercise' },
    { q: 'About how many hours of sleep does a young child need?', a: 'About 10 hours' },
    { q: 'Why do we cover our mouth when we cough?', a: 'To stop germs from spreading' },
    { q: 'What should you do after playing outside?', a: 'Wash your hands and face' },
    { q: 'Which food group gives you energy to play?', a: 'Carbohydrates like bread and rice' },
    { q: 'Why is exercise good for you?', a: 'It keeps your body strong and healthy' },
    { q: 'What should you wear on a sunny day to stay safe?', a: 'A hat and sunscreen' },
  ],
  ls_g7_wellbeing: [
    { q: 'What is a healthy way to deal with stress?', a: 'Talking to someone you trust' },
    { q: 'Why is it important to talk about your feelings?', a: 'It helps you cope and feel supported' },
    { q: "What is 'self-esteem'?", a: 'How much you value and respect yourself' },
    { q: 'Name one way to relax your mind.', a: 'Deep breathing' },
    { q: 'Who can you talk to if you feel overwhelmed?', a: 'A trusted adult or counsellor' },
    { q: 'What is a sign that someone needs support?', a: 'Withdrawing from friends and family' },
    { q: 'Why is sleep important for mental wellbeing?', a: 'It helps your brain rest and recover' },
    { q: 'What does resilience mean?', a: 'The ability to bounce back from difficulties' },
    { q: 'Why is physical activity good for your mood?', a: 'It releases feel-good chemicals in the brain' },
    { q: 'What is a healthy way to handle disappointment?', a: 'Accepting your feelings and talking it through' },
  ],
  ns_g4_weather: [
    { q: 'What instrument measures temperature?', a: 'Thermometer' },
    { q: 'What instrument measures rainfall?', a: 'Rain gauge' },
    { q: 'What causes wind?', a: 'Moving air caused by temperature differences' },
    { q: 'What is humidity?', a: 'The amount of water vapour in the air' },
    { q: 'What season is coldest in South Africa?', a: 'Winter' },
    { q: 'What instrument measures wind speed?', a: 'Anemometer' },
    { q: 'What is a cold front?', a: 'A boundary where cold air pushes out warm air' },
    { q: 'What type of clouds bring rain?', a: 'Nimbus clouds' },
    { q: 'What causes the seasons?', a: 'The tilt of the Earth as it orbits the sun' },
    { q: 'Which SA province usually has winter rainfall?', a: 'Western Cape' },
  ],
  sci_g7_health: [
    { q: 'What is the largest organ in the human body?', a: 'Skin' },
    { q: 'Which system carries blood around your body?', a: 'Circulatory system' },
    { q: "What vitamin does sunlight help your body make?", a: 'Vitamin D' },
    { q: 'What is the main function of the lungs?', a: 'To exchange oxygen and carbon dioxide' },
    { q: 'Which organ pumps blood around the body?', a: 'Heart' },
    { q: 'What is a balanced diet?', a: 'Eating the right amounts of different food groups' },
    { q: 'Why is exercise important for the heart?', a: 'It keeps the heart muscle strong' },
    { q: "What can spread disease if you don't wash your hands?", a: 'Germs' },
    { q: 'What organ filters waste from your blood?', a: 'Kidneys' },
    { q: 'What should you do to protect your body from disease?', a: 'Wash your hands and eat healthily' },
  ],
};

// ── adventureJourney fact banks ─────────────────────────────────────────

const ADVENTURE_JOURNEY = {
  ems_g7_entrepreneur: [
    { q: 'What is an entrepreneur?', a: 'Someone who starts and runs their own business' },
    { q: 'What is a business plan?', a: 'A document outlining how a business will operate and grow' },
    { q: "What is 'startup capital'?", a: 'The money needed to start a business' },
    { q: 'Why is market research important?', a: 'It helps you understand what customers want' },
    { q: "What is a 'target market'?", a: 'The specific group of customers a business aims to reach' },
    { q: "What does 'profit' mean?", a: 'The money left after subtracting costs from income' },
    { q: 'What is a USP?', a: 'A unique selling point that makes a business stand out' },
    { q: 'Why is a good product name important?', a: 'It helps customers remember and trust the brand' },
    { q: "What is 'risk' in business?", a: 'The chance of losing money or failing' },
    { q: 'Why do entrepreneurs need to be resilient?', a: 'Because they will face setbacks and must keep going' },
  ],
  ems_g7_globaleconomy: [
    { q: "What is an 'exchange rate'?", a: 'The value of one currency compared to another' },
    { q: "What does 'import' mean?", a: 'Bringing goods into a country from abroad' },
    { q: "What does 'export' mean?", a: 'Sending goods to another country to sell' },
    { q: 'What is globalisation?', a: 'Countries becoming more connected through trade and technology' },
    { q: "What is a 'trade deficit'?", a: 'When a country imports more than it exports' },
    { q: "Name South Africa's currency.", a: 'Rand' },
    { q: 'What is a multinational company?', a: 'A company that operates in many countries' },
    { q: 'Why do countries trade with each other?', a: "To access goods and resources they don't produce" },
    { q: 'What is a tariff?', a: 'A tax on imported goods' },
    { q: 'What organisation promotes free trade between countries?', a: 'World Trade Organisation' },
  ],
  ems_g7_supply_demand: [
    { q: 'What happens to price when demand increases but supply stays the same?', a: 'Price rises' },
    { q: 'What happens to price when supply increases but demand stays the same?', a: 'Price falls' },
    { q: "What is 'demand'?", a: 'How much of a product people want to buy' },
    { q: "What is 'supply'?", a: 'How much of a product is available to sell' },
    { q: "What is 'scarcity'?", a: "When there isn't enough of something to meet demand" },
    { q: "What is 'equilibrium price'?", a: 'The price where supply equals demand' },
    { q: 'What happens to demand for umbrellas on a rainy day?', a: 'It increases' },
    { q: "What is a 'surplus'?", a: 'When supply is greater than demand' },
    { q: "What is a 'shortage'?", a: 'When demand is greater than supply' },
    { q: 'Why do prices of school uniforms rise in January?', a: 'High demand as schools reopen' },
    { q: "What is 'opportunity cost'?", a: 'The value of the next best option given up' },
    { q: 'How does competition affect prices?', a: 'It tends to keep prices lower' },
    { q: 'What happens to the price of a rare collectible item?', a: 'It tends to be high due to low supply' },
    { q: "What is a 'substitute good'?", a: 'A product that can replace another, like tea for coffee' },
    { q: 'How can a drought affect the price of maize?', a: 'It reduces supply, so prices rise' },
  ],
  eng_g1_reading: [
    { q: 'What do we call the people in a story?', a: 'Characters' },
    { q: 'What do we call where and when a story happens?', a: 'Setting' },
    { q: 'What is the problem in a story called?', a: 'Conflict' },
    { q: 'What is the part where the story is solved called?', a: 'Resolution' },
    { q: 'What do we call the person telling the story?', a: 'Narrator' },
    { q: 'What is the main message of a story called?', a: 'Theme' },
    { q: 'What comes first in a story?', a: 'Beginning' },
    { q: 'What comes last in a story?', a: 'Ending' },
    { q: 'What do we call a made-up story?', a: 'Fiction' },
    { q: 'What do we call a true story?', a: 'Non-fiction' },
  ],
  eng_g4_reading: [
    { q: 'What is it called when you guess what happens next?', a: 'Predicting' },
    { q: 'What is the main idea of a passage called?', a: 'Theme' },
    { q: 'What do we call words that describe feelings in a text?', a: 'Emotive language' },
    { q: "What is 'skimming' a text?", a: 'Reading quickly for the general idea' },
    { q: "What is 'scanning' a text?", a: 'Reading quickly to find specific information' },
    { q: 'What is a summary?', a: 'A short retelling of the main points' },
    { q: 'What is an inference?', a: 'A conclusion drawn from clues in the text' },
    { q: "What is the author's purpose when they want to inform?", a: 'To give facts and information' },
    { q: "What is the author's purpose when they want to persuade?", a: 'To convince the reader of an opinion' },
    { q: 'What is a fact?', a: 'A statement that can be proven true' },
    { q: 'What is an opinion?', a: 'A personal belief or view' },
    { q: 'What is context in reading?', a: 'The information around a word that helps explain its meaning' },
    { q: 'What do we call the sequence of events in a story?', a: 'Plot' },
    { q: "What is a 'cause' in a cause-and-effect passage?", a: 'The reason something happens' },
    { q: "What is an 'effect' in a cause-and-effect passage?", a: 'The result of what happens' },
  ],
  eng_g7_comprehension: [
    { q: "What is 'tone' in a passage?", a: "The author's attitude towards the subject" },
    { q: "What is 'bias' in a text?", a: 'A one-sided or unfair view' },
    { q: 'What is a rhetorical question?', a: 'A question asked for effect, not needing an answer' },
    { q: "What does 'skim reading' help you find?", a: 'The general idea of a text quickly' },
    { q: "What is a 'counter-argument' in a persuasive text?", a: 'An opposing point the author responds to' },
    { q: "What is 'connotation'?", a: 'The feeling or idea a word suggests beyond its meaning' },
    { q: "What is 'denotation'?", a: 'The literal dictionary meaning of a word' },
    { q: "What is an 'analogy'?", a: 'A comparison between two different things' },
    { q: "What is a 'text feature'?", a: 'Elements like headings and captions that support the text' },
    { q: "What is 'critical reading'?", a: 'Reading that questions and evaluates the text' },
    { q: "What is a 'primary source'?", a: 'A first-hand account or original document' },
    { q: "What is a 'secondary source'?", a: 'A source that interprets or analyses primary sources' },
    { q: 'What is the purpose of a topic sentence?', a: 'To introduce the main idea of a paragraph' },
    { q: "What is 'figurative language' used for?", a: 'To create vivid or imaginative meaning' },
    { q: "What is a 'summary' expected to leave out?", a: 'Minor details and examples' },
  ],
  ls_g1_body: [
    { q: 'What part of your body do you see with?', a: 'Eyes' },
    { q: 'What part of your body do you hear with?', a: 'Ears' },
    { q: 'What part of your body do you smell with?', a: 'Nose' },
    { q: 'What part of your body do you taste with?', a: 'Tongue' },
    { q: 'What part of your body pumps blood?', a: 'Heart' },
    { q: 'What part of your body helps you breathe?', a: 'Lungs' },
    { q: 'What part of your body helps you think?', a: 'Brain' },
    { q: 'What part of your body do you chew with?', a: 'Teeth' },
    { q: 'What part of your body do you walk with?', a: 'Legs' },
    { q: 'What part of your body do you hold things with?', a: 'Hands' },
    { q: 'What covers and protects your body?', a: 'Skin' },
    { q: 'What joint helps your arm bend?', a: 'Elbow' },
    { q: 'What part of your body pushes air in and out?', a: 'Lungs' },
    { q: 'What organ helps digest your food?', a: 'Stomach' },
    { q: 'What part of your body has fingers?', a: 'Hands' },
  ],
  ls_g1_safety: [
    { q: 'What number do you call in an emergency in South Africa?', a: '10111' },
    { q: 'What should you do before crossing the road?', a: 'Look both ways' },
    { q: 'What should you never do with strangers?', a: 'Get in a car with them' },
    { q: 'What should you do if you get lost in a shop?', a: 'Find a shop worker or security guard' },
    { q: 'What should you wear when riding a bicycle?', a: 'A helmet' },
    { q: 'What should you do if there is a fire?', a: 'Stop, drop and roll, then get outside' },
    { q: 'Who can you talk to if someone makes you feel unsafe?', a: 'A trusted adult' },
    { q: "What should you do before eating food from someone you don't know?", a: 'Ask a parent first' },
    { q: 'What should you never do at a swimming pool without an adult?', a: 'Never swim alone' },
    { q: 'What should you remember to carry in case of emergency?', a: "A parent's phone number" },
  ],
  ls_g4_career: [
    { q: 'What does a doctor do?', a: 'Treats sick people and helps them get better' },
    { q: 'What does an engineer do?', a: 'Designs and builds structures or systems' },
    { q: 'What does a teacher do?', a: 'Helps students learn new skills and knowledge' },
    { q: 'What does a farmer do?', a: 'Grows crops and raises animals for food' },
    { q: 'What does an accountant do?', a: 'Manages and tracks money for people or businesses' },
    { q: 'What does a police officer do?', a: 'Keeps communities safe and enforces the law' },
    { q: 'What does a scientist do?', a: 'Studies and investigates how the world works' },
    { q: 'What skills does a good teamworker need?', a: 'Communication and cooperation' },
    { q: "What is a 'CV' used for?", a: 'To show your skills and experience to employers' },
    { q: 'Why is further education important for many careers?', a: 'It builds the skills needed for the job' },
    { q: 'What does an architect do?', a: 'Designs buildings and spaces' },
    { q: 'What does a nurse do?', a: 'Cares for sick or injured people' },
    { q: 'What does a chef do?', a: 'Prepares and cooks food' },
    { q: 'What does a journalist do?', a: 'Researches and reports the news' },
    { q: "What is 'work experience' useful for?", a: 'Learning what a job is really like' },
  ],
  ls_g4_social: [
    { q: "What is 'teamwork'?", a: 'Working together towards a shared goal' },
    { q: 'Why is listening important in a team?', a: "It helps you understand others' ideas" },
    { q: 'What should you do if a teammate disagrees with you?', a: 'Listen and find a compromise' },
    { q: "What is a 'compromise'?", a: 'An agreement where each side gives a little' },
    { q: 'Why is it important to share tasks fairly?', a: 'So everyone contributes and no one is overloaded' },
    { q: 'What makes a good team leader?', a: 'Someone who listens and supports the team' },
    { q: 'What should you do if you make a mistake in a team project?', a: 'Own up and help fix it' },
    { q: 'Why is trust important in a team?', a: 'It helps members rely on each other' },
    { q: "What is 'empathy'?", a: 'Understanding how someone else feels' },
    { q: "How can you show respect for a teammate's ideas?", a: 'Listen without interrupting' },
  ],
  ls_g7_citizenship: [
    { q: "What is a 'right'?", a: 'Something everyone is entitled to' },
    { q: "What is a 'responsibility'?", a: 'A duty you are expected to carry out' },
    { q: 'What is active citizenship?', a: "Taking part in improving your community" },
    { q: "What document protects South Africans' rights?", a: 'The Constitution' },
    { q: 'What is one responsibility of a citizen?', a: 'Obeying the law' },
    { q: 'Why is voting an important right?', a: 'It lets citizens choose their leaders' },
    { q: "What is 'civic duty'?", a: 'A responsibility citizens have to their community' },
    { q: 'What body protects human rights in South Africa?', a: 'The South African Human Rights Commission' },
    { q: 'Why is freedom of speech important?', a: 'It allows people to share their views safely' },
    { q: "What is 'volunteering'?", a: 'Giving your time to help others without pay' },
  ],
  ls_g7_relationships: [
    { q: 'What makes a relationship healthy?', a: 'Mutual respect and trust' },
    { q: "What is 'consent'?", a: 'Freely agreeing to something' },
    { q: 'Why is communication important in relationships?', a: 'It helps people understand each other' },
    { q: 'What is a sign of an unhealthy relationship?', a: 'Controlling behaviour' },
    { q: "What is 'peer pressure'?", a: 'Being influenced by friends to do something' },
    { q: 'How can you handle peer pressure?', a: 'Confidently say no and walk away' },
    { q: 'What is empathy in a relationship?', a: "Understanding and sharing another person's feelings" },
    { q: 'Why are boundaries important?', a: 'They help protect your comfort and safety' },
    { q: 'What should you do if a friend betrays your trust?', a: 'Talk to them honestly about how you feel' },
    { q: "What is 'bullying'?", a: 'Repeated harmful behaviour towards someone' },
    { q: 'Who should you tell if you experience bullying?', a: 'A trusted adult' },
    { q: 'What makes a good friendship?', a: 'Honesty, support and kindness' },
    { q: "What is 'conflict resolution'?", a: 'Finding a fair way to solve a disagreement' },
    { q: 'Why is honesty important in relationships?', a: 'It builds trust between people' },
    { q: 'What is a healthy way to express anger?', a: 'Calmly explaining how you feel' },
  ],
  sci_g7_forces: [
    { q: 'What is a force?', a: 'A push or pull on an object' },
    { q: 'What force pulls objects towards the Earth?', a: 'Gravity' },
    { q: 'What is friction?', a: 'A force that resists motion between surfaces' },
    { q: 'What unit is force measured in?', a: 'Newtons' },
    { q: 'What happens when balanced forces act on an object?', a: 'It stays still or moves at constant speed' },
    { q: 'What happens when unbalanced forces act on an object?', a: 'It accelerates or changes direction' },
    { q: "What is 'mass'?", a: 'The amount of matter in an object' },
    { q: "What is 'weight'?", a: "The force of gravity acting on an object's mass" },
    { q: 'Who discovered the laws of motion?', a: 'Isaac Newton' },
    { q: 'What force allows a rocket to lift off?', a: 'Thrust' },
  ],
  ss_g4_ancient: [
    { q: 'Which river was central to Ancient Egyptian civilisation?', a: 'The Nile' },
    { q: 'What structures did the Ancient Egyptians build as tombs?', a: 'Pyramids' },
    { q: 'What writing system did Ancient Egyptians use?', a: 'Hieroglyphics' },
    { q: 'Which ancient civilisation built the Great Wall?', a: 'Ancient China' },
    { q: "What was Ancient Rome's system of government called?", a: 'A republic' },
    { q: 'Which ancient civilisation is known for the Parthenon?', a: 'Ancient Greece' },
    { q: 'What did Ancient Mesopotamia develop that helped record history?', a: 'Writing (cuneiform)' },
    { q: 'What was Great Zimbabwe known for building?', a: 'Stone structures and walls' },
    { q: 'What did Ancient Egyptians believe about the afterlife?', a: 'That the dead lived on in another world' },
    { q: 'Which ancient African kingdom traded gold along the Indian Ocean?', a: 'Mapungubwe' },
  ],
  ss_g4_democracy: [
    { q: "What does 'democracy' mean?", a: 'Government by the people' },
    { q: 'How do citizens choose their leaders in a democracy?', a: 'By voting in elections' },
    { q: "What is a 'constitution'?", a: 'The supreme law of a country' },
    { q: 'Why is it important to have more than one political party?', a: 'It gives citizens real choices' },
    { q: "What is a 'referendum'?", a: 'A public vote on a specific issue' },
    { q: "What does 'majority rule' mean?", a: 'The option with the most votes wins' },
    { q: 'Why are free elections important?', a: 'They let citizens choose leaders fairly' },
    { q: "What is a 'political party'?", a: 'A group with shared political goals' },
    { q: 'What right allows citizens to share their opinions publicly?', a: 'Freedom of speech' },
    { q: 'Who can vote in a South African national election?', a: 'Citizens 18 and older' },
  ],
  ss_g4_heroes: [
    { q: "Who was South Africa's first democratically elected president?", a: 'Nelson Mandela' },
    { q: 'On which island was Nelson Mandela imprisoned?', a: 'Robben Island' },
    { q: "Who was a key anti-apartheid leader and Mandela's close ally?", a: 'Oliver Tambo' },
    { q: "Which women's leader organised the 1956 anti-pass march?", a: 'Lilian Ngoyi' },
    { q: 'What organisation did many liberation heroes belong to?', a: 'The African National Congress' },
    { q: 'Who was Steve Biko?', a: 'A Black Consciousness Movement leader' },
    { q: 'What year did Nelson Mandela become president?', a: '1994' },
    { q: 'What was Albertina Sisulu known for?', a: 'Anti-apartheid activism and leadership' },
    { q: 'What is 16 June known as in South Africa?', a: 'Youth Day, honouring the 1976 Soweto uprising' },
    { q: "Who received the Nobel Peace Prize with Mandela in 1993?", a: 'F.W. de Klerk' },
  ],
  ss_g4_indigenous: [
    { q: "Who are considered South Africa's earliest inhabitants?", a: 'The San people' },
    { q: 'What were the San people known for?', a: 'Hunting, gathering and rock art' },
    { q: 'What were the Khoikhoi known for?', a: 'Herding livestock' },
    { q: 'What language family do many indigenous SA languages belong to?', a: 'Bantu languages' },
    { q: "What is 'ubuntu'?", a: 'A philosophy of humanity and community' },
    { q: 'What did indigenous South Africans use rock art to record?', a: 'Stories, beliefs and daily life' },
    { q: 'Which indigenous group herded cattle in the Cape before colonisation?', a: 'The Khoikhoi' },
    { q: 'What tool did San hunters use?', a: 'Bow and arrow' },
    { q: 'Where can famous San rock art be found?', a: 'The Drakensberg mountains' },
    { q: 'What did indigenous communities often use to pass down history?', a: 'Oral tradition and storytelling' },
  ],
  ss_g7_apartheid: [
    { q: 'What year did apartheid officially begin?', a: '1948' },
    { q: 'What law forced people to live in separate areas by race?', a: 'The Group Areas Act' },
    { q: 'What document did people have to carry under apartheid?', a: 'A pass (passbook)' },
    { q: 'What was the 1976 student uprising called?', a: 'The Soweto Uprising' },
    { q: 'Who led the ANC during much of the anti-apartheid struggle?', a: 'Oliver Tambo, then Nelson Mandela' },
    { q: 'What year did apartheid officially end?', a: '1994' },
    { q: 'What was the armed wing of the ANC called?', a: 'Umkhonto we Sizwe' },
    { q: 'What international action did many countries take against apartheid?', a: 'Economic sanctions' },
    { q: 'What commission investigated apartheid-era crimes after 1994?', a: 'The Truth and Reconciliation Commission' },
    { q: 'Who chaired the Truth and Reconciliation Commission?', a: 'Archbishop Desmond Tutu' },
    { q: 'What day commemorates the Sharpeville Massacre?', a: 'Human Rights Day, 21 March' },
    { q: 'What law classified South Africans by race?', a: 'The Population Registration Act' },
    { q: "What education law limited Black South Africans' schooling?", a: 'The Bantu Education Act' },
    { q: "What was a 'homeland' under apartheid?", a: 'A designated area for Black South Africans' },
    { q: 'What did the 1994 election mark for South Africa?', a: 'The first democratic election for all races' },
  ],
  ss_g7_democracy: [
    { q: "What year was South Africa's first democratic election?", a: '1994' },
    { q: 'What document is the supreme law of South Africa?', a: 'The Constitution' },
    { q: "What body drafted South Africa's Constitution?", a: 'The Constitutional Assembly' },
    { q: "What does the Bill of Rights protect?", a: "Citizens' fundamental rights and freedoms" },
    { q: "What is South Africa's system of government?", a: 'A constitutional democracy' },
    { q: "How many branches does South Africa's government have?", a: 'Three (executive, legislative, judicial)' },
    { q: 'What is the role of the Constitutional Court?', a: 'To ensure laws align with the Constitution' },
    { q: "What is 'separation of powers'?", a: 'Dividing government into independent branches' },
    { q: 'What does universal suffrage mean?', a: 'All adult citizens have the right to vote' },
    { q: "Who was South Africa's first democratically elected president?", a: 'Nelson Mandela' },
  ],
  ss_g7_globalisation: [
    { q: 'What is globalisation?', a: 'Growing interconnection between countries and economies' },
    { q: 'What technology sped up globalisation?', a: 'The internet' },
    { q: 'What is a benefit of globalisation?', a: 'Access to a wider variety of goods and ideas' },
    { q: 'What is a downside of globalisation?', a: 'Local businesses can struggle to compete' },
    { q: "What is 'cultural globalisation'?", a: 'The spread of ideas and culture across the world' },
    { q: 'What organisation regulates international trade?', a: 'The World Trade Organisation' },
    { q: 'What is a multinational corporation?', a: 'A company operating in many countries' },
    { q: 'How has globalisation affected jobs?', a: 'It has shifted many jobs to other countries' },
    { q: "What is 'outsourcing'?", a: 'Hiring workers in another country to do the work' },
    { q: 'What role do container ships play in globalisation?', a: 'They transport goods around the world' },
  ],
  ss_g7_rights: [
    { q: "What document lists South Africans' basic rights?", a: 'The Bill of Rights' },
    { q: 'What international document lists universal rights?', a: 'The Universal Declaration of Human Rights' },
    { q: 'What is a human right?', a: 'A basic freedom every person is entitled to' },
    { q: 'What right protects people from unfair discrimination?', a: 'The right to equality' },
    { q: 'What right allows people to practise any religion?', a: 'Freedom of religion' },
    { q: "What right protects children specifically in South Africa?", a: "Children's rights in the Constitution" },
    { q: 'Who can approach the courts if their rights are violated?', a: 'Any South African citizen' },
    { q: 'What body investigates human rights violations in SA?', a: 'The South African Human Rights Commission' },
    { q: 'What day is celebrated as Human Rights Day?', a: '21 March' },
    { q: 'What historic event does Human Rights Day commemorate?', a: 'The Sharpeville Massacre' },
  ],
  tech_g4_robot: [
    { q: 'What is a robot?', a: 'A machine that can be programmed to perform tasks' },
    { q: 'What do sensors help a robot do?', a: 'Detect and respond to its environment' },
    { q: 'What powers most robots?', a: 'Electricity and batteries' },
    { q: "What is a robot 'actuator'?", a: 'A part that creates movement' },
    { q: 'What field of study includes designing robots?', a: 'Robotics' },
    { q: 'What do we call the instructions that tell a robot what to do?', a: 'A program or code' },
    { q: 'Where are robots commonly used in factories?', a: 'Assembly lines' },
    { q: 'What is an example of a robot used at home?', a: 'A robot vacuum cleaner' },
    { q: 'What must a robot have to move around?', a: 'Motors and wheels or legs' },
    { q: 'Why are robots useful for dangerous jobs?', a: 'They can work without risking human safety' },
  ],
  tech_g7_impact: [
    { q: 'What is a positive impact of technology on communication?', a: 'It connects people instantly across distances' },
    { q: 'What is a negative impact of too much screen time?', a: 'It can affect health and sleep' },
    { q: 'How has technology changed how we shop?', a: 'Through online shopping' },
    { q: "What is 'e-waste'?", a: 'Discarded electronic devices' },
    { q: 'How can technology help the environment?', a: 'Through renewable energy solutions' },
    { q: "What is 'automation'?", a: 'Using machines to do tasks once done by people' },
    { q: 'How has technology changed healthcare?', a: 'Through better diagnosis and treatment tools' },
    { q: 'What is a risk of sharing personal information online?', a: 'Identity theft or privacy loss' },
    { q: 'How has technology changed education?', a: 'Through online learning and digital resources' },
    { q: "What is the 'digital divide'?", a: 'The gap between those with and without technology access' },
  ],
  tech_g7_innovation: [
    { q: 'What is innovation?', a: 'Creating new ideas or improving existing ones' },
    { q: 'What is the first step in the design process?', a: 'Identifying the problem' },
    { q: 'Why is testing important in design?', a: 'It shows if a solution actually works' },
    { q: "What is a 'prototype'?", a: 'An early sample model of a design' },
    { q: 'Why is user feedback important in innovation?', a: 'It helps improve the design to meet real needs' },
    { q: "What does 'iterate' mean in design?", a: 'To repeat and refine a design' },
    { q: "What is 'sustainable design'?", a: 'Design that minimises harm to the environment' },
    { q: 'Why do inventors patent their ideas?', a: 'To protect their invention from being copied' },
    { q: "What is 'brainstorming' used for?", a: 'Generating many possible ideas' },
    { q: 'What makes an innovation successful?', a: 'It solves a real problem effectively' },
  ],
};

// Alphabet is authored separately: single-letter/number answers rely on the
// letter/number distractor heuristics above rather than the phrase pool.
ADVENTURE_JOURNEY.eng_g1_alphabet = [
  { q: 'How many letters are in the English alphabet?', a: '26' },
  { q: 'What is the first letter of the alphabet?', a: 'A' },
  { q: 'What is the last letter of the alphabet?', a: 'Z' },
  { q: 'Which letter comes after G?', a: 'H' },
  { q: 'Which letter comes before M?', a: 'L' },
  { q: 'Is B a vowel or a consonant?', a: 'Consonant' },
  { q: 'Which letter is a vowel?', a: 'E' },
  { q: "What letter does 'Apple' start with?", a: 'A' },
  { q: "What letter does 'Ball' start with?", a: 'B' },
  { q: "What letter does 'Cat' start with?", a: 'C' },
  { q: 'Which letter comes between D and F?', a: 'E' },
  { q: 'Is O a vowel or a consonant?', a: 'Vowel' },
  { q: "What letter does 'Sun' start with?", a: 'S' },
  { q: 'Which letter comes right after Y?', a: 'Z' },
  { q: "What letter does 'Dog' start with?", a: 'D' },
];

module.exports = { TUG_OF_WAR, ADVENTURE_JOURNEY, toQuizItems, toJourneyStages, autoDistractors };
