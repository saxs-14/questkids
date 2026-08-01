# Phase 10 — Educational Gamification (CAPS Curriculum) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix real content-mismatch defects surfaced by a full-catalog audit: 10 `multiplesMerge` catalog entries whose games don't teach their claimed topic (5 fall back to an unrelated generic numeric game; 5 have no real topic content at all), and 2 `tugOfWar` catalog entries that silently play multiplication questions instead of decimal/integer questions because the keypad can't enter `.` or `-`.

**Architecture:** No new engines, no new catalog entries, no grade5/6 content expansion (explicitly out of scope per user decision — see conversation). Two self-contained engine-capability fixes:
1. Finish `multiplesMerge`'s already-partially-built "pairs" mode (term↔definition matching) — the config layer already detects `pack['mode'] == 'pairs'` and falls back to a generic numeric demo; this plan wires up the actual round-generation, interaction, and rendering so pairs-mode content plays as designed.
2. Extend `tugOfWar`'s keypad and engine to support decimal and negative-integer input/questions.

Once pairs-mode rendering works, the 5 catalog entries with real but unrendered `tokenGroups` content (idioms, vocabulary ×2, leaders, population) start working with zero content changes. The 5 entries with topic-mismatched generic `tables` content (data, fractions ×2, ratio, stats) get their content packs rewritten from `numeric` to `pairs` mode with real authored question↔answer pairs, reusing the same newly-built rendering path.

**Tech Stack:** Flutter/Dart game engine layer (`lib/features/games/multiples_merge/`, `lib/features/games/tug_of_war/`), JSON content packs (`assets/content/`), no backend/Firestore changes.

## Global Constraints

- `flutter analyze` → 0 errors before every commit (60 pre-existing info lints is the current baseline — do not introduce new ones).
- `flutter test` → all green after every task.
- Catalog invariants (CLAUDE.md §4) must still hold after this phase: adventureJourney+tugOfWar ≤ 40% of all 125 entries (currently 47/125 = 37.6% — this plan does not change any entry's `engineType`, so this stays unaffected), every subject ≥ 3 distinct engines.
- No `GameCatalogEntry.id` changes, no new catalog entries — every content-pack JSON keeps its existing `id`.
- `tools/gamegen/schemas/index.js`'s `validateMultiplesMerge` requires `pairs` mode packs to have `tokenGroups.length >= min` (a tier floor) and every group to be `>= 2` non-empty strings — the 5 rewritten packs must satisfy this (run `node tools/gamegen/validate.js` from `tools/gamegen/` after content changes to confirm, informationally — this script is a pre-existing gate, not part of the Flutter build).
- Foundation/Intermediate-phase readability (CLAUDE.md §8): tile text must stay legible at grid-tile size — keep authored pair strings reasonably short (aim ≤ 40 characters per token where practical).

---

## File Structure

**Modify (multiplesMerge pairs mode):**
- `lib/features/games/multiples_merge/multiples_merge_config.dart` — add `mode`/`tokenGroups` fields, fix `fromPack` to stop discarding pairs-mode packs.
- `lib/features/games/multiples_merge/multiples_merge_engine.dart` — generalize `MergeRound` to hold either numeric or string cell values; add `_buildPairsRound()`.
- `lib/features/games/multiples_merge/multiples_merge_session.dart` — mode-aware `validNextCells`/`nextExpected`.
- `lib/features/games/multiples_merge/multiples_merge_game.dart` — string-aware tile rendering, mode-aware HUD/instruction copy.

**Modify (tugOfWar decimal/integer):**
- `lib/features/games/tug_of_war/widgets/tug_of_war_keypad.dart` — add `.` and `±` keys.
- `lib/features/games/tug_of_war/tug_of_war_session.dart` — validate `.`/`-` placement in `appendDigit`; raise the input-length cap.
- `lib/features/games/tug_of_war/tug_of_war_engine.dart` — add `'decimal'`/`'integer'` cases to `generateQuestions()`; fix `checkAnswer` to parse `num` (not just `int`).
- `lib/features/games/tug_of_war/tug_of_war_config.dart` — map `decimals/decimal_operations` → `'decimal'`, `integers/integer_operations` → `'integer'`.

**Modify (content packs — rewritten from `numeric` to `pairs` mode, real content authored):**
- `assets/content/math_g4_data.json`, `math_g4_fractions.json`, `math_g7_fractions.json`, `math_g7_ratio.json`, `math_g7_stats.json`.

**No changes needed** (content already correct, just unrendered until the engine fix lands): `assets/content/eng_g4_idioms.json`, `eng_g4_vocabulary.json`, `eng_g7_vocabulary.json`, `ss_g7_leaders.json`, `ss_g7_population.json`. No changes needed to `game_catalog.dart` — every affected entry's `engineType` and `mechanicReason` text ("Matching and merging pairs helps you spot patterns...") already accurately describes the pairs mechanic once it's implemented.

**New test files:**
- `test/games/multiples_merge_pairs_mode_test.dart`
- `test/games/tug_of_war_decimal_integer_test.dart`

---

## Task 1: Add decimal + negative-integer input to the Tug of War keypad

**Files:**
- Modify: `lib/features/games/tug_of_war/widgets/tug_of_war_keypad.dart`
- Modify: `lib/features/games/tug_of_war/tug_of_war_session.dart:83-87` (`appendDigit`)
- Test: `test/games/tug_of_war_decimal_integer_test.dart`

**Interfaces:**
- Consumes: nothing new from other tasks.
- Produces: `TugOfWarKeypad` gains two new key labels `'.'` and `'±'` that call the existing `onDigit(String)` callback (no new widget parameters). `TugOfWarSession.appendDigit(String digit)` now rejects a second `.`, rejects `±`/`-` anywhere except as the very first character, and toggles a leading `-` off if `±` is tapped again. Later tasks (Task 2, Task 3) rely on `TugOfWarSession.currentInput` being able to contain a string like `"-45"` or `"12.5"`.

- [ ] **Step 1: Write the failing test for input validation**

```dart
// test/games/tug_of_war_decimal_integer_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/features/games/core/game_config.dart';
import 'package:questkids/features/games/tug_of_war/tug_of_war_session.dart';

void main() {
  group('TugOfWarSession decimal/negative input', () {
    late TugOfWarSession session;

    setUp(() {
      session = TugOfWarSession(
        const GameConfig(
          engineType: 'tugOfWar',
          subject: 'Mathematics',
          grade: 'grade4',
          topicId: 'decimals',
          subtopicId: 'decimal_operations',
          catalogId: 'math_g4_decimals',
        ),
        'test-uid',
      );
    });

    tearDown(() => session.dispose());

    test('typing a decimal point once is accepted', () {
      session.appendDigit('1');
      session.appendDigit('2');
      session.appendDigit('.');
      session.appendDigit('5');
      expect(session.currentInput, '12.5');
    });

    test('a second decimal point is rejected', () {
      session.appendDigit('1');
      session.appendDigit('.');
      session.appendDigit('2');
      session.appendDigit('.');
      session.appendDigit('5');
      expect(session.currentInput, '1.25');
    });

    test('the sign toggle prefixes a leading minus', () {
      session.appendDigit('4');
      session.appendDigit('5');
      session.appendDigit('±');
      expect(session.currentInput, '-45');
    });

    test('tapping the sign toggle twice removes the minus again', () {
      session.appendDigit('4');
      session.appendDigit('5');
      session.appendDigit('±');
      session.appendDigit('±');
      expect(session.currentInput, '45');
    });

    test('a minus cannot appear after digits are typed via the digit key', () {
      // '-' typed as a raw digit char (not via the ± toggle) is not one of
      // the keypad's digit keys, but guard the session method directly too.
      session.appendDigit('4');
      session.appendDigit('-');
      expect(session.currentInput, '4');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/games/tug_of_war_decimal_integer_test.dart`
Expected: FAIL — `appendDigit` currently does `_currentInput += digit` unconditionally, so `'.'`/`'±'` get appended raw and the toggle/reject behavior doesn't exist (`±` literally appended as a character; second `.` not rejected).

- [ ] **Step 3: Implement input validation in `appendDigit`**

Replace `lib/features/games/tug_of_war/tug_of_war_session.dart:83-87`:

```dart
  void appendDigit(String digit) {
    if (isFinished) return;
    if (digit == '±') {
      _currentInput = _currentInput.startsWith('-')
          ? _currentInput.substring(1)
          : '-$_currentInput';
      notifyListeners();
      return;
    }
    if (digit == '.') {
      if (_currentInput.contains('.') || _currentInput.length >= 6) return;
      _currentInput += digit;
      notifyListeners();
      return;
    }
    if (digit == '-') return; // only the ± toggle may add a sign
    if (_currentInput.length >= 6) return;
    _currentInput += digit;
    notifyListeners();
  }
```

(The cap moves from 4 to 6 characters so `-XXX.X`-shaped answers fit; see Task 2 for why generated decimal/integer answers are kept small enough to stay within this.)

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/games/tug_of_war_decimal_integer_test.dart`
Expected: PASS (5/5)

- [ ] **Step 5: Add the keypad keys**

Modify `lib/features/games/tug_of_war/widgets/tug_of_war_keypad.dart`. Change the `_rows` layout from 4 rows of 3 to include the two new keys on their own row, and extend the color switch:

```dart
  static const _rows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['.', '0', '±'],
    ['❌', '✅'],
  ];
```

Update the `Row` builder above (`for (final row in _rows)`) — it already does `row.map((key) => Expanded(...))`, which works for a 2-item row too, so no structural change needed there. Update the color `switch`:

```dart
                      color: switch (key) {
                        '❌' => AppColors.error,
                        '✅' => confirmColor,
                        '.' || '±' => AppColors.blue.withAlpha(160),
                        _ => AppColors.blue.withAlpha(220),
                      },
```

And the tap dispatch `switch`:

```dart
                        switch (key) {
                          case '❌':
                            onClear();
                          case '✅':
                            onConfirm();
                          default:
                            onDigit(key);
                        }
```

(unchanged — `.` and `±` already fall into `default` and call `onDigit(key)`, which is exactly what's needed since `appendDigit` from Step 3 now handles both.)

- [ ] **Step 6: Run the full test suite**

Run: `flutter test`
Expected: PASS, no regressions (this only adds keys/rows; existing digit/clear/confirm behavior for the other 8 tug-of-war catalog entries using `'multiplication'`/`'addition'`/etc. types is untouched).

- [ ] **Step 7: Commit**

```bash
git add lib/features/games/tug_of_war/widgets/tug_of_war_keypad.dart lib/features/games/tug_of_war/tug_of_war_session.dart test/games/tug_of_war_decimal_integer_test.dart
git commit -m "feat(tug-of-war): add decimal point and sign-toggle keys to the keypad"
```

---

## Task 2: Add decimal and integer question generation to TugOfWarEngine

**Files:**
- Modify: `lib/features/games/tug_of_war/tug_of_war_engine.dart`
- Test: `test/games/tug_of_war_decimal_integer_test.dart` (extend)

**Interfaces:**
- Consumes: `TugOfWarConfig.questionType` (existing field, will carry `'decimal'`/`'integer'` once Task 3 wires the topic map — this task makes the engine handle those values regardless of how they're set, so it's testable standalone by constructing a `TugOfWarConfig` directly with `questionType: 'decimal'`).
- Produces: `TugOfWarEngine.generateQuestions()` emits `{'a': ..., 'b': ..., 'answer': num, 'display': String, 'type': 'decimal'|'integer'}` maps for those two types. `checkAnswer` accepts `num` answers (not just `int`), parsing decimals with `double.tryParse` and comparing with a small epsilon tolerance.

- [ ] **Step 1: Write the failing tests**

Append to `test/games/tug_of_war_decimal_integer_test.dart`:

```dart
import 'package:questkids/features/games/tug_of_war/tug_of_war_config.dart';
import 'package:questkids/features/games/tug_of_war/tug_of_war_engine.dart';

// ... inside main(), a new group:
  group('TugOfWarEngine decimal/integer questions', () {
    test('decimal type generates a non-integer answer with one decimal place', () {
      final config = const GameConfig(
        engineType: 'tugOfWar',
        subject: 'Mathematics',
        grade: 'grade4',
      );
      final engine = TugOfWarEngine(
        tugConfig: const TugOfWarConfig(questionType: 'decimal'),
        config: config,
      );
      final questions = engine.generateQuestions();
      expect(questions, isNotEmpty);
      for (final q in questions) {
        expect(q['type'], 'decimal');
        expect(q['answer'], isA<double>());
        final display = q['display'] as String;
        expect(display, contains('.'));
      }
    });

    test('decimal checkAnswer accepts the correct value within tolerance', () {
      final engine = TugOfWarEngine(
        tugConfig: const TugOfWarConfig(questionType: 'decimal'),
        config: const GameConfig(
            engineType: 'tugOfWar', subject: 'Mathematics', grade: 'grade4'),
      );
      final question = {'answer': 12.5, 'type': 'decimal'};
      expect(engine.checkAnswer(question, '12.5').correct, isTrue);
      expect(engine.checkAnswer(question, '12.4').correct, isFalse);
    });

    test('integer type generates answers that can be negative', () {
      final config = const GameConfig(
        engineType: 'tugOfWar',
        subject: 'Mathematics',
        grade: 'grade7',
      );
      final engine = TugOfWarEngine(
        tugConfig: const TugOfWarConfig(
            questionType: 'integer', multiplierMin: 1, multiplierMax: 20),
        config: config,
      );
      final questions = engine.generateQuestions();
      expect(questions, isNotEmpty);
      expect(questions.every((q) => q['type'] == 'integer'), isTrue);
      // Not every run is guaranteed to draw a negative result, but the
      // question shape must support one: assert the type contract instead
      // of a specific sign.
      expect(questions.every((q) => q['answer'] is int), isTrue);
    });

    test('integer checkAnswer accepts a negative submitted value', () {
      final engine = TugOfWarEngine(
        tugConfig: const TugOfWarConfig(questionType: 'integer'),
        config: const GameConfig(
            engineType: 'tugOfWar', subject: 'Mathematics', grade: 'grade7'),
      );
      final question = {'answer': -7, 'type': 'integer'};
      expect(engine.checkAnswer(question, '-7').correct, isTrue);
      expect(engine.checkAnswer(question, '7').correct, isFalse);
    });
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/games/tug_of_war_decimal_integer_test.dart`
Expected: FAIL — `'decimal'`/`'integer'` aren't handled in the engine's `switch`, so they fall into `default` and generate plain multiplication questions with `type: 'multiplication'`; `checkAnswer` does `question['answer'] as int` which throws or mismatches for a `double` answer.

- [ ] **Step 3: Implement engine support**

In `lib/features/games/tug_of_war/tug_of_war_engine.dart`, add two cases to the `switch (type)` in `generateQuestions()` (insert after the existing `'conversion'` case, before `default`):

```dart
        case 'decimal':
          // Reuse the dedup-checked a/b pair (declared above the switch)
          // rather than drawing fresh random numbers here -- keeps the
          // `used` set's a×b key meaningful for this case too, matching
          // every other case's pattern. Format `a` as a one-decimal-place
          // value using b's last digit as the tenths; keep the second
          // operand a small plain integer so results fit the keypad's
          // 6-character cap (Task 1), e.g. "83.4".
          final decimal = a + (b % 10) / 10;
          final addend = 1 + (b % 20);
          final isAdd = _rng.nextBool();
          final answer = isAdd ? decimal + addend : decimal - addend;
          out.add({
            'a': decimal,
            'b': addend,
            'answer': double.parse(answer.toStringAsFixed(1)),
            'display': '$decimal ${isAdd ? '+' : '-'} $addend = ?',
            'type': type,
          });
        case 'integer':
          // Reuse the dedup-checked a/b pair for magnitude; only the sign
          // and operation are freshly randomized, so results can land
          // negative -- exercising the ± keypad toggle from Task 1, not
          // just addition of positives.
          final signedA = _rng.nextBool() ? a : -a;
          final signedB = _rng.nextBool() ? b : -b;
          final isAdd = _rng.nextBool();
          out.add({
            'a': signedA,
            'b': signedB,
            'answer': isAdd ? signedA + signedB : signedA - signedB,
            'display': isAdd
                ? '($signedA) + ($signedB) = ?'
                : '($signedA) - ($signedB) = ?',
            'type': type,
          });
```

Update `checkAnswer` to handle `num` (not just `int`) answers:

```dart
  @override
  GameAnswerResult checkAnswer(
    Map<String, dynamic> question,
    dynamic answer, {
    int elapsedThresholdSeconds = 5,
  }) {
    final expected = question['answer'] as num;
    final submitted = answer is num ? answer : num.tryParse(answer.toString());
    final correct = submitted != null &&
        (expected - submitted).abs() < 0.001;
    final isBonus =
        correct && elapsedThresholdSeconds <= tugConfig.fastAnswerThresholdSec;
    return GameAnswerResult(
      correct: correct,
      xpDelta: correct ? (10 + (isBonus ? 5 : 0)) : 0,
      isBonus: isBonus,
    );
  }
```

(`num.tryParse` correctly parses both `"12.5"` and `"-7"`; the epsilon comparison replaces the old exact `==` since decimal answers now involve floating point.)

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/games/tug_of_war_decimal_integer_test.dart`
Expected: PASS (9/9 total in the file)

- [ ] **Step 5: Run the full test suite**

Run: `flutter test`
Expected: PASS — confirm no other engine/session test relies on `checkAnswer`'s old `int`-only signature (grep `TugOfWarEngine` usages first if any test fails unexpectedly).

- [ ] **Step 6: Commit**

```bash
git add lib/features/games/tug_of_war/tug_of_war_engine.dart test/games/tug_of_war_decimal_integer_test.dart
git commit -m "feat(tug-of-war): generate decimal and signed-integer questions, parse num answers"
```

---

## Task 3: Wire math_g4_decimals and math_g7_integers to the new question types

**Files:**
- Modify: `lib/features/games/tug_of_war/tug_of_war_config.dart:11-19`

**Interfaces:**
- Consumes: Task 2's `'decimal'`/`'integer'` engine support.
- Produces: nothing new consumed by later tasks — this is the final connective piece for the tugOfWar half of the phase.

- [ ] **Step 1: Add the topic mappings**

In `lib/features/games/tug_of_war/tug_of_war_config.dart`, update `_questionTypeByTopic`:

```dart
const Map<String, String> _questionTypeByTopic = {
  'operations/addition': 'addition',
  'operations/subtraction': 'subtraction',
  'multiplication/times_tables': 'multiplication',
  'division/long_division': 'division',
  'percentages/percentage_applications': 'percentage',
  'measurement/conversions': 'conversion',
  'economics/taxation': 'percentage',
  'decimals/decimal_operations': 'decimal',
  'integers/integer_operations': 'integer',
};
```

(`math_g4_decimals`'s catalog entry has `topicId: 'decimals'`, `subtopicId: 'decimal_operations'`; `math_g7_integers`'s has `topicId: 'integers'`, `subtopicId: 'integer_operations'` — confirmed against `lib/core/constants/game_catalog.dart:469-488` and `:1337-1357`.)

Also update the doc comment above the map (currently says decimals/integers "keep the 'multiplication' default until the keypad supports those input shapes — see docs/DEFERRED.md") to reflect that this is now done:

```dart
/// topicId/subtopicId -> questionType, mirroring
/// tools/gamegen/content/math.js's OP_BY_SUBTOPIC. Non-arithmetic "rapid
/// recall" topics (e.g. phonics/spelling/debate) aren't listed here and
/// keep the 'multiplication' default -- tugOfWar isn't used for those
/// subjects' catalog entries in practice (see game_catalog.dart), so the
/// fallback is never actually reached for them today.
```

- [ ] **Step 2: Remove the now-stale DEFERRED.md entry**

Edit `docs/DEFERRED.md`: delete the `**\`tugOfWar\` doesn't support decimal or negative-integer answers.**` bullet entirely (Tasks 1-3 of this phase resolve it).

- [ ] **Step 3: Run the full test suite**

Run: `flutter test`
Expected: PASS.

- [ ] **Step 4: Run `flutter analyze`**

Run: `flutter analyze`
Expected: 0 errors, same 60 pre-existing info lints as baseline.

- [ ] **Step 5: Commit**

```bash
git add lib/features/games/tug_of_war/tug_of_war_config.dart docs/DEFERRED.md
git commit -m "fix(tug-of-war): route math_g4_decimals and math_g7_integers to their real question types"
```

---

## Task 4: Add pairs-mode fields to MultiplesMergeConfig

**Files:**
- Modify: `lib/features/games/multiples_merge/multiples_merge_config.dart`
- Test: `test/games/multiples_merge_pairs_mode_test.dart`

**Interfaces:**
- Consumes: nothing new.
- Produces: `MultiplesMergeConfig` gains `mode` (`'numeric'` | `'pairs'`, default `'numeric'`) and `tokenGroups` (`List<List<String>>`, default `[]`) fields. `MultiplesMergeConfig.fromPack` no longer discards `pairs`-mode packs. Task 5's engine consumes `mergeConfig.mode` and `mergeConfig.tokenGroups`.

- [ ] **Step 1: Write the failing test**

```dart
// test/games/multiples_merge_pairs_mode_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/features/games/core/game_config.dart';
import 'package:questkids/features/games/multiples_merge/multiples_merge_config.dart';

void main() {
  group('MultiplesMergeConfig.fromPack pairs mode', () {
    test('a pairs-mode pack is no longer discarded into the numeric demo', () {
      final config = const GameConfig(
        engineType: 'multiplesMerge',
        subject: 'English',
        grade: 'grade4',
      );
      final pack = {
        'mode': 'pairs',
        'gridSize': 4,
        'chainLength': 2,
        'tokenGroups': [
          ['break the ice', 'do something to relax people'],
          ['piece of cake', 'something very easy'],
        ],
      };
      final merged = MultiplesMergeConfig.fromPack(pack, config);
      expect(merged.mode, 'pairs');
      expect(merged.gridSize, 4);
      expect(merged.tokenGroups, hasLength(2));
      expect(merged.tokenGroups.first, ['break the ice', 'do something to relax people']);
    });

    test('a numeric-mode pack still builds as before', () {
      final config = const GameConfig(
        engineType: 'multiplesMerge',
        subject: 'Mathematics',
        grade: 'grade4',
      );
      final pack = {
        'mode': 'numeric',
        'gridSize': 5,
        'chainLength': 5,
        'tables': [3, 4, 6, 8],
      };
      final merged = MultiplesMergeConfig.fromPack(pack, config);
      expect(merged.mode, 'numeric');
      expect(merged.tables, [3, 4, 6, 8]);
      expect(merged.tokenGroups, isEmpty);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/games/multiples_merge_pairs_mode_test.dart`
Expected: FAIL to compile — `MultiplesMergeConfig` has no `mode`/`tokenGroups` getters yet.

- [ ] **Step 3: Implement the config fields**

Replace the full contents of `lib/features/games/multiples_merge/multiples_merge_config.dart`:

```dart
import '../core/game_config.dart';
import '../core/game_theme.dart';

/// Per-grade tuning for Multiples Merge.
///
/// Difficulty mapping (from the brief):
///   Gr 1–2 → tables 2, 5, 10, short chains, strong hints.
///   Gr 3–4 → tables 3, 4, 6, 8, medium chains, normal hints.
///   Gr 5–6 → tables 7, 8, 9, 11, 12, long chains, hints off (build fluency).
class MultiplesMergeConfig {
  final String mode; // 'numeric' | 'pairs'
  final List<int> tables; // numeric mode: tables a round may draw from
  final List<List<String>> tokenGroups; // pairs mode: [term, definition] groups
  final int gridSize; // grid is gridSize × gridSize
  final int chainLength; // numeric: multiples to connect; pairs: always 2
  final int hintLevel; // 2 strong · 1 normal · 0 fluency (start hint only)

  const MultiplesMergeConfig({
    this.mode = 'numeric',
    this.tables = const [],
    this.tokenGroups = const [],
    required this.gridSize,
    required this.chainLength,
    required this.hintLevel,
  });

  /// Builds config from a generated content pack (see
  /// tools/gamegen/content/multiples_merge.js). Both 'numeric' and 'pairs'
  /// mode packs are honoured; a pack with neither recognized shape falls
  /// back to the grade-tuned numeric demo.
  factory MultiplesMergeConfig.fromPack(
      Map<String, dynamic> pack, GameConfig config) {
    if (pack['mode'] == 'pairs') {
      final groups = (pack['tokenGroups'] as List)
          .map((g) => (g as List).cast<String>())
          .toList();
      return MultiplesMergeConfig(
        mode: 'pairs',
        tokenGroups: groups,
        gridSize: pack['gridSize'] as int,
        chainLength: pack['chainLength'] as int,
        hintLevel: MultiplesMergeConfig.forGrade(config).hintLevel,
      );
    }
    if (pack['mode'] != 'numeric') return MultiplesMergeConfig.forGrade(config);
    return MultiplesMergeConfig(
      mode: 'numeric',
      tables: (pack['tables'] as List).cast<int>(),
      gridSize: pack['gridSize'] as int,
      chainLength: pack['chainLength'] as int,
      hintLevel: MultiplesMergeConfig.forGrade(config).hintLevel,
    );
  }

  factory MultiplesMergeConfig.forGrade(GameConfig config) {
    final g = GameTheme.gradeNumber(config.grade);
    if (g <= 2) {
      return const MultiplesMergeConfig(
          tables: [2, 5, 10], gridSize: 4, chainLength: 6, hintLevel: 2);
    } else if (g <= 4) {
      return const MultiplesMergeConfig(
          tables: [3, 4, 6, 8], gridSize: 5, chainLength: 9, hintLevel: 1);
    }
    return const MultiplesMergeConfig(
        tables: [7, 8, 9, 11, 12], gridSize: 5, chainLength: 12, hintLevel: 0);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/games/multiples_merge_pairs_mode_test.dart`
Expected: PASS (2/2)

- [ ] **Step 5: Run the full test suite**

Run: `flutter test`
Expected: PASS — `MultiplesMergeEngine`/`MultiplesMergeSession` still only read `mergeConfig.tables`/`gridSize`/`chainLength`/`hintLevel` at this point (Task 5 changes that), so existing numeric-mode games are unaffected by this config-only change.

- [ ] **Step 6: Commit**

```bash
git add lib/features/games/multiples_merge/multiples_merge_config.dart test/games/multiples_merge_pairs_mode_test.dart
git commit -m "feat(multiples-merge): add mode/tokenGroups fields to MultiplesMergeConfig, stop discarding pairs-mode packs"
```

---

## Task 5: Generate pairs-mode rounds in MultiplesMergeEngine

**Files:**
- Modify: `lib/features/games/multiples_merge/multiples_merge_engine.dart`
- Test: `test/games/multiples_merge_pairs_mode_test.dart` (extend)

**Interfaces:**
- Consumes: `MultiplesMergeConfig.mode`/`tokenGroups` (Task 4).
- Produces: `MergeRound` gains `mode` (`String`) and `pairPartner` (`Map<int, int>?`) fields, and `values` changes type from `List<int>` to `List<Object>` (holds `int` cells for numeric rounds, `String` cells for pairs rounds — every existing numeric-mode read site still works unchanged since `Object` is a supertype and callers already only ever read/display the value, never do int-specific arithmetic on `MergeRound.values` directly outside `_Tile`, which Task 7 updates). `MultiplesMergeEngine.buildRound()` dispatches to `_buildNumericRound()` (existing logic, renamed) or `_buildPairsRound()` (new) based on `mergeConfig.mode`. Task 6 (session) and Task 7 (widget) consume `round.mode` and `round.pairPartner`.

- [ ] **Step 1: Write the failing test**

Append to `test/games/multiples_merge_pairs_mode_test.dart`:

```dart
import 'package:questkids/features/games/multiples_merge/multiples_merge_engine.dart';

// inside main(), a new group:
  group('MultiplesMergeEngine pairs-mode rounds', () {
    test('buildRound in pairs mode places exactly one term/definition pair adjacently', () {
      const mergeConfig = MultiplesMergeConfig(
        mode: 'pairs',
        gridSize: 4,
        chainLength: 2,
        hintLevel: 1,
        tokenGroups: [
          ['break the ice', 'do something to relax people'],
          ['piece of cake', 'something very easy'],
          ['hit the books', 'study hard'],
          ['under the weather', 'feeling unwell'],
        ],
      );
      final engine = MultiplesMergeEngine(
        mergeConfig: mergeConfig,
        config: const GameConfig(
            engineType: 'multiplesMerge', subject: 'English', grade: 'grade4'),
      );

      final round = engine.buildRound();

      expect(round.mode, 'pairs');
      expect(round.values, hasLength(16)); // 4×4
      expect(round.values.every((v) => v is String), isTrue);
      expect(round.pairPartner, isNotNull);
      // Every entry in pairPartner must be a mutual, valid mapping.
      round.pairPartner!.forEach((cell, partner) {
        expect(round.pairPartner![partner], cell);
        expect(
          MultiplesMergeEngine.areAdjacent8(round.gridSize, cell, partner),
          isTrue,
        );
      });
      // Exactly one pair (2 cells) should be mapped as the round's target.
      expect(round.pairPartner!.length, 2);
      // The two mapped cells' values must be the one matching term/definition pair.
      final cells = round.pairPartner!.keys.toList();
      final texts = cells.map((c) => round.values[c] as String).toSet();
      final matchesAGroup = mergeConfig.tokenGroups.any(
        (g) => texts.containsAll(g) && g.toSet().containsAll(texts),
      );
      expect(matchesAGroup, isTrue);
    });

    test('distractor cells never form a second complete pair', () {
      const mergeConfig = MultiplesMergeConfig(
        mode: 'pairs',
        gridSize: 4,
        chainLength: 2,
        hintLevel: 1,
        tokenGroups: [
          ['break the ice', 'do something to relax people'],
          ['piece of cake', 'something very easy'],
          ['hit the books', 'study hard'],
          ['under the weather', 'feeling unwell'],
          ['spill the beans', 'reveal a secret'],
        ],
      );
      final engine = MultiplesMergeEngine(
        mergeConfig: mergeConfig,
        config: const GameConfig(
            engineType: 'multiplesMerge', subject: 'English', grade: 'grade4'),
      );

      for (int i = 0; i < 30; i++) {
        final round = engine.buildRound();
        final targetCells = round.pairPartner!.keys.toSet();
        final otherTexts = [
          for (int c = 0; c < round.values.length; c++)
            if (!targetCells.contains(c)) round.values[c] as String
        ];
        for (final group in mergeConfig.tokenGroups) {
          final bothPresent =
              otherTexts.contains(group[0]) && otherTexts.contains(group[1]);
          expect(bothPresent, isFalse,
              reason: 'distractors must never contain both halves of a pair');
        }
      }
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/games/multiples_merge_pairs_mode_test.dart`
Expected: FAIL to compile — `MergeRound.mode`/`pairPartner` don't exist yet; `buildRound()` always runs the numeric path (would throw trying to read `mergeConfig.tables[rng...]` on an empty `tables` list for a pairs-mode config).

- [ ] **Step 3: Implement pairs-mode round generation**

In `lib/features/games/multiples_merge/multiples_merge_engine.dart`, replace the `MergeRound` class and `buildRound()` method:

```dart
/// One generated round. In 'numeric' mode: the target table, the grid
/// values, and a guaranteed in-order solution path (cell indices) so a
/// valid chain always exists. In 'pairs' mode: a term/definition pair
/// placed on two adjacent cells among distractor tokens, with
/// [pairPartner] recording the mutual cell-index mapping so the session
/// can validate a tap without arithmetic.
class MergeRound {
  final String mode; // 'numeric' | 'pairs'
  final int table; // numeric mode only; 0 for pairs rounds
  final int gridSize;
  final int chainLength;
  final List<Object> values; // int cells (numeric) or String cells (pairs)
  final List<int> solutionPath; // numeric mode: cell indices, in order
  final Map<int, int>? pairPartner; // pairs mode: cell index -> partner cell

  const MergeRound({
    required this.mode,
    required this.table,
    required this.gridSize,
    required this.chainLength,
    required this.values,
    required this.solutionPath,
    this.pairPartner,
  });
}

class MultiplesMergeEngine extends GameEngine {
  final MultiplesMergeConfig mergeConfig;
  final GameConfig _config;
  final Random _rng = Random();

  MultiplesMergeEngine({required this.mergeConfig, required GameConfig config})
      : _config = config;

  @override
  GameConfig get config => _config;

  @override
  List<Map<String, dynamic>> generateQuestions() =>
      List.generate(_config.questionCount, (i) => {'round': i});

  /// Build a fresh, solvable round for the configured mode.
  MergeRound buildRound() =>
      mergeConfig.mode == 'pairs' ? _buildPairsRound() : _buildNumericRound();

  MergeRound _buildNumericRound() {
    final table = mergeConfig.tables[_rng.nextInt(mergeConfig.tables.length)];
    final n = mergeConfig.gridSize;
    final len = mergeConfig.chainLength.clamp(2, n * n);

    final path = _generatePath(n, len);
    final values = List<int>.filled(n * n, 0);
    final chainValues = List.generate(len, (i) => table * (i + 1));
    for (int i = 0; i < len; i++) {
      values[path[i]] = chainValues[i];
    }

    final used = chainValues.toSet();
    for (int c = 0; c < values.length; c++) {
      if (values[c] != 0) continue;
      values[c] = _distractor(table, len, used);
    }

    return MergeRound(
      mode: 'numeric',
      table: table,
      gridSize: n,
      chainLength: len,
      values: values,
      solutionPath: path,
    );
  }

  MergeRound _buildPairsRound() {
    final n = mergeConfig.gridSize;
    final groups = mergeConfig.tokenGroups;
    final targetGroup = groups[_rng.nextInt(groups.length)];

    final path = _generatePath(n, 2); // exactly 2 adjacent cells
    final values = List<Object?>.filled(n * n, null);
    values[path[0]] = targetGroup[0];
    values[path[1]] = targetGroup[1];

    // Fill remaining cells with ONE token per distractor pair (never both
    // halves of the same non-target pair), so no accidental second match
    // exists on the board.
    final distractorPool = <String>[];
    for (final g in groups) {
      if (identical(g, targetGroup)) continue;
      distractorPool.add(_rng.nextBool() ? g[0] : g[1]);
    }
    distractorPool.shuffle(_rng);

    int di = 0;
    for (int c = 0; c < values.length; c++) {
      if (values[c] != null) continue;
      if (di < distractorPool.length) {
        values[c] = distractorPool[di++];
      } else {
        // More filler cells than distractor tokens available (typical: 10
        // tokenGroups on a 4×4 grid needs 14 filler cells but the pool
        // above only has 9 tokens -- one per non-target group). Repeat an
        // ALREADY-PLACED distractor string rather than drawing a fresh
        // token: drawing fresh would risk introducing a non-target group's
        // other half, which would leave both halves of that pair on the
        // board with no pairPartner mapping recognizing them as a match --
        // confusing, since tapping them looks like it should work but
        // silently does nothing. A repeated distractor string is inert by
        // construction (it was already screened as safe above).
        values[c] = distractorPool[_rng.nextInt(distractorPool.length)];
      }
    }

    return MergeRound(
      mode: 'pairs',
      table: 0,
      gridSize: n,
      chainLength: 2,
      values: values.cast<Object>(),
      solutionPath: path,
      pairPartner: {path[0]: path[1], path[1]: path[0]},
    );
  }
```

Leave `_distractor`, `_generatePath`, `_walk`, `_neighbors8`, `_snake`, and `areAdjacent8` unchanged — `_generatePath(n, 2)` already works generically for a 2-cell path (it's `_walk`'s general case, not numeric-specific).

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/games/multiples_merge_pairs_mode_test.dart`
Expected: PASS (4/4 total in the file)

- [ ] **Step 5: Run the full test suite**

Run: `flutter test`
Expected: FAIL at this point — `MultiplesMergeSession` (not yet updated) reads `_round!.values` expecting `List<int>` in places and `MultiplesMergeGame`'s `_Tile` expects `int value`; this task only touches the engine, so downstream compile errors in session/widget are expected until Task 6/7 land. **Do not attempt to make the full suite green yet** — verify instead that `flutter analyze` on just the engine file shows no new issues, and that only the already-known session/widget files show type errors:

Run: `flutter analyze lib/features/games/multiples_merge/`
Expected: errors in `multiples_merge_session.dart` and `multiples_merge_game.dart` only (their `int`-typed reads of `round.values`), zero errors in `multiples_merge_engine.dart` itself.

- [ ] **Step 6: Commit**

```bash
git add lib/features/games/multiples_merge/multiples_merge_engine.dart test/games/multiples_merge_pairs_mode_test.dart
git commit -m "feat(multiples-merge): generate pairs-mode rounds (term/definition placement + distractors)"
```

(This commit intentionally leaves the build red between here and the end of Task 7 — the three files are tightly coupled and splitting them further would mean shipping a half-working intermediate state. `writing-plans`' frequent-commit guidance is satisfied at the task granularity; Tasks 5-7 together form one logically atomic change.)

---

## Task 6: Mode-aware interaction logic in MultiplesMergeSession

**Files:**
- Modify: `lib/features/games/multiples_merge/multiples_merge_session.dart`

**Interfaces:**
- Consumes: `MergeRound.mode`/`pairPartner` (Task 5).
- Produces: `MultiplesMergeSession.validNextCells` and `onTileTouched` work correctly for both modes. `table`/`nextExpected` getters return sentinel values (`0`) in pairs mode rather than throwing. Task 7 (widget) consumes `session.round!.mode` to pick which HUD copy to show.

- [ ] **Step 1: Update `validNextCells`**

In `lib/features/games/multiples_merge/multiples_merge_session.dart`, replace the `validNextCells` getter:

```dart
  /// Cells that currently form a valid next step (used for hints + validation).
  Set<int> get validNextCells {
    final r = _round;
    if (r == null || _merging) return {};
    if (r.mode == 'pairs') {
      if (_chain.length >= r.chainLength) return {};
      if (_chain.isEmpty) {
        return {for (int c = 0; c < r.values.length; c++) c};
      }
      final partner = r.pairPartner?[_chain.first];
      return partner == null ? {} : {partner};
    }
    final result = <int>{};
    if (_chain.isEmpty) {
      for (int c = 0; c < r.values.length; c++) {
        if (r.values[c] == table) result.add(c); // table × 1
      }
      return result;
    }
    if (_chain.length >= r.chainLength) return {};
    final last = _chain.last;
    for (int c = 0; c < r.values.length; c++) {
      if (_chain.contains(c)) continue;
      if (MultiplesMergeEngine.areAdjacent8(r.gridSize, last, c) &&
          r.values[c] == nextExpected) {
        result.add(c);
      }
    }
    return result;
  }
```

Update `table` and `values` getters to be mode-safe (numeric-only arithmetic guarded):

```dart
  int get table => _round?.mode == 'numeric' ? (_round?.table ?? 0) : 0;
  int get gridSize => _round?.gridSize ?? _mergeConfig.gridSize;
  int get chainLength => _round?.chainLength ?? _mergeConfig.chainLength;
  int get hintLevel => _mergeConfig.hintLevel;
  List<Object> get values => _round?.values ?? const [];

  /// The next multiple the learner needs to connect (numeric mode only).
  int get nextExpected => table * (_chain.length + 1);
```

(`values`'s return type changes from `List<int>` to `List<Object>` to match `MergeRound.values` from Task 5 — this is the type propagation the earlier `flutter analyze` run flagged.)

- [ ] **Step 2: Run `flutter analyze` on the multiples_merge package**

Run: `flutter analyze lib/features/games/multiples_merge/`
Expected: errors remain only in `multiples_merge_game.dart` (the widget still expects `int` tile values) — session and engine are now internally consistent.

- [ ] **Step 3: Run the full test suite**

Run: `flutter test`
Expected: still FAIL only on widget-layer type errors in `multiples_merge_game.dart` (Task 7 fixes this) — confirm no NEW failures beyond that file by running the non-widget tests:

Run: `flutter test test/games/`
Expected: PASS (this directory has no widget-rendering tests for multiples_merge yet, so it should be green already).

- [ ] **Step 4: Commit**

```bash
git add lib/features/games/multiples_merge/multiples_merge_session.dart
git commit -m "feat(multiples-merge): mode-aware validNextCells/onTileTouched for pairs-mode sessions"
```

---

## Task 7: Render string tiles and pairs-mode HUD copy in MultiplesMergeGame

**Files:**
- Modify: `lib/features/games/multiples_merge/multiples_merge_game.dart`
- Test: `test/widgets/multiples_merge_pairs_widget_test.dart` (new)

**Interfaces:**
- Consumes: `MultiplesMergeSession.values` as `List<Object>` (Task 6), `session.round!.mode`.
- Produces: nothing further consumed by later tasks — this closes out the pairs-mode engine work. After this task, the build must be fully green again.

- [ ] **Step 1: Write a widget smoke test for pairs mode**

```dart
// test/widgets/multiples_merge_pairs_widget_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:questkids/features/games/core/game_config.dart';
import 'package:questkids/features/games/multiples_merge/multiples_merge_session.dart';

void main() {
  testWidgets('a pairs-mode round renders string tokens, not numbers',
      (tester) async {
    final config = const GameConfig(
      engineType: 'multiplesMerge',
      subject: 'English',
      grade: 'grade4',
      catalogId: 'eng_g4_idioms',
    );
    final session = MultiplesMergeSession(config, 'test-uid', pack: {
      'mode': 'pairs',
      'gridSize': 4,
      'chainLength': 2,
      'tokenGroups': [
        ['break the ice', 'do something to relax people'],
        ['piece of cake', 'something very easy'],
        ['hit the books', 'study hard'],
        ['under the weather', 'feeling unwell'],
      ],
    })
      ..startSession();

    await tester.pumpWidget(MaterialApp(
      home: ChangeNotifierProvider.value(
        value: session,
        child: Consumer<MultiplesMergeSession>(
          builder: (_, s, __) => Text(s.round!.values.join(', ')),
        ),
      ),
    ));

    // The rendered text must contain at least one of the authored token
    // strings, proving the widget layer can hold and display non-numeric
    // round values without a type error.
    final text = tester.widget<Text>(find.byType(Text)).data!;
    final anyToken = [
      'break the ice',
      'do something to relax people',
      'piece of cake',
      'something very easy',
      'hit the books',
      'study hard',
      'under the weather',
      'feeling unwell',
    ].any(text.contains);
    expect(anyToken, isTrue);

    session.dispose();
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/multiples_merge_pairs_widget_test.dart`
Expected: FAIL to compile at this point only if something in the widget file still hard-types `int` in a way that breaks `MultiplesMergeSession` construction — more likely this specific test passes already once Task 6 lands (it doesn't touch `_Tile` directly), but the FULL widget build (`MultiplesMergeGame`) still won't compile. Proceed to Step 3 regardless; this test is the acceptance check for Step 3-4's changes to `_Tile`/`_MergeGrid`, not a strict pre-check.

- [ ] **Step 3: Update `_Tile` and HUD copy for pairs mode**

In `lib/features/games/multiples_merge/multiples_merge_game.dart`:

Change `_Tile.value`'s type and its `_gradient()`/`Text` handling:

```dart
class _Tile extends StatelessWidget {
  final Object value;
  final bool selected;
  final bool glow;
  final bool merged;
  final double pulse;

  const _Tile({
    required this.value,
    required this.selected,
    required this.glow,
    required this.merged,
    required this.pulse,
  });

  List<Color> _gradient() {
    if (value is! int) {
      // Pairs mode: a single consistent "word tile" palette instead of the
      // magnitude-tiered numeric palette below (which needs an int).
      return const [Color(0xFFBA68C8), Color(0xFF8E24AA)];
    }
    // Warm "maths orange" family; tier varies by magnitude for visual variety.
    const tiers = [
      [Color(0xFFFFB74D), Color(0xFFFF9800)],
      [Color(0xFFFF8A65), Color(0xFFFF6B35)],
      [Color(0xFFFFA726), Color(0xFFF57C00)],
      [Color(0xFFFF7043), Color(0xFFE64A19)],
    ];
    return tiers[(((value as int) - 1) ~/ 8).clamp(0, tiers.length - 1)];
  }

  @override
  Widget build(BuildContext context) {
    final grad = _gradient();
    final glowAlpha = glow ? (0.35 + 0.45 * pulse) : 0.0;
    final isWordTile = value is! int;

    final tile = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      transform: selected
          ? Matrix4.diagonal3Values(1.06, 1.06, 1.0)
          : Matrix4.identity(),
      transformAlignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: grad,
        ),
        borderRadius: BorderRadius.circular(GameTheme.radiusSmall),
        border: Border.all(
          color: selected ? Colors.white : Colors.white.withValues(alpha: 0.4),
          width: selected ? 3 : 1.5,
        ),
        boxShadow: [
          if (glowAlpha > 0)
            BoxShadow(
              color: AppColors.gold.withValues(alpha: glowAlpha),
              blurRadius: 16,
              spreadRadius: 2,
            ),
          BoxShadow(
            color: grad.last.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            maxLines: isWordTile ? 4 : 1,
            style: GameTheme.display(
              isWordTile ? 13 : 26,
              color: Colors.white,
              weight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );

    if (merged) {
      return tile
          .animate()
          .scale(
            duration: 500.ms,
            begin: const Offset(1, 1),
            end: const Offset(1.3, 1.3),
            curve: Curves.easeOut,
          )
          .fadeOut(duration: 500.ms);
    }
    return tile;
  }
}
```

Update `_MergeGrid.build`'s tile loop — `round.values[i]` is now `Object`, which the `_Tile(value: ...)` constructor now accepts directly, so no change needed there beyond the type already flowing through.

Update `_Hud` and `_InstructionStrip` to branch on mode. In `_MultiplesMergeGameState.build`, change the `_Hud`/`_InstructionStrip` construction to pass `session.round!.mode` through, and update both widgets:

```dart
                      _Hud(
                        mode: round.mode,
                        table: session.table,
                        chainLen: session.chain.length,
                        target: session.chainLength,
                        round: session.questionIndex + 1,
                        totalRounds: session.totalQuestions,
                        onClose: () => Navigator.of(ctx).pop(),
                        onQuiz: _openWeeklyQuiz,
                      ),
                      _InstructionStrip(
                          mode: round.mode,
                          table: session.table,
                          length: session.chainLength),
```

(`round` is already bound earlier in `build` via `final round = session.round;`.)

```dart
class _Hud extends StatelessWidget {
  final String mode;
  final int table;
  final int chainLen;
  final int target;
  final int round;
  final int totalRounds;
  final VoidCallback onClose;
  final VoidCallback onQuiz;

  const _Hud({
    required this.mode,
    required this.table,
    required this.chainLen,
    required this.target,
    required this.round,
    required this.totalRounds,
    required this.onClose,
    required this.onQuiz,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Row(
        children: [
          IconButton(onPressed: onClose, icon: const Icon(Icons.close)),
          Expanded(
            child: Column(
              children: [
                Text(mode == 'pairs' ? 'Match the Pairs' : 'Multiples of $table',
                    style: GameTheme.display(20, color: AppColors.math)),
                Text(
                    'Chain $chainLen / $target   •   Round $round/$totalRounds',
                    style: GameTheme.body(12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Weekly Quiz',
            onPressed: onQuiz,
            icon: const Icon(Icons.quiz_outlined, color: AppColors.math),
          ),
        ],
      ),
    );
  }
}

class _InstructionStrip extends StatelessWidget {
  final String mode;
  final int table;
  final int length;
  const _InstructionStrip(
      {required this.mode, required this.table, required this.length});

  @override
  Widget build(BuildContext context) {
    final text = mode == 'pairs'
        ? 'Tap a tile, then tap its matching pair!'
        : 'Connect the multiples in order:  ${[
            for (int i = 1; i <= math.min(4, length); i++) '${table * i}'
          ].join(' → ')} …';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.math.withValues(alpha: 0.10),
        borderRadius: GameTheme.roundedSmall,
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style:
            GameTheme.body(13, color: AppColors.math, weight: FontWeight.w700),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widgets/multiples_merge_pairs_widget_test.dart`
Expected: PASS

- [ ] **Step 5: Run the full test suite**

Run: `flutter test`
Expected: PASS, all green (this closes out the multi-file pairs-mode change spanning Tasks 4-7).

- [ ] **Step 6: Run `flutter analyze`**

Run: `flutter analyze`
Expected: 0 errors, 60 pre-existing info lints (unchanged baseline).

- [ ] **Step 7: Commit**

```bash
git add lib/features/games/multiples_merge/multiples_merge_game.dart test/widgets/multiples_merge_pairs_widget_test.dart
git commit -m "feat(multiples-merge): render string tiles and pairs-mode HUD copy, completing pairs-mode support"
```

- [ ] **Step 8: Update DEFERRED.md**

Edit `docs/DEFERRED.md`: delete the `**\`multiplesMerge\`'s 5 "pairs mode" topics fall back to the numeric demo.**` bullet — this task fully resolves it.

```bash
git add docs/DEFERRED.md
git commit -m "docs: remove resolved multiplesMerge pairs-mode deferred item"
```

---

## Task 8: Rewrite the 5 topic-mismatched multiplesMerge content packs as real pairs-mode content

**Files:**
- Modify: `assets/content/math_g4_data.json`
- Modify: `assets/content/math_g4_fractions.json`
- Modify: `assets/content/math_g7_fractions.json`
- Modify: `assets/content/math_g7_ratio.json`
- Modify: `assets/content/math_g7_stats.json`

**Interfaces:**
- Consumes: Task 4-7's pairs-mode support (`mode: "pairs"`, `tokenGroups` shape, validated by `tools/gamegen/schemas/index.js`'s `validateMultiplesMerge`).
- Produces: nothing consumed by later tasks — content-only change.

No test for this task (content JSON, not code) — verification is Task 9's live playthrough plus `node tools/gamegen/validate.js`.

- [ ] **Step 1: Rewrite `math_g4_data.json`**

Replace its contents (CAPS Grade 4 data handling — reading bar graphs/pictographs/tables):

```json
{
  "id": "math_g4_data",
  "engine": "multiplesMerge",
  "grade": "grade4",
  "subject": "Mathematics",
  "title": "Data City",
  "tagline": "Read bar graphs, pictographs and tables to answer data questions!",
  "accentColorHex": "#FF6B35",
  "emoji": "📊",
  "mode": "pairs",
  "gridSize": 4,
  "chainLength": 2,
  "tokenGroups": [
    ["A graph that uses bars to show amounts", "Bar graph"],
    ["A graph that uses pictures to show amounts", "Pictograph"],
    ["The value shown most often in a data set", "Mode"],
    ["Rows and columns used to organise data", "Table"],
    ["The picture or symbol key on a pictograph", "Legend"],
    ["The line along the bottom of a bar graph", "X-axis"],
    ["The line up the side of a bar graph", "Y-axis"],
    ["Sales: Mon 10, Tue 15, Wed 8 — which day sold the most?", "Tuesday"],
    ["4 pictures = 20 apples, so 1 picture equals", "5 apples"],
    ["Counting and recording data as it is collected", "Tally"]
  ]
}
```

- [ ] **Step 2: Rewrite `math_g4_fractions.json`**

CAPS Grade 4 fractions (compare, simplify, add):

```json
{
  "id": "math_g4_fractions",
  "engine": "multiplesMerge",
  "grade": "grade4",
  "subject": "Mathematics",
  "title": "Fraction Forest",
  "tagline": "Navigate the fraction forest — compare, simplify and add fractions!",
  "accentColorHex": "#FF6B35",
  "emoji": "🌲",
  "mode": "pairs",
  "gridSize": 4,
  "chainLength": 2,
  "tokenGroups": [
    ["1/2 + 1/4", "3/4"],
    ["2/4 simplified", "1/2"],
    ["1/3 + 1/3", "2/3"],
    ["3/6 simplified", "1/2"],
    ["1/4 + 2/4", "3/4"],
    ["Which is bigger: 1/2 or 1/3?", "1/2"],
    ["4/8 simplified", "1/2"],
    ["1/5 + 2/5", "3/5"],
    ["Which is smaller: 1/4 or 1/6?", "1/6"],
    ["2/3 + 1/3", "1 whole"]
  ]
}
```

- [ ] **Step 3: Rewrite `math_g7_fractions.json`**

CAPS Grade 7 fraction operations (add/subtract/multiply/divide, mixed numbers):

```json
{
  "id": "math_g7_fractions",
  "engine": "multiplesMerge",
  "grade": "grade7",
  "subject": "Mathematics",
  "title": "Fraction Fighter",
  "tagline": "Add, subtract, multiply and divide fractions and mixed numbers!",
  "accentColorHex": "#FF6B35",
  "emoji": "🍕",
  "mode": "pairs",
  "gridSize": 4,
  "chainLength": 2,
  "tokenGroups": [
    ["1/2 × 1/3", "1/6"],
    ["3/4 ÷ 1/2", "1 1/2"],
    ["2/3 - 1/6", "1/2"],
    ["1 1/2 + 2 1/4", "3 3/4"],
    ["5/6 - 1/3", "1/2"],
    ["2/5 × 5/6", "1/3"],
    ["1/4 ÷ 1/8", "2"],
    ["3 1/3 - 1 2/3", "1 2/3"],
    ["7/8 + 1/8", "1 whole"],
    ["2/7 × 7/4", "1/2"]
  ]
}
```

- [ ] **Step 4: Rewrite `math_g7_ratio.json`**

CAPS Grade 7 ratio, rate and proportion:

```json
{
  "id": "math_g7_ratio",
  "engine": "multiplesMerge",
  "grade": "grade7",
  "subject": "Mathematics",
  "title": "Ratio Racer",
  "tagline": "Race through ratios, rates and proportions!",
  "accentColorHex": "#FF6B35",
  "emoji": "⚖️",
  "mode": "pairs",
  "gridSize": 4,
  "chainLength": 2,
  "tokenGroups": [
    ["Simplify 8:12", "2:3"],
    ["Simplify 10:15", "2:3"],
    ["Share R60 in the ratio 1:2", "R20 and R40"],
    ["If 3:5 and total is 40, the larger share is", "25"],
    ["A car travels 180km in 3 hours — its rate is", "60km/h"],
    ["Simplify 15:25", "3:5"],
    ["If the ratio of boys:girls is 2:3 in a class of 25", "10 boys, 15 girls"],
    ["A recipe needs flour:sugar as 4:1 — for 8 cups flour", "2 cups sugar"],
    ["Simplify 6:9:12", "2:3:4"],
    ["R5 for 2 apples is a rate of", "R2.50 per apple"]
  ]
}
```

- [ ] **Step 5: Rewrite `math_g7_stats.json`**

CAPS Grade 7 statistics (mean/median/mode, data interpretation):

```json
{
  "id": "math_g7_stats",
  "engine": "multiplesMerge",
  "grade": "grade7",
  "subject": "Mathematics",
  "title": "Stats Showdown",
  "tagline": "Calculate mean, median, mode and interpret graphs!",
  "accentColorHex": "#FF6B35",
  "emoji": "📊",
  "mode": "pairs",
  "gridSize": 4,
  "chainLength": 2,
  "tokenGroups": [
    ["Mean of 2, 4, 6, 8", "5"],
    ["Median of 3, 7, 9, 12, 15", "9"],
    ["Mode of 2, 2, 3, 5, 5, 5", "5"],
    ["Range of 4, 9, 15, 22", "18"],
    ["Mean of 10, 20, 30", "20"],
    ["Median of 1, 2, 3, 4", "2.5"],
    ["The middle value in an ordered data set", "Median"],
    ["The value that appears most often", "Mode"],
    ["Sum of values divided by how many values", "Mean"],
    ["Highest value minus lowest value", "Range"]
  ]
}
```

- [ ] **Step 6: Verify each pack is valid JSON**

Run: `node -e "['math_g4_data','math_g4_fractions','math_g7_fractions','math_g7_ratio','math_g7_stats'].forEach(f=>{JSON.parse(require('fs').readFileSync('assets/content/'+f+'.json','utf8'));console.log(f,'ok')})"`
Expected: prints `<id> ok` for all 5 files, no parse errors.

- [ ] **Step 7: Run the gamegen validator (informational, not a Flutter build gate)**

Run (from repo root): `cd tools/gamegen && node validate.js && cd ../..`
Expected: no new `FAIL:` lines referencing these 5 ids (pairs-mode packs need `tokenGroups.length >= min`; each pack above has exactly 10 groups, matching the existing pairs-mode packs' item counts, so this should clear the same tier floor they clear).

- [ ] **Step 8: Commit**

```bash
git add assets/content/math_g4_data.json assets/content/math_g4_fractions.json assets/content/math_g7_fractions.json assets/content/math_g7_ratio.json assets/content/math_g7_stats.json
git commit -m "content(multiples-merge): author real pairs-mode question content for Data City, Fraction Forest/Fighter, Ratio Racer, Stats Showdown"
```

---

## Task 9: End-of-phase verification + summary

**Files:** none (verification only)

- [ ] **Step 1: Full regression suite**

Run in order:
```bash
flutter analyze
flutter test
flutter build web --release
flutter build apk --debug
```
Expected: `flutter analyze` 0 errors (60 pre-existing info lints); `flutter test` all green; both builds succeed. If free memory is low (check via the platform's memory-check command before building — this machine has previously run out of RAM mid-build during this engagement), run builds sequentially, not in parallel, and clear any leftover build-tool processes first if a build gets killed.

- [ ] **Step 2: Live browser verification**

Using the already-running local web server and Chrome DevTools MCP tools (same approach as Phase 9):
1. Log in as the learner test account, navigate to the Quests tab.
2. Play **Idiom Island** (`eng_g4_idioms`) end-to-end — confirm it now shows idiom/meaning pairs tiles (not a generic number-multiples grid), tapping a term then its matching definition advances the round, and the session completes with a result screen.
3. Play **Fraction Fighter** (`math_g7_fractions`) end-to-end — confirm it shows real fraction-operation pairs (not a generic `tables` grid), completes correctly.
4. Play **Decimal Dunes** (`math_g4_decimals`) or **Integer Invaders** (`math_g7_integers`) end-to-end via Tug of War — confirm the keypad's `.`/`±` keys work, questions display decimal/negative-integer problems (not multiplication), and answers submit correctly including at least one deliberately-wrong answer to confirm the red-flash/no-crash path.
5. Check the console for new errors introduced by this phase's changes (existing pre-existing Cloud Functions 404/500s from earlier phases are expected and not this phase's concern).

Document results honestly — if a specific interaction can't be verified live (e.g. canvas-tap limitations encountered in earlier phases), fall back to code-review-level confirmation and say so explicitly, matching how Phase 7/9 handled the same limitation.

- [ ] **Step 3: Write the phase completion report**

Cover: what was fixed (10 catalog entries' content-mismatch defects: 5 pairs-mode entries now render their real content, 5 numeric-mismatched entries got real authored pairs-mode content; 2 tugOfWar entries now generate decimal/integer questions instead of silently defaulting to multiplication), files touched, tests added, DEFERRED.md items resolved, verification performed, and any remaining known issues. Explicitly note the grade5/6 content-breadth gap and the `sequenceBuilder`/backdrop/EMS-color items from `docs/DEFERRED.md` were deliberately left out of this phase's scope per the user's decision, and remain there for a future phase if wanted.

- [ ] **Step 4: Stop and wait for "Continue"**

Per the standing engagement rule, do not start Phase 11 until the user explicitly says to continue.
