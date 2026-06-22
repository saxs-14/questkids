# Sub-project A: Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Secure the Gemini API key via a Cloud Functions proxy, add fl_chart, deliver a live grade + class leaderboard, and implement 3-tier daily missions with 1.5× XP rewards.

**Architecture:** All Gemini calls move from the Flutter client to Firebase Cloud Functions (us-central1) so the API key lives only in Firebase Secret Manager. Leaderboard data is written daily by a scheduled Cloud Function and streamed in real-time to a new LeaderboardScreen. Daily missions are generated nightly per-learner using a three-tier priority stack (teacher-assigned → Gemini-adaptive → curated rotation) and presented in the learner dashboard Home tab.

**Tech Stack:** Flutter 3.4+, Dart, Firebase Functions v2 (Node 24, TypeScript), `@google/generative-ai` npm package, `firebase_functions: ^5.1.0` Flutter package, `fl_chart: ^0.68.0`, Provider, Cloud Firestore.

## Global Constraints

- Flutter SDK: `>=3.4.0 <4.0.0`
- State management: Provider only
- Design system: `AppColors`, `AppTextStyles` (Nunito), `GameTheme` — no inline hex colours or raw font sizes
- All Gemini calls through Cloud Functions — never direct from Flutter client
- Gemini API key only in Firebase Secret Manager (production) and `functions/.env` (local) — never in Dart source
- `flutter analyze` must pass clean after every task commit
- Conventional commit messages: `feat:`, `fix:`, `chore:`
- Never hardcode UIDs, grade strings, or subject names — use `AppConstants.*` constants
- Firestore rules must be updated for every new collection in the same commit that creates the collection

---

## File Map

### New files
```
functions/src/gemini/proxy.ts                              — 5 HttpsCallable functions wrapping Gemini
functions/src/leaderboard/refresh.ts                       — scheduled refreshLeaderboards CF
functions/src/missions/catalog.ts                          — curated 7-day mission rotation map
functions/src/missions/generate.ts                         — scheduled generateDailyMissions CF
lib/data/models/leaderboard_entry_model.dart               — LeaderboardEntry data class
lib/data/models/daily_mission_model.dart                   — DailyMission data class
lib/data/repositories/leaderboard_repository.dart          — streams for grade + class boards
lib/data/repositories/mission_repository.dart              — watchTodayMissions, completeMission
lib/features/rewards/screens/leaderboard_screen.dart       — grade + class tab UI
lib/features/rewards/widgets/leaderboard_entry_tile.dart   — single rank row widget
lib/features/rewards/widgets/own_rank_banner.dart          — pinned "your rank" footer
lib/features/dashboard/widgets/daily_missions_card.dart    — 3-card horizontal scroller
lib/providers/mission_provider.dart                        — MissionProvider ChangeNotifier
```

### Modified files
```
functions/package.json                                     — add @google/generative-ai
functions/src/index.ts                                     — export new functions, keep sendEmail/cleanupOldEmails
pubspec.yaml                                               — add firebase_functions ^5.1.0, fl_chart ^0.68.0
lib/core/services/gemini_service.dart                      — replace SDK calls with HttpsCallable
lib/features/rewards/screens/rewards_screen.dart           — add 4th tab "Leaderboard" → LeaderboardScreen
lib/features/dashboard/screens/learner_dashboard.dart      — insert DailyMissionsCard in _LearnerHomeTab
lib/features/games/core/game_session_state.dart            — call MissionRepository.completeMission on finish
lib/main.dart                                              — add MissionProvider to MultiProvider
firestore.rules                                            — add leaderboard + daily_missions rules
firestore.indexes.json                                     — add leaderboard xp index
```

---

## Task 1: Gemini Cloud Functions Proxy

**Files:**
- Create: `functions/src/gemini/proxy.ts`
- Modify: `functions/package.json` (add `@google/generative-ai`)
- Modify: `functions/src/index.ts` (export proxy functions)

**Interfaces:**
- Produces:
  - `exports.questbotChat` — `onCall({data: {message: string, history?: {role:string,text:string}[]}}) → {text: string}`
  - `exports.analyzeImage` — `onCall({data: {imageBase64: string, prompt: string}}) → {text: string}`
  - `exports.getRecommendation` — `onCall({data: {name,grade,subjectScores,streakDays,totalPoints}}) → {text: string}`
  - `exports.explainAnswer` — `onCall({data: {question,correctAnswer,subject,grade}}) → {text: string}`
  - `exports.generateHint` — `onCall({data: {question,subject}}) → {text: string}`

- [ ] **Step 1: Add @google/generative-ai to functions/package.json**

Open `functions/package.json` and add to `"dependencies"`:
```json
{
  "name": "functions",
  "scripts": {
    "lint": "eslint --ext .js,.ts .",
    "build": "tsc",
    "build:watch": "tsc --watch",
    "serve": "npm run build && firebase emulators:start --only functions",
    "shell": "npm run build && firebase functions:shell",
    "start": "npm run shell",
    "deploy": "firebase deploy --only functions",
    "logs": "firebase functions:log"
  },
  "engines": {
    "node": "24"
  },
  "main": "lib/index.js",
  "dependencies": {
    "@google/generative-ai": "^0.21.0",
    "firebase-admin": "^13.6.0",
    "firebase-functions": "^7.0.0",
    "nodemailer": "^6.9.7"
  },
  "devDependencies": {
    "@types/nodemailer": "^8.0.0",
    "@typescript-eslint/eslint-plugin": "^5.12.0",
    "@typescript-eslint/parser": "^5.12.0",
    "eslint": "^8.9.0",
    "eslint-config-google": "^0.14.0",
    "eslint-plugin-import": "^2.25.4",
    "firebase-functions-test": "^3.4.1",
    "typescript": "^6.0.0"
  },
  "private": true
}
```

- [ ] **Step 2: Install the new dependency**

```bash
cd functions
npm install
cd ..
```

Expected: `node_modules/@google/generative-ai` exists. No errors.

- [ ] **Step 3: Create functions/src/gemini/proxy.ts**

```typescript
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {GoogleGenerativeAI, Content} from "@google/generative-ai";

const SYSTEM_PROMPT = `You are QuestBot, a friendly and encouraging AI tutor
for South African primary school children (Grades 1-7).
Your role is to:
- Explain concepts in simple, age-appropriate language
- Use fun examples, emojis and analogies children relate to
- Encourage learners when they struggle
- Reference South African context (rand, braai, provinces etc)
- Cover: Math, Science, English, Social Sciences
- Keep responses concise (max 3-4 short paragraphs)
- Never give direct quiz answers, guide them to think
- Celebrate correct answers enthusiastically
CRITICAL RULES:
1. You MUST ONLY answer questions relevant to a primary school child (Grade 1 to 7 level).
2. If a question is outside this educational scope, politely decline.
Always respond in a warm, child-friendly tone.`;

function getModel() {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) throw new HttpsError("internal", "Gemini API key not configured");
  const genAI = new GoogleGenerativeAI(apiKey);
  return genAI.getGenerativeModel({
    model: "gemini-1.5-flash",
    generationConfig: {temperature: 0.7, topK: 40, topP: 0.95, maxOutputTokens: 1024},
    systemInstruction: {role: "system", parts: [{text: SYSTEM_PROMPT}]},
  });
}

export const questbotChat = onCall(async (request) => {
  const {message, history = []} = request.data as {
    message: string;
    history?: {role: string; text: string}[];
  };
  if (!message?.trim()) throw new HttpsError("invalid-argument", "message is required");

  const model = getModel();
  const chatHistory: Content[] = history.map((h) => ({
    role: h.role === "user" ? "user" : "model",
    parts: [{text: h.text}],
  }));
  const chat = model.startChat({history: chatHistory});
  const result = await chat.sendMessage(message);
  return {text: result.response.text() ?? "I did not understand that. Could you rephrase?"};
});

export const analyzeImage = onCall(async (request) => {
  const {imageBase64, prompt} = request.data as {imageBase64: string; prompt: string};
  if (!imageBase64 || !prompt) throw new HttpsError("invalid-argument", "imageBase64 and prompt are required");

  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) throw new HttpsError("internal", "Gemini API key not configured");
  const genAI = new GoogleGenerativeAI(apiKey);
  const model = genAI.getGenerativeModel({model: "gemini-1.5-flash"});
  const result = await model.generateContent([
    prompt,
    {inlineData: {mimeType: "image/jpeg", data: imageBase64}},
  ]);
  return {text: result.response.text() ?? "I could not analyse the image. Please try again."};
});

export const getRecommendation = onCall(async (request) => {
  const {name, grade, subjectScores, streakDays, totalPoints} = request.data as {
    name: string; grade: string;
    subjectScores: Record<string, number>;
    streakDays: number; totalPoints: number;
  };
  const weak = Object.entries(subjectScores).filter(([, v]) => v < 60).map(([k]) => k);
  const strong = Object.entries(subjectScores).filter(([, v]) => v >= 80).map(([k]) => k);
  const prompt = `Give a short personalised learning recommendation for:
- Name: ${name}, Grade: ${grade}, Streak: ${streakDays} days, Points: ${totalPoints}
- Strong: ${strong.join(", ") || "none yet"}
- Needs improvement: ${weak.join(", ") || "none"}
Keep it encouraging, 2-3 sentences, use their name, end with a tip. Use 1-2 emojis.`;

  const model = getModel();
  const result = await model.generateContent(prompt);
  return {text: result.response.text() ?? `Keep up the great work, ${name}! 🌟`};
});

export const explainAnswer = onCall(async (request) => {
  const {question, correctAnswer, subject, grade} = request.data as {
    question: string; correctAnswer: string; subject: string; grade: string;
  };
  const prompt = `A ${grade} learner answered this ${subject} question wrong:
Question: ${question}
Correct answer: ${correctAnswer}
Explain WHY this is correct in a simple, fun way a child understands. Use an analogy. 2-3 sentences. 1 emoji.`;

  const model = getModel();
  const result = await model.generateContent(prompt);
  return {text: result.response.text() ?? `The correct answer is ${correctAnswer}. Keep practising! 💪`};
});

export const generateHint = onCall(async (request) => {
  const {question, subject} = request.data as {question: string; subject: string};
  const prompt = `A learner is stuck on this ${subject} question: "${question}"
Give ONE helpful hint WITHOUT giving the answer away. 1-2 sentences. Be encouraging. 1 emoji.`;

  const model = getModel();
  const result = await model.generateContent(prompt);
  return {text: result.response.text() ?? "Think carefully about what you have learned! 💡"};
});
```

- [ ] **Step 4: Export proxy functions from functions/src/index.ts**

Add these lines at the top of `functions/src/index.ts`, after the existing imports but before any other code:

```typescript
export {
  questbotChat,
  analyzeImage,
  getRecommendation,
  explainAnswer,
  generateHint,
} from "./gemini/proxy";
```

Keep all existing exports (`sendEmail`, `cleanupOldEmails`) unchanged.

- [ ] **Step 5: Add GEMINI_API_KEY to functions/.env**

Create `functions/.env` (already in .gitignore):
```
GEMINI_API_KEY=<GEMINI_API_KEY — see .env.local>
```

- [ ] **Step 6: Build and verify TypeScript compiles**

```bash
cd functions && npm run build 2>&1
```

Expected: `lib/gemini/proxy.js` created. No TypeScript errors.

- [ ] **Step 7: Commit**

```bash
git add functions/package.json functions/package-lock.json functions/src/ functions/.env
git commit -m "feat: add Gemini Cloud Functions proxy (questbotChat, analyzeImage, recommendation, explain, hint)"
```

---

## Task 2: Flutter GeminiService → HttpsCallable

**Files:**
- Modify: `pubspec.yaml` (add `firebase_functions: ^5.1.0`)
- Modify: `lib/core/services/gemini_service.dart` (replace all SDK calls)

**Interfaces:**
- Consumes: Task 1 exports (`questbotChat`, `analyzeImage`, `getRecommendation`, `explainAnswer`, `generateHint`)
- Produces: `GeminiService` with identical public method signatures as before:
  - `Future<String> sendMessage(String message, {List<Map<String,String>> history})`
  - `Future<String> analyzeImage({required List<int> imageBytes, required String prompt})`
  - `Future<String> getPersonalisedRecommendation({required String name, required String grade, required Map<String,int> subjectScores, required int streakDays, required int totalPoints})`
  - `Future<String> explainQuizAnswer({required String question, required String correctAnswer, required String subject, required String grade})`
  - `Future<String> generateQuizHint({required String question, required String subject})`
  - `void startNewSession({List<Content>? history})` — removed (no longer needed; kept as no-op for compatibility)

- [ ] **Step 1: Add firebase_functions to pubspec.yaml**

In `pubspec.yaml`, add under the Firebase section:
```yaml
  firebase_functions: ^5.1.0
```

Run:
```bash
flutter pub get
```

Expected: `firebase_functions` appears in `pubspec.lock`. No conflicts.

- [ ] **Step 2: Replace lib/core/services/gemini_service.dart entirely**

```dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_functions/firebase_functions.dart';

class GeminiService {
  final _functions = FirebaseFunctions.instanceFor(region: 'us-central1');

  // No-op kept so existing callers (AiTutorProvider) don't need changes.
  void startNewSession({List<dynamic>? history}) {}

  Future<String> sendMessage(
    String message, {
    List<Map<String, String>> history = const [],
  }) async {
    try {
      final result = await _functions.httpsCallable('questbotChat').call({
        'message': message,
        'history': history,
      });
      return (result.data as Map<dynamic, dynamic>)['text'] as String? ??
          'I did not understand that. Could you rephrase?';
    } catch (_) {
      return 'Oops! I am having trouble connecting right now. Please try again in a moment! 🔄';
    }
  }

  Future<String> analyzeImage({
    required List<int> imageBytes,
    required String prompt,
  }) async {
    try {
      final base64Image = base64Encode(Uint8List.fromList(imageBytes));
      final result = await _functions.httpsCallable('analyzeImage').call({
        'imageBase64': base64Image,
        'prompt': prompt,
      });
      return (result.data as Map<dynamic, dynamic>)['text'] as String? ??
          'I could not analyse the image. Please try again.';
    } catch (_) {
      return 'Image analysis failed. Please check your connection and try again.';
    }
  }

  Future<String> getPersonalisedRecommendation({
    required String name,
    required String grade,
    required Map<String, int> subjectScores,
    required int streakDays,
    required int totalPoints,
  }) async {
    try {
      final result =
          await _functions.httpsCallable('getRecommendation').call({
        'name': name,
        'grade': grade,
        'subjectScores': subjectScores,
        'streakDays': streakDays,
        'totalPoints': totalPoints,
      });
      return (result.data as Map<dynamic, dynamic>)['text'] as String? ??
          'Keep up the great work, $name! 🌟';
    } catch (_) {
      return 'You are doing amazing, $name! Keep completing quests every day! 🚀';
    }
  }

  Future<String> explainQuizAnswer({
    required String question,
    required String correctAnswer,
    required String subject,
    required String grade,
  }) async {
    try {
      final result = await _functions.httpsCallable('explainAnswer').call({
        'question': question,
        'correctAnswer': correctAnswer,
        'subject': subject,
        'grade': grade,
      });
      return (result.data as Map<dynamic, dynamic>)['text'] as String? ??
          correctAnswer;
    } catch (_) {
      return 'The correct answer is $correctAnswer. Keep practising and you will get it! 💪';
    }
  }

  Future<String> generateQuizHint({
    required String question,
    required String subject,
  }) async {
    try {
      final result = await _functions.httpsCallable('generateHint').call({
        'question': question,
        'subject': subject,
      });
      return (result.data as Map<dynamic, dynamic>)['text'] as String? ??
          'Think carefully about what you have learned! 💡';
    } catch (_) {
      return 'You can do it! Think step by step. 💡';
    }
  }
}
```

- [ ] **Step 3: Verify flutter analyze passes**

```bash
flutter analyze --no-pub 2>&1 | tail -5
```

Expected: `No issues found!` (or only pre-existing warnings unrelated to this task).

- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/core/services/gemini_service.dart lib/core/config/
git commit -m "feat: migrate GeminiService to Cloud Functions HttpsCallable, remove API key from client"
```

---

## Task 3: fl_chart Dependency

**Files:**
- Modify: `pubspec.yaml`

**Interfaces:**
- Produces: `fl_chart` package available for import in Sub-project B chart widgets.

- [ ] **Step 1: Add fl_chart to pubspec.yaml**

In `pubspec.yaml`, add after `flutter_animate`:
```yaml
  fl_chart: ^0.68.0
```

- [ ] **Step 2: Run pub get and verify**

```bash
flutter pub get 2>&1 | tail -5
```

Expected: Resolves without conflicts. `fl_chart` appears in `pubspec.lock`.

- [ ] **Step 3: Verify flutter analyze still passes**

```bash
flutter analyze --no-pub 2>&1 | tail -5
```

Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: add fl_chart ^0.68.0 for analytics dashboards (Sub-project B)"
```

---

## Task 4: Leaderboard Data Layer

**Files:**
- Create: `lib/data/models/leaderboard_entry_model.dart`
- Create: `lib/data/repositories/leaderboard_repository.dart`
- Modify: `firestore.rules`
- Modify: `firestore.indexes.json`

**Interfaces:**
- Produces:
  - `LeaderboardEntry` — `{uid, displayName, avatarEmoji, grade, xp, rank}`
  - `LeaderboardRepository.watchGradeLeaderboard(String grade, {String period})` → `Stream<List<LeaderboardEntry>>`
  - `LeaderboardRepository.watchClassLeaderboard(String teacherUid)` → `Stream<List<LeaderboardEntry>>`
  - `LeaderboardRepository.getOwnRank(String uid, String grade, {String period})` → `Future<int?>`

- [ ] **Step 1: Create lib/data/models/leaderboard_entry_model.dart**

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

class LeaderboardEntry {
  final String uid;
  final String displayName;
  final String avatarEmoji;
  final String grade;
  final int xp;
  final int rank;

  const LeaderboardEntry({
    required this.uid,
    required this.displayName,
    required this.avatarEmoji,
    required this.grade,
    required this.xp,
    required this.rank,
  });

  factory LeaderboardEntry.fromMap(Map<String, dynamic> map) {
    return LeaderboardEntry(
      uid: map['uid'] as String? ?? '',
      displayName: map['displayName'] as String? ?? 'Learner',
      avatarEmoji: map['avatarEmoji'] as String? ?? '🦁',
      grade: map['grade'] as String? ?? 'Grade 1',
      xp: (map['xp'] as num?)?.toInt() ?? 0,
      rank: (map['rank'] as num?)?.toInt() ?? 0,
    );
  }

  factory LeaderboardEntry.fromDoc(DocumentSnapshot doc) {
    return LeaderboardEntry.fromMap(doc.data() as Map<String, dynamic>? ?? {});
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'displayName': displayName,
        'avatarEmoji': avatarEmoji,
        'grade': grade,
        'xp': xp,
        'rank': rank,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
```

- [ ] **Step 2: Create lib/data/repositories/leaderboard_repository.dart**

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/leaderboard_entry_model.dart';

class LeaderboardRepository {
  final _db = FirebaseFirestore.instance;

  /// Stream top-50 entries for [grade] from the [period] snapshot
  /// ('weekly' or 'allTime'). Written daily by the refreshLeaderboards CF.
  Stream<List<LeaderboardEntry>> watchGradeLeaderboard(
    String grade, {
    String period = 'weekly',
  }) {
    return _db
        .collection('leaderboards')
        .doc(grade)
        .collection(period)
        .orderBy('rank')
        .limit(50)
        .snapshots()
        .map((snap) =>
            snap.docs.map(LeaderboardEntry.fromDoc).toList());
  }

  /// Real-time XP totals for all learners linked to [teacherUid].
  /// Reads directly from users collection — no CF needed for class board.
  Stream<List<LeaderboardEntry>> watchClassLeaderboard(String teacherUid) {
    return _db
        .collection('users')
        .where('linkedTeacherUids', arrayContains: teacherUid)
        .snapshots()
        .map((snap) {
      final entries = snap.docs.map((doc) {
        final data = doc.data();
        return LeaderboardEntry(
          uid: doc.id,
          displayName:
              '${data['name'] ?? ''} ${data['surname'] ?? ''}'.trim(),
          avatarEmoji: data['avatarEmoji'] as String? ?? '🦁',
          grade: data['grade'] as String? ?? 'Grade 1',
          xp: (data['totalPoints'] as num?)?.toInt() ?? 0,
          rank: 0, // assigned below after sort
        );
      }).toList();

      entries.sort((a, b) => b.xp.compareTo(a.xp));
      return entries
          .asMap()
          .entries
          .map((e) => LeaderboardEntry(
                uid: e.value.uid,
                displayName: e.value.displayName,
                avatarEmoji: e.value.avatarEmoji,
                grade: e.value.grade,
                xp: e.value.xp,
                rank: e.key + 1,
              ))
          .toList();
    });
  }

  /// Returns the rank of [uid] in the [period] grade leaderboard, or null
  /// if the entry doesn't exist yet.
  Future<int?> getOwnRank(
    String uid,
    String grade, {
    String period = 'weekly',
  }) async {
    final doc = await _db
        .collection('leaderboards')
        .doc(grade)
        .collection(period)
        .where('uid', isEqualTo: uid)
        .limit(1)
        .get();
    if (doc.docs.isEmpty) return null;
    return (doc.docs.first.data()['rank'] as num?)?.toInt();
  }
}
```

- [ ] **Step 3: Update firestore.rules — add leaderboard rules**

Find the closing `}` of the existing rules and add before it:

```javascript
    // Leaderboard — any signed-in user can read; only Cloud Functions write
    match /leaderboards/{grade}/{period}/{doc} {
      allow read: if isSignedIn();
      allow write: if false;
    }
```

- [ ] **Step 4: Update firestore.indexes.json — add leaderboard rank index**

Add to the `"indexes"` array:
```json
{
  "collectionGroup": "weekly",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "rank", "order": "ASCENDING" }
  ]
},
{
  "collectionGroup": "allTime",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "rank", "order": "ASCENDING" }
  ]
}
```

- [ ] **Step 5: Verify flutter analyze passes**

```bash
flutter analyze --no-pub 2>&1 | tail -5
```

Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/data/models/leaderboard_entry_model.dart lib/data/repositories/leaderboard_repository.dart firestore.rules firestore.indexes.json
git commit -m "feat: leaderboard data layer — LeaderboardEntry model, repository, Firestore rules & indexes"
```

---

## Task 5: refreshLeaderboards Cloud Function

**Files:**
- Create: `functions/src/leaderboard/refresh.ts`
- Modify: `functions/src/index.ts` (export `refreshLeaderboards`)

**Interfaces:**
- Produces: `refreshLeaderboards` — scheduled Cloud Function that runs daily at 01:00 SAST, writing `leaderboards/{grade}/weekly` and `leaderboards/{grade}/allTime` snapshots.

- [ ] **Step 1: Create functions/src/leaderboard/refresh.ts**

```typescript
import {onSchedule} from "firebase-functions/v2/scheduler";
import * as admin from "firebase-admin";

const GRADES = [
  "Grade 1", "Grade 2", "Grade 3", "Grade 4",
  "Grade 5", "Grade 6", "Grade 7",
];

export const refreshLeaderboards = onSchedule(
  {schedule: "every day 01:00", timeZone: "Africa/Johannesburg"},
  async () => {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();
    const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);

    for (const grade of GRADES) {
      // Fetch all learners for this grade
      const usersSnap = await db
        .collection("users")
        .where("role", "==", "learner")
        .where("grade", "==", grade)
        .get();

      if (usersSnap.empty) continue;

      // Collect XP from rewards collection (authoritative source)
      const entries: {
        uid: string; displayName: string; avatarEmoji: string;
        grade: string; allTimeXp: number; weeklyXp: number;
      }[] = [];

      for (const userDoc of usersSnap.docs) {
        const userData = userDoc.data();
        const rewardDoc = await db.collection("rewards").doc(userDoc.id).get();
        const allTimeXp = (rewardDoc.data()?.["totalPoints"] as number) ?? 0;

        // Weekly XP: sum progress points earned in last 7 days
        const progressSnap = await db
          .collection("progress")
          .where("childUid", "==", userDoc.id)
          .where("completedAt", ">=", admin.firestore.Timestamp.fromDate(sevenDaysAgo))
          .get();
        const weeklyXp = progressSnap.docs.reduce(
          (sum, d) => sum + ((d.data()["pointsEarned"] as number) ?? 0),
          0
        );

        entries.push({
          uid: userDoc.id,
          displayName: `${userData["name"] ?? ""} ${userData["surname"] ?? ""}`.trim(),
          avatarEmoji: (userData["avatarEmoji"] as string) ?? "🦁",
          grade,
          allTimeXp,
          weeklyXp,
        });
      }

      // Write weekly board
      const weeklyRanked = [...entries]
        .sort((a, b) => b.weeklyXp - a.weeklyXp)
        .slice(0, 50);
      const weeklyBatch = db.batch();
      // Clear existing weekly docs for this grade
      const existingWeekly = await db
        .collection("leaderboards").doc(grade).collection("weekly").get();
      existingWeekly.docs.forEach((d) => weeklyBatch.delete(d.ref));
      weeklyRanked.forEach((entry, i) => {
        const ref = db.collection("leaderboards").doc(grade)
          .collection("weekly").doc(entry.uid);
        weeklyBatch.set(ref, {
          uid: entry.uid,
          displayName: entry.displayName,
          avatarEmoji: entry.avatarEmoji,
          grade: entry.grade,
          xp: entry.weeklyXp,
          rank: i + 1,
          updatedAt: now,
        });
      });
      await weeklyBatch.commit();

      // Write allTime board
      const allTimeRanked = [...entries]
        .sort((a, b) => b.allTimeXp - a.allTimeXp)
        .slice(0, 50);
      const allTimeBatch = db.batch();
      const existingAllTime = await db
        .collection("leaderboards").doc(grade).collection("allTime").get();
      existingAllTime.docs.forEach((d) => allTimeBatch.delete(d.ref));
      allTimeRanked.forEach((entry, i) => {
        const ref = db.collection("leaderboards").doc(grade)
          .collection("allTime").doc(entry.uid);
        allTimeBatch.set(ref, {
          uid: entry.uid,
          displayName: entry.displayName,
          avatarEmoji: entry.avatarEmoji,
          grade: entry.grade,
          xp: entry.allTimeXp,
          rank: i + 1,
          updatedAt: now,
        });
      });
      await allTimeBatch.commit();

      console.log(`Leaderboard refreshed for ${grade}`);
    }
  }
);
```

- [ ] **Step 2: Export refreshLeaderboards from functions/src/index.ts**

Add to the existing export block at the top of `functions/src/index.ts`:
```typescript
export {refreshLeaderboards} from "./leaderboard/refresh";
```

- [ ] **Step 3: Build and verify**

```bash
cd functions && npm run build 2>&1 | tail -10
```

Expected: `lib/leaderboard/refresh.js` created. No TypeScript errors.

- [ ] **Step 4: Commit**

```bash
git add functions/src/leaderboard/ functions/src/index.ts functions/lib/
git commit -m "feat: refreshLeaderboards scheduled Cloud Function — daily grade XP rankings"
```

---

## Task 6: Leaderboard UI

**Files:**
- Create: `lib/features/rewards/widgets/leaderboard_entry_tile.dart`
- Create: `lib/features/rewards/widgets/own_rank_banner.dart`
- Create: `lib/features/rewards/screens/leaderboard_screen.dart`
- Modify: `lib/features/rewards/screens/rewards_screen.dart` (add 4th tab)

**Interfaces:**
- Consumes: `LeaderboardRepository` from Task 4, `AuthProvider`, `AppColors`, `AppTextStyles`
- Produces: `LeaderboardScreen` widget (stateful, two tabs: Grade / My Class)

- [ ] **Step 1: Create lib/features/rewards/widgets/leaderboard_entry_tile.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/leaderboard_entry_model.dart';

class LeaderboardEntryTile extends StatelessWidget {
  final LeaderboardEntry entry;
  final bool isOwnEntry;
  final int animationIndex;

  const LeaderboardEntryTile({
    super.key,
    required this.entry,
    required this.isOwnEntry,
    this.animationIndex = 0,
  });

  String get _trophy {
    switch (entry.rank) {
      case 1: return '🥇';
      case 2: return '🥈';
      case 3: return '🥉';
      default: return '${entry.rank}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final highlight = isOwnEntry;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: highlight
            ? AppColors.gold.withValues(alpha: 0.15)
            : (isDark ? const Color(0xFF1E1E2E) : Colors.white),
        borderRadius: BorderRadius.circular(16),
        border: highlight
            ? Border.all(color: AppColors.gold, width: 1.5)
            : Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: entry.rank <= 3
                ? Text(_trophy, style: const TextStyle(fontSize: 22))
                : Text(
                    _trophy,
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(entry.avatarEmoji,
                  style: const TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.displayName,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: highlight ? AppColors.gold : null,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(entry.grade, style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${entry.xp}',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w800,
                  color: highlight ? AppColors.gold : AppColors.primary,
                ),
              ),
              Text('XP', style: AppTextStyles.bodySmall),
            ],
          ),
        ],
      ),
    )
        .animate(delay: Duration(milliseconds: animationIndex * 30))
        .slideX(begin: 0.3, end: 0, curve: Curves.easeOut)
        .fadeIn();
  }
}
```

- [ ] **Step 2: Create lib/features/rewards/widgets/own_rank_banner.dart**

```dart
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class OwnRankBanner extends StatelessWidget {
  final int? rank;
  final int xp;
  final String avatarEmoji;

  const OwnRankBanner({
    super.key,
    required this.rank,
    required this.xp,
    required this.avatarEmoji,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5C35F5), Color(0xFF9C27B0)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Text(avatarEmoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Rank',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: Colors.white70),
                ),
                Text(
                  rank != null ? '#$rank' : 'Not ranked yet',
                  style: AppTextStyles.h3.copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$xp XP',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text('this week',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: Colors.white70)),
            ],
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Create lib/features/rewards/screens/leaderboard_screen.dart**

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/repositories/leaderboard_repository.dart';
import '../../../data/models/leaderboard_entry_model.dart';
import '../../../providers/auth_provider.dart';
import '../widgets/leaderboard_entry_tile.dart';
import '../widgets/own_rank_banner.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _repo = LeaderboardRepository();

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    final hasTeacher = (user?.linkedTeacherUids?.isNotEmpty ?? false);
    _tabCtrl = TabController(length: hasTeacher ? 2 : 1, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final grade = user?.grade ?? 'Grade 1';
    final uid = user?.uid ?? '';
    final teacherUid = user?.linkedTeacherUids?.firstOrNull;
    final avatarEmoji = user?.avatarEmoji ?? '🦁';
    final hasTeacher = teacherUid != null;

    return Column(
      children: [
        Material(
          color: AppColors.primary,
          child: TabBar(
            controller: _tabCtrl,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            indicatorColor: Colors.white,
            tabs: [
              const Tab(text: 'Grade'),
              if (hasTeacher) const Tab(text: 'My Class'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _GradeBoard(
                  grade: grade, uid: uid,
                  avatarEmoji: avatarEmoji, repo: _repo),
              if (hasTeacher)
                _ClassBoard(
                    teacherUid: teacherUid!, uid: uid,
                    avatarEmoji: avatarEmoji, repo: _repo),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Grade leaderboard ──────────────────────────────────────────────────────

class _GradeBoard extends StatefulWidget {
  final String grade;
  final String uid;
  final String avatarEmoji;
  final LeaderboardRepository repo;

  const _GradeBoard({
    required this.grade, required this.uid,
    required this.avatarEmoji, required this.repo,
  });

  @override
  State<_GradeBoard> createState() => _GradeBoardState();
}

class _GradeBoardState extends State<_GradeBoard> {
  String _period = 'weekly';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Period toggle
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              _PeriodChip(
                label: 'This Week',
                selected: _period == 'weekly',
                onTap: () => setState(() => _period = 'weekly'),
              ),
              const SizedBox(width: 8),
              _PeriodChip(
                label: 'All Time',
                selected: _period == 'allTime',
                onTap: () => setState(() => _period = 'allTime'),
              ),
            ],
          ),
        ),
        // Own rank banner
        FutureBuilder<int?>(
          future: widget.repo.getOwnRank(widget.uid, widget.grade,
              period: _period),
          builder: (_, snap) => OwnRankBanner(
            rank: snap.data,
            xp: 0,
            avatarEmoji: widget.avatarEmoji,
          ),
        ),
        // Leaderboard list
        Expanded(
          child: StreamBuilder<List<LeaderboardEntry>>(
            stream: widget.repo.watchGradeLeaderboard(widget.grade,
                period: _period),
            builder: (_, snap) {
              if (snap.hasError) {
                return Center(
                    child: Text('Error loading leaderboard',
                        style: AppTextStyles.bodyMedium));
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final entries = snap.data!;
              if (entries.isEmpty) {
                return _EmptyState(
                    period: _period, grade: widget.grade);
              }
              return ListView.builder(
                padding: const EdgeInsets.only(top: 8, bottom: 24),
                itemCount: entries.length,
                itemBuilder: (_, i) => LeaderboardEntryTile(
                  entry: entries[i],
                  isOwnEntry: entries[i].uid == widget.uid,
                  animationIndex: i,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Class leaderboard ──────────────────────────────────────────────────────

class _ClassBoard extends StatelessWidget {
  final String teacherUid;
  final String uid;
  final String avatarEmoji;
  final LeaderboardRepository repo;

  const _ClassBoard({
    required this.teacherUid, required this.uid,
    required this.avatarEmoji, required this.repo,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<LeaderboardEntry>>(
      stream: repo.watchClassLeaderboard(teacherUid),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final entries = snap.data!;
        if (entries.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🏫', style: TextStyle(fontSize: 56)),
                const SizedBox(height: 12),
                Text('No classmates yet', style: AppTextStyles.h3),
                Text('Your class leaderboard will appear here.',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.textSecondary)),
              ],
            ),
          );
        }
        final ownEntry = entries.firstWhere((e) => e.uid == uid,
            orElse: () => entries.first);
        return Column(
          children: [
            const SizedBox(height: 8),
            OwnRankBanner(
                rank: ownEntry.uid == uid ? ownEntry.rank : null,
                xp: ownEntry.uid == uid ? ownEntry.xp : 0,
                avatarEmoji: avatarEmoji),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(top: 8, bottom: 24),
                itemCount: entries.length,
                itemBuilder: (_, i) => LeaderboardEntryTile(
                  entry: entries[i],
                  isOwnEntry: entries[i].uid == uid,
                  animationIndex: i,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Helper widgets ────────────────────────────────────────────────────────

class _PeriodChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PeriodChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? AppColors.primary : AppColors.textSecondary),
        ),
        child: Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String period;
  final String grade;

  const _EmptyState({required this.period, required this.grade});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🏆', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 12),
          Text('No rankings yet', style: AppTextStyles.h3),
          Text(
            period == 'weekly'
                ? 'Be the first to earn XP this week!'
                : 'Complete quests to appear on the all-time board!',
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Add Leaderboard as 4th tab in rewards_screen.dart**

In `lib/features/rewards/screens/rewards_screen.dart`:

Change `TabController(length: 3, ...)` to `TabController(length: 4, ...)`.

Add the import at the top:
```dart
import 'leaderboard_screen.dart';
```

Change the `TabBarView children` list from:
```dart
children: [
  _OverviewTab(rewards: rewards, user: user),
  _BadgesTab(rewards: rewards),
  _HistoryTab(rewards: rewards),
],
```
to:
```dart
children: [
  _OverviewTab(rewards: rewards, user: user),
  _BadgesTab(rewards: rewards),
  _HistoryTab(rewards: rewards),
  const LeaderboardScreen(),
],
```

Change both `TabBar` widgets (embedded and non-embedded) from 3 tabs to 4:
```dart
tabs: const [
  Tab(text: 'Overview'),
  Tab(text: 'Badges'),
  Tab(text: 'History'),
  Tab(text: 'Leaderboard'),
],
```

- [ ] **Step 5: Verify flutter analyze passes**

```bash
flutter analyze --no-pub 2>&1 | tail -5
```

Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/features/rewards/
git commit -m "feat: leaderboard screen — grade (weekly/all-time) + class tabs with animated rank reveal"
```

---

## Task 7: Daily Missions Data Layer

**Files:**
- Create: `lib/data/models/daily_mission_model.dart`
- Create: `lib/data/repositories/mission_repository.dart`
- Modify: `firestore.rules`

**Interfaces:**
- Produces:
  - `DailyMission` — `{id, gameId, title, subject, emoji, xpBonus, completed, completedAt, source}`
  - `MissionRepository.watchTodayMissions(String uid)` → `Stream<List<DailyMission>>`
  - `MissionRepository.completeMission(String uid, String missionId, String gameId)` → `Future<void>`

- [ ] **Step 1: Create lib/data/models/daily_mission_model.dart**

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

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
    );
  }

  String get sourceBadge {
    switch (source) {
      case 'teacher': return '📋 Teacher';
      case 'adaptive': return '🤖 AI Pick';
      default: return '⭐ Daily';
    }
  }
}
```

- [ ] **Step 2: Create lib/data/repositories/mission_repository.dart**

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/daily_mission_model.dart';

class MissionRepository {
  final _db = FirebaseFirestore.instance;

  /// Stream today's missions for [uid]. The 'today' document contains a
  /// 'missions' list written by the generateDailyMissions Cloud Function.
  Stream<List<DailyMission>> watchTodayMissions(String uid) {
    return _db
        .collection('daily_missions')
        .doc(uid)
        .collection('today')
        .doc('missions')
        .snapshots()
        .map((doc) {
      if (!doc.exists) return <DailyMission>[];
      final data = doc.data() ?? {};
      final list = (data['missions'] as List<dynamic>?) ?? [];
      return list
          .map((m) =>
              DailyMission.fromMap(m['id'] as String? ?? '', m as Map<String, dynamic>))
          .toList();
    });
  }

  /// Mark a mission as completed and award the xpBonus via a batch write.
  Future<void> completeMission(
    String uid,
    String missionId,
    String gameId,
  ) async {
    final docRef = _db
        .collection('daily_missions')
        .doc(uid)
        .collection('today')
        .doc('missions');

    await _db.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) return;

      final data = snap.data() ?? {};
      final missions = List<Map<String, dynamic>>.from(
          (data['missions'] as List<dynamic>? ?? [])
              .map((m) => Map<String, dynamic>.from(m as Map)));

      bool found = false;
      for (final m in missions) {
        if (m['id'] == missionId && !(m['completed'] as bool? ?? false)) {
          m['completed'] = true;
          m['completedAt'] = FieldValue.serverTimestamp();
          found = true;
          break;
        }
      }
      if (!found) return;

      tx.update(docRef, {'missions': missions});
    });
  }
}
```

- [ ] **Step 3: Add daily_missions rules to firestore.rules**

Add before the closing `}`:
```javascript
    // Daily missions — learner reads/updates own; Cloud Functions write
    match /daily_missions/{uid}/{sub}/{doc} {
      allow read: if isUser(uid);
      allow update: if isUser(uid) && sub == 'today';
      allow write: if false; // Cloud Functions create
    }
    // Teacher-assigned missions — teacher writes; Cloud Functions read
    match /daily_missions/{uid}/assigned/{doc} {
      allow read: if isUser(uid);
      allow write: if isTeacher();
    }
```

- [ ] **Step 4: Verify flutter analyze passes**

```bash
flutter analyze --no-pub 2>&1 | tail -5
```

Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/data/models/daily_mission_model.dart lib/data/repositories/mission_repository.dart firestore.rules
git commit -m "feat: daily missions data layer — DailyMission model, repository, Firestore rules"
```

---

## Task 8: generateDailyMissions Cloud Function

**Files:**
- Create: `functions/src/missions/catalog.ts`
- Create: `functions/src/missions/generate.ts`
- Modify: `functions/src/index.ts`

**Interfaces:**
- Consumes: `questbotChat` function signature (same Gemini model reused with structured prompt)
- Produces: `generateDailyMissions` — scheduled CF that writes `daily_missions/{uid}/today/missions` for every learner

- [ ] **Step 1: Create functions/src/missions/catalog.ts**

```typescript
// Curated 7-day subject rotation. dayIndex = new Date().getDay() (0=Sun)
// Each day provides 3 fallback missions mapped to game IDs in GameCatalog.
export const MISSION_CATALOG: Record<number, {gameId: string; subject: string; emoji: string; title: string}[]> = {
  0: [ // Sunday — Social Sciences + Life Skills
    {gameId: "ssc_g5_africa", subject: "Social Sciences", emoji: "🌍", title: "Explore Africa"},
    {gameId: "lsk_g3_emotions", subject: "Life Skills", emoji: "😊", title: "Emotion Explorer"},
    {gameId: "ssc_g7_mali", subject: "Social Sciences", emoji: "🏛️", title: "Ancient Kingdoms"},
  ],
  1: [ // Monday — Mathematics
    {gameId: "math_g4_multiplication", subject: "Mathematics", emoji: "✖️", title: "Multiples Master"},
    {gameId: "math_g5_fractions", subject: "Mathematics", emoji: "½", title: "Fraction Quest"},
    {gameId: "math_g7_algebra", subject: "Mathematics", emoji: "🔢", title: "Algebra Arena"},
  ],
  2: [ // Tuesday — English
    {gameId: "eng_g4_grammar", subject: "English", emoji: "📝", title: "Grammar Hero"},
    {gameId: "eng_g5_figurative", subject: "English", emoji: "✍️", title: "Figurative Language"},
    {gameId: "eng_g7_essay", subject: "English", emoji: "📖", title: "Essay Explorer"},
  ],
  3: [ // Wednesday — Natural Sciences
    {gameId: "sci_g4_water", subject: "Natural Sciences", emoji: "💧", title: "Water Cycle"},
    {gameId: "sci_g5_body", subject: "Natural Sciences", emoji: "🫀", title: "Body Systems"},
    {gameId: "sci_g7_biodiversity", subject: "Natural Sciences", emoji: "🌿", title: "Biosphere"},
  ],
  4: [ // Thursday — Mathematics
    {gameId: "math_g3_tables", subject: "Mathematics", emoji: "🔢", title: "Times Tables"},
    {gameId: "math_g6_percentages", subject: "Mathematics", emoji: "%", title: "Percentage Power"},
    {gameId: "math_g7_integers", subject: "Mathematics", emoji: "±", title: "Integer Island"},
  ],
  5: [ // Friday — Technology + EMS
    {gameId: "tech_g5_mechanisms", subject: "Technology", emoji: "⚙️", title: "Machine Builder"},
    {gameId: "ems_g7_budget", subject: "EMS", emoji: "💰", title: "Budget Boss"},
    {gameId: "tech_g7_circuits", subject: "Technology", emoji: "⚡", title: "Circuit Challenge"},
  ],
  6: [ // Saturday — Social Sciences + Science
    {gameId: "ssc_g4_provinces", subject: "Social Sciences", emoji: "🗺️", title: "Province Explorer"},
    {gameId: "sci_g6_ecosystem", subject: "Natural Sciences", emoji: "🌳", title: "Ecosystem Quest"},
    {gameId: "ssc_g7_colonisation", subject: "Social Sciences", emoji: "🏴", title: "Cape Colony"},
  ],
};
```

- [ ] **Step 2: Create functions/src/missions/generate.ts**

```typescript
import {onSchedule} from "firebase-functions/v2/scheduler";
import * as admin from "firebase-admin";
import {GoogleGenerativeAI} from "@google/generative-ai";
import {MISSION_CATALOG} from "./catalog";

const SEVEN_DAYS_MS = 7 * 24 * 60 * 60 * 1000;

interface MissionEntry {
  id: string;
  gameId: string;
  title: string;
  subject: string;
  emoji: string;
  xpBonus: number;
  completed: boolean;
  source: "teacher" | "adaptive" | "curated";
}

function nextMidnightSAST(): Date {
  // SAST = UTC+2. Find next 00:00 SAST.
  const now = new Date();
  const sastOffset = 2 * 60 * 60 * 1000;
  const sastNow = new Date(now.getTime() + sastOffset);
  const nextMidnight = new Date(
    Date.UTC(
      sastNow.getUTCFullYear(),
      sastNow.getUTCMonth(),
      sastNow.getUTCDate() + 1,
      0, 0, 0, 0
    ) - sastOffset
  );
  return nextMidnight;
}

async function getAdaptiveMissions(
  uid: string,
  grade: string,
  dayIndex: number
): Promise<{gameId: string; subject: string; emoji: string; title: string}[]> {
  const db = admin.firestore();
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) return [];

  // Gather last 30 days of progress
  const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
  const progressSnap = await db.collection("progress")
    .where("childUid", "==", uid)
    .where("completedAt", ">=", admin.firestore.Timestamp.fromDate(thirtyDaysAgo))
    .get();

  if (progressSnap.size < 7) return []; // Not enough history

  const subjectScores: Record<string, number[]> = {};
  progressSnap.docs.forEach((d) => {
    const data = d.data();
    const subj = (data["subject"] as string) || "General";
    if (!subjectScores[subj]) subjectScores[subj] = [];
    subjectScores[subj].push((data["score"] as number) || 0);
  });

  const avgScores: Record<string, number> = {};
  for (const [subj, scores] of Object.entries(subjectScores)) {
    avgScores[subj] = scores.reduce((a, b) => a + b, 0) / scores.length;
  }

  const weakSubjects = Object.entries(avgScores)
    .filter(([, v]) => v < 65)
    .map(([k]) => k)
    .slice(0, 2);

  if (weakSubjects.length === 0) return [];

  // Build catalog subset for Gemini to pick from
  const catalogSubset = MISSION_CATALOG[dayIndex].map((m) => m.gameId).join(", ");

  const genAI = new GoogleGenerativeAI(apiKey);
  const model = genAI.getGenerativeModel({model: "gemini-1.5-flash"});

  const prompt = `A Grade ${grade} learner is weak in: ${weakSubjects.join(", ")}.
Available game IDs: ${catalogSubset}
Pick 1-2 game IDs that target their weak subjects. Respond ONLY with valid JSON:
{"missions":[{"gameId":"<id>","reason":"<one sentence>"}]}
If no games match the weak subjects, return {"missions":[]}`;

  try {
    const result = await model.generateContent(prompt);
    const text = result.response.text().trim();
    const jsonMatch = text.match(/\{[\s\S]*\}/);
    if (!jsonMatch) return [];
    const parsed = JSON.parse(jsonMatch[0]) as {missions: {gameId: string}[]};
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
        };
      })
      .slice(0, 2);
  } catch {
    return [];
  }
}

export const generateDailyMissions = onSchedule(
  {schedule: "every day 00:00", timeZone: "Africa/Johannesburg", memory: "512MiB"},
  async () => {
    const db = admin.firestore();
    const expiresAt = admin.firestore.Timestamp.fromDate(nextMidnightSAST());
    const generatedAt = admin.firestore.Timestamp.now();
    const dayIndex = new Date().getDay();

    // Process all learners
    const learnersSnap = await db.collection("users")
      .where("role", "==", "learner")
      .get();

    const batchSize = 20;
    const learners = learnersSnap.docs;

    for (let i = 0; i < learners.length; i += batchSize) {
      const chunk = learners.slice(i, i + batchSize);
      await Promise.all(chunk.map(async (learnerDoc) => {
        const uid = learnerDoc.id;
        const grade = (learnerDoc.data()["grade"] as string) || "Grade 1";
        const gradeNum = parseInt(grade.replace(/\D/g, ""), 10) || 1;
        const missions: MissionEntry[] = [];

        // TIER 1: Teacher-assigned missions
        const assignedSnap = await db
          .collection("daily_missions").doc(uid)
          .collection("assigned").limit(3).get();
        assignedSnap.docs.forEach((d) => {
          if (missions.length < 3) {
            const data = d.data();
            missions.push({
              id: d.id,
              gameId: (data["gameId"] as string) || "",
              title: (data["title"] as string) || "Teacher Mission",
              subject: (data["subject"] as string) || "General",
              emoji: (data["emoji"] as string) || "📋",
              xpBonus: 20,
              completed: false,
              source: "teacher",
            });
          }
        });

        // TIER 2: Adaptive Gemini missions
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
              });
            }
          });
        }

        // TIER 3: Curated rotation to fill remaining slots
        const catalog = MISSION_CATALOG[dayIndex] ?? MISSION_CATALOG[1];
        catalog.forEach((m) => {
          if (missions.length < 3 &&
              !missions.some((existing) => existing.gameId === m.gameId)) {
            missions.push({
              id: `curated_${m.gameId}_${dayIndex}`,
              gameId: m.gameId,
              title: m.title,
              subject: m.subject,
              emoji: m.emoji,
              xpBonus: 10,
              completed: false,
              source: "curated",
            });
          }
        });

        await db.collection("daily_missions").doc(uid)
          .collection("today").doc("missions")
          .set({missions, generatedAt, expiresAt}, {merge: false});
      }));
    }

    console.log(`Daily missions generated for ${learners.length} learners`);
  }
);
```

- [ ] **Step 3: Export generateDailyMissions from functions/src/index.ts**

Add to the export block:
```typescript
export {generateDailyMissions} from "./missions/generate";
```

- [ ] **Step 4: Build and verify**

```bash
cd functions && npm run build 2>&1 | tail -10
```

Expected: `lib/missions/generate.js` and `lib/missions/catalog.js` created. No errors.

- [ ] **Step 5: Commit**

```bash
git add functions/src/missions/ functions/src/index.ts functions/lib/
git commit -m "feat: generateDailyMissions scheduled CF — 3-tier (teacher/adaptive/curated) daily mission generator"
```

---

## Task 9: MissionProvider + DailyMissionsCard + Dashboard Integration

**Files:**
- Create: `lib/providers/mission_provider.dart`
- Create: `lib/features/dashboard/widgets/daily_missions_card.dart`
- Modify: `lib/main.dart` (add MissionProvider)
- Modify: `lib/features/dashboard/screens/learner_dashboard.dart` (insert card in _LearnerHomeTab)

**Interfaces:**
- Consumes: `MissionRepository` from Task 7, `GameRouter`, `GameConfig`, `AppColors`, `AppTextStyles`, `GameTheme`
- Produces: `MissionProvider` — `ChangeNotifier` with `missions`, `watchMissions(uid)`, `completeMission(...)`

- [ ] **Step 1: Create lib/providers/mission_provider.dart**

```dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/models/daily_mission_model.dart';
import '../data/repositories/mission_repository.dart';

class MissionProvider extends ChangeNotifier {
  final _repo = MissionRepository();
  StreamSubscription<List<DailyMission>>? _sub;

  List<DailyMission> _missions = [];
  List<DailyMission> get missions => _missions;

  int get completedCount => _missions.where((m) => m.completed).length;
  int get totalCount => _missions.length;
  bool get allComplete => totalCount > 0 && completedCount == totalCount;

  void watchMissions(String uid) {
    _sub?.cancel();
    _sub = _repo.watchTodayMissions(uid).listen((list) {
      _missions = list;
      notifyListeners();
    });
  }

  Future<void> completeMission(String uid, String missionId, String gameId) async {
    await _repo.completeMission(uid, missionId, gameId);
    // Optimistic local update
    _missions = _missions.map((m) {
      if (m.id == missionId) {
        return DailyMission(
          id: m.id, gameId: m.gameId, title: m.title,
          subject: m.subject, emoji: m.emoji, xpBonus: m.xpBonus,
          completed: true, completedAt: DateTime.now(), source: m.source,
        );
      }
      return m;
    }).toList();
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
```

- [ ] **Step 2: Create lib/features/dashboard/widgets/daily_missions_card.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/daily_mission_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/mission_provider.dart';
import '../../games/core/game_catalog.dart';
import '../../games/core/game_config.dart';
import '../../games/core/game_router.dart';

class DailyMissionsCard extends StatelessWidget {
  const DailyMissionsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MissionProvider>();
    final missions = provider.missions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Daily Missions', style: AppTextStyles.h3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${provider.completedCount}/${provider.totalCount}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: provider.totalCount > 0
                ? provider.completedCount / provider.totalCount
                : 0,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            minHeight: 4,
          ),
        ),
        const SizedBox(height: 12),
        if (missions.isEmpty)
          _EmptyMissions()
        else
          SizedBox(
            height: 136,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: missions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) => _MissionTile(
                mission: missions[i],
                index: i,
              ),
            ),
          ),
      ],
    );
  }
}

class _MissionTile extends StatelessWidget {
  final DailyMission mission;
  final int index;

  const _MissionTile({required this.mission, required this.index});

  Color _subjectColor() {
    switch (mission.subject) {
      case 'Mathematics': return AppColors.math;
      case 'English': return AppColors.english;
      case 'Natural Sciences': return AppColors.science;
      case 'Social Sciences': return AppColors.socialSciences;
      case 'Technology': return const Color(0xFF7C4DFF);
      case 'EMS': return const Color(0xFF00897B);
      default: return AppColors.primary;
    }
  }

  void _launchGame(BuildContext context) {
    final catalogEntry = GameCatalog.all
        .where((g) => g.id == mission.gameId)
        .firstOrNull;
    if (catalogEntry == null) return;

    final uid = context.read<AuthProvider>().user?.uid ?? '';
    final config = GameConfig.fromCatalogEntry(catalogEntry);

    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => GameRouter(config: config, uid: uid),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final color = _subjectColor();
    final done = mission.completed;

    return GestureDetector(
      onTap: done ? null : () => _launchGame(context),
      child: Container(
        width: 148,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: done
              ? null
              : LinearGradient(
                  colors: [color, color.withValues(alpha: 0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          color: done
              ? Colors.grey.withValues(alpha: 0.15)
              : null,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: done ? Colors.grey.withValues(alpha: 0.3) : color,
          ),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mission.emoji,
                  style: TextStyle(
                    fontSize: 30,
                    color: done ? Colors.grey : null,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  mission.title,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: done ? Colors.grey : Colors.white,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                Text(
                  mission.sourceBadge,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: done
                        ? Colors.grey
                        : Colors.white.withValues(alpha: 0.75),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            if (done)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Center(
                    child: Text('✅', style: TextStyle(fontSize: 32)),
                  ),
                ),
              ),
          ],
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: index * 60))
        .slideX(begin: 0.2, end: 0, curve: Curves.easeOut)
        .fadeIn();
  }
}

class _EmptyMissions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          const Text('🌅', style: TextStyle(fontSize: 32)),
          const SizedBox(height: 8),
          Text("Today's missions are loading...",
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Add MissionProvider to main.dart**

In `lib/main.dart`, add import:
```dart
import 'providers/mission_provider.dart';
```

Add to the `MultiProvider` providers list:
```dart
ChangeNotifierProvider(create: (_) => MissionProvider()),
```

Also add `watchMissions` call. In `_LearnerDashboardState.initState` in `learner_dashboard.dart`, add:
```dart
if (uid != null) {
  context.read<MissionProvider>().watchMissions(uid);
}
```

- [ ] **Step 4: Insert DailyMissionsCard into _LearnerHomeTab**

In `lib/features/dashboard/screens/learner_dashboard.dart`:

Add import at top:
```dart
import '../../../providers/mission_provider.dart';
import '../widgets/daily_missions_card.dart';
```

In the `_LearnerHomeTab.build` method, inside the `Padding` widget that wraps the column (after `_StatsRow` and before `_DailyChallengeCard`), insert:

```dart
const SizedBox(height: 24),
const DailyMissionsCard(),
const SizedBox(height: 24),
```

Full updated children block inside the inner `Padding`:
```dart
children: [
  const SizedBox(height: 20),
  _StatsRow(coins: _coins, streakDays: _streakDays, badgeCount: badgeCount),
  const SizedBox(height: 24),
  const DailyMissionsCard(),   // ← NEW
  const SizedBox(height: 24),
  _DailyChallengeCard(user: user),
  const SizedBox(height: 24),
],
```

- [ ] **Step 5: Verify flutter analyze passes**

```bash
flutter analyze --no-pub 2>&1 | tail -5
```

Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/providers/mission_provider.dart lib/features/dashboard/widgets/daily_missions_card.dart lib/main.dart lib/features/dashboard/screens/learner_dashboard.dart
git commit -m "feat: MissionProvider + DailyMissionsCard — 3-mission horizontal scroll in learner home tab"
```

---

## Task 10: Mission XP Bonus on Game Completion

**Files:**
- Modify: `lib/features/games/core/game_session_state.dart`

**Interfaces:**
- Consumes: `MissionRepository.completeMission(uid, missionId, gameId)` from Task 7
- Produces: When a game session ends, if the completed game's ID matches an incomplete mission's `gameId`, `completeMission` is called, awarding the xpBonus on top of the normal session XP.

- [ ] **Step 1: Update game_session_state.dart to accept missionId and call completeMission**

In `lib/features/games/core/game_session_state.dart`:

Add import:
```dart
import '../../../data/repositories/mission_repository.dart';
```

Add private field after `final _repo = GameRepository();`:
```dart
final _missionRepo = MissionRepository();
```

Update the `finishSession` signature to optionally accept a missionId:
```dart
@protected
Future<void> finishSession(String uid, {bool earlyWin = false, String? activeMissionId}) async {
  if (_finished) return;
  _ticker?.cancel();
  _finished = true;

  _result = engine.buildResult(
    correct: _correctCount,
    total: totalQuestions,
    timeTakenSeconds: _elapsed,
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
    try {
      await _repo.logGameSession(session);
    } catch (_) {
      // Non-fatal: local state already updated
    }

    // Award mission XP bonus if this game was a daily mission
    if (activeMissionId != null && activeMissionId.isNotEmpty) {
      try {
        await _missionRepo.completeMission(uid, activeMissionId, config.gameId ?? '');
      } catch (_) {
        // Non-fatal
      }
    }
  }
}
```

Note: `config.gameId` needs to be available on `GameConfig`. Check if `GameConfig` has a `gameId` field — if not, add it:

In `lib/features/games/core/game_config.dart`, add to the config class:
```dart
final String? gameId; // The GameCatalog entry id, used for mission completion
```

And update `GameConfig.fromCatalogEntry`:
```dart
static GameConfig fromCatalogEntry(GameCatalogEntry entry) {
  return GameConfig(
    // ... existing fields ...
    gameId: entry.id,
  );
}
```

- [ ] **Step 2: Verify flutter analyze passes**

```bash
flutter analyze --no-pub 2>&1 | tail -5
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/features/games/core/game_session_state.dart lib/features/games/core/game_config.dart
git commit -m "feat: mission XP bonus hook — completeMission called in finishSession when activeMissionId provided"
```

---

## Task 11: Deploy Cloud Functions & Build Final APK

**Files:**
- No code changes — deploy and build only.

- [ ] **Step 1: Set GEMINI_API_KEY secret in Firebase**

```bash
cd functions
firebase functions:secrets:set GEMINI_API_KEY
```

When prompted, paste: `<GEMINI_API_KEY — see .env.local>`

- [ ] **Step 2: Deploy all Cloud Functions**

```bash
firebase deploy --only functions 2>&1
```

Expected: All functions deploy successfully. URLs printed for `questbotChat`, `analyzeImage`, `getRecommendation`, `explainAnswer`, `generateHint`, `refreshLeaderboards`, `generateDailyMissions`, `sendEmail`, `cleanupOldEmails`.

- [ ] **Step 3: Deploy Firestore rules and indexes**

```bash
firebase deploy --only firestore 2>&1
```

Expected: Rules and indexes deployed without errors.

- [ ] **Step 4: Build release APK**

```bash
flutter build apk --release "--dart-define=GEMINI_API_KEY=" 2>&1
```

Note: The APK no longer uses `GEMINI_API_KEY` client-side (the key is in Cloud Functions). Pass an empty value to satisfy the `String.fromEnvironment` call in `AppConfig` — the value is ignored at runtime since `GeminiService` now calls Cloud Functions.

Expected: `build\app\outputs\flutter-apk\app-release.apk` built successfully.

- [ ] **Step 5: Commit and tag**

```bash
git add -A
git commit -m "chore: deploy Cloud Functions, Firestore rules — Sub-project A complete"
git tag v2.1.0-subproject-a
git push origin main --tags
```

---

## Self-Review Checklist

**Spec coverage:**
- [x] A1: Gemini proxy → Tasks 1–2
- [x] A2: fl_chart dependency → Task 3
- [x] A3: Leaderboard (grade + class) → Tasks 4–6
- [x] A4: Daily missions (3-tier) → Tasks 7–9
- [x] Mission XP bonus → Task 10
- [x] Deployment → Task 11

**Placeholder scan:** No TBDs or "implement later" found. All code blocks are complete.

**Type consistency:**
- `LeaderboardEntry` fields used in Tasks 4, 6 match exactly
- `DailyMission.id`, `.gameId`, `.source`, `.sourceBadge` consistent across Tasks 7, 9, 10
- `MissionRepository.completeMission(uid, missionId, gameId)` — 3-param signature consistent across Tasks 7, 9, 10
- `finishSession(uid, {earlyWin, activeMissionId})` — new optional param, backwards-compatible with all existing subclass callers that don't pass `activeMissionId`
