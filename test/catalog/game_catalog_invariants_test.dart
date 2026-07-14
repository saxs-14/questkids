import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/core/constants/app_constants.dart';
import 'package:questkids/core/constants/game_catalog.dart';

void main() {
  // Every engineType string used by the catalog must be registered as a
  // constant in app_constants.dart and wired into GameRouter's switch — see
  // lib/features/games/core/game_router.dart. This list is kept in sync
  // with both by hand; a mismatch here means either the catalog references
  // an engine GameRouter can't route to, or a wired engine has no games.
  const registeredEngines = {
    AppConstants.engineTugOfWar,
    AppConstants.engineAdventureJourney,
    AppConstants.engineRunnerCollector,
    AppConstants.engineExplorerMap,
    AppConstants.engineMultiplesMerge,
    AppConstants.engineSequenceBuilder,
    AppConstants.engineCircuitBuilder,
    AppConstants.engineBudgetBuilder,
    AppConstants.engineNumberCountingDuel,
  };

  const entries = GameCatalog.all;

  test('catalog is non-empty', () {
    expect(entries, isNotEmpty);
  });

  test('every engineType is registered in app_constants.dart / GameRouter', () {
    for (final e in entries) {
      expect(
        registeredEngines.contains(e.engineType),
        isTrue,
        reason: "${e.id} uses unregistered engineType '${e.engineType}'",
      );
    }
  });

  test('adventureJourney + tugOfWar combined are at most 40% of the catalog',
      () {
    final reskinCount = entries
        .where((e) =>
            e.engineType == AppConstants.engineAdventureJourney ||
            e.engineType == AppConstants.engineTugOfWar)
        .length;
    final ratio = reskinCount / entries.length;
    expect(
      ratio,
      lessThanOrEqualTo(0.40),
      reason: 'adventureJourney+tugOfWar is $reskinCount/${entries.length} '
          '(${(ratio * 100).toStringAsFixed(1)}%) — every topic should feel '
          'like its own game, not a single quiz reskinned',
    );
  });

  test('every subject uses at least 3 distinct engines', () {
    final bySubject = <String, Set<String>>{};
    for (final e in entries) {
      bySubject.putIfAbsent(e.subject, () => {}).add(e.engineType);
    }
    for (final subject in bySubject.keys) {
      expect(
        bySubject[subject]!.length,
        greaterThanOrEqualTo(3),
        reason: "$subject only uses ${bySubject[subject]!.length} distinct "
            'engine(s): ${bySubject[subject]}',
      );
    }
  });

  test('runnerCollector (Grammar Hero Run) has at least 5 catalog entries', () {
    final count = entries
        .where((e) => e.engineType == AppConstants.engineRunnerCollector)
        .length;
    expect(
      count,
      greaterThanOrEqualTo(5),
      reason: 'runnerCollector is built and wired into GameRouter but has '
          'too few catalog entries to be discoverable',
    );
  });

  test('every entry has a non-empty learningObjective and mechanicReason', () {
    for (final e in entries) {
      expect(
        e.learningObjective.trim(),
        isNotEmpty,
        reason: '${e.id} has an empty learningObjective',
      );
      expect(
        e.mechanicReason.trim(),
        isNotEmpty,
        reason: '${e.id} has an empty mechanicReason',
      );
    }
  });

  test('catalog ids are unique', () {
    final ids = entries.map((e) => e.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('every tugOfWar catalog entry has a real arithmetic topic/subtopic',
      () {
    // The complete set of topic/subtopic pairs TugOfWarEngine can render
    // correctly -- mirrors _questionTypeByTopic in tug_of_war_config.dart.
    // Anything not listed here silently falls back to a generic
    // multiplication question, showing the wrong content for that entry's
    // advertised subject (see the Phase 12 tugOfWar content-mismatch fix).
    const arithmeticTopics = {
      'operations/addition',
      'operations/subtraction',
      'multiplication/times_tables',
      'division/long_division',
      'percentages/percentage_applications',
      'measurement/conversions',
      'economics/taxation',
      'decimals/decimal_operations',
      'integers/integer_operations',
      'algebra/linear_equations',
    };
    final offenders = entries
        .where((e) => e.engineType == AppConstants.engineTugOfWar)
        .where(
            (e) => !arithmeticTopics.contains('${e.topicId}/${e.subtopicId}'))
        .map((e) => e.id)
        .toList();
    expect(
      offenders,
      isEmpty,
      reason: 'tugOfWar entries with no matching question type show '
          'wrong content: $offenders',
    );
  });
}
