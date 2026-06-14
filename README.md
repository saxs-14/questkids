# QuestKids 2.0 - Gamified EdTech Learning Platform

QuestKids 2.0 is a **Flutter-based gamified learning platform** built for South African learners in Grades 1–7. It features an animated learner adventure, AI-powered tutoring via Gemini, and comprehensive dashboards for teachers and parents.

**Repository:** [saxs-14/questkids](https://github.com/saxs-14/questkids.git)

---

## Architecture

```text
Flutter App (Dart)
├── lib/
│   ├── core/          # Services, models, themes, routing
│   ├── features/      # Auth, learner, teacher, parent, admin modules
│   └── shared/        # Reusable widgets
├── functions/         # Firebase Cloud Functions (Node.js)
├── android/           # Android platform config
├── ios/               # iOS platform config
└── web/               # Web platform entry point
```

**Backend:** Firebase (Firestore, Auth, Storage, Messaging, Analytics, Cloud Functions)
**AI:** Google Gemini via `google_generative_ai`
**State:** Provider
**Navigation:** GoRouter

---

## Getting Started

### Prerequisites

- Flutter SDK `>=3.4.0`
- Firebase project configured (see [FIREBASE_SETUP_GUIDE.md](FIREBASE_SETUP_GUIDE.md))
- `google-services.json` placed in `android/app/`
- `GoogleService-Info.plist` placed in `ios/Runner/`

### Run the app

```bash
# Install dependencies
flutter pub get

# Run on a connected device or emulator
flutter run

# Run as web
flutter run -d chrome
```

### Firebase Cloud Functions

```bash
cd functions
npm install
firebase deploy --only functions
```

---

## Key Features

- **Learner Portal** — Quest-based lessons, XP/coin rewards, AI wizard chatbot, interactive activities
- **Teacher Dashboard** — Student analytics, progress tracking, assignment creator
- **Parent Dashboard** — Screen-time controls, activity reports, multi-child linking, shared calendar
- **Admin Panel** — Curriculum management, user oversight

---

## Firebase Services Used

| Service            | Purpose                      |
| ------------------ | ---------------------------- |
| Firebase Auth      | Email, Google, phone sign-in |
| Cloud Firestore    | Real-time data store         |
| Firebase Storage   | Media uploads                |
| Firebase Messaging | Push notifications           |
| Firebase Analytics | Usage tracking               |
| Cloud Functions    | Server-side logic            |

---

## Documentation

- [FIREBASE_SETUP_GUIDE.md](FIREBASE_SETUP_GUIDE.md) — Firebase project configuration steps
- [AUTHENTICATION_README.md](AUTHENTICATION_README.md) — Auth flow details
- [QUICK_START.md](QUICK_START.md) — Fast setup reference
- [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md) — Development progress tracker
