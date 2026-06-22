# QuestKids Commercial Upgrade — Design Spec

> **Status:** Approved by product owner 2026-06-22  
> **Scope:** Sub-projects A → D, executed in sequence  
> **Stack:** Flutter 3.4+, Firebase (Auth, Firestore, Storage, Functions, Messaging), Gemini 1.5 Flash via Cloud Functions proxy, Provider, SQLite (offline), fl_chart 0.68+

---

## Background & Current State

QuestKids is a Flutter EdTech app targeting South African Grades 1–7 learners. The codebase is approximately 75% complete: 6 working game engines (tugOfWar, adventureJourney, runnerCollector, explorerMap, multiplesMerge, sequenceBuilder), 159 CAPS-aligned catalog entries, multi-role auth (learner, parent, teacher), parent-child QR/code linking, parent dashboard (5 tabs), teacher dashboard (4 tabs), Gemini AI tutor, offline SQLite cache, and responsive layout.

Critical gaps before commercial release:
1. Gemini API key hardcoded in source (security vulnerability)
2. fl_chart not in pubspec — analytics screens cannot render charts
3. Leaderboard screen missing (data model exists, no UI or aggregation)
4. Daily missions are static, not Firestore-driven
5. Grade 7 curriculum underserved (Technology, EMS need dedicated engines)
6. No analytics charts in parent or teacher dashboards
7. Zero automated tests

---

## Global Constraints

- Flutter SDK: `>=3.4.0 <4.0.0`
- Target platforms: Android (minSdk 21), iOS (iOS 13+)
- State management: Provider only — no Riverpod, Bloc, or GetX
- Design system: `AppColors`, `AppTextStyles` (Nunito), `GameTheme` — no inline hex colours or font sizes
- All Gemini calls must go through Cloud Functions proxy — never direct from client
- All API keys in Firebase Secret Manager (production) / `.env` files (local) — never in source
- Firestore rules must be updated for every new collection
- `flutter analyze` must pass clean after each sub-project
- Git: one commit per task, conventional commit messages (`feat:`, `fix:`, `chore:`)
- CAPS curriculum alignment is non-negotiable for all game content

---

## Sub-project A: Foundation

**Goal:** Eliminate the API key security vulnerability, add the fl_chart dependency, deliver a working leaderboard, and implement a three-tier daily missions system.

### A1 — Gemini Cloud Functions Proxy

**Problem:** `AIzaSyCtA9gneaigWxeKmcVICWUZQlcUsjhWi3o` is hardcoded in `lib/core/services/gemini_service.dart:5`.

**Solution:** Move all Gemini SDK calls into Firebase Cloud Functions. The Flutter client calls `HttpsCallable` — no API key ever touches the client bundle.

**New files:**
```
functions/src/gemini/
  proxy.ts          — questbotChat, analyzeImage, getRecommendation, explainAnswer, generateHint
  index.ts          — export all functions (merge with existing index.ts)
functions/.env      — GEMINI_API_KEY=<key> (gitignored)
```

**Modified files:**
```
lib/core/services/gemini_service.dart  — replace SDK calls with FirebaseFunctions.instance.httpsCallable()
```

**Cloud Function signatures (TypeScript):**
```typescript
// questbotChat
interface ChatRequest { message: string; history?: {role: string; text: string}[] }
interface ChatResponse { text: string }

// analyzeImage
interface ImageRequest { imageBase64: string; prompt: string }
interface ImageResponse { text: string }

// getRecommendation
interface RecommendationRequest {
  name: string; grade: string;
  subjectScores: Record<string, number>;
  streakDays: number; totalPoints: number;
}
interface RecommendationResponse { text: string }

// explainAnswer
interface ExplainRequest { question: string; correctAnswer: string; subject: string; grade: string }
interface ExplainResponse { text: string }

// generateHint
interface HintRequest { question: string; subject: string }
interface HintResponse { text: string }
```

**Flutter GeminiService after change:**
```dart
class GeminiService {
  final _functions = FirebaseFunctions.instanceFor(region: 'us-central1');

  Future<String> sendMessage(String message, {List<Map<String,String>> history = const []}) async {
    final result = await _functions
        .httpsCallable('questbotChat')
        .call({'message': message, 'history': history});
    return result.data['text'] as String;
  }
  // same pattern for analyzeImage, getPersonalisedRecommendation, explainQuizAnswer, generateQuizHint
}
```

**Environment setup:**
- Local: `functions/.env` with `GEMINI_API_KEY`
- Production: `firebase functions:secrets:set GEMINI_API_KEY`
- `.gitignore` must include `functions/.env`

**Firestore rules:** No changes — functions run with Admin SDK, bypass rules.

---

### A2 — fl_chart Dependency

**Change:** Add `fl_chart: ^0.68.0` to `pubspec.yaml` dependencies.

No chart UI built in Sub-project A. This task exists to verify the dependency resolves cleanly with all existing packages before Sub-project B builds on it.

**Verify:** `flutter pub get` completes without conflicts. `flutter analyze` passes.

---

### A3 — Leaderboard System

**Architecture:**

Two leaderboards: grade-wide (top 50 by XP, refreshed daily by Cloud Function) and class cohort (real-time stream of linked learners' XP).

**New Firestore collections:**
```
leaderboards/{grade}/weekly    — {uid, displayName, avatarEmoji, grade, xp, rank, updatedAt}
leaderboards/{grade}/allTime   — same shape
class_leaderboards/{teacherUid} — {uid, displayName, avatarEmoji, xp, rank, updatedAt}
```

**New Cloud Function:** `refreshLeaderboards` — runs on `pubsub.schedule('every 24 hours').timeZone('Africa/Johannesburg')`. Queries `users` collection grouped by grade, sums `totalPoints` from `rewards/{uid}`, writes ranked snapshots to both leaderboard collections.

**New files:**
```
lib/data/repositories/leaderboard_repository.dart
lib/features/rewards/screens/leaderboard_screen.dart
lib/features/rewards/widgets/leaderboard_entry_tile.dart
lib/features/rewards/widgets/own_rank_banner.dart
functions/src/leaderboard/refresh.ts
```

**Modified files:**
```
lib/features/rewards/screens/rewards_screen.dart  — replace leaderboard tab stub with LeaderboardScreen
functions/src/index.ts                             — export refreshLeaderboards
firestore.rules                                    — read rules for leaderboards collections
firestore.indexes.json                             — index on grade + xp descending
```

**LeaderboardRepository:**
```dart
class LeaderboardRepository {
  Stream<List<LeaderboardEntry>> watchGradeLeaderboard(String grade, {String period = 'weekly'});
  Stream<List<LeaderboardEntry>> watchClassLeaderboard(String teacherUid);
  Future<int?> getOwnRank(String uid, String grade, {String period = 'weekly'});
}
```

**LeaderboardScreen UI:**
- Two tabs: "Grade" and "My Class" (class tab hidden if no teacher linked)
- Animated staggered list reveal on load (flutter_animate slide + fade, 30ms stagger)
- Own entry pinned at bottom with gold highlight when outside top 10
- Trophy emoji (🥇🥈🥉) for top 3 positions
- Loading skeleton while data streams in
- Empty state when class has no learners

---

### A4 — Daily Missions System

**Architecture:** Three-tier priority stack generating 3 missions per learner per day.

**New Firestore collections:**
```
daily_missions/{uid}/today     — {missions: [...], generatedAt, expiresAt}
daily_missions/{uid}/assigned  — {missions: [...], assignedBy, assignedAt}  (teacher writes here)
```

**Mission document shape:**
```dart
class DailyMission {
  final String id;
  final String gameId;        // matches GameCatalog entry id
  final String title;
  final String subject;
  final String emoji;
  final int xpBonus;          // 1.5× normal XP
  final bool completed;
  final DateTime? completedAt;
  final String source;        // 'teacher' | 'adaptive' | 'curated'
}
```

**New Cloud Function:** `generateDailyMissions` — scheduled at 00:00 SAST (`every 24 hours` with `timeZone('Africa/Johannesburg')`).

Logic per learner:
1. Read `daily_missions/{uid}/assigned` — take up to 3 teacher missions
2. If slots remain AND learner has ≥7 days of progress history → call Gemini proxy with subject score breakdown. Gemini must respond with valid JSON matching `{"missions":[{"gameId":"<id>","reason":"<one sentence>"}]}`. The prompt instructs Gemini to pick only IDs from the provided catalog subset. Parse 1–2 entries from the `missions` array; malformed JSON falls through to step 3.
3. Fill remaining slots from `MissionCatalog` (TypeScript map: dayOfWeek → [{subject, gameId}])
4. Write to `daily_missions/{uid}/today` with `expiresAt = next midnight SAST`

**New files:**
```
lib/data/models/daily_mission_model.dart
lib/data/repositories/mission_repository.dart
lib/features/dashboard/widgets/daily_missions_card.dart
lib/providers/mission_provider.dart
functions/src/missions/generate.ts
functions/src/missions/catalog.ts          — curated rotation map
```

**Modified files:**
```
lib/features/dashboard/screens/learner_dashboard.dart  — Home tab: DailyMissionsCard above game catalog
lib/features/games/core/game_session_state.dart         — on finishSession(), check if game completes a mission → award 1.5× XP
lib/main.dart                                           — add MissionProvider to MultiProvider
functions/src/index.ts                                  — export generateDailyMissions
firestore.rules                                         — learner reads own missions; teacher writes to assigned
```

**MissionProvider:**
```dart
class MissionProvider extends ChangeNotifier {
  List<DailyMission> _missions = [];
  List<DailyMission> get missions => _missions;
  int get completedCount => _missions.where((m) => m.completed).length;

  void watchMissions(String uid);
  Future<void> completeMission(String uid, String missionId);
}
```

**DailyMissionsCard UI:**
- Horizontal scroll of 3 mission cards
- Each card: emoji, subject colour gradient, title, source badge ('📋 Teacher' / '🤖 AI Pick' / '⭐ Daily')
- Completed state: checkmark overlay, XP gained shown
- Progress summary: "2 / 3 missions complete" with animated progress bar
- Tap → launches the game via `GameRouter`

---

## Sub-project B: Analytics Dashboards

**Goal:** Replace placeholder analytics panels in parent and teacher dashboards with real fl_chart visualisations, AI-generated insights, and data export.

### B1 — Parent Analytics

**Parent dashboard Reports tab — chart suite:**

| Chart | Type | Data source | Period |
|-------|------|-------------|--------|
| XP per subject | `BarChart` | `progress` aggregated by subject | Last 30 days |
| Score trend | `LineChart` | 7-day rolling average across all games | Last 8 weeks |
| Subject mastery | `RadarChart` (pentagon) | Average score per subject (all time) | All time |
| Time spent | Horizontal `BarChart` | Sum of `game_session.timeTaken` per subject | Last 30 days |

Colours: each bar/line uses `AppColors` subject colour. Dark/light theme aware.

**Multi-child selector:** If parent has multiple linked children, a scrollable avatar row appears above the charts. Tapping a child avatar reloads all charts for that child.

**PDF export:** `printing` package. Each chart is wrapped in a `RepaintBoundary` with a `GlobalKey`. Tapping the share icon calls `boundary.toImage()` on each `RenderRepaintBoundary`, encodes to PNG bytes, and assembles a one-page PDF (child name, grade, date range, four chart images, Gemini summary paragraph) via the `pdf` package. Shared via `share_plus`.

**New files:**
```
lib/features/parent/screens/child_analytics_screen.dart
lib/features/parent/widgets/subject_bar_chart.dart
lib/features/parent/widgets/score_trend_chart.dart
lib/features/parent/widgets/mastery_radar_chart.dart
lib/features/parent/widgets/time_spent_chart.dart
lib/features/parent/widgets/analytics_export_button.dart
```

**Modified files:**
```
lib/features/dashboard/screens/parent_dashboard.dart  — Reports tab body → ChildAnalyticsScreen
lib/data/repositories/parent_repository.dart           — getChildAnalytics already exists; add getWeeklyTrend, getTimeSummary
```

---

### B2 — Teacher Analytics

**New Analytics tab** added to `TeacherDashboard` (5th tab, icon: `Icons.analytics_outlined`).

| Chart | Type | Insight |
|-------|------|---------|
| Class avg by subject | `BarChart` | Colour: red if avg < 60%, amber 60–79%, green 80%+ |
| Quest completion rate | `PieChart` | Completed vs. attempted (last 30 days) |
| Weak topic list | Ranked list | Topics where class avg < 60%, sorted by severity |
| Active learners trend | `LineChart` | Daily active count over last 14 days |

**AI Insight card:** On tab open, calls Cloud Function `getTeacherInsight` with class stats JSON → Gemini returns a 2-sentence recommendation → displayed in a purple gradient card with 🤖 icon. Cached for 24h in Firestore to avoid repeated AI calls.

**CSV export:** One tap exports `progress` records for all linked learners as CSV (already have `csv` package). Columns: learner name, grade, subject, activity, score, date, time spent.

**New files:**
```
lib/features/teacher/screens/class_analytics_screen.dart
lib/features/teacher/widgets/class_subject_chart.dart
lib/features/teacher/widgets/completion_pie_chart.dart
lib/features/teacher/widgets/weak_topic_list.dart
lib/features/teacher/widgets/active_trend_chart.dart
lib/features/teacher/widgets/teacher_insight_card.dart
lib/data/repositories/teacher_repository.dart
functions/src/teacher/insights.ts
```

**Modified files:**
```
lib/features/dashboard/screens/teacher_dashboard.dart  — add Analytics tab (index 4), push index 3 → Profile
functions/src/index.ts                                  — export getTeacherInsight
```

---

## Sub-project C: Grade 7 Content & New Game Engines

**Goal:** Build two new game engines for subjects that existing engines cannot serve well, then expand the Grade 7 catalog to full CAPS coverage.

### C1 — CircuitBuilder Engine

**Location:** `lib/features/games/circuit_builder/`

**Mechanic:** Drag-and-connect electrical circuit puzzle rendered on a `CustomPainter` canvas.

- Canvas shows a grid with component dock at the bottom: Battery 🔋, Bulb 💡, Switch 🔌, Resistor ⬜, Motor ⚙️
- Player drags components onto grid cells, then taps two endpoints to draw a wire between them
- Circuit validator runs on each wire addition: checks for complete loop, correct component set, series vs. parallel topology
- **Easy (Grade 7 intro):** Drag provided components into a pre-drawn partial circuit (gap-fill)
- **Medium:** Build a complete series circuit from scratch to match a spec card ("make the bulb light")
- **Hard:** Design a parallel circuit; switch must control only one branch

**Difficulty levels map to CAPS topics:**
- Easy → simple circuits (Term 1)
- Medium → series and parallel circuits (Term 2)  
- Hard → electromagnets and motors (Term 3)

**New files:**
```
lib/features/games/circuit_builder/
  circuit_builder_game.dart       — top-level StatefulWidget
  circuit_builder_session.dart    — ChangeNotifier, extends GameSessionState
  circuit_builder_engine.dart     — circuit validation logic
  circuit_builder_config.dart     — CircuitChallenge definitions (component list, target topology)
  widgets/
    circuit_canvas.dart           — CustomPainter: grid, components, wires, validation glow
    component_dock.dart           — draggable component tray
    circuit_result_overlay.dart   — success/fail overlay reusing GameTheme colours
```

**AppConstants:** Add `circuitBuilder` engine type constant.
**GameRouter:** Add `case AppConstants.engineCircuitBuilder: return CircuitBuilderGame(config: config)`.

---

### C2 — BudgetBuilder Engine

**Location:** `lib/features/games/budget_builder/`

**Mechanic:** Drag-and-allocate monthly budget management game.

- Player receives a scenario card: name, income amount (in rand), a list of 8–12 items (rent, food, school fees, data, airtime, cinema, new shoes, savings)
- Drag items into three columns: **Needs** (must pay), **Wants** (optional), **Skip** (can't afford)
- Scoring rubric: all essential needs covered (+40 pts), savings ≥10% of income (+30 pts), no debt (+20 pts), wants balanced sensibly (+10 pts)
- Scenarios scale in complexity: Grade 7 Term 1 → personal pocket money; Term 4 → small business cash flow

**CAPS topics covered:** needs vs. wants, budgets, savings, banks, production costs, entrepreneur activities, poverty and inequality context.

**New files:**
```
lib/features/games/budget_builder/
  budget_builder_game.dart
  budget_builder_session.dart
  budget_builder_engine.dart      — scoring rubric validation
  budget_builder_config.dart      — BudgetScenario definitions (income, items, rubric weights)
  widgets/
    budget_columns.dart           — three DragTarget columns with drop animation
    item_card.dart                — draggable item chip with rand amount
    budget_result_overlay.dart    — score breakdown with financial advice from Gemini hint
```

**AppConstants:** Add `budgetBuilder` engine type constant.
**GameRouter:** Add `case AppConstants.engineBudgetBuilder: return BudgetBuilderGame(config: config)`.

---

### C3 — Grade 7 Catalog Expansion

**Target:** 60+ new `GameCatalogEntry` entries in `lib/core/constants/game_catalog.dart`.

**Coverage by subject:**

| Subject | New entries | Engine used |
|---------|-------------|-------------|
| Technology | 12 | circuitBuilder (circuits, electromagnets), sequenceBuilder (IDMEC process, mechanisms), adventureJourney (structures, hydraulics, graphical comm) |
| EMS | 10 | budgetBuilder (budgets, needs/wants, savings, entrepreneur), tugOfWar (money calculations, interest), adventureJourney (production, poverty/inequality) |
| Natural Sciences | 12 | explorerMap (periodic table, solar system already exist — expand), adventureJourney (biodiversity, reproduction, ecology, micro-organisms), sequenceBuilder (food chains, water treatment, life cycles) |
| Social Sciences — Geography | 8 | explorerMap (map skills, climate zones, SA resources, disaster response, population density) |
| Social Sciences — History | 8 | adventureJourney (Mali/Timbuktu narrative, slave trade, colonisation of the Cape, frontier conflict) |
| English FAL | 10 | runnerCollector (grammar, vocabulary, figurative language), sequenceBuilder (story reconstruction, essay structure), adventureJourney (comprehension, visual texts, dialogue missions) |

Each entry follows the existing `GameCatalogEntry` shape: id, title, description, grades, subject, engineType, emoji, color, difficulty, xpReward, coinsReward, isFeatured, extras.

---

## Sub-project D: Testing & Production Readiness

**Goal:** Automated test coverage for critical paths, production build configuration, and complete developer documentation.

### D1 — Widget & Integration Tests

**Test files:**
```
test/
  auth/
    login_routing_test.dart          — learner/parent/teacher login → correct dashboard
  leaderboard/
    leaderboard_repository_test.dart — mock Firestore, verify grade/class stream shapes
  missions/
    mission_provider_test.dart       — tier priority logic (teacher > adaptive > curated)
    mission_xp_bonus_test.dart       — 1.5× XP awarded on mission completion
  games/
    circuit_builder_engine_test.dart — series circuit validation, parallel circuit validation
    budget_builder_engine_test.dart  — rubric scoring (all needs met, savings < 10%, etc.)
  parent/
    parent_link_test.dart            — link request → approve → child appears in dashboard
  analytics/
    chart_data_test.dart             — ParentRepository.getWeeklyTrend returns correct shape
integration_test/
  offline_sync_test.dart             — complete game offline → reconnect → progress saved to Firestore
```

**Coverage target:** All business logic in engines and repositories. UI widget tests for DailyMissionsCard, LeaderboardScreen, CircuitBuilderGame happy path.

### D2 — Production Build Configuration

**Android:**
- `android/key.properties` (gitignored): `storeFile`, `storePassword`, `keyAlias`, `keyPassword`
- `android/app/build.gradle.kts`: release signing config reads from `key.properties`
- Update `applicationId` if needed for Play Store

**iOS:**
- `ios/ExportOptions.plist`: `method = app-store`, `teamID` placeholder
- Provisioning profile and cert configured in Xcode (documented, not automated)

**Firebase:**
- `firebase.json` emulator config for local test runs
- `firestore.indexes.json` updated with all new composite indexes:
  - `leaderboards/{grade}/weekly`: `(xp DESC)`
  - `daily_missions/{uid}/today`: `(expiresAt ASC)`
  - `progress`: `(childUid ASC, completedAt DESC)`

### D3 — Documentation

**Updated files:**
```
README.md                    — architecture diagram (ASCII), environment setup, build commands
docs/ENVIRONMENT_SETUP.md    — .env files, Firebase Secret Manager, local emulator setup
docs/ARCHITECTURE.md         — layer diagram, provider graph, game engine extension guide
docs/CURRICULUM_MAPPING.md   — how CAPS topics map to game engines and catalog entries
docs/DEPLOYMENT.md           — Android Play Store, iOS App Store, Firebase deploy steps
```

---

## Firestore Collections Summary (new in this upgrade)

| Collection | Purpose | Writer | Reader |
|---|---|---|---|
| `leaderboards/{grade}/{period}` | Grade XP rankings | Cloud Function | Learner (own grade) |
| `class_leaderboards/{teacherUid}` | Class XP rankings | Cloud Function | Learner (if teacher linked) |
| `daily_missions/{uid}/today` | Today's 3 missions | Cloud Function | Learner (own) |
| `daily_missions/{uid}/assigned` | Teacher-set missions | Teacher | Cloud Function |

---

## Security Rules Summary (additions)

```javascript
// leaderboards — public read within own grade
match /leaderboards/{grade}/{period}/{doc} {
  allow read: if isSignedIn();
  allow write: if false; // Cloud Function only
}

// daily_missions — learner reads own; teacher writes assigned
match /daily_missions/{uid}/{sub}/{doc} {
  allow read: if isUser(uid);
  allow write: if sub == 'assigned' && isTeacher();
}
```

---

## Execution Order

```
Sub-project A  →  Sub-project B  →  Sub-project C  →  Sub-project D
   Foundation        Analytics        New Engines         Ship-ready
   (security,        (fl_chart        (CircuitBuilder,    (tests, signing,
   leaderboard,      dashboards,      BudgetBuilder,      docs)
   missions)         AI insights,     Grade 7 catalog)
                     export)
```

Each sub-project ends with `flutter analyze` passing clean and a tagged commit.

---

*Spec written 2026-06-22. Approved by product owner.*
