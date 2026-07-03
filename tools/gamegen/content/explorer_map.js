'use strict';

const { shuffle, rngFor, seedFromString } = require('./math');

/**
 * explorerMap packs: pins[] (real places/facts) + questions[] that ask the
 * learner to pick the correct pin. Questions are generated from each pin's
 * facts using a couple of templates, so authoring only needs real pins +
 * facts, not hand-written question text.
 */

const PALETTE = ['#E53935', '#1E88E5', '#43A047', '#FB8C00', '#8E24AA', '#00897B', '#F4511E', '#3949AB', '#00ACC1'];

function genQuestions(rng, pins, count) {
  const questions = [];
  let i = 0;
  while (questions.length < count) {
    const pin = pins[i % pins.length];
    const fact = pin.facts[Math.floor(i / pins.length) % pin.facts.length];
    const others = shuffle(rng, pins.filter((p) => p.id !== pin.id)).slice(0, 3);
    const optionIds = shuffle(rng, [pin.id, ...others.map((o) => o.id)]);
    questions.push({
      question: `Which one is true: "${fact}"?`,
      correctId: pin.id,
      optionIds,
      feedbackFact: fact,
    });
    i++;
  }
  return questions;
}

function pack(pins, questionCount) {
  const rng = rngFor(seedFromString(pins.map((p) => p.id).join(',')));
  return { pins, questions: genQuestions(rng, pins, questionCount) };
}

const PROVINCES = [
  { id: 'GP', name: 'Gauteng', capital: 'Johannesburg', emoji: '🏙️', x: 0.6, y: 0.45, facts: ['Gauteng is the smallest province but the most populous.', "Gauteng's name means 'place of gold' in Sotho."] },
  { id: 'WC', name: 'Western Cape', capital: 'Cape Town', emoji: '🍷', x: 0.25, y: 0.85, facts: ['Table Mountain is one of the New 7 Wonders of Nature.', 'The Cape Winelands are famous worldwide.'] },
  { id: 'KZN', name: 'KwaZulu-Natal', capital: 'Pietermaritzburg', emoji: '🌊', x: 0.78, y: 0.62, facts: ['The Drakensberg mountains run through KwaZulu-Natal.', 'Durban is South Africa’s busiest port city.'] },
  { id: 'EC', name: 'Eastern Cape', capital: 'Bhisho', emoji: '🐘', x: 0.55, y: 0.85, facts: ['Addo Elephant National Park is in the Eastern Cape.', 'Nelson Mandela was born in the Eastern Cape.'] },
  { id: 'LIM', name: 'Limpopo', capital: 'Polokwane', emoji: '🦁', x: 0.6, y: 0.12, facts: ['Limpopo borders Zimbabwe, Botswana and Mozambique.', 'Part of the Kruger National Park lies in Limpopo.'] },
  { id: 'MP', name: 'Mpumalanga', capital: 'Mbombela', emoji: '🌅', x: 0.72, y: 0.32, facts: ["Mpumalanga's name means 'place where the sun rises'.", 'The Blyde River Canyon is one of the largest canyons on Earth.'] },
  { id: 'NW', name: 'North West', capital: 'Mahikeng', emoji: '🌾', x: 0.45, y: 0.35, facts: ['The Sun City resort is in North West province.', 'North West is known for its maize and platinum mining.'] },
  { id: 'FS', name: 'Free State', capital: 'Bloemfontein', emoji: '🌻', x: 0.55, y: 0.6, facts: ['Bloemfontein is known as the judicial capital of South Africa.', 'The Free State is known for its wide-open maize and sunflower fields.'] },
  { id: 'NC', name: 'Northern Cape', capital: 'Kimberley', emoji: '💎', x: 0.3, y: 0.5, facts: ['The Northern Cape is the largest but least populated province.', 'Kimberley is famous for its diamond mining history.'] },
];

const MAP_SKILLS = [
  { id: 'north', name: 'North', emoji: '⬆️', x: 0.5, y: 0.1, facts: ['North is usually shown at the top of a map.', 'A compass needle points to magnetic North.'] },
  { id: 'south', name: 'South', emoji: '⬇️', x: 0.5, y: 0.9, facts: ['South is usually shown at the bottom of a map.', 'South is the opposite direction to North.'] },
  { id: 'east', name: 'East', emoji: '➡️', x: 0.9, y: 0.5, facts: ['East is the direction the sun rises from.', 'East is usually shown on the right of a map.'] },
  { id: 'west', name: 'West', emoji: '⬅️', x: 0.1, y: 0.5, facts: ['West is the direction the sun sets in.', 'West is usually shown on the left of a map.'] },
  { id: 'legend', name: 'Map Legend', emoji: '🔑', x: 0.15, y: 0.15, facts: ['A legend (key) explains what map symbols mean.', 'Without a legend, map symbols would be hard to understand.'] },
  { id: 'scale', name: 'Map Scale', emoji: '📏', x: 0.85, y: 0.15, facts: ['A scale shows how map distances relate to real distances.', 'A scale bar helps you measure real distance on a map.'] },
  { id: 'grid', name: 'Grid Reference', emoji: '#️⃣', x: 0.15, y: 0.85, facts: ['Grid references use letters and numbers to find a location.', 'Grid lines divide a map into squares for easy searching.'] },
  { id: 'contour', name: 'Contour Line', emoji: '⛰️', x: 0.85, y: 0.85, facts: ['Contour lines join points of equal height on a map.', 'Contour lines close together show steep terrain.'] },
];

const COMMUNITY_HELPERS = [
  { id: 'hospital', name: 'Hospital', emoji: '🏥', x: 0.3, y: 0.3, facts: ['Doctors and nurses at the hospital help sick and injured people.', 'A hospital has an emergency room for urgent care.'] },
  { id: 'police', name: 'Police Station', emoji: '👮', x: 0.65, y: 0.25, facts: ['Police officers keep the community safe.', 'You can call the police in an emergency.'] },
  { id: 'fire', name: 'Fire Station', emoji: '🚒', x: 0.2, y: 0.65, facts: ['Firefighters put out fires and rescue people.', 'Fire trucks carry water, hoses and ladders.'] },
  { id: 'school', name: 'School', emoji: '🏫', x: 0.5, y: 0.5, facts: ['Teachers at school help children learn.', 'Schools have classrooms, a library and a playground.'] },
  { id: 'clinic', name: 'Clinic', emoji: '💉', x: 0.75, y: 0.55, facts: ['A clinic gives check-ups and vaccinations.', 'Nurses at a clinic care for the community.'] },
  { id: 'post_office', name: 'Post Office', emoji: '📮', x: 0.35, y: 0.75, facts: ['The post office helps send and receive letters and parcels.', 'You can pay some bills at the post office.'] },
  { id: 'library', name: 'Library', emoji: '📚', x: 0.6, y: 0.8, facts: ['A librarian helps you find and borrow books.', 'Libraries are quiet places to read and study.'] },
  { id: 'market', name: 'Market', emoji: '🧺', x: 0.85, y: 0.35, facts: ['Vendors at the market sell fresh fruit and vegetables.', 'Markets are a place where the community buys and sells.'] },
];

const SOLAR_SYSTEM = [
  { id: 'mercury', name: 'Mercury', emoji: '☄️', x: 0.1, y: 0.5, facts: ['Mercury is the closest planet to the Sun.', 'Mercury is the smallest planet in the solar system.'] },
  { id: 'venus', name: 'Venus', emoji: '🌕', x: 0.2, y: 0.5, facts: ['Venus is the hottest planet in the solar system.', 'Venus is often called Earth’s twin because of its similar size.'] },
  { id: 'earth', name: 'Earth', emoji: '🌍', x: 0.32, y: 0.5, facts: ['Earth is the only known planet with life.', 'Earth takes 365 days to orbit the Sun.'] },
  { id: 'mars', name: 'Mars', emoji: '🔴', x: 0.44, y: 0.5, facts: ['Mars is known as the Red Planet.', 'Mars has the largest volcano in the solar system, Olympus Mons.'] },
  { id: 'jupiter', name: 'Jupiter', emoji: '🟠', x: 0.58, y: 0.5, facts: ['Jupiter is the largest planet in the solar system.', 'Jupiter has a giant storm called the Great Red Spot.'] },
  { id: 'saturn', name: 'Saturn', emoji: '🪐', x: 0.7, y: 0.5, facts: ['Saturn is famous for its bright rings.', "Saturn's rings are made mostly of ice and rock."] },
  { id: 'uranus', name: 'Uranus', emoji: '🔵', x: 0.82, y: 0.5, facts: ['Uranus spins on its side compared to other planets.', 'Uranus appears blue-green due to methane gas.'] },
  { id: 'neptune', name: 'Neptune', emoji: '🔷', x: 0.92, y: 0.5, facts: ['Neptune is the farthest planet from the Sun.', 'Neptune has the strongest winds in the solar system.'] },
];

const BIOMES = [
  { id: 'fynbos', name: 'Fynbos', emoji: '🌸', x: 0.25, y: 0.85, facts: ['Fynbos is found mainly in the Western Cape.', 'Fynbos is one of the richest floral kingdoms on Earth.'] },
  { id: 'savanna', name: 'Savanna', emoji: '🦒', x: 0.62, y: 0.25, facts: ['Savanna covers the largest area of South Africa.', 'The Kruger National Park lies in the savanna biome.'] },
  { id: 'grassland', name: 'Grassland', emoji: '🌾', x: 0.55, y: 0.55, facts: ['Grassland covers much of the Free State and Highveld.', 'Grassland has few trees and is good for grazing animals.'] },
  { id: 'desert', name: 'Desert', emoji: '🏜️', x: 0.25, y: 0.4, facts: ['The Namaqualand desert bursts into flower after rain.', 'Deserts receive very little rainfall each year.'] },
  { id: 'forest', name: 'Forest', emoji: '🌳', x: 0.72, y: 0.65, facts: ['The Knysna forest is one of South Africa’s largest indigenous forests.', 'Forests have the highest rainfall of all SA biomes.'] },
  { id: 'thicket', name: 'Thicket', emoji: '🌿', x: 0.55, y: 0.8, facts: ['Thicket is dense, thorny vegetation found in the Eastern Cape.', 'Thicket provides food for elephants and other browsers.'] },
  { id: 'wetland', name: 'Wetland', emoji: '💧', x: 0.8, y: 0.55, facts: ['Wetlands like the iSimangaliso Wetland Park filter water naturally.', 'Wetlands are important breeding grounds for birds and fish.'] },
];

const CLIMATE_ZONES = [
  { id: 'highveld', name: 'Highveld', emoji: '⛅', x: 0.55, y: 0.4, facts: ['The Highveld has warm summers and cold, dry winters.', 'Johannesburg lies on the Highveld plateau.'] },
  { id: 'mediterranean', name: 'Mediterranean (Cape)', emoji: '🍇', x: 0.25, y: 0.85, facts: ['The Cape has a Mediterranean climate with winter rainfall.', 'Cape Town has hot, dry summers and mild, wet winters.'] },
  { id: 'subtropical', name: 'Subtropical Coast', emoji: '🌴', x: 0.78, y: 0.62, facts: ['The KZN coast is warm and humid with summer rainfall.', 'Durban has a subtropical climate most of the year.'] },
  { id: 'semi_desert', name: 'Semi-Desert (Karoo)', emoji: '🌵', x: 0.4, y: 0.65, facts: ['The Karoo is a semi-desert with very low rainfall.', 'The Karoo has huge temperature swings between day and night.'] },
  { id: 'desert_zone', name: 'Desert (Kalahari)', emoji: '🏜️', x: 0.35, y: 0.15, facts: ['The Kalahari is an arid desert region in the north.', 'The Kalahari receives less than 250mm of rain a year.'] },
  { id: 'escarpment', name: 'Escarpment', emoji: '🏔️', x: 0.7, y: 0.3, facts: ['The Drakensberg escarpment has the coldest temperatures in SA.', 'Snow can fall on the Drakensberg escarpment in winter.'] },
];

const RIVERS = [
  { id: 'orange', name: 'Orange River', emoji: '🏞️', x: 0.3, y: 0.5, facts: ["The Orange River is South Africa's longest river.", 'The Orange River forms part of the border with Namibia.'] },
  { id: 'vaal', name: 'Vaal River', emoji: '🌊', x: 0.5, y: 0.45, facts: ['The Vaal River is a major tributary of the Orange River.', 'The Vaal River supplies water to Gauteng industry and homes.'] },
  { id: 'limpopo', name: 'Limpopo River', emoji: '🐊', x: 0.6, y: 0.12, facts: ['The Limpopo River forms much of the border with Zimbabwe and Botswana.', 'The Limpopo River basin supports farming across several countries.'] },
  { id: 'tugela', name: 'Tugela River', emoji: '💦', x: 0.75, y: 0.55, facts: ['The Tugela River flows through KwaZulu-Natal.', 'The Tugela Falls is one of the tallest waterfalls in the world.'] },
  { id: 'breede', name: 'Breede River', emoji: '🚣', x: 0.28, y: 0.8, facts: ['The Breede River flows through the Western Cape winelands.', 'The Breede River is popular for canoeing.'] },
  { id: 'olifants', name: 'Olifants River', emoji: '🐘', x: 0.65, y: 0.3, facts: ['The Olifants River flows through the Kruger National Park.', 'The Olifants River is important for irrigation in Mpumalanga.'] },
];

const CAREER_PATHWAYS = [
  { id: 'health', name: 'Hospital — Health Sciences', emoji: '🏥', x: 0.2, y: 0.3, facts: ['Careers in health science include doctors, nurses and physiotherapists.', 'Health science careers usually need a university or college qualification.'] },
  { id: 'law', name: 'Court — Law', emoji: '⚖️', x: 0.5, y: 0.2, facts: ['Careers in law include lawyers, magistrates and paralegals.', 'Law careers require strong reading, writing and reasoning skills.'] },
  { id: 'education', name: 'School — Education', emoji: '🏫', x: 0.8, y: 0.3, facts: ['Careers in education include teachers, principals and curriculum advisors.', 'Education careers focus on helping others learn.'] },
  { id: 'finance', name: 'Bank — Finance', emoji: '🏦', x: 0.2, y: 0.6, facts: ['Careers in finance include accountants, bankers and financial advisors.', 'Finance careers involve managing and growing money.'] },
  { id: 'agriculture', name: 'Farm — Agriculture', emoji: '🚜', x: 0.5, y: 0.75, facts: ['Careers in agriculture include farmers and agricultural scientists.', 'Agriculture careers help produce South Africa’s food.'] },
  { id: 'media', name: 'Studio — Media & Arts', emoji: '🎬', x: 0.8, y: 0.6, facts: ['Careers in media include journalists, designers and filmmakers.', 'Media careers combine creativity with technology.'] },
  { id: 'science', name: 'Lab — Science', emoji: '🔬', x: 0.35, y: 0.45, facts: ['Careers in science include researchers and lab technicians.', 'Science careers investigate how the world works.'] },
  { id: 'engineering', name: 'Workshop — Engineering', emoji: '🛠️', x: 0.65, y: 0.45, facts: ['Careers in engineering include civil, mechanical and electrical engineers.', 'Engineering careers design and build the things we use every day.'] },
];

const TOPIC_PINS = {
  ss_g4_provinces: PROVINCES,
  ss_g4_maps: MAP_SKILLS,
  ls_g1_community: COMMUNITY_HELPERS,
  ns_g4_solar: SOLAR_SYSTEM,
  ss_g4_biomes: BIOMES,
  ss_g7_climate: CLIMATE_ZONES,
  ss_g7_rivers: RIVERS,
  ls_g7_career: CAREER_PATHWAYS,
};

function withColors(pins) {
  return pins.map((p, i) => ({ ...p, color: PALETTE[i % PALETTE.length] }));
}

module.exports = { TOPIC_PINS, withColors, pack };
