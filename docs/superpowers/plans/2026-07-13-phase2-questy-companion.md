# Phase 2 — Questy AI Companion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn Questy from a working-but-fragmented AI tutor (real Gemini backend, but three different visual identities across the app, a static non-animated avatar, and zero reactivity to learner progress) into a single, consistent, animated companion that appears the same way everywhere, visibly "thinks," and reacts to quest completions, badges, and level-ups without needing a dedicated Gemini call for every reaction.

**Architecture:** The Gemini backend (`functions/src/gemini/proxy.ts`), quota system, system prompt, and AI-transparency/report-flag compliance are already correct and are explicitly **out of scope** (Rule 3 — fix broken wiring, don't redesign working parts). This phase is entirely client-side: (1) give `QuestyAvatar` real animated expression states, (2) make it the *only* visual representation of Questy anywhere in the app (replacing two other ad-hoc emoji stand-ins), (3) route every hint/explain call through the one existing provider method instead of two inconsistent code paths, (4) add a local (non-Gemini, quota-free) scripted-dialogue layer for celebration/encouragement so reactive moments don't compete with homework-help quota, and (5) surface a proactive recommendation on the dashboard home tab so Questy doesn't only exist inside its own tab.

**Tech Stack:** Flutter (Dart ≥3.4), `flutter_animate` (already a dependency, unused by `QuestyAvatar` today), `flutter_tts`, `provider`. No new packages, no new binary assets — `QuestyAvatar` stays pure-code-drawn (`CustomPainter`) per its existing convention and this project's memory-constrained dev machine.

## Global Constraints

- `flutter analyze` → 0 new errors before any commit (warnings only if pre-existing).
- `flutter test` → all tests green, including new tests this plan adds.
- Do not touch `functions/src/gemini/proxy.ts`'s `SYSTEM_PROMPT`, quota logic (`enforceQuota`, `DAILY_AI_QUOTA=50`), safety settings, or `secrets.ts`/`config.ts` — these are correct and already satisfy CLAUDE.md §6 AI-compliance rules.
- Do not remove or weaken the AI-transparency label (`chat_bubble.dart` "AI · Questy") or the report/flag flow (`_showReportSheet` → `ai_reports` collection) — both are Google Play policy requirements per CLAUDE.md §6 rule 6.
- New reactive dialogue (celebration/encouragement) must be **local/scripted, not new Gemini calls** — the existing 50/day/uid quota is shared across chat, image analysis, hints, explanations, and recommendations; adding a Gemini call per badge/level-up would burn through it fast for an active player.
- Preserve existing game engine layering (CLAUDE.md §4): `GameEngine` subclasses stay pure Dart; only widget/session-layer files in `tug_of_war`, `runner_collector`, `sequence_builder` are touched.
- Commit style: `type(scope): summary`. Small, reviewable commits; run `flutter analyze` before each.

---

## File Structure

New files:
```
lib/features/ai_tutor/widgets/questy_dialogue.dart   # Task 5 — local scripted-line pools
test/widgets/questy_avatar_test.dart                 # Task 1
test/widgets/questy_dialogue_test.dart                # Task 5
test/providers/ai_tutor_provider_test.dart            # Task 4
```

Files modified: `lib/features/ai_tutor/widgets/questy_avatar.dart`, `lib/features/ai_tutor/widgets/chat_bubble.dart`, `lib/features/ai_tutor/screens/ai_tutor_screen.dart`, `lib/features/games/core/game_theme.dart`, `lib/features/games/tug_of_war/tug_of_war_game.dart`, `lib/features/quests/screens/quiz_screen.dart`, `lib/providers/ai_tutor_provider.dart`, `lib/data/models/chat_message_model.dart`, `lib/providers/rewards_provider.dart`, `lib/features/rewards/widgets/badge_earned_dialog.dart`, `lib/features/dashboard/screens/learner_dashboard.dart`.

---

### Task 1: `QuestyAvatar` gets real animated expression states

**Files:**
- Modify: `lib/features/ai_tutor/widgets/questy_avatar.dart` (currently 108 lines, fully static `StatelessWidget` + `CustomPainter`, `shouldRepaint` always `false`)
- Test: `test/widgets/questy_avatar_test.dart`

**Interfaces:**
- Produces: `enum QuestyExpression { idle, thinking, happy, encouraging, celebrating }` and `QuestyAvatar({double size = 36, bool glow = true, QuestyExpression expression = QuestyExpression.idle})`. Every later task that currently instantiates `QuestyAvatar(size: ...)` continues to compile unchanged (new param is optional with a default), and tasks 2, 3, 6, 7 pass an explicit `expression:`.

Read the current file first — the star/eyes/smile painter logic must be preserved exactly (Rule 3: this is a well-established, screenshot-approved visual, not a redesign target); only animation and expression-driven variation are added.

- [ ] **Step 1: Write the failing test**

```dart
// test/widgets/questy_avatar_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/features/ai_tutor/widgets/questy_avatar.dart';

void main() {
  testWidgets('QuestyAvatar renders at the requested size for every expression', (tester) async {
    for (final expr in QuestyExpression.values) {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: QuestyAvatar(size: 48, expression: expr),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      final container = tester.widget<Container>(find.byType(Container).first);
      expect(container.constraints?.maxWidth ?? 48, 48);
      expect(find.byType(CustomPaint), findsWidgets);
    }
  });

  testWidgets('QuestyAvatar idle expression animates over time (repaints)', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: QuestyAvatar(expression: QuestyExpression.idle)),
    ));
    await tester.pump();
    final firstFrameHasTicker = tester.binding.hasScheduledFrame;
    await tester.pump(const Duration(milliseconds: 500));
    // An animated idle state must keep scheduling frames; a static widget wouldn't.
    expect(firstFrameHasTicker || tester.binding.hasScheduledFrame, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/questy_avatar_test.dart`
Expected: FAIL — `QuestyExpression` undefined / `QuestyAvatar` constructor has no `expression` parameter.

- [ ] **Step 3: Read the current file, then convert to a `StatefulWidget` with expression-driven animation**

First run `Read` on `lib/features/ai_tutor/widgets/questy_avatar.dart` to get the exact current `_StarFacePainter` implementation (star path trig, eye/smile drawing) — copy it verbatim into the new version below, only changing what's noted.

```dart
import 'dart:math' as math;
import 'package:flutter/material.dart';

enum QuestyExpression { idle, thinking, happy, encouraging, celebrating }

/// Questy's single shared visual identity across the whole app — the AI
/// Tutor chat, in-game hint bubbles, and celebration dialogs all render
/// this same widget instead of ad-hoc emoji. Pure code-drawn (CustomPainter),
/// no bundled assets, to stay light on this project's memory-constrained
/// dev machine.
class QuestyAvatar extends StatefulWidget {
  final double size;
  final bool glow;
  final QuestyExpression expression;

  const QuestyAvatar({
    super.key,
    this.size = 36,
    this.glow = true,
    this.expression = QuestyExpression.idle,
  });

  @override
  State<QuestyAvatar> createState() => _QuestyAvatarState();
}

class _QuestyAvatarState extends State<QuestyAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _durationFor(widget.expression),
    )..repeat(reverse: _reversesFor(widget.expression));
  }

  @override
  void didUpdateWidget(covariant QuestyAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expression != widget.expression) {
      _controller
        ..duration = _durationFor(widget.expression)
        ..reset()
        ..repeat(reverse: _reversesFor(widget.expression));
    }
  }

  Duration _durationFor(QuestyExpression e) => switch (e) {
        QuestyExpression.thinking => const Duration(milliseconds: 700),
        QuestyExpression.celebrating => const Duration(milliseconds: 500),
        QuestyExpression.happy => const Duration(milliseconds: 900),
        QuestyExpression.encouraging => const Duration(milliseconds: 1100),
        QuestyExpression.idle => const Duration(milliseconds: 1600),
      };

  bool _reversesFor(QuestyExpression e) => e != QuestyExpression.thinking;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        // Gentle vertical bob for idle/happy/encouraging/celebrating;
        // a steady rotation for thinking.
        final bob = widget.expression == QuestyExpression.thinking
            ? 0.0
            : math.sin(t * math.pi) * (widget.size * 0.06);
        final tilt = widget.expression == QuestyExpression.thinking
            ? math.sin(t * 2 * math.pi) * 0.12
            : 0.0;
        final scale = widget.expression == QuestyExpression.celebrating
            ? 1.0 + (math.sin(t * math.pi) * 0.08)
            : 1.0;

        return Transform.translate(
          offset: Offset(0, -bob),
          child: Transform.rotate(
            angle: tilt,
            child: Transform.scale(
              scale: scale,
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFFF9800)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: widget.glow
                      ? [
                          BoxShadow(
                            color: const Color(0xFFFFD700)
                                .withValues(alpha: 0.45),
                            blurRadius: widget.size * 0.35,
                            spreadRadius: widget.size * 0.03,
                          ),
                        ]
                      : null,
                ),
                child: CustomPaint(
                  painter: _StarFacePainter(expression: widget.expression),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StarFacePainter extends CustomPainter {
  final QuestyExpression expression;
  _StarFacePainter({required this.expression});

  // PASTE the existing star-path/eyes/smile drawing code from the current
  // _StarFacePainter here verbatim, then branch the smile arc's sweep angle
  // and eye shape on `expression`:
  //  - happy/celebrating: wider smile arc (larger sweepAngle), eyes as
  //    upward-curved arcs ("^ ^") instead of dots
  //  - thinking: smile becomes a short flat line (Path with a single
  //    horizontal segment instead of drawArc), one eyebrow-like arc raised
  //  - encouraging: same as idle smile but eyes rendered slightly larger
  //  - idle: unchanged current behavior (baseline)

  @override
  bool shouldRepaint(covariant _StarFacePainter oldDelegate) =>
      oldDelegate.expression != expression;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widgets/questy_avatar_test.dart`
Expected: PASS (2/2)

- [ ] **Step 5: `flutter analyze` clean, then commit**

```bash
flutter analyze lib/features/ai_tutor/widgets/questy_avatar.dart
git add lib/features/ai_tutor/widgets/questy_avatar.dart test/widgets/questy_avatar_test.dart
git commit -m "feat(questy): animate QuestyAvatar with expression states"
```

---

### Task 2: Unify the two hint code paths through `AiTutorProvider`

**Why:** `tug_of_war_game.dart` calls `GeminiService()` directly (new instance per tap, no TTS, no chat history, no loading-state sharing with the rest of the app), while `quiz_screen.dart` correctly goes through `AiTutorProvider.getHint()`. Two code paths for the same feature is exactly the kind of duplication Rule 4 (clean, reusable code) rules out.

**Files:**
- Modify: `lib/features/games/tug_of_war/tug_of_war_game.dart` (read the file first — locate `_hintLoading`/`_hintText` state and `_fetchHint()`)
- Modify: `lib/features/quests/screens/quiz_screen.dart` (read the file first — locate the 💡 hint bottom sheet)

**Interfaces:**
- Consumes: existing `AiTutorProvider.getHint(question, subject)` (unchanged signature), `QuestyAvatar` (Task 1).

- [ ] **Step 1: Read both files to confirm current exact code**

Run `Read` on `lib/features/games/tug_of_war/tug_of_war_game.dart` (full file) and `lib/features/quests/screens/quiz_screen.dart` (full file) to get exact current line numbers for `_fetchHint()`, the hint `IconButton`, the `_HintBubble` widget, and the quiz hint bottom sheet — line numbers below are from the last investigation pass and must be re-verified against the live file before editing.

- [ ] **Step 2: Replace `tug_of_war_game.dart`'s direct `GeminiService()` call with the provider**

Change `_fetchHint()` to obtain `AiTutorProvider` via `context.read<AiTutorProvider>()` and call `.getHint(question, subject)` instead of constructing `GeminiService()` inline. Remove the now-unused direct `GeminiService` import if nothing else in the file uses it (`grep -n GeminiService` the file first to confirm). Show a loading state using `QuestyAvatar(expression: QuestyExpression.thinking, size: 28)` in place of whatever spinner `_HintBubble` currently renders while `_hintLoading` is true, and the resting/answered state using `QuestyAvatar(expression: QuestyExpression.encouraging, size: 28)`.

- [ ] **Step 3: Replace the quiz screen's 💡-emoji hint sheet header with `QuestyAvatar`**

In `quiz_screen.dart`'s hint bottom sheet (the `showModalBottomSheet` titled "Questy Hint"), replace the plain 💡 emoji header with `QuestyAvatar(size: 40, expression: QuestyExpression.thinking)` while the async `getHint` call is pending, then rebuild with `QuestyExpression.encouraging` once the hint text arrives (use a local `FutureBuilder` or existing loading flag already in that widget — read the file to match its existing state-management style rather than introducing a new pattern).

- [ ] **Step 4: Manual verification**

Run: `flutter run -d chrome`. Play a Tug of War round, tap the hint button — confirm it now shows the animated `QuestyAvatar` (thinking → encouraging) and that a hint appears identically in behavior to before (same text source, same button placement). Do the same for a quiz question's hint button.

- [ ] **Step 5: `flutter analyze` clean, then commit**

```bash
flutter analyze lib/features/games/tug_of_war/tug_of_war_game.dart lib/features/quests/screens/quiz_screen.dart
git add lib/features/games/tug_of_war/tug_of_war_game.dart lib/features/quests/screens/quiz_screen.dart
git commit -m "refactor(questy): route tug-of-war hints through AiTutorProvider, unify hint UI on QuestyAvatar"
```

---

### Task 3: Replace `MascotBubble`'s raw 🤖 emoji with `QuestyAvatar`

**Why:** `lib/features/games/core/game_theme.dart`'s `MascotBubble` (used by `grammar_hero_run.dart` and `sequence_builder_game.dart`) renders a hardcoded `🤖` for **both** its `positive` and non-`positive` branches — visually identical regardless of whether it's cheering or encouraging, and inconsistent with the real `QuestyAvatar` used in the AI Tutor tab. This is the third distinct "Questy" identity in the codebase; after this task there is exactly one.

**Files:**
- Modify: `lib/features/games/core/game_theme.dart` (read first — locate `MascotBubble`, currently ~lines 175-208 per last read)

**Interfaces:**
- Consumes: `QuestyAvatar` (Task 1). `MascotBubble`'s existing constructor signature (`positive: bool`, message text param) must stay the same — only its internal rendering changes, so `grammar_hero_run.dart` and `sequence_builder_game.dart` require zero changes.

- [ ] **Step 1: Read the current `MascotBubble` implementation**

Confirm the exact constructor params and the `Text(positive ? '🤖' : '🤖', ...)` line (or equivalent) via `Read`.

- [ ] **Step 2: Swap the emoji `Text` for `QuestyAvatar`**

Replace the emoji-rendering `Text` widget with `QuestyAvatar(size: 32, expression: positive ? QuestyExpression.happy : QuestyExpression.encouraging)`. Keep the surrounding speech-bubble `Container`/`Text` message layout exactly as-is — only the mascot icon itself changes. Add the import `import '../../ai_tutor/widgets/questy_avatar.dart';` (adjust relative path to match `game_theme.dart`'s actual location).

- [ ] **Step 3: Manual verification**

Run: `flutter run -d chrome`. Play Grammar Hero Run (runner_collector) and a Sequence Builder round; confirm the feedback bubble now shows the animated star-face Questy instead of a robot emoji, and that it visibly differs between a correct catch (happy) and a miss (encouraging).

- [ ] **Step 4: `flutter analyze` clean, then commit**

```bash
flutter analyze lib/features/games/core/game_theme.dart
git add lib/features/games/core/game_theme.dart
git commit -m "feat(questy): replace MascotBubble's robot emoji with the real QuestyAvatar"
```

---

### Task 4: Persist hints/explanations to chat history with an `intent` tag

**Why:** `AiTutorProvider.getHint()` and `.explainAnswer()` never call `_chatRepo.saveMessage` — every hint or mistake-explanation Questy has ever given a child vanishes the moment the bottom sheet closes, and there's no way to tell, from stored data, what kind of interaction a message represents. This is the concrete first step toward "tracks learner progress."

**Files:**
- Modify: `lib/data/models/chat_message_model.dart` (read first — confirm exact current fields/factories)
- Modify: `lib/providers/ai_tutor_provider.dart` (read first — confirm exact current `getHint`/`explainAnswer` bodies)
- Test: `test/providers/ai_tutor_provider_test.dart`

**Interfaces:**
- Produces: `ChatMessageModel` gains a nullable `String? intent` field (values used elsewhere in this plan: `'chat'`, `'hint'`, `'explain'`, `'recommendation'`), defaulting to `null`/`'chat'` for backward compatibility with existing stored messages (Firestore documents without the field must still deserialize — `fromMap` must use `map['intent'] as String?`, no required-field break).
- `AiTutorProvider.getHint`/`.explainAnswer` now persist both the (synthetic) user-intent message and the bot's response via `_chatRepo.saveMessage`, tagged with the matching `intent`.

- [ ] **Step 1: Write the failing test**

```dart
// test/providers/ai_tutor_provider_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/data/models/chat_message_model.dart';

void main() {
  test('ChatMessageModel round-trips the intent field', () {
    final msg = ChatMessageModel.bot('Try counting on your fingers!', intent: 'hint');
    final map = msg.toMap();
    expect(map['intent'], 'hint');

    final restored = ChatMessageModel.fromMap(map);
    expect(restored.intent, 'hint');
  });

  test('ChatMessageModel.fromMap defaults intent to null for legacy documents', () {
    final legacyMap = {
      'id': 'abc',
      'text': 'Hi!',
      'isUser': false,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'isLoading': false,
    };
    final restored = ChatMessageModel.fromMap(legacyMap);
    expect(restored.intent, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/providers/ai_tutor_provider_test.dart`
Expected: FAIL — `ChatMessageModel.bot` has no `intent` named parameter.

- [ ] **Step 3: Add the `intent` field**

Read `lib/data/models/chat_message_model.dart` in full first. Add `final String? intent;` to the class, add `this.intent` (optional, default `null`) to the constructor and to the `.user(...)`/`.bot(...)` factories (as an optional named param), include `'intent': intent` in `toMap()`, and read `map['intent'] as String?` in `fromMap()`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/providers/ai_tutor_provider_test.dart`
Expected: PASS (2/2)

- [ ] **Step 5: Wire `intent` through `getHint`/`explainAnswer` and persist**

Read `lib/providers/ai_tutor_provider.dart` in full to get the exact current bodies of `getHint(question, subject)` and `explainAnswer({...})`. Modify each so that, alongside calling `_gemini.generateQuizHint`/`.explainQuizAnswer`, it also:
1. builds a `ChatMessageModel.bot(resultText, intent: 'hint')` (or `'explain'`),
2. calls `await _chatRepo.saveMessage(_currentUser!.uid, message)` (matching the existing save pattern already used in `sendMessage`),
3. still returns the raw text string to the caller (quiz_screen/tug_of_war bottom sheets), so their existing call sites need **no signature changes**.

Guard the persistence with `if (_currentUser != null)` (matching existing null-safety style in the file) so a hint requested before session init doesn't crash.

- [ ] **Step 6: Manual verification**

Run: `flutter run -d chrome`. Request a hint in a quiz, then open the Questy chat tab — confirm the hint now appears in chat history (tagged, even if the UI doesn't yet render the tag visibly — that's fine, the goal here is persistence, not new UI chrome).

- [ ] **Step 7: `flutter analyze` clean, then commit**

```bash
flutter analyze lib/data/models/chat_message_model.dart lib/providers/ai_tutor_provider.dart
git add lib/data/models/chat_message_model.dart lib/providers/ai_tutor_provider.dart test/providers/ai_tutor_provider_test.dart
git commit -m "feat(questy): persist hints and answer explanations to chat history with an intent tag"
```

---

### Task 5: Local scripted-dialogue pool for celebration and encouragement

**Why:** Badge/level-up celebration currently has zero Questy involvement (confetti + a generic dialog only) and the existing scripted lines in `quiz_screen.dart`/`grammar_hero_run.dart` are hardcoded ad-hoc strings duplicated per screen. This task builds one shared, varied line-pool so celebration feels alive without spending Gemini quota on every badge earned.

**Files:**
- Create: `lib/features/ai_tutor/widgets/questy_dialogue.dart`
- Test: `test/widgets/questy_dialogue_test.dart`

**Interfaces:**
- Produces: `class QuestyDialogue` with static methods `celebrateBadge(String badgeName) → String`, `celebrateLevelUp(int newLevel) → String`, `encourageAfterMiss() → String`, `cheerCorrect() → String` — each returns a randomly-chosen line from a small hardcoded pool (3-5 variants per category) so repeated triggers don't feel robotic. Task 6 consumes `celebrateBadge`/`celebrateLevelUp`; Task 3's `MascotBubble` callers can optionally be migrated to `encourageAfterMiss`/`cheerCorrect` in a later pass but that's not required by this task (out of scope — don't touch `grammar_hero_run.dart`/`sequence_builder_game.dart`'s existing message strings here, only add the new shared utility).

- [ ] **Step 1: Write the failing test**

```dart
// test/widgets/questy_dialogue_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/features/ai_tutor/widgets/questy_dialogue.dart';

void main() {
  test('celebrateBadge returns non-empty text mentioning the badge name', () {
    final line = QuestyDialogue.celebrateBadge('Math Wizard');
    expect(line, isNotEmpty);
    expect(line.contains('Math Wizard'), isTrue);
  });

  test('celebrateLevelUp returns non-empty text mentioning the new level', () {
    final line = QuestyDialogue.celebrateLevelUp(5);
    expect(line, isNotEmpty);
    expect(line.contains('5'), isTrue);
  });

  test('encourageAfterMiss and cheerCorrect return varied non-empty lines', () {
    final seen = <String>{};
    for (var i = 0; i < 20; i++) {
      seen.add(QuestyDialogue.encourageAfterMiss());
    }
    expect(seen.every((s) => s.isNotEmpty), isTrue);
    // With >=3 pool variants and 20 draws, expect more than one distinct line.
    expect(seen.length, greaterThan(1));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/questy_dialogue_test.dart`
Expected: FAIL — file doesn't exist.

- [ ] **Step 3: Implement `QuestyDialogue`**

```dart
// lib/features/ai_tutor/widgets/questy_dialogue.dart
import 'dart:math';

/// Local, quota-free scripted lines Questy uses to react to gameplay/
/// progress events (badges, level-ups, streaks) so celebration doesn't
/// compete with the shared 50/day Gemini quota used by chat/hints.
class QuestyDialogue {
  static final _random = Random();

  static const _badgeLines = [
    'You earned the {badge} badge! I knew you had it in you! 🌟',
    'Whoa, {badge}! That is such a big achievement — amazing work! 🎉',
    '{badge} unlocked! You should be so proud of yourself! ✨',
  ];

  static const _levelUpLines = [
    'Level {level}! You are growing into a真 QuestKids champion! 🚀',
    'Ding! Level {level} reached — your hard work is really paying off! 💫',
    'Look at you go — Level {level} already! Keep it up! 🔥',
  ];

  static const _encourageLines = [
    'Not quite — but every mistake helps your brain grow! Try again! 💪',
    'So close! Take another look and give it one more shot! 🌈',
    'That is okay — even champions get tricky questions wrong sometimes! 🙂',
    'Keep going! You are learning something new with every try! ✨',
  ];

  static const _cheerLines = [
    'Yes! Perfect! You are on fire today! 🔥',
    'Correct! Fantastic thinking! 🌟',
    'Nailed it! Keep that streak going! 🎯',
    'Great job! You really know your stuff! 🎉',
  ];

  static String celebrateBadge(String badgeName) =>
      (_badgeLines[_random.nextInt(_badgeLines.length)])
          .replaceAll('{badge}', badgeName);

  static String celebrateLevelUp(int newLevel) =>
      (_levelUpLines[_random.nextInt(_levelUpLines.length)])
          .replaceAll('{level}', '$newLevel');

  static String encourageAfterMiss() =>
      _encourageLines[_random.nextInt(_encourageLines.length)];

  static String cheerCorrect() =>
      _cheerLines[_random.nextInt(_cheerLines.length)];
}
```

(Fix the stray non-ASCII character in the level-up line draft above — write the committed version as plain ASCII: `'Level {level}! You are growing into a real QuestKids champion! 🚀'`.)

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widgets/questy_dialogue_test.dart`
Expected: PASS (3/3)

- [ ] **Step 5: `flutter analyze` clean, then commit**

```bash
flutter analyze lib/features/ai_tutor/widgets/questy_dialogue.dart
git add lib/features/ai_tutor/widgets/questy_dialogue.dart test/widgets/questy_dialogue_test.dart
git commit -m "feat(questy): add local scripted dialogue pool for celebration/encouragement"
```

---

### Task 6: Wire celebration dialogue + animated avatar into badge/level-up moments

**Files:**
- Modify: `lib/providers/rewards_provider.dart` (read first — confirm exact current `checkForNewBadges` implementation)
- Modify: `lib/features/rewards/widgets/badge_earned_dialog.dart` (read first — confirm exact current dialog structure)

**Interfaces:**
- Consumes: `QuestyDialogue.celebrateBadge`/`.celebrateLevelUp` (Task 5), `QuestyAvatar(expression: QuestyExpression.celebrating)` (Task 1), `AiTutorProvider.speak(String)` (existing, unchanged — reused here so the celebration is spoken aloud consistent with the rest of the app's auto-TTS behavior, per §10 of the investigation).

- [ ] **Step 1: Read both files to confirm current exact structure**

- [ ] **Step 2: Add a Questy line and animated avatar to `badge_earned_dialog.dart`**

Add a `QuestyAvatar(size: 56, expression: QuestyExpression.celebrating)` above/beside the existing badge icon, and a `Text` showing `QuestyDialogue.celebrateBadge(badge.name)` (use whatever the badge model's display-name field is called — confirm via the file read) below the existing "Badge Earned!" heading. Do not remove the existing confetti/animation — this adds to it, not replaces it (Rule 3).

- [ ] **Step 3: Speak the celebration line via TTS**

Where `badge_earned_dialog.dart` is shown (likely triggered from wherever `RewardsProvider.checkForNewBadges` results are consumed — confirm the call site), thread through a call to `context.read<AiTutorProvider>().speak(QuestyDialogue.celebrateBadge(badge.name))` when the dialog opens, matching the existing pattern of auto-speaking Questy's lines everywhere else in the app (§10 of the investigation) — this dialog was the one celebration moment where Questy previously said nothing at all.

- [ ] **Step 4: Level-up detection and celebration**

Read `lib/providers/rewards_provider.dart` and `lib/core/services/rewards_service.dart`'s `getLevelFromPoints` to find where level changes could be detected (likely by comparing the previous and new `totalPoints`-derived level inside `RewardsProvider` after a points update). Add a `_previousLevel` tracking field and, when a level increase is detected, call the same `AiTutorProvider.speak(QuestyDialogue.celebrateLevelUp(newLevel))` pattern — if there is no existing UI surface for a "level up" moment (confirm via search), add a minimal `SnackBar` or reuse `badge_earned_dialog.dart`'s visual shell with level-up copy rather than building a whole new dialog widget from scratch (YAGNI — don't over-build this if a simple reuse suffices).

- [ ] **Step 5: Manual verification**

Run: `flutter run -d chrome`. Complete enough quests/games in a test account to trigger a badge award — confirm the badge dialog now shows the animated celebrating Questy, a randomized congratulation line, and that it's spoken aloud.

- [ ] **Step 6: `flutter analyze` clean, then commit**

```bash
flutter analyze lib/providers/rewards_provider.dart lib/features/rewards/widgets/badge_earned_dialog.dart
git add lib/providers/rewards_provider.dart lib/features/rewards/widgets/badge_earned_dialog.dart
git commit -m "feat(questy): celebrate badges and level-ups with Questy dialogue and TTS"
```

---

### Task 7: Consistent "thinking" indicator + TTS mute control

**Why:** `recommendation_card.dart` already shows a decent "Questy is looking at your progress..." loading state, but game hint bubbles (Task 2) previously used plain spinners, and there is **no way to silence TTS anywhere** — `AiTutorProvider.stopSpeaking()` exists but is called from zero places in the app (confirmed dead code).

**Files:**
- Modify: `lib/features/ai_tutor/screens/ai_tutor_screen.dart` (read first — locate the app bar, currently non-embedded mode only per investigation §3)
- Modify: `lib/features/ai_tutor/widgets/chat_bubble.dart` (read first — locate `_TypingIndicator`)

**Interfaces:**
- Consumes: `AiTutorProvider.stopSpeaking()` (existing, unchanged), `QuestyAvatar(expression: QuestyExpression.thinking)` (Task 1).

- [ ] **Step 1: Add a mute/TTS-toggle button to the AI Tutor app bar**

In `ai_tutor_screen.dart`'s non-embedded `AppBar` (the one skipped in embedded/dashboard-tab mode per investigation §3), add an `IconButton` (e.g. `Icons.volume_up`/`Icons.volume_off`, toggled by a new local bool or a new `AiTutorProvider` field `bool isMuted`) that calls `context.read<AiTutorProvider>().stopSpeaking()` when toggled off, and gates future `speak()` calls behind the mute flag (add a small `if (!_isMuted)` guard inside `AiTutorProvider.speak()` itself, reading a new `bool _muted = false` field with a `toggleMute()` method, so the mute setting also suppresses TTS triggered from quiz/game screens, not just the chat tab).

- [ ] **Step 2: Optionally replace `_TypingIndicator`'s bouncing dots with `QuestyAvatar(expression: thinking)`**

Read the current `_TypingIndicator` in `chat_bubble.dart` (3 staggered `AnimationController`s per investigation §4). This is cosmetic and already reasonably good — only replace it if doing so is a net simplification (reusing Task 1's animation instead of maintaining a second bespoke animation system); if the existing dots are simpler to keep working alongside the avatar, leave them and just confirm a `QuestyAvatar(expression: thinking)` sits next to them as it already does today (verify via the file read — don't force a change here if it adds risk for no clear benefit, per Rule 4's "don't over-engineer").

- [ ] **Step 3: Manual verification**

Run: `flutter run -d chrome`. Open the AI Tutor tab (via `ResponsiveScaffold`'s Questy destination — non-embedded route if one exists, or verify the mute button surfaces correctly even in embedded mode by adding it to the embedded body's own small header row if the app bar is truly skipped). Send a message, confirm TTS speaks it; toggle mute; send another message, confirm it does not speak.

- [ ] **Step 4: `flutter analyze` clean, then commit**

```bash
flutter analyze lib/features/ai_tutor/screens/ai_tutor_screen.dart lib/providers/ai_tutor_provider.dart lib/features/ai_tutor/widgets/chat_bubble.dart
git add lib/features/ai_tutor/screens/ai_tutor_screen.dart lib/providers/ai_tutor_provider.dart lib/features/ai_tutor/widgets/chat_bubble.dart
git commit -m "feat(questy): add TTS mute control, finally wire up stopSpeaking()"
```

---

### Task 8: Proactive "Questy's Tip" card on the dashboard home tab

**Why:** Today, Questy's personalized recommendation only exists inside the AI Tutor tab and only loads when that tab is opened — this is the core of "Questy should integrate throughout the application instead of existing as a separate feature." Surface it on the learner's home screen instead, cached once/day to protect quota (mirroring the existing daily-missions caching pattern already in the codebase).

**Files:**
- Modify: `lib/features/dashboard/screens/learner_dashboard.dart` (read first — locate `_LearnerHomeTab`, confirmed in Phase 1 work at roughly lines 183-257)

**Interfaces:**
- Consumes: `AiTutorProvider.loadRecommendation(...)` (existing, unchanged signature), `QuestyAvatar` (Task 1), `RewardsProvider` (existing, already watched in this file for `_StatsRow`/`_ProgressSection`).

- [ ] **Step 1: Read the current `_LearnerHomeTab` build method in full** to find the exact insertion point (after `_DailyChallengeCard`, before `_FeaturedGamesSection`, matching the existing card-stacking order) and confirm `RewardsProvider`'s exposed fields (`subjectCounts`, `questsCompleted`, etc. — used by `loadRecommendation`'s `subjectScores` param).

- [ ] **Step 2: Add day-scoped caching to avoid burning quota on every dashboard open**

Add a small check using `shared_preferences` (already a dependency): store `questy_tip_date` (ISO date string) and `questy_tip_text` keys. On dashboard init, if `questy_tip_date` matches today, use the cached text; otherwise call `AiTutorProvider.loadRecommendation(...)` once and cache the result. This mirrors the existing `daily_missions` server-side once-per-day pattern but implemented client-side since `getRecommendation` has no dedicated scheduled function.

- [ ] **Step 3: Add the tip card widget**

Add a compact card (reuse `recommendation_card.dart`'s visual style — read it first — rather than inventing a new one) showing `QuestyAvatar(size: 32)` + "Questy's Tip" + the cached/loaded recommendation text, placed in the home tab's scroll column.

- [ ] **Step 4: Manual verification**

Run: `flutter run -d chrome`. Open the learner dashboard home tab — confirm a "Questy's Tip" card appears without needing to open the AI Tutor tab, and that reloading the app the same day reuses the cached text (check via a print/log or by confirming no new network tab activity in a second load) rather than calling Gemini again.

- [ ] **Step 5: `flutter analyze` clean, then commit**

```bash
flutter analyze lib/features/dashboard/screens/learner_dashboard.dart
git add lib/features/dashboard/screens/learner_dashboard.dart
git commit -m "feat(questy): surface a daily proactive tip card on the dashboard home tab"
```

---

### Task 9: Fix `preferredLanguage` → TTS locale (dead plumbing)

**Why:** `UserModel.preferredLanguage` is stored and user-editable (Profile screen, Teacher dashboard) but has zero effect anywhere — `AiTutorProvider._initTts()` hardcodes `en-ZA`. This is a real, scoped, fixable bug (Rule 3), not a redesign. Full multi-language *Gemini response* generation is out of scope for this phase (a content/i18n effort, not a companion-feel fix) — this task only fixes the TTS voice.

**Files:**
- Modify: `lib/providers/ai_tutor_provider.dart` (read first — confirm exact current `_initTts()` and how/when `UserModel` becomes available to the provider)

- [ ] **Step 1: Read the file to confirm when `_currentUser`/the `UserModel` is set relative to `_initTts()`'s call site** (constructor vs. `initSession`) — the locale must be chosen using the user's actual `preferredLanguage`, so `_initTts()` may need to move to (or be re-called from) `initSession(UserModel user)` if it currently runs before the user is known.

- [ ] **Step 2: Add a language-name → TTS-locale mapping**

`flutter_tts` locales are BCP-47 codes; South African languages don't all have dedicated TTS engine voices on every device, so map to the closest available with `en-ZA` as the universal fallback:

```dart
String _ttsLocaleFor(String? preferredLanguage) {
  const map = {
    'Afrikaans': 'af-ZA',
    'English': 'en-ZA',
    // isiZulu, isiXhosa, siSwati, isiNdebele, Sesotho, Northern Sotho,
    // Setswana, Tshivenda, Xitsonga have no widely-available on-device
    // TTS voice — fall back to en-ZA rather than silently failing.
  };
  return map[preferredLanguage] ?? 'en-ZA';
}
```

Call `await _flutterTts.setLanguage(_ttsLocaleFor(user.preferredLanguage));` inside `initSession`, replacing (or supplementing, if `_initTts()` must still run earlier for other setup) the hardcoded `'en-ZA'` call.

- [ ] **Step 3: Manual verification**

Run: `flutter run -d chrome` with a test account whose `preferredLanguage` is set to `Afrikaans` — confirm (via `flutter_tts`'s available-languages check or by observing no crash/fallback warning) that `af-ZA` is requested; a device/browser without that voice installed will silently fall back per `flutter_tts`'s own behavior, which is acceptable (matches the existing fallback design, doesn't need new error handling).

- [ ] **Step 4: `flutter analyze` clean, then commit**

```bash
flutter analyze lib/providers/ai_tutor_provider.dart
git add lib/providers/ai_tutor_provider.dart
git commit -m "fix(questy): make TTS locale follow the user's preferredLanguage instead of hardcoded en-ZA"
```

---

### Task 10: Give the chat user-avatar the child's real identity

**Why:** `chat_bubble.dart`'s `_UserAvatar` renders a hardcoded 👧 emoji for every user message regardless of the actual child's avatar/gender — a small but real inconsistency now that Phase 1 gave the rest of the app a real avatar picker (`profile_avatar_picker.dart`, `ProfileAvatarPicker`).

**Files:**
- Modify: `lib/features/ai_tutor/widgets/chat_bubble.dart` (read first — confirm exact current `_UserAvatar` implementation and what data `ChatBubble` currently receives, e.g. does it get a `UserModel` at all, or only the message?)

- [ ] **Step 1: Read the file and its call sites** (`ai_tutor_screen.dart`'s message list builder) to see whether `ChatBubble` already has access to the current user or would need a new parameter threaded through.

- [ ] **Step 2: Thread the user's `avatarUrl` (if any) into `ChatBubble`, falling back to the existing 👧 emoji only when no avatar is set**

Add an optional `String? userAvatarUrl` constructor param to `ChatBubble`, pass `NetworkImage(avatarUrl)` when present (mirroring the `CircleAvatar(backgroundImage: ...)` pattern already used in `profile_screen.dart`/`learner_dashboard.dart`), else keep the current 👧 emoji fallback exactly as-is (no behavior change for children who haven't set a profile picture).

- [ ] **Step 3: Manual verification**

Run: `flutter run -d chrome`. As a user with a set profile picture, send a chat message to Questy — confirm the user bubble now shows their real avatar instead of the generic 👧.

- [ ] **Step 4: `flutter analyze` clean, then commit**

```bash
flutter analyze lib/features/ai_tutor/widgets/chat_bubble.dart lib/features/ai_tutor/screens/ai_tutor_screen.dart
git add lib/features/ai_tutor/widgets/chat_bubble.dart lib/features/ai_tutor/screens/ai_tutor_screen.dart
git commit -m "feat(questy): show the child's real avatar in chat instead of a hardcoded emoji"
```

---

## End-of-Phase Checklist (per project Rule 1 — do not report Phase 2 complete until all of these hold)

- [ ] `flutter analyze` → 0 new errors
- [ ] `flutter test` → all green, including the new tests this plan adds
- [ ] `flutter build web --release` and `flutter build apk --debug` both succeed (per the Phase 1 lesson: verify actual compiles, not just `flutter test`)
- [ ] Questy's animated avatar appears identically in: the AI Tutor chat, Tug of War hints, quiz hints/explanations, Grammar Hero Run and Sequence Builder feedback bubbles, and the badge-earned dialog — no `🤖`/💡-emoji stand-ins remain anywhere
- [ ] A badge earned and a level-up both trigger a spoken, animated Questy celebration
- [ ] The dashboard home tab shows a "Questy's Tip" card without requiring the learner to open the AI Tutor tab
- [ ] TTS can be muted from the AI Tutor screen and the mute setting suppresses speech triggered from quiz/game screens too
- [ ] `preferredLanguage` now affects the TTS voice locale
- [ ] Hints and answer explanations are now saved to Firestore chat history with an `intent` tag
- [ ] The existing AI-transparency label and report/flag flow (`chat_bubble.dart`, `ai_reports` collection) are untouched and still functional
- [ ] `functions/src/gemini/proxy.ts`'s system prompt, quota (50/day/uid), and safety settings are untouched
- [ ] No files matching forbidden-secrets patterns were added
