# Phase 12: Advanced Educational Game Logic Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make per-question XP fair and consistent across all 9 game engines, fix a critical bug where `numberCountingDuel` never persists its earned XP, activate `tugOfWar`'s existing-but-unreachable adaptive-difficulty mechanism on real catalog entries, add within-session difficulty ramping to two engines, fix a catalog-wide content-mismatch bug where 10 `tugOfWar` entries show generic arithmetic questions instead of their advertised subject content, and surface + harden weak-topic mission targeting for learners.

**Architecture:** All engine-layer changes stay inside the existing `GameRouter → <Engine>Game → <Engine>Session → <Engine>Engine` layering (see root `CLAUDE.md` §4). The core fairness fix threads the already-computed-but-discarded `GameAnswerResult.xpDelta` through `GameSessionState` into the final session XP total, replacing the flat `correct * 10` formula. The content-mismatch fix reassigns catalog entries between existing engines (no new engine) and authors new content packs in each target engine's existing pack schema. No new Firestore collections or breaking schema changes.

**Tech Stack:** Flutter/Dart (client engines), TypeScript Cloud Functions (`functions/src/missions/generate.ts`), Firestore, JSON content packs (`assets/content/`).

## Global Constraints

- `flutter analyze` → 0 new errors before every commit (repo-wide CLAUDE.md §9).
- `flutter test` → all green after every task.
- Catalog invariants (CLAUDE.md §4): `adventureJourney` + `tugOfWar` combined ≤ 40% of all 125 entries; every subject ≥ 3 distinct engines; every entry keeps non-empty `learningObjective`/`mechanicReason`.
- No placeholder content — every authored content pack must be real, CAPS-appropriate South African primary-school content.
- Small, reviewable commits; run `flutter analyze` before each (repo CLAUDE.md §8).
- Branch: `phase-12-advanced-game-logic` (already checked out).

---

## Task 1: Thread real per-question XP into session totals

**Context:** Every engine's `checkAnswer()` computes a `GameAnswerResult.xpDelta` that differs meaningfully by engine (tug_of_war 10-15, adventure_journey 10, runner_collector 10, explorer_map 10-15, multiples_merge 20, sequence_builder 25, circuit_builder 15, budget_builder 20/partial 5) — but it is never consumed. `GameSessionState.recordAnswer(bool correct)` only takes a boolean, and the real session XP is always `defaultResult()`'s flat `correct * 10` + completion bonus. This means multi-substep engines (multiples_merge's 6-12-cell chain, sequence_builder's 4-stage ordering, budget_builder's 4-item categorisation) earn the same per-question XP as single-tap engines. It also causes two separate bugs fixed by this same change: `explorer_map` double-applies its perfect-run bonus (its custom `buildResult()` adds +100/+10 on top of `defaultResult()`'s own +100/+10 for a perfect run), and `adventure_journey`'s custom `buildResult()` is missing the "win" (+50 XP, correct > total/2 but not perfect) tier that every `defaultResult()`-based engine gets for free.

**Files:**
- Modify: `lib/features/games/core/game_engine.dart`
- Modify: `lib/features/games/core/game_session_state.dart`
- Modify: `lib/features/games/tug_of_war/tug_of_war_engine.dart`
- Modify: `lib/features/games/tug_of_war/tug_of_war_session.dart`
- Modify: `lib/features/games/adventure_journey/adventure_journey_engine.dart`
- Modify: `lib/features/games/adventure_journey/adventure_journey_session.dart`
- Modify: `lib/features/games/explorer_map/explorer_map_engine.dart`
- Modify: `lib/features/games/explorer_map/explorer_map_session.dart`
- Modify: `lib/features/games/runner_collector/runner_collector_engine.dart`
- Modify: `lib/features/games/runner_collector/runner_collector_session.dart`
- Modify: `lib/features/games/multiples_merge/multiples_merge_engine.dart`
- Modify: `lib/features/games/multiples_merge/multiples_merge_session.dart`
- Modify: `lib/features/games/multiples_merge/multiples_quiz.dart`
- Modify: `lib/features/games/sequence_builder/sequence_builder_engine.dart`
- Modify: `lib/features/games/sequence_builder/sequence_builder_session.dart`
- Modify: `lib/features/games/circuit_builder/circuit_builder_engine.dart`
- Modify: `lib/features/games/circuit_builder/circuit_builder_session.dart`
- Modify: `lib/features/games/budget_builder/budget_builder_engine.dart`
- Modify: `lib/features/games/budget_builder/budget_builder_session.dart`
- Test: `test/games/game_session_xp_fairness_test.dart` (new)

**Interfaces:**
- Produces: `GameSessionState.recordAnswer(GameAnswerResult result)` (signature change from `recordAnswer(bool correct)`), `GameSessionState.xpFromAnswers` getter (`int`), `GameEngine.defaultResult({..., required int xpFromAnswers})`, `GameEngine.buildResult({..., required int xpFromAnswers})`.
- Consumes: existing `GameAnswerResult` class (unchanged shape).

- [ ] **Step 1: Write the failing test**

Create `test/games/game_session_xp_fairness_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/features/games/core/game_config.dart';
import 'package:questkids/features/games/tug_of_war/tug_of_war_engine.dart';
import 'package:questkids/features/games/tug_of_war/tug_of_war_config.dart';
import 'package:questkids/features/games/explorer_map/explorer_map_engine.dart';
import 'package:questkids/features/games/explorer_map/explorer_map_config.dart';
import 'package:questkids/features/games/adventure_journey/adventure_journey_engine.dart';
import 'package:questkids/features/games/adventure_journey/adventure_journey_config.dart';

void main() {
  group('Session XP now reflects real per-question xpDelta', () {
    test('tug_of_war: 3 correct with 1 fast-bonus sums real xpDelta, not correct*10', () {
      const config = GameConfig(
        engineType: 'tugOfWar',
        subject: 'Mathematics',
        grade: 'grade4',
        topicId: 'multiplication',
        subtopicId: 'times_tables',
      );
      final tugConfig = TugOfWarConfig.fromGameConfig(config);
      final engine = TugOfWarEngine(tugConfig: tugConfig, config: config);
      // 2 plain-correct (10 each) + 1 fast-bonus correct (15) = 35, not 3*10=30.
      final result = engine.buildResult(
        correct: 3,
        total: 3,
        timeTakenSeconds: 30,
        xpFromAnswers: 35,
      );
      expect(result.xpEarned, 35 + 100); // + perfect-run bonus
    });

    test('explorer_map perfect run no longer double-applies the +100/+10 bonus', () {
      const config = GameConfig(
        engineType: 'explorerMap',
        subject: 'Social Sciences',
        grade: 'grade4',
        topicId: 'geography_sa',
        subtopicId: 'provinces',
      );
      final engine = ExplorerMapEngine(
        mapConfig: ExplorerMapConfig.forGame(config),
        config: config,
      );
      final result = engine.buildResult(
        correct: 4,
        total: 4,
        timeTakenSeconds: 20,
        xpFromAnswers: 40,
      );
      // Old buggy behaviour would have been 40 + 100 + 100 = 240.
      expect(result.xpEarned, 40 + 100);
      expect(result.coinsEarned, (40 + 100) ~/ 10);
    });

    test('adventure_journey now grants the win (+50) tier like other engines', () {
      const config = GameConfig(
        engineType: 'adventureJourney',
        subject: 'Natural Sciences',
        grade: 'grade4',
        topicId: 'water_cycle',
        subtopicId: 'evaporation_condensation',
      );
      final engine = AdventureJourneyEngine(
        journeyConfig: AdventureJourneyConfig.forGame(config),
        config: config,
      );
      // 3 of 4 correct: a win, not perfect -- old custom formula granted 0 bonus.
      final result = engine.buildResult(
        correct: 3,
        total: 4,
        timeTakenSeconds: 40,
        xpFromAnswers: 30,
      );
      expect(result.xpEarned, 30 + 50);
      expect(result.result, 'win');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/games/game_session_xp_fairness_test.dart`
Expected: FAIL — `buildResult` doesn't accept a named `xpFromAnswers` parameter yet (compile error).

- [ ] **Step 3: Update the base `GameEngine` contract**

In `lib/features/games/core/game_engine.dart`, change the abstract `buildResult` signature and `defaultResult`:

```dart
  /// Build the final [GameSessionResult] once all questions are done
  /// (or the session ends early). [xpFromAnswers] is the sum of every
  /// answer's [GameAnswerResult.xpDelta] this session, tracked by
  /// [GameSessionState] -- the real per-question XP, not a flat formula.
  GameSessionResult buildResult({
    required int correct,
    required int total,
    required int timeTakenSeconds,
    required int xpFromAnswers,
    bool earlyWin = false,
  });

  // ── Default scoring helper — call from concrete buildResult ───────────────

  /// Standard XP formula (spec §2E).  Override in engines that
  /// have different reward tables.
  GameSessionResult defaultResult({
    required int correct,
    required int total,
    required int timeTakenSeconds,
    required int xpFromAnswers,
    bool earlyWin = false,
  }) {
    final accuracy = total > 0 ? correct / total : 0.0;
    final score = (accuracy * 100).round();
    final isWin = earlyWin || correct > total / 2;
    final isPerfect = correct == total;

    int xp = xpFromAnswers;
    if (isPerfect) {
      xp += 100;
    } else if (isWin) {
      xp += 50;
    }

    return GameSessionResult(
      result: isPerfect ? 'complete' : (isWin ? 'win' : 'loss'),
      score: score,
      xpEarned: xp,
      coinsEarned: xp ~/ 10,
      accuracy: accuracy,
    );
  }
```

- [ ] **Step 4: Thread `xpFromAnswers` through `GameSessionState`**

In `lib/features/games/core/game_session_state.dart`:

Add a private field next to `_questionIndex` (line 50):

```dart
  int _correctCount = 0;
  int _xpFromAnswers = 0;
  int _questionIndex = 0;
```

Add a getter next to `correctCount` (line 57):

```dart
  int get correctCount => _correctCount;
  int get xpFromAnswers => _xpFromAnswers;
```

Replace `recordAnswer` (lines 92-100):

```dart
  /// Call inside [submitAnswer] to record the outcome of one answer and
  /// advance to the next question. [result] carries both the correctness
  /// and the real per-question XP (see [GameAnswerResult.xpDelta]) --
  /// accumulated here so [finishSession] can pass a true per-question XP
  /// total into [GameEngine.buildResult] instead of a flat correct-count
  /// formula. Returns true when the session ends.
  @protected
  bool recordAnswer(GameAnswerResult result) {
    if (result.correct) _correctCount++;
    _xpFromAnswers += result.xpDelta;
    _questionIndex++;
    notifyListeners();
    return _questionIndex >= totalQuestions;
  }
```

Update the `buildResult` call inside `finishSession` (around line 110):

```dart
    _result = engine.buildResult(
      correct: _correctCount,
      total: totalQuestions,
      timeTakenSeconds: _elapsed,
      xpFromAnswers: _xpFromAnswers,
      earlyWin: earlyWin,
    );
```

- [ ] **Step 5: Update every engine's `buildResult` override**

`lib/features/games/tug_of_war/tug_of_war_engine.dart` (lines 173-186), `lib/features/games/runner_collector/runner_collector_engine.dart` (lines 104-117), `lib/features/games/multiples_merge/multiples_merge_engine.dart` (lines 211-223), `lib/features/games/multiples_merge/multiples_quiz.dart` (lines 58-70), `lib/features/games/sequence_builder/sequence_builder_engine.dart` (lines 29-41), `lib/features/games/circuit_builder/circuit_builder_engine.dart` (lines 251-262), `lib/features/games/budget_builder/budget_builder_engine.dart` (lines 282-293) — for **each** of these 7, change the `buildResult` override to:

```dart
  @override
  GameSessionResult buildResult({
    required int correct,
    required int total,
    required int timeTakenSeconds,
    required int xpFromAnswers,
    bool earlyWin = false,
  }) =>
      defaultResult(
        correct: correct,
        total: total,
        timeTakenSeconds: timeTakenSeconds,
        xpFromAnswers: xpFromAnswers,
        earlyWin: earlyWin,
      );
```

(`circuit_builder_engine.dart` and `budget_builder_engine.dart` currently use unbraced single-line-arg formatting without trailing commas — keep their existing brace style, just add the `required int xpFromAnswers,` parameter and pass-through argument.)

For `lib/features/games/explorer_map/explorer_map_engine.dart` (lines 42-64), **delete the custom double-bonus logic** and replace with the same one-line passthrough — `defaultResult()` already grants the full perfect-run bonus once `xpFromAnswers` is real, so the extra `+100`/`+10` block was always redundant on top of a correct formula and actively double-counted once `xpFromAnswers` starts carrying real per-question totals:

```dart
  @override
  GameSessionResult buildResult({
    required int correct,
    required int total,
    required int timeTakenSeconds,
    required int xpFromAnswers,
    bool earlyWin = false,
  }) =>
      defaultResult(
        correct: correct,
        total: total,
        timeTakenSeconds: timeTakenSeconds,
        xpFromAnswers: xpFromAnswers,
        earlyWin: earlyWin,
      );
```

For `lib/features/games/adventure_journey/adventure_journey_engine.dart` (lines 46-66), **delete the custom formula** (it was a hand-duplicated, incomplete copy of `defaultResult()` missing the win tier) and replace with the same passthrough:

```dart
  @override
  GameSessionResult buildResult({
    required int correct,
    required int total,
    required int timeTakenSeconds,
    required int xpFromAnswers,
    bool earlyWin = false,
  }) =>
      defaultResult(
        correct: correct,
        total: total,
        timeTakenSeconds: timeTakenSeconds,
        xpFromAnswers: xpFromAnswers,
        earlyWin: earlyWin,
      );
```

- [ ] **Step 6: Run the new test to verify it passes**

Run: `flutter test test/games/game_session_xp_fairness_test.dart`
Expected: still FAIL (engines now compile, but session call sites still call `recordAnswer` with a `bool`) — this is expected; continue to Step 7 before re-running.

- [ ] **Step 7: Update every `recordAnswer` call site**

`lib/features/games/tug_of_war/tug_of_war_session.dart` line 141 — change:
```dart
    final done = recordAnswer(ar.correct);
```
to:
```dart
    final done = recordAnswer(ar);
```

`lib/features/games/explorer_map/explorer_map_session.dart` line 159 (learn-mode discovery — not a scored answer, so use a synthetic result matching the existing non-bonus correct-answer rate of 10 XP) — change:
```dart
      final done = recordAnswer(true);
```
to:
```dart
      final done =
          recordAnswer(const GameAnswerResult(correct: true, xpDelta: 10));
```
and add the import at the top of the file (after line 1 `import 'dart:math';`, before the blank line):
```dart
import '../core/game_engine.dart';
```

Line 200 of the same file — change:
```dart
      final done = recordAnswer(result.correct);
```
to:
```dart
      final done = recordAnswer(result);
```

`lib/features/games/runner_collector/runner_collector_session.dart` — these three call sites never went through `engine.checkAnswer()`; `RunnerCollectorEngine.checkAnswer()` accepts any `answer` and only checks `answer == true`, ignoring `question`, so call it directly to reuse its already-correct `xpDelta` constants instead of hardcoding numbers at each site. Line 163 — change:
```dart
        recordAnswer(true);
```
to:
```dart
        recordAnswer(engine.checkAnswer(currentQuestion ?? const {}, true));
```
Line 171 — change:
```dart
        recordAnswer(false);
```
to:
```dart
        recordAnswer(engine.checkAnswer(currentQuestion ?? const {}, false));
```
Line 198 (level-complete filler loop) — change:
```dart
        recordAnswer(true);
```
to:
```dart
        recordAnswer(engine.checkAnswer(currentQuestion ?? const {}, true));
```

`lib/features/games/multiples_merge/multiples_merge_session.dart` line 161 — `MultiplesMergeEngine.checkAnswer()` has the same `answer == true` shape (ignores `question`), so reuse it the same way. Change:
```dart
    final done = recordAnswer(true);
```
to:
```dart
    final done =
        recordAnswer(engine.checkAnswer(currentQuestion ?? const {}, true));
```

`lib/features/games/multiples_merge/multiples_quiz.dart` line 114 — change:
```dart
      final done = recordAnswer(res.correct);
```
to:
```dart
      final done = recordAnswer(res);
```

`lib/features/games/sequence_builder/sequence_builder_session.dart` line 101 — `SequenceBuilderEngine.checkAnswer()` also has the `answer == true` shape. Change:
```dart
        final done = recordAnswer(true);
```
to:
```dart
        final done = recordAnswer(
            engine.checkAnswer(currentQuestion ?? const {}, true));
```

`lib/features/games/circuit_builder/circuit_builder_session.dart` line 57-58 — change:
```dart
    final done =
        recordAnswer(engine.checkAnswer(currentQuestion!, submitted).correct);
```
to:
```dart
    final done = recordAnswer(engine.checkAnswer(currentQuestion!, submitted));
```

`lib/features/games/budget_builder/budget_builder_session.dart` line 58-60 — change:
```dart
    final done = recordAnswer(engine
        .checkAnswer(currentQuestion!, Map<String, String>.from(_categorised))
        .correct);
```
to:
```dart
    final done = recordAnswer(
        engine.checkAnswer(currentQuestion!, Map<String, String>.from(_categorised)));
```

`lib/features/games/adventure_journey/adventure_journey_session.dart` — this session **overrides** `recordAnswer` itself (lines 103-112) to add retry semantics. Change the override:
```dart
  @override
  bool recordAnswer(bool correct) {
    if (!correct) {
      _retryCount++;
      notifyListeners();
      return false; // never advance on wrong
    }
    _retryCount = 0;
    return super.recordAnswer(correct);
  }
```
to:
```dart
  @override
  bool recordAnswer(GameAnswerResult result) {
    if (!result.correct) {
      _retryCount++;
      notifyListeners();
      return false; // never advance on wrong
    }
    _retryCount = 0;
    return super.recordAnswer(result);
  }
```
and add `import '../core/game_engine.dart';` to its import block (after line 1 `import '../core/game_config.dart';`).

Then update its two call sites. Line 74 (correct branch, `result` from `_engine.checkAnswer(q, answer)` at line 62 is in scope via closure) — change:
```dart
        final done = recordAnswer(true);
```
to:
```dart
        final done = recordAnswer(result);
```
Line 87-88 (wrong branch, same `result` in scope, already `correct: false`) — change:
```dart
        recordAnswer(
            false); // records the wrong attempt but does NOT advance stage
```
to:
```dart
        recordAnswer(
            result); // records the wrong attempt but does NOT advance stage
```

- [ ] **Step 8: Run the fairness test again**

Run: `flutter test test/games/game_session_xp_fairness_test.dart`
Expected: PASS (3/3).

- [ ] **Step 9: Run the full test suite**

Run: `flutter analyze` — expect 0 errors.
Run: `flutter test` — expect all green (this signature change touches every engine, so any pre-existing test calling `recordAnswer`/`buildResult` directly must also be checked; fix any that construct a `GameAnswerResult`-less call).

- [ ] **Step 10: Commit**

```bash
git add lib/features/games/core/game_engine.dart lib/features/games/core/game_session_state.dart lib/features/games/tug_of_war/tug_of_war_engine.dart lib/features/games/tug_of_war/tug_of_war_session.dart lib/features/games/adventure_journey/adventure_journey_engine.dart lib/features/games/adventure_journey/adventure_journey_session.dart lib/features/games/explorer_map/explorer_map_engine.dart lib/features/games/explorer_map/explorer_map_session.dart lib/features/games/runner_collector/runner_collector_engine.dart lib/features/games/runner_collector/runner_collector_session.dart lib/features/games/multiples_merge/multiples_merge_engine.dart lib/features/games/multiples_merge/multiples_merge_session.dart lib/features/games/multiples_merge/multiples_quiz.dart lib/features/games/sequence_builder/sequence_builder_engine.dart lib/features/games/sequence_builder/sequence_builder_session.dart lib/features/games/circuit_builder/circuit_builder_engine.dart lib/features/games/circuit_builder/circuit_builder_session.dart lib/features/games/budget_builder/budget_builder_engine.dart lib/features/games/budget_builder/budget_builder_session.dart test/games/game_session_xp_fairness_test.dart
git commit -m "fix(games): thread real per-question XP into session totals

xpDelta was computed by every engine's checkAnswer() but silently
discarded; session XP was always a flat correct*10. Also fixes
explorer_map's double-applied perfect-run bonus and adds
adventure_journey's missing win-tier bonus, both side effects of the
same dead-code path."
```

---

## Task 2: Extract shared session-persistence helper and fix `numberCountingDuel`'s lost XP

**Context:** `numberCountingDuel` is a fully self-contained `StatefulWidget` (its own doc comment says so) that never goes through `GameSessionState`/`GameRepository`/`RewardsService`. Its victory screen displays a real `totalXP` total (`+10` per correct answer, `lib/features/games/number_counting_duel/number_counting_duel_game.dart:245`), but that XP is **never written to Firestore** — `GameRouter` doesn't even pass the `GameConfig` through to it (`lib/features/games/core/game_router.dart:48-49` calls `NumberCountingDuelGame(user: user)`, dropping `config`). A learner playing this game earns and sees XP that silently vanishes: it never reaches `player_stats`, `game_progress`, the leaderboard, or the Rewards screen.

**Files:**
- Modify: `lib/features/games/core/game_session_persistence.dart` (extract shared helper)
- Modify: `lib/features/games/core/game_session_state.dart` (use the extracted helper)
- Modify: `lib/features/games/core/game_router.dart`
- Modify: `lib/features/games/number_counting_duel/number_counting_duel_game.dart`
- Test: `test/games/number_counting_duel_persistence_test.dart` (new)

**Interfaces:**
- Produces: `Future<void> persistGameSession(GameSessionModel session)` in `game_session_persistence.dart`.
- Consumes: `GameRepository.logGameSession`, `RewardsService().grantGameSessionRewards`, `AnalyticsService.logGameComplete`, `OfflineService`, `shouldQueueGameSessionOffline` (all pre-existing, unchanged signatures).

- [ ] **Step 1: Write the failing test**

Create `test/games/number_counting_duel_persistence_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/features/games/core/game_config.dart';
import 'package:questkids/features/games/core/game_router.dart';
import 'package:questkids/features/games/number_counting_duel/number_counting_duel_game.dart';
import '../firebase_test_helpers.dart';

void main() {
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await setupFirebaseForTests();
  });

  testWidgets('GameRouter passes config through to NumberCountingDuelGame',
      (tester) async {
    const config = GameConfig(
      engineType: 'numberCountingDuel',
      subject: 'Mathematics',
      grade: 'grade1',
      topicId: 'numbers',
      subtopicId: 'counting',
      catalogId: 'math_g1_counting',
    );
    await tester.pumpWidget(const MaterialApp(
      home: GameRouter(config: config, user: null),
    ));
    expect(find.byType(NumberCountingDuelGame), findsOneWidget);
    final widget =
        tester.widget<NumberCountingDuelGame>(find.byType(NumberCountingDuelGame));
    expect(widget.config.catalogId, 'math_g1_counting');
  });
}
```

(If `test/firebase_test_helpers.dart` with `setupFirebaseCoreMocks()`/`setupFirebaseForTests()` doesn't exist under that exact name, use whatever this repo's existing widget tests import for Firebase mocking — check `test/widgets/multiples_merge_pairs_widget_test.dart` from Phase 10 for the established import path and copy it exactly.)

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/games/number_counting_duel_persistence_test.dart`
Expected: FAIL — `NumberCountingDuelGame` has no `config` parameter yet.

- [ ] **Step 3: Extract the shared persistence helper**

In `lib/features/games/core/game_session_persistence.dart`, add imports and the new function (keep the existing `shouldQueueGameSessionOffline` untouched):

```dart
import '../../../core/services/analytics_service.dart';
import '../../../core/services/offline_service.dart';
import '../../../core/services/rewards_service.dart';
import '../../../data/models/game_session_model.dart';
import '../../../data/repositories/game_repository.dart';

/// A session should be queued to the local pending-sync table whenever
/// the Firestore write did not succeed, regardless of why (device is
/// offline, or the write threw for some other transient reason).
///
/// [isOnline] is accepted for readability at call sites even though the
/// logic collapses to `!writeSucceeded` -- a failed write must always be
/// queued whether or not the device *currently* reports online, since a
/// reported-online write can still fail (a Firestore permission hiccup,
/// or a captive-portal wifi false positive from connectivity_plus).
bool shouldQueueGameSessionOffline({
  required bool isOnline,
  required bool writeSucceeded,
}) =>
    !writeSucceeded;

/// Logs a completed [session] to Firestore, records analytics, grants
/// rewards, and falls back to the offline queue on failure. Shared by
/// [GameSessionState.finishSession] and any self-contained game widget
/// that doesn't go through the GameEngine/GameSessionState architecture
/// (currently only NumberCountingDuelGame) -- both need identical
/// online/offline/rewards handling, so this is the one place it lives.
Future<void> persistGameSession(GameSessionModel session) async {
  final offlineService = OfflineService();
  final online = await offlineService.isOnline();
  var writeSucceeded = false;
  if (online) {
    try {
      await GameRepository().logGameSession(session);
      writeSucceeded = true;
      try {
        await AnalyticsService.logGameComplete(
          engineType: session.engineType,
          subject: session.subject,
          score: session.score,
        );
      } catch (_) {
        // Non-fatal: analytics failures must never affect gameplay.
      }
      try {
        await RewardsService().grantGameSessionRewards(session);
      } catch (_) {
        // Non-fatal: the session itself is already saved; a failure
        // here just means this session's XP won't show on the
        // Rewards screen/dashboard until the next successful grant.
      }
    } catch (_) {
      writeSucceeded = false;
    }
  }
  if (shouldQueueGameSessionOffline(
      isOnline: online, writeSucceeded: writeSucceeded)) {
    await offlineService.saveGameSessionOffline(session);
  }
}
```

- [ ] **Step 4: Use the extracted helper from `GameSessionState.finishSession`**

In `lib/features/games/core/game_session_state.dart`, replace the inline persistence block inside `finishSession` (the `if (uid.isNotEmpty) { ... }` body from `final session = GameSessionModel(...)` through the closing of the `if (online)` block) with a call to the shared helper. The method becomes:

```dart
  @protected
  Future<void> finishSession(String uid, {bool earlyWin = false}) async {
    if (_finished) return;
    _ticker?.cancel();
    _finished = true;

    _result = engine.buildResult(
      correct: _correctCount,
      total: totalQuestions,
      timeTakenSeconds: _elapsed,
      xpFromAnswers: _xpFromAnswers,
      earlyWin: earlyWin,
    );
    notifyListeners();

    if (uid.isNotEmpty) {
      final session = GameSessionModel(
        id: _uuid.v4(),
        uid: uid,
        grade: config.grade,
        subject: config.subject,
        engineType: config.engineType,
        score: _result!.score,
        xpEarned: _result!.xpEarned,
        coinsEarned: _result!.coinsEarned,
        accuracy: _result!.accuracy,
        timeTakenSeconds: _elapsed,
        completedAt: DateTime.now(),
        result: _result!.result,
      );
      await persistGameSession(session);
    }
  }
```

Remove the now-unused imports this leaves behind at the top of the file (`../../../core/services/analytics_service.dart`, `../../../core/services/offline_service.dart`, `../../../core/services/rewards_service.dart`, `../../../data/repositories/game_repository.dart` — check each is not used elsewhere in the file before removing; `game_session_persistence.dart` is already imported at line 13 and now exposes everything needed).

- [ ] **Step 5: Pass `config` through `GameRouter` to `NumberCountingDuelGame`**

In `lib/features/games/core/game_router.dart`, change line 48-49:
```dart
      AppConstants.engineNumberCountingDuel =>
        NumberCountingDuelGame(user: user),
```
to:
```dart
      AppConstants.engineNumberCountingDuel =>
        NumberCountingDuelGame(config: config, user: user),
```

- [ ] **Step 6: Accept `config` and persist the session in `NumberCountingDuelGame`**

In `lib/features/games/number_counting_duel/number_counting_duel_game.dart`, add imports at the top (after the existing 3):

```dart
import 'package:uuid/uuid.dart';

import '../core/game_config.dart';
import '../core/game_session_persistence.dart';
import '../../../data/models/game_session_model.dart';
```

Change the widget class (lines 52-58):
```dart
class NumberCountingDuelGame extends StatefulWidget {
  final GameConfig config;
  final dynamic user;
  const NumberCountingDuelGame({super.key, required this.config, this.user});

  @override
  State<NumberCountingDuelGame> createState() => _NCDState();
}
```

Add a `uid` getter near the top of `_NCDState` (after the `_rng` field, line 102), matching the exact pattern already used in `TugOfWarGame`'s state class:

```dart
  String get _uid => (widget.user?.uid as String?) ?? '';
```

In `_advance()` (around line 267), the victory branch currently just sets `_phase = _Phase.victory`. Total questions across all 5 levels is `_levels.length * 5 = 25` (each `_Level.questionCount` is a fixed `5`). Change:
```dart
      if (_levelIdx + 1 >= _levels.length) {
        setState(() => _phase = _Phase.victory);
      } else {
```
to:
```dart
      if (_levelIdx + 1 >= _levels.length) {
        _persistSession();
        setState(() => _phase = _Phase.victory);
      } else {
```

Add the persistence method near `_advance` (after it):

```dart
  /// Persists this completed session the same way every other engine's
  /// GameSessionState.finishSession does -- this widget is intentionally
  /// self-contained (no GameEngine/GameSessionState), but it must not
  /// silently drop the XP it already shows the player on the victory
  /// screen. Applies the same completion-bonus tiers as
  /// GameEngine.defaultResult() so the number shown here matches what
  /// actually gets awarded.
  void _persistSession() {
    const totalQuestions = 25; // 5 levels x 5 questions (_Level.questionCount)
    final accuracy = totalQuestions > 0 ? _playerSco / totalQuestions : 0.0;
    final isPerfect = _playerSco == totalQuestions;
    final isWin = _playerSco > totalQuestions / 2;
    var xp = _totalXP;
    if (isPerfect) {
      xp += 100;
    } else if (isWin) {
      xp += 50;
    }
    setState(() => _totalXP = xp);

    final uid = _uid;
    if (uid.isEmpty) return;
    final session = GameSessionModel(
      id: const Uuid().v4(),
      uid: uid,
      grade: widget.config.grade,
      subject: widget.config.subject,
      engineType: widget.config.engineType,
      score: (accuracy * 100).round(),
      xpEarned: xp,
      coinsEarned: xp ~/ 10,
      accuracy: accuracy,
      timeTakenSeconds: 0,
      completedAt: DateTime.now(),
      result: isPerfect ? 'complete' : (isWin ? 'win' : 'loss'),
    );
    persistGameSession(session);
  }
```

- [ ] **Step 7: Run the persistence test**

Run: `flutter test test/games/number_counting_duel_persistence_test.dart`
Expected: PASS.

- [ ] **Step 8: Run the full test suite**

Run: `flutter analyze` — expect 0 errors.
Run: `flutter test` — expect all green.

- [ ] **Step 9: Commit**

```bash
git add lib/features/games/core/game_session_persistence.dart lib/features/games/core/game_session_state.dart lib/features/games/core/game_router.dart lib/features/games/number_counting_duel/number_counting_duel_game.dart test/games/number_counting_duel_persistence_test.dart
git commit -m "fix(games): persist numberCountingDuel XP -- it was never saved to Firestore

Extracted GameSessionState.finishSession's persistence logic into a
shared persistGameSession() helper so the self-contained
NumberCountingDuelGame widget (which bypasses GameEngine entirely) can
reuse it instead of silently discarding the XP its own victory screen
displays."
```

---

## Task 3: Wire `tugOfWar` adaptive difficulty into real catalog entries

**Context:** `TugOfWarConfig.fromGameConfig` (`lib/features/games/tug_of_war/tug_of_war_config.dart:44-61`) already branches on `config.difficulty == 'adaptive'` for opponent pacing/accuracy/multiplier-max, and `TugOfWarSession.submitAnswer` (`lib/features/games/tug_of_war/tug_of_war_session.dart:131-136`) already speeds the opponent up after a 3-answer streak when `config.difficulty == 'adaptive'`. No catalog entry has ever used `difficulty: 'adaptive'` (`grep` confirms zero matches in `game_catalog.dart`), so this mechanism has never run in production. Separately, the existing mechanism only ratchets one direction (faster after a hit-streak, never eases back after a miss-streak) — a real fairness gap once genuinely exercised, especially for entries that must serve a 3-grade span in one catalog entry.

**Files:**
- Modify: `lib/core/constants/game_catalog.dart`
- Modify: `lib/features/games/tug_of_war/tug_of_war_session.dart`
- Test: `test/games/tug_of_war_adaptive_difficulty_test.dart` (new)

**Interfaces:**
- Consumes: `TugOfWarConfig.fromGameConfig` (unchanged), `TugOfWarSession._currentOpponentIntervalMs`/`_restartOpponent()` (existing private state/method).

- [ ] **Step 1: Write the failing test**

Create `test/games/tug_of_war_adaptive_difficulty_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/features/games/core/game_config.dart';
import 'package:questkids/features/games/tug_of_war/tug_of_war_session.dart';

void main() {
  group('TugOfWar adaptive difficulty eases back down after a miss streak', () {
    test('opponent interval slows back toward the config default after 3 misses', () {
      const config = GameConfig(
        engineType: 'tugOfWar',
        subject: 'Mathematics',
        grade: 'grade4',
        topicId: 'multiplication',
        subtopicId: 'times_tables',
        difficulty: 'adaptive',
      );
      final session = TugOfWarSession(config, 'test-uid');
      session.startSession();

      // Force 3 wrong answers in a row.
      for (var i = 0; i < 3; i++) {
        session.appendDigit('1');
        session.submitAnswer('999999'); // near-certainly wrong
      }

      expect(session.currentOpponentIntervalMs,
          greaterThanOrEqualTo(session.tugConfig.opponentIntervalMs));
      session.dispose();
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/games/tug_of_war_adaptive_difficulty_test.dart`
Expected: FAIL — `currentOpponentIntervalMs` and `tugConfig` aren't public accessors yet.

- [ ] **Step 3: Expose the two accessors and add the symmetric ease-down branch**

In `lib/features/games/tug_of_war/tug_of_war_session.dart`, add two public getters next to the existing accessors (after line 53 `bool? get lastAnswerCorrect => _lastAnswerCorrect;`):

```dart
  int get currentOpponentIntervalMs => _currentOpponentIntervalMs;
  TugOfWarConfig get tugConfig => _tugConfig;
```

Add a miss-streak counter next to `_playerStreak` (line 39):
```dart
  int _playerStreak = 0;
  int _missStreak = 0;
```

Update the streak-handling block (lines 130-139) to add the symmetric ease-down branch:
```dart
    if (ar.correct) {
      _playerStreak++;
      _missStreak = 0;
      if (_playerStreak >= 3 && config.difficulty == 'adaptive') {
        _currentOpponentIntervalMs =
            (_currentOpponentIntervalMs * 0.85).toInt().clamp(1500, 8000);
        _restartOpponent();
      }
    } else {
      _playerStreak = 0;
      _missStreak++;
      if (_missStreak >= 3 && config.difficulty == 'adaptive') {
        _currentOpponentIntervalMs =
            (_currentOpponentIntervalMs * 1.18)
                .toInt()
                .clamp(1500, _tugConfig.opponentIntervalMs);
        _missStreak = 0;
        _restartOpponent();
      }
    }
```

- [ ] **Step 4: Run the adaptive-difficulty test**

Run: `flutter test test/games/tug_of_war_adaptive_difficulty_test.dart`
Expected: PASS.

- [ ] **Step 5: Flip the 4 grade-spanning Mathematics `tugOfWar` entries to adaptive**

In `lib/core/constants/game_catalog.dart`, these 4 entries are the only `tugOfWar` entries whose `grades` list spans all of grade4/grade5/grade6 in one catalog entry — the strongest case for adaptive pacing, since one entry must serve the widest ability range of any `tugOfWar` game. Change each entry's `difficulty:` line:

`math_g4_measurement` (line 443): `difficulty: 'medium',` → `difficulty: 'adaptive',`
`math_g4_decimals` (line 485): `difficulty: 'hard',` → `difficulty: 'adaptive',`
`math_g4_division` (line 527): `difficulty: 'hard',` → `difficulty: 'adaptive',`
`math_g4_timestable` (line 588): `difficulty: 'medium',` → `difficulty: 'adaptive',`

- [ ] **Step 6: Run the full test suite**

Run: `flutter analyze` — expect 0 errors.
Run: `flutter test` — expect all green.

- [ ] **Step 7: Commit**

```bash
git add lib/features/games/tug_of_war/tug_of_war_session.dart lib/core/constants/game_catalog.dart test/games/tug_of_war_adaptive_difficulty_test.dart
git commit -m "feat(tugOfWar): activate adaptive difficulty on 4 grade-spanning entries

TugOfWarConfig/TugOfWarSession already had a full adaptive-difficulty
mechanism (opponent pacing/accuracy scaled by config.difficulty ==
'adaptive'), but zero catalog entries ever used it. Wired it into the
4 Mathematics tugOfWar entries that span grade4-6 in one entry, and
added a symmetric ease-down branch after a 3-miss streak -- the
existing mechanism only ever sped the opponent up, never back down."
```

---

## Task 4: Add within-session difficulty ramping to `tugOfWar`

**Context:** `TugOfWarEngine.generateQuestions()` generates the full question batch once at session start using a single fixed `[multiplierMin, multiplierMax]` range for every question. This task makes the numbers themselves get harder as the session progresses (independent of the adaptive opponent-pacing mechanism from Task 3, which only affects the opponent's answer speed, not question difficulty).

**Files:**
- Modify: `lib/features/games/tug_of_war/tug_of_war_engine.dart`
- Test: `test/games/tug_of_war_ramping_test.dart` (new)

- [ ] **Step 1: Write the failing test**

Create `test/games/tug_of_war_ramping_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/features/games/core/game_config.dart';
import 'package:questkids/features/games/tug_of_war/tug_of_war_config.dart';
import 'package:questkids/features/games/tug_of_war/tug_of_war_engine.dart';

void main() {
  test('later questions in a tugOfWar session use a wider multiplier range', () {
    const config = GameConfig(
      engineType: 'tugOfWar',
      subject: 'Mathematics',
      grade: 'grade4',
      topicId: 'multiplication',
      subtopicId: 'times_tables',
      questionCount: 12,
      extras: {'multiplierMin': 2, 'multiplierMax': 12},
    );
    final tugConfig = TugOfWarConfig.fromGameConfig(config);
    final engine = TugOfWarEngine(tugConfig: tugConfig, config: config);
    final questions = engine.generateQuestions();

    final firstThirdMax = questions
        .take(4)
        .map((q) => [q['a'] as int, q['b'] as int].reduce((a, b) => a > b ? a : b))
        .reduce((a, b) => a > b ? a : b);
    final lastThirdMax = questions
        .skip(8)
        .map((q) => [q['a'] as int, q['b'] as int].reduce((a, b) => a > b ? a : b))
        .reduce((a, b) => a > b ? a : b);

    expect(lastThirdMax, greaterThanOrEqualTo(firstThirdMax));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/games/tug_of_war_ramping_test.dart`
Expected: Likely FAIL or flaky-pass (current generation draws from the full range uniformly at random for every question, so no ramping guarantee exists).

- [ ] **Step 3: Implement ramping in `generateQuestions()`**

In `lib/features/games/tug_of_war/tug_of_war_engine.dart`, replace the question-generation loop (lines 19-32) to scale the effective max per-question based on progress through the batch:

```dart
  @override
  List<Map<String, dynamic>> generateQuestions() {
    final min = tugConfig.multiplierMin;
    final max = tugConfig.multiplierMax;
    final count = config.questionCount;
    final type = tugConfig.questionType;

    final Set<String> used = {};
    final List<Map<String, dynamic>> out = [];
    int attempts = 0;

    while (out.length < count && attempts < 2000) {
      attempts++;
      // Ramp the effective range across the session: the first third of
      // questions stays at the easiest half of [min, max], the middle
      // third opens up to three-quarters of the range, and only the
      // final third reaches the full configured max. Keeps early
      // questions approachable and later ones the hardest, rather than
      // drawing uniformly from the full range for every question.
      final progress = count > 1 ? out.length / count : 1.0;
      final rampFactor = progress < 1 / 3
          ? 0.5
          : (progress < 2 / 3 ? 0.75 : 1.0);
      final effectiveMax =
          (min + ((max - min) * rampFactor)).round().clamp(min, max);

      final a = min + _rng.nextInt(effectiveMax - min + 1);
      final b = min + _rng.nextInt(effectiveMax - min + 1);
      final key = '$a×$b';
      if (used.contains(key)) continue;
      used.add(key);
```

(The `switch (type) { ... }` block below is unchanged — it already reads `a`/`b` from the loop.)

- [ ] **Step 4: Run the ramping test**

Run: `flutter test test/games/tug_of_war_ramping_test.dart`
Expected: PASS.

- [ ] **Step 5: Run the full test suite**

Run: `flutter analyze` — expect 0 errors.
Run: `flutter test` — expect all green (re-run the Task 1 fairness test and Task 3 adaptive test too, since this touches the same file).

- [ ] **Step 6: Commit**

```bash
git add lib/features/games/tug_of_war/tug_of_war_engine.dart test/games/tug_of_war_ramping_test.dart
git commit -m "feat(tugOfWar): ramp question difficulty across a session

Questions were drawn uniformly from the full configured multiplier
range for the whole session. Now the first third of questions stays
in the easier half of the range and only the final third reaches the
full configured max."
```

---

## Task 5: Add within-session difficulty ramping to `multiplesMerge`

**Context:** `MultiplesMergeEngine.buildRound()` always uses the single `mergeConfig.chainLength` for every round in a session (fixed per grade tier, e.g. 6/9/12). This task ramps the chain length up across the session's rounds, using the round index already available to the session.

**Files:**
- Modify: `lib/features/games/multiples_merge/multiples_merge_engine.dart`
- Modify: `lib/features/games/multiples_merge/multiples_merge_session.dart`
- Test: `test/games/multiples_merge_ramping_test.dart` (new)

- [ ] **Step 1: Write the failing test**

Create `test/games/multiples_merge_ramping_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/features/games/core/game_config.dart';
import 'package:questkids/features/games/multiples_merge/multiples_merge_config.dart';
import 'package:questkids/features/games/multiples_merge/multiples_merge_engine.dart';

void main() {
  test('chain length ramps up across rounds within a session', () {
    const config = GameConfig(
      engineType: 'multiplesMerge',
      subject: 'Mathematics',
      grade: 'grade4',
      topicId: 'multiplication',
      subtopicId: 'times_tables',
      questionCount: 6,
    );
    final mergeConfig = MultiplesMergeConfig.forGrade(config);
    final engine = MultiplesMergeEngine(mergeConfig: mergeConfig, config: config);

    final firstRound =
        engine.buildRound(roundIndex: 0, totalRounds: config.questionCount);
    final lastRound = engine.buildRound(
        roundIndex: config.questionCount - 1,
        totalRounds: config.questionCount);

    expect(lastRound.chainLength, greaterThanOrEqualTo(firstRound.chainLength));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/games/multiples_merge_ramping_test.dart`
Expected: FAIL — `buildRound()` doesn't accept `roundIndex`/`totalRounds` yet.

- [ ] **Step 3: Add ramping parameters to `buildRound`**

In `lib/features/games/multiples_merge/multiples_merge_engine.dart`, change `buildRound` (line 49) and `_buildNumericRound` (lines 52-78) — pairs mode always uses a fixed `chainLength: 2` (two adjacent cells; ramping doesn't apply there, so only numeric mode ramps):

```dart
  /// Build a fresh, solvable round for the configured mode. [roundIndex]
  /// (0-based) and [totalRounds] ramp numeric mode's chain length up
  /// across a session -- pairs mode always uses exactly 2 cells (one
  /// term/definition pair), so ramping doesn't apply there.
  MergeRound buildRound({required int roundIndex, required int totalRounds}) =>
      mergeConfig.mode == 'pairs'
          ? _buildPairsRound()
          : _buildNumericRound(roundIndex, totalRounds);

  MergeRound _buildNumericRound(int roundIndex, int totalRounds) {
    final table = mergeConfig.tables[_rng.nextInt(mergeConfig.tables.length)];
    final n = mergeConfig.gridSize;
    final baseLen = mergeConfig.chainLength.clamp(2, n * n);
    // Ramp: first round starts 2 shorter than the configured chain length
    // (never below 2, the minimum a chain can be), the last round reaches
    // the full configured length, and rounds in between step evenly
    // between those two bounds.
    final progress = totalRounds > 1 ? roundIndex / (totalRounds - 1) : 1.0;
    final len = (baseLen - 2 + (2 * progress).round()).clamp(2, n * n);

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
```

- [ ] **Step 4: Update the session's call site**

In `lib/features/games/multiples_merge/multiples_merge_session.dart`, find the `_startRound()` method's call to `engine.buildRound()` (it constructs the round that becomes `_round`). Update the call to pass the current round index and total rounds:

```dart
    _round = engine.buildRound(
      roundIndex: questionIndex,
      totalRounds: config.questionCount,
    );
```

(Locate the exact existing line via `grep -n "buildRound(" lib/features/games/multiples_merge/multiples_merge_session.dart` before editing — it is called from `_startRound()`, referenced at line 168 of the file as already read in this investigation; replace its argument-less call with the one above, keeping the rest of `_startRound()`'s body unchanged.)

- [ ] **Step 5: Run the ramping test**

Run: `flutter test test/games/multiples_merge_ramping_test.dart`
Expected: PASS.

- [ ] **Step 6: Run the full test suite**

Run: `flutter analyze` — expect 0 errors.
Run: `flutter test` — expect all green, including the Phase 10 `test/games/multiples_merge_pairs_mode_test.dart` and `test/widgets/multiples_merge_pairs_widget_test.dart` (pairs mode is untouched by this change, but re-verify since `buildRound`'s signature changed).

- [ ] **Step 7: Commit**

```bash
git add lib/features/games/multiples_merge/multiples_merge_engine.dart lib/features/games/multiples_merge/multiples_merge_session.dart test/games/multiples_merge_ramping_test.dart
git commit -m "feat(multiplesMerge): ramp chain length across a session's rounds

Numeric-mode rounds always used the same configured chain length. Now
the first round starts 2 cells shorter (min 2) and later rounds ramp
up to the full configured length. Pairs mode is unaffected (always 2
cells by design)."
```

---

## Task 6: Add an `algebra` question type to `TugOfWarEngine` and wire `math_g7_algebra`

**Context:** `math_g7_algebra` ("Algebra Arena", `topicId: 'algebra'`, `subtopicId: 'linear_equations'`) is a real arithmetic-adjacent Mathematics `tugOfWar` entry, but `algebra/linear_equations` is missing from `_questionTypeByTopic` in `tug_of_war_config.dart`, so it silently falls back to generic multiplication questions ("7 × 4 = ?") instead of solving for x — a genuine "wrong content shown" bug, same shape as the 9 entries fixed in Task 7, but fixable by completing the arithmetic mapping (like Phase 10 did for decimals/integers) rather than reassigning to a different engine, since solving a simple linear equation for a single numeric answer fits `tugOfWar`'s fast head-to-head numeric-answer mechanic well.

**Files:**
- Modify: `lib/features/games/tug_of_war/tug_of_war_config.dart`
- Modify: `lib/features/games/tug_of_war/tug_of_war_engine.dart`
- Test: `test/games/tug_of_war_algebra_test.dart` (new)

- [ ] **Step 1: Write the failing test**

Create `test/games/tug_of_war_algebra_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/features/games/core/game_config.dart';
import 'package:questkids/features/games/tug_of_war/tug_of_war_config.dart';
import 'package:questkids/features/games/tug_of_war/tug_of_war_engine.dart';

void main() {
  test('algebra/linear_equations topic generates solve-for-x questions, not multiplication', () {
    const config = GameConfig(
      engineType: 'tugOfWar',
      subject: 'Mathematics',
      grade: 'grade7',
      topicId: 'algebra',
      subtopicId: 'linear_equations',
    );
    final tugConfig = TugOfWarConfig.fromGameConfig(config);
    expect(tugConfig.questionType, 'algebra');

    final engine = TugOfWarEngine(tugConfig: tugConfig, config: config);
    final questions = engine.generateQuestions();
    expect(questions, isNotEmpty);
    for (final q in questions) {
      expect(q['type'], 'algebra');
      // ax + b = c form: verify the stored answer actually solves the
      // stored a/b/c, i.e. a*answer + b == c.
      final a = q['coeffA'] as int;
      final b = q['coeffB'] as int;
      final c = q['coeffC'] as int;
      final answer = q['answer'] as int;
      expect(a * answer + b, c);
    }
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/games/tug_of_war_algebra_test.dart`
Expected: FAIL — `tugConfig.questionType` is `'multiplication'` (the fallback), not `'algebra'`.

- [ ] **Step 3: Add the mapping entry**

In `lib/features/games/tug_of_war/tug_of_war_config.dart`, add to `_questionTypeByTopic` (after the `'integers/integer_operations': 'integer',` line):

```dart
  'algebra/linear_equations': 'algebra',
```

Also fix the now-doubly-inaccurate doc comment above the map (lines 3-8) — it was already wrong before this phase (Task 7 proves several non-arithmetic topics *do* reach the fallback in production) and `algebra/linear_equations` was a second, independent case of the same fallback being reached unintentionally. Replace it with:

```dart
/// topicId/subtopicId -> questionType, mirroring
/// tools/gamegen/content/math.js's OP_BY_SUBTOPIC. Every tugOfWar catalog
/// entry's topic/subtopic pair must have an entry here, or it silently
/// falls back to 'multiplication' -- see game_catalog.dart for the full
/// list of tugOfWar entries and keep this map in sync with it.
```

- [ ] **Step 4: Generate solve-for-x questions in `TugOfWarEngine`**

In `lib/features/games/tug_of_war/tug_of_war_engine.dart`, add a new `case 'algebra':` arm to the `switch (type)` block, after the existing `case 'integer':` arm and before `default:`:

```dart
        case 'algebra':
          // Solve ax + b = c for x. Reuse the dedup-checked a/b pair: a
          // becomes the coefficient (never 0, so the equation always has
          // exactly one solution), b becomes a random small answer (the
          // value of x itself, kept in the keypad's comfortable range),
          // and c is derived so the equation is guaranteed solvable in
          // integers.
          final coeffA = 1 + (a % 9); // 1..9, never 0
          final answer = 1 + (b % 12); // the solution x, 1..12
          final coeffB = 1 + ((a + b) % 15); // 1..15
          final coeffC = coeffA * answer + coeffB;
          out.add({
            'a': coeffA,
            'b': answer,
            'coeffA': coeffA,
            'coeffB': coeffB,
            'coeffC': coeffC,
            'answer': answer,
            'display':
                '${coeffA}x + $coeffB = $coeffC. What is x?',
            'type': type,
          });
```

- [ ] **Step 5: Run the algebra test**

Run: `flutter test test/games/tug_of_war_algebra_test.dart`
Expected: PASS.

- [ ] **Step 6: Run the full test suite**

Run: `flutter analyze` — expect 0 errors.
Run: `flutter test` — expect all green.

- [ ] **Step 7: Commit**

```bash
git add lib/features/games/tug_of_war/tug_of_war_config.dart lib/features/games/tug_of_war/tug_of_war_engine.dart test/games/tug_of_war_algebra_test.dart
git commit -m "fix(tugOfWar): add algebra question type -- math_g7_algebra showed multiplication, not linear equations

algebra/linear_equations was missing from _questionTypeByTopic, so
Algebra Arena silently fell back to generic multiplication questions
instead of solving for x."
```

---

## Task 7: Reassign 9 non-arithmetic `tugOfWar` catalog entries to their correct engines

**Context:** 9 of the 19 `tugOfWar` catalog entries have topics with no arithmetic content at all (phonics, spelling, debate, healthy habits, weather, wellbeing, human health) — none are in `_questionTypeByTopic`, so every one of them silently falls back to generic multiplication questions in production, contradicting each entry's advertised `learningObjective`. This directly contradicts a doc comment written in Phase 10 claiming this fallback was "never actually reached... in practice" — that claim was false. Each of the 9 has a fully-authored, on-topic content pack already sitting in `assets/content/` (real quiz questions), but `TugOfWarEngine` never reads content packs at all (it's a pure numeric generator), so that content has always been dead data.

The fix is to reassign each entry to the engine already used for its closest sibling topic elsewhere in the catalog (confirmed via a full catalog audit):
- `phonics/blending`, `spelling/grade_level_words`, `spelling/advanced_spelling`, `speaking/debate`, `speaking/formal_debate` → `sequenceBuilder` (siblings: `phonics/alphabet`→adventureJourney but `spelling/cvc_words`→sequenceBuilder and `speaking/oral_presentation`→sequenceBuilder; spelling and structured-speech topics consistently use sequenceBuilder elsewhere in the catalog).
- `health/healthy_habits`, `mental_health/wellbeing`, `biology/human_health` → `runnerCollector` (siblings: `health/healthy_living`, `biology/cells`, `biology/reproduction` all already use runnerCollector).
- `weather/weather_patterns` → `runnerCollector` (Natural Sciences' most common non-circuitBuilder engine; a sort-into-the-right-category mechanic fits classifying weather signs/cloud types).

Both catalog invariants hold after this change (verified via a per-subject engine-distribution audit): `adventureJourney`+`tugOfWar` combined drops from 47/125 (37.6%) to 38/125 (30.4%), well under the 40% cap; English drops from 5 to 4 distinct engines (still ≥3: adventureJourney, sequenceBuilder, runnerCollector, multiplesMerge), Life Skills drops from 5 to 4 (still ≥3), Natural Sciences drops from 6 to 5 (still ≥3).

**Files:**
- Modify: `lib/core/constants/game_catalog.dart`
- Modify: `lib/features/games/tug_of_war/tug_of_war_config.dart` (doc comment correction)
- Test: `test/catalog/catalog_invariants_test.dart` (new, or extend an existing catalog test if one already exists — check `test/` for a `game_catalog` test file first via `grep -rl "GameCatalog.all" test/`)

- [ ] **Step 1: Write the failing test**

Create (or extend, if one exists) `test/catalog/catalog_invariants_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/core/constants/game_catalog.dart';

void main() {
  group('Catalog invariants after Phase 12 tugOfWar content-mismatch fix', () {
    test('every tugOfWar catalog entry has a real arithmetic topic/subtopic', () {
      // The complete set of topic/subtopic pairs TugOfWarEngine can render
      // correctly (mirrors _questionTypeByTopic in tug_of_war_config.dart).
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
      final offenders = GameCatalog.all
          .where((e) => e.engineType == 'tugOfWar')
          .where((e) =>
              !arithmeticTopics.contains('${e.topicId}/${e.subtopicId}'))
          .map((e) => e.id)
          .toList();
      expect(offenders, isEmpty,
          reason: 'tugOfWar entries with no matching question type show '
              'wrong content: $offenders');
    });

    test('adventureJourney + tugOfWar stays <= 40% of the catalog', () {
      final total = GameCatalog.all.length;
      final combined = GameCatalog.all
          .where((e) => e.engineType == 'adventureJourney' || e.engineType == 'tugOfWar')
          .length;
      expect(combined / total, lessThanOrEqualTo(0.40));
    });

    test('every subject uses at least 3 distinct engines', () {
      final bySubject = <String, Set<String>>{};
      for (final e in GameCatalog.all) {
        bySubject.putIfAbsent(e.subject, () => {}).add(e.engineType);
      }
      for (final entry in bySubject.entries) {
        expect(entry.value.length, greaterThanOrEqualTo(3),
            reason: '${entry.key} only uses ${entry.value}');
      }
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/catalog/catalog_invariants_test.dart`
Expected: FAIL on the first test (9 offenders reported: `eng_g1_phonics`, `ls_g1_habits`, `ns_g4_weather`, `eng_g4_spelling`, `eng_g4_debate`, `math_g7_algebra` [fixed in Task 6, so re-run this test after Task 6 lands and it should already be gone], `eng_g7_debate`, `eng_g7_spelling`, `ls_g7_wellbeing`, `ns_g7_health`).

- [ ] **Step 3: Reassign the 9 entries in `game_catalog.dart`**

For each entry below, change `engineType:` and rewrite `mechanicReason:` to match the target engine's established phrasing pattern used by its siblings (quoted above). Keep `id`, `title`, `description`, `grade(s)`, `subject`, `topicId`, `subtopicId`, `emoji`, `color`, `learningObjective`, `difficulty`, `xpReward`, `coinsReward`, `isFeatured` all unchanged.

`eng_g1_phonics` (line 219): `engineType: 'tugOfWar',` → `engineType: 'sequenceBuilder',`; `mechanicReason: 'Answering fast head-to-head builds quick, confident recall of blending.',` → `mechanicReason: 'Putting the steps in the right order breaks blending into stages you can follow one by one.',`

`ls_g1_habits` (line 366): `engineType: 'tugOfWar',` → `engineType: 'runnerCollector',`; `mechanicReason: 'Answering fast head-to-head builds quick, confident recall of healthy habits.',` → `mechanicReason: 'Sorting the right answers on the run trains you to quickly tell healthy habits apart.',`

`ns_g4_weather` (line 709): `engineType: 'tugOfWar',` → `engineType: 'runnerCollector',`; `mechanicReason: 'Answering fast head-to-head builds quick, confident recall of weather patterns.',` → `mechanicReason: 'Sorting the right answers on the run trains you to quickly tell weather patterns apart.',`

`eng_g4_spelling` (line 1111): `engineType: 'tugOfWar',` → `engineType: 'sequenceBuilder',`; `mechanicReason: 'Answering fast head-to-head builds quick, confident recall of grade level words.',` → `mechanicReason: 'Putting the steps in the right order breaks grade level words into stages you can follow one by one.',`

`eng_g4_debate` (line 1213): `engineType: 'tugOfWar',` → `engineType: 'sequenceBuilder',`; `mechanicReason: 'Answering fast head-to-head builds quick, confident recall of debate.',` → `mechanicReason: 'Putting the steps in the right order breaks debate into stages you can follow one by one.',`

`math_g7_algebra`: **already fixed by Task 6** — no change here (kept on `tugOfWar` with the new `algebra` question type).

`eng_g7_debate` (line 1684): `engineType: 'tugOfWar',` → `engineType: 'sequenceBuilder',`; `mechanicReason: 'Answering fast head-to-head builds quick, confident recall of formal debate.',` → `mechanicReason: 'Putting the steps in the right order breaks formal debate into stages you can follow one by one.',`

`eng_g7_spelling` (line 1726): `engineType: 'tugOfWar',` → `engineType: 'sequenceBuilder',`; `mechanicReason: 'Answering fast head-to-head builds quick, confident recall of advanced spelling.',` → `mechanicReason: 'Putting the steps in the right order breaks advanced spelling into stages you can follow one by one.',`

`ls_g7_wellbeing` (line 1811): `engineType: 'tugOfWar',` → `engineType: 'runnerCollector',`; `mechanicReason: 'Answering fast head-to-head builds quick, confident recall of wellbeing.',` → `mechanicReason: 'Sorting the right answers on the run trains you to quickly tell wellbeing apart.',`

`ns_g7_health` (line 2274): `engineType: 'tugOfWar',` → `engineType: 'runnerCollector',`; `mechanicReason: 'Answering fast head-to-head builds quick, confident recall of human health.',` → `mechanicReason: 'Sorting the right answers on the run trains you to quickly tell human health apart.',`

(Re-check exact line numbers with `grep -n "id: 'eng_g1_phonics'\|id: 'ls_g1_habits'\|id: 'ns_g4_weather'\|id: 'eng_g4_spelling'\|id: 'eng_g4_debate'\|id: 'eng_g7_debate'\|id: 'eng_g7_spelling'\|id: 'ls_g7_wellbeing'\|id: 'ns_g7_health'" lib/core/constants/game_catalog.dart` before editing, since Task 6's edits above it may shift line numbers slightly.)

- [ ] **Step 4: Correct the misleading doc comment (redundant with Task 6, verify it's already fixed)**

Confirm `lib/features/games/tug_of_war/tug_of_war_config.dart`'s doc comment above `_questionTypeByTopic` was already rewritten in Task 6 Step 3 to no longer claim the fallback is unreachable. If Task 6 was skipped or done in a different order, apply that same doc-comment fix now.

- [ ] **Step 5: Run the catalog invariants test**

Run: `flutter test test/catalog/catalog_invariants_test.dart`
Expected: PASS (all 3).

- [ ] **Step 6: Run the full test suite**

Run: `flutter analyze` — expect 0 errors.
Run: `flutter test` — expect all green (Task 8/9 will add the actual content packs these reassigned entries need; until then, sequenceBuilder/runnerCollector fall back to their built-in demo content for these 9 entries, which is a temporary content mismatch of its own but not a crash — verify no test asserts on old tugOfWar-specific content for these ids).

- [ ] **Step 7: Commit**

```bash
git add lib/core/constants/game_catalog.dart lib/features/games/tug_of_war/tug_of_war_config.dart test/catalog/catalog_invariants_test.dart
git commit -m "fix(catalog): reassign 9 non-arithmetic tugOfWar entries to sequenceBuilder/runnerCollector

phonics/spelling/debate/health/weather/wellbeing topics had no
arithmetic content, so TugOfWarEngine's generic multiplication
fallback was reached in production, showing arithmetic questions in
games advertised as teaching phonics, health, weather, spelling and
debate -- including to Grade 1 Foundation Phase learners. Reassigned
each to the engine already used by its closest sibling topic
elsewhere in the catalog. Content packs land in Tasks 8-9."
```

---

## Task 8: Author `sequenceBuilder` content packs for the 5 reassigned English entries

**Context:** `SequenceBuilderConfig.fromPack` (`lib/features/games/sequence_builder/sequence_builder_config.dart:39-54`) expects `{title, sceneType, steps: [{id, label, emoji, description}, ...]}`. The 5 entries reassigned to `sequenceBuilder` in Task 7 need real content packs in this shape, replacing their now-dead `tugOfWar`-shaped `sampleItems` packs. Debate topics have genuine intrinsic structure (propose → oppose → rebuttal, matching the existing `eng_g7_oral` sibling pack's stage-based approach); phonics/spelling are framed as an escalating-difficulty progression of distinct words/skills, matching the existing `spelling/cvc_words` sibling's approach of using `steps` as a taught-order progression rather than a single word's letter-by-letter sequence.

**Files:**
- Modify: `assets/content/eng_g1_phonics.json`
- Modify: `assets/content/eng_g4_spelling.json`
- Modify: `assets/content/eng_g4_debate.json`
- Modify: `assets/content/eng_g7_debate.json`
- Modify: `assets/content/eng_g7_spelling.json`
- Test: `test/content/sequence_builder_packs_test.dart` (new)

- [ ] **Step 1: Write the failing test**

Create `test/content/sequence_builder_packs_test.dart`:

```dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const files = [
    'assets/content/eng_g1_phonics.json',
    'assets/content/eng_g4_spelling.json',
    'assets/content/eng_g4_debate.json',
    'assets/content/eng_g7_debate.json',
    'assets/content/eng_g7_spelling.json',
  ];

  for (final path in files) {
    test('$path is sequenceBuilder-shaped with >= 4 real steps', () {
      final json = jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
      expect(json['engine'], 'sequenceBuilder');
      expect(json['sceneType'], isA<String>());
      final steps = json['steps'] as List;
      expect(steps.length, greaterThanOrEqualTo(4));
      for (final s in steps) {
        final step = s as Map<String, dynamic>;
        expect(step['id'], isA<String>());
        expect((step['label'] as String).isNotEmpty, isTrue);
        expect((step['emoji'] as String).isNotEmpty, isTrue);
        expect((step['description'] as String).length, greaterThan(10));
      }
    });
  }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/content/sequence_builder_packs_test.dart`
Expected: FAIL — all 5 files still have `"engine": "tugOfWar"` and `sampleItems`, not `steps`.

- [ ] **Step 3: Author `assets/content/eng_g1_phonics.json`**

Replace the full file contents:

```json
{
  "id": "eng_g1_phonics",
  "engine": "sequenceBuilder",
  "grade": "grade1",
  "subject": "English",
  "title": "Phonics Fun",
  "tagline": "Blend sounds together to decode and read words!",
  "accentColorHex": "#E91E63",
  "emoji": "🎵",
  "sceneType": "phonicsPath",
  "steps": [
    {
      "id": "blend_cat",
      "label": "c-a-t",
      "emoji": "🐱",
      "description": "Blend the sounds /c/ /a/ /t/ together to read the word 'cat'."
    },
    {
      "id": "blend_sun",
      "label": "s-u-n",
      "emoji": "☀️",
      "description": "Blend the sounds /s/ /u/ /n/ together to read the word 'sun'."
    },
    {
      "id": "blend_dog",
      "label": "d-o-g",
      "emoji": "🐶",
      "description": "Blend the sounds /d/ /o/ /g/ together to read the word 'dog'."
    },
    {
      "id": "blend_map",
      "label": "m-a-p",
      "emoji": "🗺️",
      "description": "Blend the sounds /m/ /a/ /p/ together to read the word 'map'."
    },
    {
      "id": "blend_pig",
      "label": "p-i-g",
      "emoji": "🐷",
      "description": "Blend the sounds /p/ /i/ /g/ together to read the word 'pig'."
    },
    {
      "id": "blend_bed",
      "label": "b-e-d",
      "emoji": "🛏️",
      "description": "Blend the sounds /b/ /e/ /d/ together to read the word 'bed'."
    }
  ],
  "roundVariants": [
    ["blend_cat", "blend_sun", "blend_dog"],
    ["blend_map", "blend_pig", "blend_bed"],
    ["blend_cat", "blend_dog", "blend_pig", "blend_bed"]
  ]
}
```

- [ ] **Step 4: Author `assets/content/eng_g4_spelling.json`**

Replace the full file contents:

```json
{
  "id": "eng_g4_spelling",
  "engine": "sequenceBuilder",
  "grade": "grade4",
  "subject": "English",
  "title": "Spelling Bee",
  "tagline": "Spell grade-level words correctly and win the spelling bee!",
  "accentColorHex": "#E91E63",
  "emoji": "🐝",
  "sceneType": "spellingBee",
  "steps": [
    {
      "id": "school",
      "label": "school",
      "emoji": "🏫",
      "description": "S-C-H-O-O-L: a place where you learn."
    },
    {
      "id": "tomorrow",
      "label": "tomorrow",
      "emoji": "📅",
      "description": "T-O-M-O-R-R-O-W: the day after today."
    },
    {
      "id": "teacher",
      "label": "teacher",
      "emoji": "👩‍🏫",
      "description": "T-E-A-C-H-E-R: a person who teaches."
    },
    {
      "id": "grateful",
      "label": "grateful",
      "emoji": "🙏",
      "description": "G-R-A-T-E-F-U-L: feeling thankful."
    },
    {
      "id": "different",
      "label": "different",
      "emoji": "🔀",
      "description": "D-I-F-F-E-R-E-N-T: not the same."
    },
    {
      "id": "beautiful",
      "label": "beautiful",
      "emoji": "🌸",
      "description": "B-E-A-U-T-I-F-U-L: very pretty."
    }
  ],
  "roundVariants": [
    ["school", "teacher", "tomorrow"],
    ["grateful", "different", "beautiful"],
    ["school", "grateful", "different", "beautiful"]
  ]
}
```

- [ ] **Step 5: Author `assets/content/eng_g4_debate.json`**

Replace the full file contents:

```json
{
  "id": "eng_g4_debate",
  "engine": "sequenceBuilder",
  "grade": "grade4",
  "subject": "English",
  "title": "Debate Duel",
  "tagline": "Choose your argument, support it with evidence and win the debate!",
  "accentColorHex": "#E91E63",
  "emoji": "🎤",
  "sceneType": "debateStage",
  "steps": [
    {
      "id": "opening",
      "label": "Opening",
      "emoji": "👋",
      "description": "State your opinion clearly so everyone knows where you stand."
    },
    {
      "id": "reason",
      "label": "Give a Reason",
      "emoji": "💡",
      "description": "Explain one clear reason why you think this."
    },
    {
      "id": "evidence",
      "label": "Evidence",
      "emoji": "📊",
      "description": "Back up your reason with an example or a fact."
    },
    {
      "id": "listen",
      "label": "Listen",
      "emoji": "👂",
      "description": "Listen carefully to the other side's argument."
    },
    {
      "id": "closing",
      "label": "Closing",
      "emoji": "🏁",
      "description": "Sum up your argument in one strong closing sentence."
    }
  ],
  "roundVariants": [
    ["opening", "reason", "closing"],
    ["opening", "reason", "evidence", "closing"],
    ["reason", "evidence", "listen", "closing"]
  ]
}
```

- [ ] **Step 6: Author `assets/content/eng_g7_debate.json`**

Replace the full file contents:

```json
{
  "id": "eng_g7_debate",
  "engine": "sequenceBuilder",
  "grade": "grade7",
  "subject": "English",
  "title": "Formal Debate",
  "tagline": "Master formal debate structure — proposing, opposing and rebuttal!",
  "accentColorHex": "#E91E63",
  "emoji": "🎤",
  "sceneType": "debateStage",
  "steps": [
    {
      "id": "motion",
      "label": "State the Motion",
      "emoji": "📜",
      "description": "Read out the motion being debated so everyone understands the topic."
    },
    {
      "id": "propose",
      "label": "Proposing Argument",
      "emoji": "✅",
      "description": "The proposing team argues in favour of the motion with clear points."
    },
    {
      "id": "oppose",
      "label": "Opposing Argument",
      "emoji": "❌",
      "description": "The opposing team argues against the motion with their own points."
    },
    {
      "id": "rebuttal",
      "label": "Rebuttal",
      "emoji": "🔄",
      "description": "Each side responds directly to the other side's strongest point."
    },
    {
      "id": "summary",
      "label": "Closing Summary",
      "emoji": "🏁",
      "description": "Each side sums up why their argument was stronger."
    },
    {
      "id": "vote",
      "label": "Audience Vote",
      "emoji": "🗳️",
      "description": "The audience votes on which side argued the motion more convincingly."
    }
  ],
  "roundVariants": [
    ["motion", "propose", "oppose", "summary"],
    ["propose", "oppose", "rebuttal", "summary"],
    ["motion", "propose", "oppose", "rebuttal", "summary", "vote"]
  ]
}
```

- [ ] **Step 7: Author `assets/content/eng_g7_spelling.json`**

Replace the full file contents:

```json
{
  "id": "eng_g7_spelling",
  "engine": "sequenceBuilder",
  "grade": "grade7",
  "subject": "English",
  "title": "Advanced Spelling",
  "tagline": "Spell complex Grade 7 words — prefixes, suffixes and word origins!",
  "accentColorHex": "#E91E63",
  "emoji": "🔤",
  "sceneType": "spellingBee",
  "steps": [
    {
      "id": "unnecessary",
      "label": "unnecessary",
      "emoji": "🚫",
      "description": "U-N-N-E-C-E-S-S-A-R-Y: prefix 'un-' meaning not needed."
    },
    {
      "id": "achievement",
      "label": "achievement",
      "emoji": "🏆",
      "description": "A-C-H-I-E-V-E-M-E-N-T: suffix '-ment' turns a verb into a noun."
    },
    {
      "id": "responsibility",
      "label": "responsibility",
      "emoji": "🤝",
      "description": "R-E-S-P-O-N-S-I-B-I-L-I-T-Y: suffix '-ity' turns an adjective into a noun."
    },
    {
      "id": "disappear",
      "label": "disappear",
      "emoji": "💨",
      "description": "D-I-S-A-P-P-E-A-R: prefix 'dis-' meaning the opposite."
    },
    {
      "id": "irresponsible",
      "label": "irresponsible",
      "emoji": "⚠️",
      "description": "I-R-R-E-S-P-O-N-S-I-B-L-E: prefix 'ir-' before words starting with 'r'."
    },
    {
      "id": "biography",
      "label": "biography",
      "emoji": "📖",
      "description": "B-I-O-G-R-A-P-H-Y: from Greek 'bio' (life) + 'graphy' (writing)."
    }
  ],
  "roundVariants": [
    ["unnecessary", "achievement", "disappear"],
    ["responsibility", "irresponsible", "biography"],
    ["unnecessary", "disappear", "irresponsible", "biography"]
  ]
}
```

- [ ] **Step 8: Run the content-pack test**

Run: `flutter test test/content/sequence_builder_packs_test.dart`
Expected: PASS (5/5).

- [ ] **Step 9: Run the full test suite**

Run: `flutter analyze` — expect 0 errors.
Run: `flutter test` — expect all green.

- [ ] **Step 10: Commit**

```bash
git add assets/content/eng_g1_phonics.json assets/content/eng_g4_spelling.json assets/content/eng_g4_debate.json assets/content/eng_g7_debate.json assets/content/eng_g7_spelling.json test/content/sequence_builder_packs_test.dart
git commit -m "content(sequenceBuilder): author real content packs for 5 reassigned English entries

Replaces dead tugOfWar-shaped sampleItems (never read by any engine)
with real sequenceBuilder steps for phonics blending, spelling, and
debate structure."
```

---

## Task 9: Author `runnerCollector` content packs for the 4 reassigned Life Skills/Natural Sciences entries

**Context:** `RunnerCollectorConfig.fromPack` (`lib/features/games/runner_collector/runner_collector_config.dart:52-69`) expects `{levels: [{targetClass, missionLabel, scrollSpeed, buckets: {className: [words...]}}, ...]}`. The 4 entries reassigned to `runnerCollector` in Task 7 need real content packs in this shape, matching the sibling `ls_g4_health.json` pack's healthy/unhealthy classification style.

**Files:**
- Modify: `assets/content/ls_g1_habits.json`
- Modify: `assets/content/ns_g4_weather.json`
- Modify: `assets/content/ls_g7_wellbeing.json`
- Modify: `assets/content/sci_g7_health.json`
- Test: `test/content/runner_collector_packs_test.dart` (new)

- [ ] **Step 1: Write the failing test**

Create `test/content/runner_collector_packs_test.dart`:

```dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const files = [
    'assets/content/ls_g1_habits.json',
    'assets/content/ns_g4_weather.json',
    'assets/content/ls_g7_wellbeing.json',
    'assets/content/sci_g7_health.json',
  ];

  for (final path in files) {
    test('$path is runnerCollector-shaped with >= 2 levels and real buckets', () {
      final json = jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
      expect(json['engine'], 'runnerCollector');
      final levels = json['levels'] as List;
      expect(levels.length, greaterThanOrEqualTo(2));
      for (final l in levels) {
        final level = l as Map<String, dynamic>;
        expect((level['targetClass'] as String).isNotEmpty, isTrue);
        expect((level['missionLabel'] as String).isNotEmpty, isTrue);
        final buckets = level['buckets'] as Map<String, dynamic>;
        expect(buckets.containsKey(level['targetClass']), isTrue);
        for (final words in buckets.values) {
          expect((words as List).length, greaterThanOrEqualTo(4));
        }
      }
    });
  }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/content/runner_collector_packs_test.dart`
Expected: FAIL — all 4 files still have `"engine": "tugOfWar"` and `sampleItems`, not `levels`.

- [ ] **Step 3: Author `assets/content/ls_g1_habits.json`**

Replace the full file contents:

```json
{
  "id": "ls_g1_habits",
  "engine": "runnerCollector",
  "grade": "grade1",
  "subject": "Life Skills",
  "title": "Healthy Habits",
  "tagline": "Build good habits around hygiene, nutrition and exercise!",
  "accentColorHex": "#FF9800",
  "emoji": "🥗",
  "levels": [
    {
      "targetClass": "healthy",
      "missionLabel": "Collect healthy habits! 🥗",
      "scrollSpeed": 0.08,
      "buckets": {
        "healthy": ["wash hands", "brush teeth", "eat fruit", "drink water", "sleep early", "wear a hat in the sun"],
        "unhealthy": ["skip a bath", "eat too many sweets", "stay up late", "forget to wash hands", "sit all day"]
      }
    },
    {
      "targetClass": "unhealthy",
      "missionLabel": "Spot the bad habits! 🚫",
      "scrollSpeed": 0.09,
      "buckets": {
        "healthy": ["wash hands", "brush teeth", "eat fruit", "drink water", "sleep early", "wear a hat in the sun"],
        "unhealthy": ["skip a bath", "eat too many sweets", "stay up late", "forget to wash hands", "sit all day"]
      }
    }
  ]
}
```

- [ ] **Step 4: Author `assets/content/ns_g4_weather.json`**

Replace the full file contents:

```json
{
  "id": "ns_g4_weather",
  "engine": "runnerCollector",
  "grade": "grade4",
  "subject": "Natural Sciences",
  "title": "Weather Watcher",
  "tagline": "Read weather maps, identify cloud types and predict SA weather!",
  "accentColorHex": "#03A9F4",
  "emoji": "🌤️",
  "levels": [
    {
      "targetClass": "fair_weather",
      "missionLabel": "Collect fair-weather signs! ☀️",
      "scrollSpeed": 0.09,
      "buckets": {
        "fair_weather": ["clear sky", "gentle breeze", "cumulus clouds", "high pressure", "sunshine"],
        "stormy_weather": ["cumulonimbus clouds", "lightning", "heavy rain", "strong wind", "low pressure"]
      }
    },
    {
      "targetClass": "stormy_weather",
      "missionLabel": "Spot the storm signs! ⛈️",
      "scrollSpeed": 0.1,
      "buckets": {
        "fair_weather": ["clear sky", "gentle breeze", "cumulus clouds", "high pressure", "sunshine"],
        "stormy_weather": ["cumulonimbus clouds", "lightning", "heavy rain", "strong wind", "low pressure"]
      }
    }
  ]
}
```

- [ ] **Step 5: Author `assets/content/ls_g7_wellbeing.json`**

Replace the full file contents:

```json
{
  "id": "ls_g7_wellbeing",
  "engine": "runnerCollector",
  "grade": "grade7",
  "subject": "Life Skills",
  "title": "Wellbeing Quest",
  "tagline": "Manage stress, build resilience and maintain mental health!",
  "accentColorHex": "#FF9800",
  "emoji": "🧘",
  "levels": [
    {
      "targetClass": "helps_wellbeing",
      "missionLabel": "Collect healthy coping strategies! 🧘",
      "scrollSpeed": 0.1,
      "buckets": {
        "helps_wellbeing": ["deep breathing", "talking to a friend", "regular exercise", "getting enough sleep", "journaling"],
        "hurts_wellbeing": ["bottling up feelings", "isolating yourself", "skipping meals", "staying up all night", "avoiding help"]
      }
    },
    {
      "targetClass": "hurts_wellbeing",
      "missionLabel": "Spot the unhelpful habits! ⚠️",
      "scrollSpeed": 0.11,
      "buckets": {
        "helps_wellbeing": ["deep breathing", "talking to a friend", "regular exercise", "getting enough sleep", "journaling"],
        "hurts_wellbeing": ["bottling up feelings", "isolating yourself", "skipping meals", "staying up all night", "avoiding help"]
      }
    }
  ]
}
```

- [ ] **Step 6: Author `assets/content/sci_g7_health.json`**

Replace the full file contents:

```json
{
  "id": "ns_g7_health",
  "engine": "runnerCollector",
  "grade": "grade7",
  "subject": "Natural Sciences",
  "title": "Human Health",
  "tagline": "Understand diseases, the immune system and healthy lifestyle choices!",
  "accentColorHex": "#4CAF50",
  "emoji": "💉",
  "levels": [
    {
      "targetClass": "communicable",
      "missionLabel": "Collect communicable diseases! 🦠",
      "scrollSpeed": 0.1,
      "buckets": {
        "communicable": ["flu", "measles", "tuberculosis", "common cold", "chickenpox"],
        "non_communicable": ["diabetes", "asthma", "high blood pressure", "heart disease", "malnutrition"]
      }
    },
    {
      "targetClass": "non_communicable",
      "missionLabel": "Spot the non-communicable diseases! 🩺",
      "scrollSpeed": 0.11,
      "buckets": {
        "communicable": ["flu", "measles", "tuberculosis", "common cold", "chickenpox"],
        "non_communicable": ["diabetes", "asthma", "high blood pressure", "heart disease", "malnutrition"]
      }
    }
  ]
}
```

(Note: the file on disk is named `sci_g7_health.json` but the catalog entry `id` is `ns_g7_health` — content pack filenames must match `GameConfig.contentPackPath`'s `assets/content/{catalogId}.json` pattern, i.e. the entry's `id`. Rename the file as part of this step: `git mv assets/content/sci_g7_health.json assets/content/ns_g7_health.json` before writing the content above, so the pack actually loads for this catalog entry — it was silently unreachable under the old filename too, a second content-pack bug of the same "wrong/no content shown" shape caught while doing this task.)

- [ ] **Step 7: Run the content-pack test**

Update the test file's `files` list to use `assets/content/ns_g7_health.json` (matching the rename in Step 6), then run:
Run: `flutter test test/content/runner_collector_packs_test.dart`
Expected: PASS (4/4).

- [ ] **Step 8: Run the full test suite**

Run: `flutter analyze` — expect 0 errors.
Run: `flutter test` — expect all green.

- [ ] **Step 9: Commit**

```bash
git add assets/content/ls_g1_habits.json assets/content/ns_g4_weather.json assets/content/ls_g7_wellbeing.json assets/content/ns_g7_health.json test/content/runner_collector_packs_test.dart
git commit -m "content(runnerCollector): author real content packs for 4 reassigned Life Skills/Natural Sciences entries

Replaces dead tugOfWar-shaped sampleItems with real runnerCollector
classification buckets. Also fixes a second, independent bug: the
Human Health pack was saved as sci_g7_health.json but the catalog
entry id is ns_g7_health, so it was never loaded under either engine."
```

---

## Task 10: Surface weak-topic mission targeting to the learner

**Context:** `getAdaptiveMissions` in `functions/src/missions/generate.ts` already asks Gemini for a one-sentence `reason` per adaptive mission pick (line 77), but the code immediately discards it: the parse type only declares `gameId` (line 85), the mapped object only carries `gameId, subject, emoji, title` (lines 89-96), and neither `MissionEntry` (lines 8-17) nor the client's `DailyMission` model has a `reason` field. The only learner-facing hint that a mission was chosen for them is a generic `sourceBadge` ("🤖 AI Pick") with no subject-specific explanation — the entire point of adaptive targeting is invisible to the learner it's meant to help.

**Files:**
- Modify: `functions/src/missions/generate.ts`
- Modify: `lib/data/models/daily_mission_model.dart`
- Modify: `lib/features/dashboard/widgets/daily_missions_card.dart`
- Test: `functions/src/missions/__tests__/generate.reason.test.ts` (new, if the functions project has a test runner configured — check `functions/package.json`'s `scripts.test`; if none exists, skip Cloud Function unit testing and instead add a Dart widget test asserting the reason renders, per Step 5 below)
- Test: `test/widgets/daily_missions_reason_test.dart` (new)

- [ ] **Step 1: Thread `reason` through the Cloud Function**

In `functions/src/missions/generate.ts`, update `MissionEntry` (lines 8-17):

```ts
interface MissionEntry {
  id: string;
  gameId: string;
  title: string;
  subject: string;
  emoji: string;
  xpBonus: number;
  completed: boolean;
  source: "teacher" | "adaptive" | "curated";
  reason?: string;
}
```

Update `getAdaptiveMissions`'s return type (line 36) and its body (lines 85-98):

```ts
async function getAdaptiveMissions(
  uid: string,
  grade: string,
  dayIndex: number
): Promise<{gameId: string; subject: string; emoji: string; title: string; reason: string}[]> {
```

```ts
    const parsed = JSON.parse(jsonMatch[0]) as
      {missions: {gameId: string; reason?: string}[]};
    const validIds = new Set(MISSION_CATALOG[dayIndex].map((m) => m.gameId));
    return (parsed.missions || [])
      .filter((m) => validIds.has(m.gameId))
      .map((m) => {
        const catalog = MISSION_CATALOG[dayIndex].find((c) => c.gameId === m.gameId)!;
        return {
          gameId: m.gameId,
          subject: catalog.subject,
          emoji: catalog.emoji,
          title: catalog.title,
          reason: m.reason || `Because you're working on ${catalog.subject}`,
        };
      })
      .slice(0, 2);
```

Update the Tier 2 push block inside `generateDailyMissions` (lines 158-170):

```ts
        if (missions.length < 3) {
          const adaptive = await getAdaptiveMissions(uid, String(gradeNum), dayIndex);
          adaptive.forEach((m) => {
            if (missions.length < 3) {
              missions.push({
                id: `adaptive_${m.gameId}_${Date.now()}`,
                gameId: m.gameId,
                title: m.title,
                subject: m.subject,
                emoji: m.emoji,
                xpBonus: 15,
                completed: false,
                source: "adaptive",
                reason: m.reason,
              });
            }
          });
        }
```

- [ ] **Step 2: Build the Cloud Functions project to verify no TypeScript errors**

Run: `cd functions && npm run build`
Expected: success, 0 errors.

- [ ] **Step 3: Thread `reason` through the client model**

In `lib/data/models/daily_mission_model.dart`, add the field and update the constructor and `fromMap`:

```dart
class DailyMission {
  final String id;
  final String gameId;
  final String title;
  final String subject;
  final String emoji;
  final int xpBonus;
  final bool completed;
  final DateTime? completedAt;
  final String source; // 'teacher' | 'adaptive' | 'curated'
  final String? reason; // learner-facing "why this mission" (adaptive only)

  const DailyMission({
    required this.id,
    required this.gameId,
    required this.title,
    required this.subject,
    required this.emoji,
    required this.xpBonus,
    required this.completed,
    this.completedAt,
    required this.source,
    this.reason,
  });

  factory DailyMission.fromMap(String id, Map<String, dynamic> map) {
    return DailyMission(
      id: id,
      gameId: map['gameId'] as String? ?? '',
      title: map['title'] as String? ?? 'Daily Mission',
      subject: map['subject'] as String? ?? 'General',
      emoji: map['emoji'] as String? ?? '⭐',
      xpBonus: (map['xpBonus'] as num?)?.toInt() ?? 15,
      completed: map['completed'] as bool? ?? false,
      completedAt: map['completedAt'] is Timestamp
          ? (map['completedAt'] as Timestamp).toDate()
          : null,
      source: map['source'] as String? ?? 'curated',
      reason: map['reason'] as String?,
    );
  }

  String get sourceBadge {
    switch (source) {
      case 'teacher':
        return '📋 Teacher';
      case 'adaptive':
        return '🤖 AI Pick';
      default:
        return '⭐ Daily';
    }
  }
}
```

- [ ] **Step 4: Show the reason on the mission card**

In `lib/features/dashboard/widgets/daily_missions_card.dart`, `_MissionTile.build()`, replace the `sourceBadge` `Text` widget (lines 172-180) — when an adaptive mission has a `reason`, show that instead of the generic badge (same slot, more informative, no layout change):

```dart
                const Spacer(),
                Text(
                  mission.source == 'adaptive' && mission.reason != null
                      ? mission.reason!
                      : mission.sourceBadge,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: done
                        ? Colors.grey
                        : Colors.white.withValues(alpha: 0.75),
                    fontSize: 10,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
```

- [ ] **Step 5: Write a widget test for the reason display**

Create `test/widgets/daily_missions_reason_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/data/models/daily_mission_model.dart';

void main() {
  test('an adaptive mission with a reason prefers the reason over the generic badge', () {
    const mission = DailyMission(
      id: 'adaptive_math_g4_timestable_1',
      gameId: 'math_g4_timestable',
      title: 'Times Table Tower',
      subject: 'Mathematics',
      emoji: '🏗️',
      xpBonus: 15,
      completed: false,
      source: 'adaptive',
      reason: "Because you're working on Mathematics",
    );
    final displayText =
        mission.source == 'adaptive' && mission.reason != null
            ? mission.reason!
            : mission.sourceBadge;
    expect(displayText, "Because you're working on Mathematics");
  });

  test('a curated mission with no reason falls back to the generic badge', () {
    const mission = DailyMission(
      id: 'curated_math_g4_timestable_1',
      gameId: 'math_g4_timestable',
      title: 'Times Table Tower',
      subject: 'Mathematics',
      emoji: '🏗️',
      xpBonus: 10,
      completed: false,
      source: 'curated',
    );
    final displayText =
        mission.source == 'adaptive' && mission.reason != null
            ? mission.reason!
            : mission.sourceBadge;
    expect(displayText, '⭐ Daily');
  });
}
```

Run: `flutter test test/widgets/daily_missions_reason_test.dart`
Expected: PASS (2/2).

- [ ] **Step 6: Run the full test suite**

Run: `flutter analyze` — expect 0 errors.
Run: `flutter test` — expect all green.
Run: `cd functions && npm run build && npm run lint` — expect 0 errors.

- [ ] **Step 7: Commit**

```bash
git add functions/src/missions/generate.ts lib/data/models/daily_mission_model.dart lib/features/dashboard/widgets/daily_missions_card.dart test/widgets/daily_missions_reason_test.dart
git commit -m "feat(missions): surface the AI's weak-topic reason to the learner

Gemini already produced a one-sentence reason per adaptive mission
pick, but it was parsed and then discarded -- the learner only ever
saw a generic '🤖 AI Pick' badge with no explanation of why a mission
was chosen. Threads reason through MissionEntry -> DailyMission ->
the mission card."
```

---

## Task 11: Fix weak-topic detection's combined-sample-size gate

**Context:** `getAdaptiveMissions` in `functions/src/missions/generate.ts:47` gates the entire adaptive-missions feature on `progressSnap.size < 7` — 7 progress records **combined across every subject**, not per subject. A learner with 6 Mathematics sessions and 1 English session passes this gate, and that single English data point's score can trivially average below 65, flagging English "weak" off a sample size of one. This task changes the gate to a per-subject minimum instead.

**Files:**
- Modify: `functions/src/missions/generate.ts`
- Test: `functions/src/missions/__tests__/generate.weaksubjects.test.ts` (new, only if `functions/package.json` already has a configured test runner — check first with `cat functions/package.json`; if none exists, this task's correctness is verified by Step 3's manual trace plus the existing `npm run build`/`npm run lint` checks, and no new test file is created)

- [ ] **Step 1: Check whether the functions project has a test runner**

Run: `cat functions/package.json`
If `scripts.test` runs something other than a placeholder/`echo` stub, write a Jest/Mocha test (matching whatever framework is configured) asserting: given 6 Mathematics + 1 English progress doc where the English doc scores 40, `getAdaptiveMissions` does NOT include English in `weakSubjects` (would need `getAdaptiveMissions`'s weak-subject computation extracted to a separately-testable pure function first — if so, extract `computeWeakSubjects(subjectScores: Record<string, number[]>): string[]` as a named export and test that directly rather than mocking Firestore). If no test runner is configured, skip to Step 2 and rely on manual verification.

- [ ] **Step 2: Fix the gate**

In `functions/src/missions/generate.ts`, replace the early-return gate and weak-subject computation (lines 41-67):

```ts
  const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
  const progressSnap = await db.collection("progress")
    .where("childUid", "==", uid)
    .where("completedAt", ">=", admin.firestore.Timestamp.fromDate(thirtyDaysAgo))
    .get();

  const subjectScores: Record<string, number[]> = {};
  progressSnap.docs.forEach((d) => {
    const data = d.data();
    const subj = (data["subject"] as string) || "General";
    if (!subjectScores[subj]) subjectScores[subj] = [];
    subjectScores[subj].push((data["score"] as number) || 0);
  });

  // Require at least 5 samples of a SPECIFIC subject before judging it
  // weak -- gating on a combined total across all subjects (the old
  // `progressSnap.size < 7` check) let a subject with just 1-2 data
  // points get flagged "weak" off a tiny, noisy sample as long as some
  // OTHER subject padded out the combined count.
  const minSamplesPerSubject = 5;
  const avgScores: Record<string, number> = {};
  for (const [subj, scores] of Object.entries(subjectScores)) {
    if (scores.length < minSamplesPerSubject) continue;
    avgScores[subj] = scores.reduce((a, b) => a + b, 0) / scores.length;
  }

  const weakSubjects = Object.entries(avgScores)
    .filter(([, v]) => v < 65)
    .map(([k]) => k)
    .slice(0, 2);

  if (weakSubjects.length === 0) return [];
```

- [ ] **Step 3: Manually trace the fix**

Confirm: a learner with 6 Mathematics docs (avg 80) + 1 English doc (score 40) → `subjectScores['English'].length === 1 < 5`, so English is skipped entirely from `avgScores`; Mathematics has 6 ≥ 5 samples but averages 80 ≥ 65, so `weakSubjects` is empty and the function correctly returns `[]` instead of wrongly flagging English.

- [ ] **Step 4: Build and lint**

Run: `cd functions && npm run build && npm run lint`
Expected: 0 errors.

- [ ] **Step 5: Commit**

```bash
git add functions/src/missions/generate.ts
git commit -m "fix(missions): gate weak-subject detection per-subject, not combined

progressSnap.size < 7 counted records across every subject combined,
so a learner with 6 Maths sessions and 1 English session could get
English flagged 'weak' off a single data point. Now each subject
needs its own 5-sample minimum before its average is considered."
```

---

## Task 12: End-of-phase verification and summary

- [ ] **Step 1: Full static + test verification**

Run: `flutter analyze` — must be 0 errors.
Run: `flutter test` — must be 100% green.
Run: `cd functions && npm run build && npm run lint` — must be 0 errors.

- [ ] **Step 2: Live verification — tugOfWar reassignment**

Run `flutter run -d chrome`, log in as a test learner, and play through at least 2 of the reassigned entries end-to-end (e.g. `eng_g1_phonics` via Home tab or Quests, and `ls_g7_wellbeing`), confirming: the game launches the correct engine (sequenceBuilder / runnerCollector, not tugOfWar's numeric keypad), the on-screen content matches the authored packs from Tasks 8-9 (real words/buckets, not generic multiplication), and the session completes and grants XP.

- [ ] **Step 3: Live verification — XP fairness**

Play one full session each of `multiples_merge` (pairs or numeric mode) and `tug_of_war`, and compare the XP granted at the end screen against the Rewards screen's updated total — confirm the amounts match what Task 1's new `xpFromAnswers`-based formula would predict (not the old flat `correct * 10`).

- [ ] **Step 4: Live verification — numberCountingDuel persistence**

Play a full `numberCountingDuel` session (Grade 1 test account) to the victory screen, note the displayed XP total, then check the Rewards/Profile screen and Firestore's `player_stats/{uid}` document — confirm the XP actually landed there (previously it never did).

- [ ] **Step 5: Live verification — adaptive difficulty**

Play `math_g4_timestable` (now `difficulty: 'adaptive'`), deliberately answer 3 in a row correctly fast, and confirm the opponent visibly speeds up; then deliberately miss 3 in a row and confirm the opponent eases back down (Task 3's new symmetric branch).

- [ ] **Step 6: Live verification — mission reason surfacing**

If a learner test account has ≥5 Firestore `progress` docs in one subject averaging below 65 (seed manually via the Firebase emulator or existing test data if needed), trigger `generateDailyMissions` (via emulator or a manual Firestore write mimicking its output) and confirm the Daily Missions card shows the specific reason text instead of the generic "🤖 AI Pick" badge.

- [ ] **Step 7: Write the phase completion report**

Summarize for the user: all 12 tasks completed, the 2 critical bugs found and fixed beyond the original 4-item scope (`numberCountingDuel` XP data loss, `explorer_map` double-bonus), the 10-entry tugOfWar content-mismatch fix (9 reassigned + 1 algebra-mapping fix), and any items that could not be live-verified due to the machine's memory constraints (flag explicitly, do not claim success without having tested). Per Rule 2, stop and wait for the user's "Continue" before starting Phase 13 (Parent Portal).
