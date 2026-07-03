# QuestKids — Architecture Overview

## Stack

| Layer | Technology |
|---|---|
| Frontend | Flutter 3.4+, Dart, Provider |
| Backend | Firebase (Auth, Firestore, Storage, Functions, Messaging) |
| AI | Google Gemini 2.5 Flash (via Cloud Functions proxy) |
| Analytics | fl_chart 0.68+ |
| Charts | fl_chart 0.68+ |

## Frontend Architecture

```
lib/
├── core/
│   ├── constants/          # AppConstants, GameCatalog
│   ├── services/           # GeminiService (CF client), AuthService
│   └── theme/              # AppColors, AppTextStyles, ThemeProvider
├── data/
│   ├── models/             # UserModel, DailyMission, LeaderboardEntry, ...
│   └── repositories/       # ParentRepo, TeacherRepo, GameRepo, ...
├── features/
│   ├── auth/               # LoginScreen, SplashScreen
│   ├── dashboard/          # LearnerDashboard, ParentDashboard, TeacherDashboard
│   ├── games/              # 8 game engines (core/ pattern)
│   ├── parent/             # Analytics charts, ChildAnalyticsScreen
│   ├── rewards/            # LeaderboardScreen, RewardsScreen
│   └── teacher/            # ClassAnalyticsScreen, 5 chart widgets
└── providers/              # AuthProvider, ParentProvider, MissionProvider
```

## Game Engine Architecture

Each engine follows a 3-layer pattern:
```
*Game (StatefulWidget)
  └── *Session (GameSessionState — ChangeNotifier)
        └── *Engine (GameEngine — pure rules, no Flutter)
```

### Engines

| Constant | Engine | Subjects |
|---|---|---|
| `tugOfWar` | TugOfWarGame | Math, Science, English |
| `adventureJourney` | AdventureJourneyGame | All subjects |
| `runnerCollector` | GrammarHeroRun | English, Science |
| `explorerMap` | ProvinceExplorer | Geography, Social Sciences |
| `multiplesMerge` | MultiplesMergeGame | Mathematics |
| `sequenceBuilder` | SequenceBuilderGame | History, Technology |
| `circuitBuilder` | CircuitBuilderGame | Technology (Grade 7) |
| `budgetBuilder` | BudgetBuilderGame | EMS (Grade 7) |

## Cloud Functions

All functions are in `functions/src/` and exported from `index.ts`.

| Function | Trigger | Purpose |
|---|---|---|
| `questyChat` | HTTPS onCall | Questy AI chat |
| `analyzeImage` | HTTPS onCall | Image analysis |
| `getRecommendation` | HTTPS onCall | Personalised learning recommendation |
| `explainAnswer` | HTTPS onCall | Quiz answer explanation |
| `generateHint` | HTTPS onCall | Quiz hint generator |
| `getTeacherInsight` | HTTPS onCall | AI class analytics insight |
| `refreshLeaderboards` | Scheduled (01:00 SAST) | Refresh all leaderboard rankings |
| `generateDailyMissions` | Scheduled (00:00 SAST) | Generate 3 daily missions per learner |
| `sendEmail` | Firestore onCreate | Send transactional emails |
| `cleanupOldEmails` | Scheduled (02:00 SAST) | Delete email records older than 30 days |

## Security

- Gemini API key lives **only** in Firebase Secret Manager (production) and `functions/.env` (local)
- Flutter client never touches the API key — all AI calls go through Cloud Functions
- Firestore rules enforce role-based access (learner, parent, teacher)
- `functions/.env` and `android/key.properties` are gitignored

## Data Model (Firestore)

```
users/{uid}               — UserModel (role, grade, linkedTeacherUid, ...)
game_sessions/{id}        — completed game session with score, xp, subject
progress/{id}             — activity progress (for parent verification)
rewards/{uid}             — totalPoints, totalCoins, streakDays
leaderboards/{grade}/weekly/{uid}  — weekly XP rank
leaderboards/{grade}/allTime/{uid} — all-time XP rank
daily_missions/{uid}/today/missions — 3 daily missions
daily_missions/{uid}/assigned/{id}  — teacher-assigned missions
```
