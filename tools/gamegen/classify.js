'use strict';

/**
 * Cognitive-verb → engine mapping (CLAUDE.md gamegen Phase A table) and the
 * curriculum-analysis lookup that assigns a cognitiveVerb to every catalog
 * topic. This module is the single source of truth for "which engine should
 * this topic use" — both generate.js (assignment) and validate.js (the gate)
 * import it, so the check is never a tautology against whatever the catalog
 * already says.
 */

// cognitiveVerb category -> allowed engine(s)
const VERB_TO_ENGINES = {
  count_compare: ['numberCountingDuel', 'multiplesMerge'],
  order_sequence: ['sequenceBuilder'],
  locate_map: ['explorerMap'],
  connect_systems: ['circuitBuilder'],
  money_budget: ['budgetBuilder'],
  rapid_recall: ['tugOfWar'],
  word_classify: ['runnerCollector'],
  narrative_comprehension: ['adventureJourney'],
};

const VERB_LABELS = {
  count_compare: 'count / compare',
  order_sequence: 'order / sequence / stages / cycles',
  locate_map: 'locate / map / places',
  connect_systems: 'connect / systems / flows',
  money_budget: 'money / budget / needs vs wants',
  rapid_recall: 'rapid-recall fluency',
  word_classify: 'word / grammar / classification',
  narrative_comprehension: 'narrative comprehension / word problems',
};

// Deterministic per-topic classification, keyed by "topicId/subtopicId".
// Built from a manual curriculum pass over every catalog entry (see
// tools/gamegen/README.md) rather than fuzzy keyword matching, because the
// same subtopicId (e.g. "climate_zones", "comprehension") legitimately maps
// to different cognitive verbs at different grades.
const BY_TOPIC_KEY = {
  // Mathematics
  'numbers/counting': 'count_compare',
  'operations/addition': 'rapid_recall',
  'operations/subtraction': 'rapid_recall',
  'operations/mixed_operations': 'order_sequence',
  'multiplication/multiples': 'count_compare',
  'fractions/fractions_operations': 'count_compare',
  'geometry/shapes_angles': 'word_classify',
  'measurement/conversions': 'rapid_recall',
  'data/graphs_tables': 'count_compare',
  'decimals/decimal_operations': 'rapid_recall',
  'multiplication/multi_digit': 'order_sequence',
  'division/long_division': 'rapid_recall',
  'patterns/number_sequences': 'order_sequence',
  'problem_solving/word_problems': 'narrative_comprehension',
  'multiplication/times_tables': 'rapid_recall',
  'integers/integer_operations': 'rapid_recall',
  'algebra/linear_equations': 'rapid_recall',
  'ratio/ratios_proportions': 'count_compare',
  'geometry/constructions': 'order_sequence',
  'data/statistics': 'count_compare',
  'percentages/percentage_applications': 'rapid_recall',
  'fractions/fraction_operations': 'count_compare',
  'data/probability': 'narrative_comprehension',

  // English
  'phonics/alphabet': 'narrative_comprehension',
  'spelling/cvc_words': 'order_sequence',
  'phonics/blending': 'rapid_recall',
  'reading/comprehension': 'narrative_comprehension',
  'grammar/parts_of_speech': 'word_classify',
  'grammar/nouns': 'word_classify',
  'grammar/verbs_tense': 'word_classify',
  'vocabulary/synonyms_antonyms': 'count_compare',
  'spelling/grade_level_words': 'rapid_recall',
  'punctuation/punctuation_rules': 'word_classify',
  'writing/story_structure': 'order_sequence',
  'literature/poetry': 'word_classify',
  'vocabulary/idioms': 'count_compare',
  'speaking/debate': 'rapid_recall',
  'grammar/complex_grammar': 'word_classify',
  'language/figurative_language': 'word_classify',
  'writing/essay_structure': 'order_sequence',
  'speaking/formal_debate': 'rapid_recall',
  'reading/media_texts': 'word_classify',
  'spelling/advanced_spelling': 'rapid_recall',
  'speaking/oral_presentation': 'order_sequence',

  // Life Skills
  'personal_care/body_parts': 'narrative_comprehension',
  'social_skills/emotions': 'word_classify',
  'safety/personal_safety': 'narrative_comprehension',
  'beginning_knowledge/community_helpers': 'locate_map',
  'health/healthy_habits': 'rapid_recall',
  'careers/career_exploration': 'narrative_comprehension',
  'financial_literacy/budgeting': 'money_budget',
  'health/healthy_living': 'word_classify',
  'social_skills/teamwork': 'narrative_comprehension',
  'environment/conservation': 'word_classify',
  'relationships/healthy_relationships': 'narrative_comprehension',
  'careers/career_pathways': 'locate_map',
  'mental_health/wellbeing': 'rapid_recall',
  'citizenship/rights_responsibilities': 'narrative_comprehension',
  'digital_literacy/online_safety': 'word_classify',

  // Natural Sciences / Technology
  'ecology/ecosystems': 'connect_systems',
  'matter/states_of_matter': 'word_classify',
  'energy/energy_types': 'word_classify',
  'biology/life_cycles': 'order_sequence',
  'earth_science/solar_system': 'locate_map',
  'weather/weather_patterns': 'rapid_recall',
  'technology/simple_machines': 'connect_systems',
  'technology/coding_basics': 'order_sequence',
  'technology/electric_circuits': 'connect_systems',
  'technology/robotics': 'narrative_comprehension',
  'energy/energy_transformations': 'order_sequence',
  'biology/cells': 'word_classify',
  'ecology/food_webs': 'connect_systems',
  'matter/physical_chemical_changes': 'word_classify',
  'ecology/food_chains': 'connect_systems',
  'biology/reproduction': 'word_classify',
  'physics/forces': 'narrative_comprehension',
  'matter/separating_mixtures': 'order_sequence',
  'biology/human_health': 'rapid_recall',
  'matter/atoms_molecules': 'connect_systems',
  'electric_circuits/series_circuits': 'connect_systems',
  'electric_circuits/parallel_circuits': 'connect_systems',
  'design/design_process': 'order_sequence',
  'structures/forces_structures': 'connect_systems',
  'mechanisms/gears_levers_pulleys': 'connect_systems',
  'electronics/switching_circuits': 'connect_systems',
  'materials/material_selection': 'word_classify',
  'systems/input_process_output': 'order_sequence',
  'technology_society/impact': 'narrative_comprehension',
  'design/innovation': 'narrative_comprehension',

  // Social Sciences
  'geography/map_skills': 'locate_map',
  'geography/sa_provinces': 'locate_map',
  'geography/climate_zones/grade4': 'word_classify',
  'geography/climate_zones/grade7': 'locate_map',
  'geography/water_cycle': 'order_sequence',
  'geography/biomes': 'locate_map',
  'history/ancient_civilizations': 'narrative_comprehension',
  'history/indigenous_peoples': 'narrative_comprehension',
  'history/colonization': 'order_sequence',
  'history/liberation_heroes': 'narrative_comprehension',
  'history/democracy': 'narrative_comprehension',
  'history/apartheid': 'narrative_comprehension',
  'history/timeline': 'order_sequence',
  'history/liberation_leaders': 'count_compare',
  'geography/rivers': 'locate_map',
  'geography/settlements': 'word_classify',
  'geography/population': 'count_compare',
  'geography/globalisation': 'narrative_comprehension',
  'history/human_rights': 'narrative_comprehension',

  // EMS
  'economics/basic_economics': 'money_budget',
  'economics/supply_demand': 'narrative_comprehension',
  'business/entrepreneurship': 'narrative_comprehension',
  'financial_literacy/banking': 'money_budget',
  'economics/taxation': 'rapid_recall',
  'accounting/profit_loss': 'money_budget',
  'economics/consumer_rights': 'word_classify',
  'financial_literacy/savings': 'money_budget',
  'economics/global_economy': 'narrative_comprehension',
};

/**
 * @param {{id: string, topicId: string, subtopicId: string, grade: string}} entry
 * @returns {keyof typeof VERB_TO_ENGINES}
 */
function classify(entry) {
  const gradeKey = `${entry.topicId}/${entry.subtopicId}/${entry.grade}`;
  if (BY_TOPIC_KEY[gradeKey]) return BY_TOPIC_KEY[gradeKey];
  const key = `${entry.topicId}/${entry.subtopicId}`;
  const verb = BY_TOPIC_KEY[key];
  if (!verb) {
    throw new Error(
      `No cognitiveVerb classification for topic "${key}" (id: ${entry.id}). ` +
        `Add it to tools/gamegen/classify.js BY_TOPIC_KEY.`
    );
  }
  return verb;
}

function expectedEngines(verb) {
  return VERB_TO_ENGINES[verb];
}

module.exports = { classify, VERB_TO_ENGINES, VERB_LABELS, expectedEngines };
