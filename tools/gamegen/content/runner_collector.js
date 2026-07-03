'use strict';

/**
 * runnerCollector packs: 3-5 levels, each a classification challenge with
 * a `targetClass` bucket to collect and 2-4 `buckets` of words to sort
 * between. See tools/gamegen/README.md for why buckets are a generic map
 * (engine-side change) rather than the original noun/verb/adjective/
 * pronoun-only shape.
 */

const BANKS = {
  eng_g1_grammar: {
    buckets: {
      noun: ['dog', 'house', 'school', 'river', 'table', 'book', 'city', 'teacher'],
      verb: ['run', 'eat', 'jump', 'sleep', 'play', 'swim'],
      adjective: ['happy', 'big', 'cold', 'fast', 'small'],
    },
    levels: [
      { targetClass: 'noun', missionLabel: 'Collect only Nouns! 📦', scrollSpeed: 0.08 },
      { targetClass: 'verb', missionLabel: 'Collect only Verbs! 🏃', scrollSpeed: 0.1 },
      { targetClass: 'adjective', missionLabel: 'Collect only Adjectives! ✨', scrollSpeed: 0.12 },
    ],
  },
  eng_g4_grammar_nouns: {
    buckets: {
      'common noun': ['dog', 'city', 'teacher', 'river', 'shop', 'phone', 'chair', 'garden'],
      'proper noun': ['Cape Town', 'Mandela', 'Gauteng', 'Limpopo', 'Zulu', 'Durban', 'Africa', 'Monday'],
      'collective noun': ['herd', 'flock', 'team', 'family', 'class', 'swarm', 'pack', 'crowd'],
    },
    levels: [
      { targetClass: 'common noun', missionLabel: 'Collect common nouns! 🏙️', scrollSpeed: 0.09 },
      { targetClass: 'proper noun', missionLabel: 'Collect proper nouns! 🌍', scrollSpeed: 0.1 },
      { targetClass: 'collective noun', missionLabel: 'Collect collective nouns! 👥', scrollSpeed: 0.12 },
    ],
  },
  eng_g4_grammar_verbs: {
    buckets: {
      present: ['walk', 'eat', 'play', 'sing', 'run', 'read', 'write', 'jump'],
      past: ['walked', 'ate', 'played', 'sang', 'ran', 'read', 'wrote', 'jumped'],
      future: ['will walk', 'will eat', 'will play', 'will sing', 'will run', 'will read', 'will write'],
    },
    levels: [
      { targetClass: 'present', missionLabel: 'Collect present tense! ⏱️', scrollSpeed: 0.09 },
      { targetClass: 'past', missionLabel: 'Collect past tense! ⏪', scrollSpeed: 0.11 },
      { targetClass: 'future', missionLabel: 'Collect future tense! ⏩', scrollSpeed: 0.13 },
    ],
  },
  eng_g4_poetry: {
    buckets: {
      simile: ['as brave as a lion', 'like a shining star', 'as quiet as a mouse', 'like a rolling wave'],
      metaphor: ['the classroom is a zoo', 'time is money', 'her voice is music', 'the world is a stage'],
      onomatopoeia: ['buzz', 'crash', 'sizzle', 'splash', 'boom', 'whisper'],
    },
    levels: [
      { targetClass: 'simile', missionLabel: 'Collect similes! 🦁', scrollSpeed: 0.09 },
      { targetClass: 'metaphor', missionLabel: 'Collect metaphors! 🎭', scrollSpeed: 0.11 },
      { targetClass: 'onomatopoeia', missionLabel: 'Collect onomatopoeia! 💥', scrollSpeed: 0.1 },
    ],
  },
  eng_g4_punctuation: {
    buckets: {
      'full stop': ['I like dogs.', 'She went home.', 'It is raining.', 'We play soccer.'],
      'question mark': ['Are you okay?', 'What is your name?', 'Where do you live?', 'Can you help me?'],
      'exclamation mark': ['Watch out!', 'That is amazing!', "Let's go!", 'Wow, well done!'],
    },
    levels: [
      { targetClass: 'full stop', missionLabel: 'Collect statements! 🔵', scrollSpeed: 0.09 },
      { targetClass: 'question mark', missionLabel: 'Collect questions! ❓', scrollSpeed: 0.1 },
      { targetClass: 'exclamation mark', missionLabel: 'Collect exclamations! ❗', scrollSpeed: 0.12 },
    ],
  },
  eng_g7_figurative: {
    buckets: {
      simile: ['as fast as lightning', 'like a hawk circling', 'as cold as ice', 'like a lion roaring'],
      metaphor: ['the news was a bombshell', 'her heart is stone', 'the city never sleeps', 'life is a journey'],
      personification: ['the wind whispered', 'the sun smiled down', 'the trees danced', 'the shadows crept in'],
      hyperbole: ["I've told you a million times", "I'm so hungry I could eat a horse", "it weighs a ton"],
    },
    levels: [
      { targetClass: 'simile', missionLabel: 'Collect similes! ⚡', scrollSpeed: 0.11 },
      { targetClass: 'metaphor', missionLabel: 'Collect metaphors! 🗿', scrollSpeed: 0.12 },
      { targetClass: 'personification', missionLabel: 'Collect personification! 🌳', scrollSpeed: 0.13 },
      { targetClass: 'hyperbole', missionLabel: 'Collect hyperbole! 🏔️', scrollSpeed: 0.13 },
    ],
  },
  eng_g7_grammar: {
    buckets: {
      'active voice': ['The dog chased the cat.', 'Zanele wrote the letter.', 'The team won the match.', 'The chef cooked dinner.'],
      'passive voice': ['The cat was chased by the dog.', 'The letter was written by Zanele.', 'The match was won by the team.', 'Dinner was cooked by the chef.'],
      'subordinate clause': ['because it was raining', 'although she was tired', 'when the bell rings', 'if you study hard'],
      'independent clause': ['She stayed inside.', 'He finished his homework.', 'They arrived on time.'],
    },
    levels: [
      { targetClass: 'active voice', missionLabel: 'Collect active voice! 🏃', scrollSpeed: 0.11 },
      { targetClass: 'passive voice', missionLabel: 'Collect passive voice! 🔄', scrollSpeed: 0.12 },
      { targetClass: 'subordinate clause', missionLabel: 'Collect subordinate clauses! 🔗', scrollSpeed: 0.13 },
      { targetClass: 'independent clause', missionLabel: 'Collect independent clauses! ✅', scrollSpeed: 0.13 },
    ],
  },
  eng_g7_media: {
    buckets: {
      fact: ['South Africa has 11 official languages.', 'The Vaal is a river.', 'Cape Town hosted the 2010 World Cup matches.', 'Table Mountain is in Cape Town.'],
      opinion: ['That was the best movie ever.', 'Soccer is more exciting than rugby.', 'This is the tastiest food in town.'],
      bias: ['Only our product actually works!', "Everyone knows the other side is wrong.", 'Experts (unnamed) agree with us.'],
    },
    levels: [
      { targetClass: 'fact', missionLabel: 'Collect facts! 📰', scrollSpeed: 0.1 },
      { targetClass: 'opinion', missionLabel: 'Collect opinions! 💭', scrollSpeed: 0.11 },
      { targetClass: 'bias', missionLabel: 'Collect biased statements! ⚠️', scrollSpeed: 0.12 },
    ],
  },
  eng_g7_poetry: {
    buckets: {
      rhyme: ['cat / hat', 'light / night', 'rain / pain', 'sky / fly'],
      alliteration: ['the wild wind whistled', 'she sells seashells', 'busy bees buzzing', 'proud peacocks prancing'],
      onomatopoeia: ['crackle', 'thud', 'hiss', 'clang', 'murmur'],
    },
    levels: [
      { targetClass: 'rhyme', missionLabel: 'Collect rhyming pairs! 🎵', scrollSpeed: 0.1 },
      { targetClass: 'alliteration', missionLabel: 'Collect alliteration! 🔤', scrollSpeed: 0.11 },
      { targetClass: 'onomatopoeia', missionLabel: 'Collect onomatopoeia! 💥', scrollSpeed: 0.12 },
    ],
  },
  ls_g1_feelings: {
    buckets: {
      happy: ['smiling', 'laughing', 'excited', 'proud', 'cheerful'],
      sad: ['crying', 'lonely', 'disappointed', 'gloomy', 'upset'],
      angry: ['frustrated', 'furious', 'annoyed', 'cross', 'grumpy'],
      scared: ['nervous', 'worried', 'frightened', 'anxious', 'shy'],
    },
    levels: [
      { targetClass: 'happy', missionLabel: 'Collect happy feelings! 😄', scrollSpeed: 0.07 },
      { targetClass: 'sad', missionLabel: 'Collect sad feelings! 😢', scrollSpeed: 0.07 },
      { targetClass: 'angry', missionLabel: 'Collect angry feelings! 😠', scrollSpeed: 0.08 },
      { targetClass: 'scared', missionLabel: 'Collect scared feelings! 😟', scrollSpeed: 0.08 },
    ],
  },
  ls_g4_environment: {
    buckets: {
      reduce: ['use a refillable water bottle', 'switch off lights', 'buy only what you need', 'walk instead of drive'],
      reuse: ['reuse a glass jar', 'donate old clothes', 'repair broken toys', 'use both sides of paper'],
      recycle: ['recycle plastic bottles', 'recycle paper', 'recycle cans', 'recycle glass'],
    },
    levels: [
      { targetClass: 'reduce', missionLabel: 'Collect ways to Reduce! ♻️', scrollSpeed: 0.09 },
      { targetClass: 'reuse', missionLabel: 'Collect ways to Reuse! 🔁', scrollSpeed: 0.1 },
      { targetClass: 'recycle', missionLabel: 'Collect ways to Recycle! 🗑️', scrollSpeed: 0.1 },
    ],
  },
  ls_g4_health: {
    buckets: {
      healthy: ['fruit', 'vegetables', 'water', 'exercise', 'sleep', 'whole grains'],
      unhealthy: ['too much sugar', 'skipping meals', 'no exercise', 'too little sleep', 'too much screen time'],
    },
    levels: [
      { targetClass: 'healthy', missionLabel: 'Collect healthy habits! 🥗', scrollSpeed: 0.09 },
      { targetClass: 'unhealthy', missionLabel: 'Spot unhealthy habits! 🚫', scrollSpeed: 0.1 },
    ],
  },
  ls_g7_digital: {
    buckets: {
      safe: ['using a strong password', 'asking a parent before sharing photos', 'reporting a bully online', 'checking privacy settings', 'logging out of shared devices'],
      unsafe: ['sharing your address online', 'meeting an online stranger alone', 'sharing your password', 'clicking unknown links', 'posting your location publicly'],
    },
    levels: [
      { targetClass: 'safe', missionLabel: 'Collect safe online habits! 🛡️', scrollSpeed: 0.1 },
      { targetClass: 'unsafe', missionLabel: 'Spot unsafe online habits! ⚠️', scrollSpeed: 0.11 },
    ],
  },
  math_g4_geometry: {
    buckets: {
      triangle: ['3 sides, 3 angles', 'equilateral triangle', 'isosceles triangle', 'right-angled triangle', 'scalene triangle'],
      quadrilateral: ['4 sides, 4 angles', 'square', 'rectangle', 'parallelogram', 'trapezium'],
      circle: ['no straight sides', 'has a radius', 'has a diameter', 'has a circumference', 'has 360 degrees around it'],
    },
    levels: [
      { targetClass: 'triangle', missionLabel: 'Collect triangle facts! 🔺', scrollSpeed: 0.1 },
      { targetClass: 'quadrilateral', missionLabel: 'Collect quadrilateral facts! 🟦', scrollSpeed: 0.1 },
      { targetClass: 'circle', missionLabel: 'Collect circle facts! ⚪', scrollSpeed: 0.1 },
    ],
  },
  ns_g4_energy: {
    buckets: {
      renewable: ['solar energy', 'wind energy', 'hydro energy', 'geothermal energy', 'biomass energy'],
      'non-renewable': ['coal', 'oil', 'natural gas', 'nuclear fuel', 'petrol'],
    },
    levels: [
      { targetClass: 'renewable', missionLabel: 'Collect renewable energy! ☀️', scrollSpeed: 0.09 },
      { targetClass: 'non-renewable', missionLabel: 'Collect non-renewable energy! ⛽', scrollSpeed: 0.1 },
    ],
  },
  ns_g4_matter: {
    buckets: {
      solid: ['ice', 'rock', 'wood', 'a book', 'a chair'],
      liquid: ['water', 'juice', 'milk', 'oil', 'rain'],
      gas: ['steam', 'oxygen', 'helium in a balloon', 'carbon dioxide', 'the air we breathe'],
    },
    levels: [
      { targetClass: 'solid', missionLabel: 'Collect solids! 🧊', scrollSpeed: 0.09 },
      { targetClass: 'liquid', missionLabel: 'Collect liquids! 💧', scrollSpeed: 0.1 },
      { targetClass: 'gas', missionLabel: 'Collect gases! 💨', scrollSpeed: 0.1 },
    ],
  },
  sci_g7_cells: {
    buckets: {
      'plant cell part': ['cell wall', 'chloroplast', 'large vacuole', 'plastid'],
      'animal cell part': ['centriole', 'small vacuole', 'lysosome'],
      'both cell types': ['nucleus', 'cell membrane', 'cytoplasm', 'mitochondria'],
    },
    levels: [
      { targetClass: 'plant cell part', missionLabel: 'Collect plant cell parts! 🌱', scrollSpeed: 0.11 },
      { targetClass: 'animal cell part', missionLabel: 'Collect animal cell parts! 🐾', scrollSpeed: 0.11 },
      { targetClass: 'both cell types', missionLabel: 'Collect parts in both cells! 🔬', scrollSpeed: 0.11 },
    ],
  },
  sci_g7_physical: {
    buckets: {
      physical: ['melting ice', 'tearing paper', 'dissolving sugar in water', 'boiling water', 'freezing juice'],
      chemical: ['burning wood', 'rusting iron', 'baking a cake', 'food digesting', 'milk turning sour'],
    },
    levels: [
      { targetClass: 'physical', missionLabel: 'Collect physical changes! 🧊', scrollSpeed: 0.1 },
      { targetClass: 'chemical', missionLabel: 'Collect chemical changes! 🔥', scrollSpeed: 0.11 },
    ],
  },
  sci_g7_reproduction: {
    buckets: {
      sexual: ['requires two parents', 'produces genetic variation', 'seen in mammals', 'seen in flowering plants', 'seen in birds'],
      asexual: ['requires one parent', 'produces identical offspring', 'seen in bacteria', 'seen in some plants (runners)', 'budding in yeast'],
    },
    levels: [
      { targetClass: 'sexual', missionLabel: 'Collect sexual reproduction facts! 🌸', scrollSpeed: 0.1 },
      { targetClass: 'asexual', missionLabel: 'Collect asexual reproduction facts! 🦠', scrollSpeed: 0.1 },
    ],
  },
  ss_g4_climate: {
    buckets: {
      'hot and dry': ['Kalahari Desert', 'Karoo', 'low rainfall', 'sparse vegetation'],
      'warm and wet': ['Durban coast', 'subtropical', 'high humidity', 'summer rainfall'],
      'mild and dry summer': ['Cape Town', 'winter rainfall', 'Mediterranean climate', 'mild summers'],
    },
    levels: [
      { targetClass: 'hot and dry', missionLabel: 'Collect hot & dry climate facts! 🏜️', scrollSpeed: 0.1 },
      { targetClass: 'warm and wet', missionLabel: 'Collect warm & wet climate facts! 🌴', scrollSpeed: 0.1 },
      { targetClass: 'mild and dry summer', missionLabel: 'Collect Cape climate facts! 🍇', scrollSpeed: 0.1 },
    ],
  },
  ss_g7_settlement: {
    buckets: {
      urban: ['high population density', 'many tall buildings', 'formal employment', 'good service delivery', 'heavy traffic'],
      rural: ['low population density', 'farming activities', 'informal employment', 'fewer services', 'wide open land'],
    },
    levels: [
      { targetClass: 'urban', missionLabel: 'Collect urban settlement facts! 🏙️', scrollSpeed: 0.1 },
      { targetClass: 'rural', missionLabel: 'Collect rural settlement facts! 🌾', scrollSpeed: 0.1 },
    ],
  },
  tech_g7_materials: {
    buckets: {
      metal: ['strong and conducts electricity', 'steel', 'aluminium', 'copper wiring'],
      plastic: ['lightweight and waterproof', 'PVC pipe', 'polyethylene bag', 'plastic bottle'],
      wood: ['natural and renewable', 'pine plank', 'oak table', 'plywood sheet'],
      ceramic: ['hard and heat-resistant', 'clay pot', 'porcelain plate', 'brick'],
    },
    levels: [
      { targetClass: 'metal', missionLabel: 'Collect metal properties! 🔩', scrollSpeed: 0.11 },
      { targetClass: 'plastic', missionLabel: 'Collect plastic properties! 🧴', scrollSpeed: 0.11 },
      { targetClass: 'wood', missionLabel: 'Collect wood properties! 🪵', scrollSpeed: 0.11 },
      { targetClass: 'ceramic', missionLabel: 'Collect ceramic properties! 🏺', scrollSpeed: 0.11 },
    ],
  },
  ems_g7_consumer: {
    buckets: {
      right: ['the right to safety', 'the right to information', 'the right to choose', 'the right to redress', 'the right to fair value'],
      responsibility: ['read the label', 'keep your receipt', 'use products safely', 'report faulty goods', 'check the expiry date'],
    },
    levels: [
      { targetClass: 'right', missionLabel: 'Collect consumer rights! ⚖️', scrollSpeed: 0.1 },
      { targetClass: 'responsibility', missionLabel: 'Collect consumer responsibilities! 📋', scrollSpeed: 0.11 },
    ],
  },
};

module.exports = { BANKS };
