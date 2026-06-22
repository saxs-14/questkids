// Curated 7-day subject rotation. dayIndex = new Date().getDay() (0=Sun)
export const MISSION_CATALOG: Record<number, {gameId: string; subject: string; emoji: string; title: string}[]> = {
  0: [ // Sunday — Social Sciences + Life Skills
    { gameId: "ssc_g5_africa", subject: "Social Sciences", emoji: "🌍", title: "Explore Africa" },
    { gameId: "lsk_g3_emotions", subject: "Life Skills", emoji: "😊", title: "Emotion Explorer" },
    { gameId: "ssc_g7_mali", subject: "Social Sciences", emoji: "🏛️", title: "Ancient Kingdoms" },
  ],
  1: [ // Monday — Mathematics
    { gameId: "math_g4_multiplication", subject: "Mathematics", emoji: "✖️", title: "Multiples Master" },
    { gameId: "math_g5_fractions", subject: "Mathematics", emoji: "½", title: "Fraction Quest" },
    { gameId: "math_g7_algebra", subject: "Mathematics", emoji: "🔢", title: "Algebra Arena" },
  ],
  2: [ // Tuesday — English
    { gameId: "eng_g4_grammar", subject: "English", emoji: "📝", title: "Grammar Hero" },
    { gameId: "eng_g5_figurative", subject: "English", emoji: "✍️", title: "Figurative Language" },
    { gameId: "eng_g7_essay", subject: "English", emoji: "📖", title: "Essay Explorer" },
  ],
  3: [ // Wednesday — Natural Sciences
    { gameId: "sci_g4_water", subject: "Natural Sciences", emoji: "💧", title: "Water Cycle" },
    { gameId: "sci_g5_body", subject: "Natural Sciences", emoji: "🫀", title: "Body Systems" },
    { gameId: "sci_g7_biodiversity", subject: "Natural Sciences", emoji: "🌿", title: "Biosphere" },
  ],
  4: [ // Thursday — Mathematics
    { gameId: "math_g3_tables", subject: "Mathematics", emoji: "🔢", title: "Times Tables" },
    { gameId: "math_g6_percentages", subject: "Mathematics", emoji: "%", title: "Percentage Power" },
    { gameId: "math_g7_integers", subject: "Mathematics", emoji: "±", title: "Integer Island" },
  ],
  5: [ // Friday — Technology + EMS
    { gameId: "tech_g5_mechanisms", subject: "Technology", emoji: "⚙️", title: "Machine Builder" },
    { gameId: "ems_g7_budget", subject: "EMS", emoji: "💰", title: "Budget Boss" },
    { gameId: "tech_g7_circuits", subject: "Technology", emoji: "⚡", title: "Circuit Challenge" },
  ],
  6: [ // Saturday — Social Sciences + Science
    { gameId: "ssc_g4_provinces", subject: "Social Sciences", emoji: "🗺️", title: "Province Explorer" },
    { gameId: "sci_g6_ecosystem", subject: "Natural Sciences", emoji: "🌳", title: "Ecosystem Quest" },
    { gameId: "ssc_g7_colonisation", subject: "Social Sciences", emoji: "🏴", title: "Cape Colony" },
  ],
};
