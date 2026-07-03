'use strict';

/**
 * multiplesMerge packs: the engine's grid-and-chain mechanic is inherently
 * numeric, but several catalog topics assigned here (vocabulary, idioms,
 * history) are word-matching, not arithmetic. `mode: 'pairs'` reuses the
 * exact same grid/path/distractor procedural logic (see
 * lib/features/games/multiples_merge/multiples_merge_engine.dart) with
 * token strings instead of computed multiples — same tested mechanic,
 * topic-appropriate content.
 */

const NUMERIC = {
  math_g1_multiples: { tables: [2, 3, 4, 5], gridSize: 4, chainLength: 4 },
  math_g4_fractions: { tables: [2, 3, 4, 5, 6, 8, 9, 10, 12], gridSize: 5, chainLength: 5 },
  math_g4_data: { tables: [5, 10, 15, 20, 25], gridSize: 4, chainLength: 4 },
  math_g7_ratio: { tables: [2, 3, 4, 5, 6, 7, 8, 9], gridSize: 5, chainLength: 5 },
  math_g7_stats: { tables: [3, 4, 5, 6, 7, 8, 9, 11], gridSize: 5, chainLength: 5 },
  math_g7_fractions: { tables: [2, 3, 4, 5, 6, 7, 8, 9, 10, 12], gridSize: 5, chainLength: 6 },
};

const PAIRS = {
  eng_g4_idioms: {
    gridSize: 4,
    chainLength: 2,
    tokenGroups: [
      ['break the ice', 'do something to relax people'],
      ['piece of cake', 'something very easy'],
      ['hit the books', 'study hard'],
      ['under the weather', 'feeling unwell'],
      ['spill the beans', 'reveal a secret'],
      ['once in a blue moon', 'very rarely'],
      ['costs an arm and a leg', 'very expensive'],
      ['let the cat out of the bag', 'reveal a secret by accident'],
      ['on the ball', 'alert and doing a good job'],
      ['a blessing in disguise', 'something good that seemed bad at first'],
    ],
  },
  eng_g4_vocabulary: {
    gridSize: 4,
    chainLength: 2,
    tokenGroups: [
      ['happy', 'joyful'],
      ['sad', 'unhappy'],
      ['big', 'huge'],
      ['small', 'tiny'],
      ['fast', 'quick'],
      ['hot', 'cold'],
      ['light', 'dark'],
      ['begin', 'start'],
      ['end', 'finish'],
      ['brave', 'courageous'],
    ],
  },
  eng_g7_vocabulary: {
    gridSize: 5,
    chainLength: 2,
    tokenGroups: [
      ['benevolent', 'kind'],
      ['malicious', 'spiteful'],
      ['abundant', 'plentiful'],
      ['scarce', 'insufficient'],
      ['candid', 'honest'],
      ['ambiguous', 'unclear'],
      ['resilient', 'tough'],
      ['fragile', 'delicate'],
      ['diligent', 'hardworking'],
      ['reluctant', 'unwilling'],
      ['eloquent', 'articulate'],
    ],
  },
  ss_g7_leaders: {
    gridSize: 4,
    chainLength: 2,
    tokenGroups: [
      ['Nelson Mandela', "South Africa's first democratic president"],
      ['Oliver Tambo', 'Led the ANC in exile for decades'],
      ['Albertina Sisulu', 'Anti-apartheid activist and community leader'],
      ['Steve Biko', 'Founded the Black Consciousness Movement'],
      ['Lilian Ngoyi', 'Led the 1956 anti-pass march'],
      ['Desmond Tutu', 'Chaired the Truth and Reconciliation Commission'],
      ['Walter Sisulu', 'Key ANC leader and Rivonia trialist'],
      ['Helen Joseph', 'Anti-apartheid activist and organiser'],
      ['Chris Hani', 'Leader of the SACP and MK'],
      ['F.W. de Klerk', 'Ended apartheid and released Mandela'],
    ],
  },
  ss_g7_population: {
    gridSize: 4,
    chainLength: 2,
    tokenGroups: [
      ['birth rate', 'number of births per 1000 people per year'],
      ['death rate', 'number of deaths per 1000 people per year'],
      ['population density', 'number of people per square kilometre'],
      ['urbanisation', 'growth of the population living in cities'],
      ['migration', 'movement of people from one place to another'],
      ['life expectancy', 'average number of years a person is expected to live'],
      ['census', 'official count of a country’s population'],
      ['population pyramid', 'graph showing age and gender structure'],
      ['emigration', 'people leaving a country to live elsewhere'],
      ['immigration', 'people arriving to live in a new country'],
    ],
  },
};

function numericPack(id, count) {
  const spec = NUMERIC[id];
  return { mode: 'numeric', gridSize: spec.gridSize, chainLength: spec.chainLength, tables: spec.tables };
}

function pairsPack(id) {
  const spec = PAIRS[id];
  return { mode: 'pairs', gridSize: spec.gridSize, chainLength: spec.chainLength, tokenGroups: spec.tokenGroups };
}

module.exports = { NUMERIC, PAIRS, numericPack, pairsPack };
