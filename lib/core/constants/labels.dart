/// Display-layer taxonomy for "The Quest" theme.
///
/// This file maps internal, unchanged data concepts (CAPS phase/grade,
/// subject, topic, coins) to themed display names the learner actually
/// sees. Nothing here touches Firestore field names, `AppConstants`
/// values, or `GameCatalogEntry.grade`/`subject`/`topicId` -- those stay
/// exactly as they are; this is purely a rendering-time lookup so every
/// themed label lives in one swappable place instead of being scattered
/// across widgets.
///
/// | Internal concept                  | Themed name   |
/// |------------------------------------|---------------|
/// | Phase (Foundation/Intermediate/Senior) | Realm    |
/// | Grade                              | Camp          |
/// | Subject                            | Quest         |
/// | Topic (topicId)                    | Trail         |
/// | Individual activity                | Challenge (or the game's own title) |
/// | Reward display room                | Hideout       |
/// | Coin shop                          | Trading Post  |
/// | Coins                              | Gold          |
/// | AI tutor                           | QuestBot      |
class QuestLabels {
  QuestLabels._();

  // ==================== APP-WIDE FRAMING ====================
  static const String theQuest = 'The Quest';

  // ==================== REALM (CAPS phase) ====================
  // Keyed by the same anchor grade GameCatalogEntry.grade already uses
  // ('grade1' | 'grade4' | 'grade7'), so callers holding a catalog entry
  // can look a realm up directly without a separate phase enum.
  static const Map<String, String> _realmByAnchorGrade = {
    'grade1': 'Sprout Realm',
    'grade4': 'Trail Realm',
    'grade7': 'Summit Realm',
  };

  static const Map<String, String> _realmRangeByAnchorGrade = {
    'grade1': 'Grades 1–3',
    'grade4': 'Grades 4–6',
    'grade7': 'Grade 7',
  };

  /// The CAPS-phase anchor grade ('grade1'/'grade4'/'grade7') that [grade]
  /// (any of 'grade1'..'grade7') belongs to.
  static String anchorGradeFor(String grade) {
    final n = int.tryParse(grade.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
    if (n <= 3) return 'grade1';
    if (n <= 6) return 'grade4';
    return 'grade7';
  }

  /// e.g. 'grade5' -> 'Trail Realm'
  static String realmForGrade(String grade) =>
      _realmByAnchorGrade[anchorGradeFor(grade)] ?? 'Sprout Realm';

  /// e.g. 'grade5' -> 'Grades 4–6'
  static String realmRangeForGrade(String grade) =>
      _realmRangeByAnchorGrade[anchorGradeFor(grade)] ?? 'Grades 1–3';

  /// All three realms in progression order, for realm-select screens.
  static const List<String> realmOrder = ['grade1', 'grade4', 'grade7'];

  static String realmName(String anchorGrade) =>
      _realmByAnchorGrade[anchorGrade] ?? anchorGrade;

  static String realmRange(String anchorGrade) =>
      _realmRangeByAnchorGrade[anchorGrade] ?? '';

  // ==================== CAMP (grade) ====================
  /// e.g. 'grade5' -> 'Camp 5'
  static String campName(String grade) {
    final n = grade.replaceAll(RegExp(r'[^0-9]'), '');
    return 'Camp $n';
  }

  // ==================== QUEST (subject) ====================
  // Shorter, kid-friendlier forms than the raw CAPS subject name.
  static const Map<String, String> _subjectShortName = {
    'Mathematics': 'Maths',
    'Natural Sciences': 'Science',
    'English': 'English',
    'Social Sciences': 'Social Studies',
    'Technology': 'Tech',
    'Life Skills': 'Life Skills',
    'EMS': 'EMS',
  };

  /// e.g. 'Mathematics' -> 'Maths Quest'
  static String questName(String subject) =>
      '${_subjectShortName[subject] ?? subject} Quest';

  static String subjectShortName(String subject) =>
      _subjectShortName[subject] ?? subject;

  // ==================== TRAIL (topic) ====================
  // Acronyms/proper nouns that must not be title-cased word-by-word.
  static const Map<String, String> _trailWordOverrides = {
    'sa': 'SA',
    'vat': 'VAT',
    'cpa': 'CPA',
    'cvc': 'CVC',
    '2d': '2D',
    '3d': '3D',
  };

  /// Extension point for specific topics that deserve a hand-written,
  /// more evocative Trail name instead of the auto-formatted default.
  /// Populate as individual topics are reviewed in the running UI --
  /// deliberately left mostly empty rather than pre-guessing all 173.
  static const Map<String, String> trailOverrides = {};

  /// e.g. 'sa_provinces' -> 'SA Provinces', 'fractions_operations' ->
  /// 'Fractions Operations'.
  static String trailName(String topicId) {
    final override = trailOverrides[topicId];
    if (override != null) return override;

    return topicId.split('_').map((word) {
      final lower = word.toLowerCase();
      if (_trailWordOverrides.containsKey(lower)) {
        return _trailWordOverrides[lower]!;
      }
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  // ==================== CHALLENGE (individual activity) ====================
  // No renaming needed -- a Challenge is displayed under the game's own
  // proper title (GameCatalogEntry.title), e.g. "Fraction Forest". This
  // entry exists so the taxonomy table above is complete and searchable.
  static const String challenge = 'Challenge';

  // ==================== REWARD SYSTEMS ====================
  static const String hideout = 'Hideout';
  static const String tradingPost = 'Trading Post';
  static const String gold = 'Gold';
  static const String goldSingular = 'Gold';

  /// e.g. 240 -> '240 Gold'
  static String goldAmount(int amount) => '$amount $gold';

  // ==================== AI TUTOR ====================
  static const String questBot = 'QuestBot';
  static const String questBotMascotName = 'Quest Boy';
}
