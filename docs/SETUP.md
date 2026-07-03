# QuestKids — Quickstart

Full details live in [ENVIRONMENT_SETUP.md](ENVIRONMENT_SETUP.md) (local dev)
and [DEPLOYMENT.md](DEPLOYMENT.md) (releasing). This page is the fast path.

## Prerequisites

- Flutter 3.4+, Dart 3.4+
- Node.js 22+
- Firebase CLI (`npm install -g firebase-tools`)

## Get running

```bash
git clone https://github.com/saxs-14/questkids.git
cd questkids
flutter pub get
cd functions && npm install && cd ..

firebase login
firebase use --add          # select your Firebase project

echo "GEMINI_API_KEY=your_key_here" > functions/.env

flutter run -d chrome       # fastest way to see the app boot
```

## Before you touch Firestore/Storage rules or the Gemini proxy

Test against the emulators first — never deploy rules or functions straight
to production:

```bash
firebase emulators:start --only functions,firestore,auth
```

## Definition of done for any change

1. `flutter analyze` → 0 errors
2. `flutter test` → green
3. `cd functions && npm run build && npm run lint` → clean
4. App boots to login on `flutter run -d chrome`, no red screen
5. `git status` reviewed — no new files matching secret patterns (see
   [SECURITY.md](SECURITY.md))

See [CLAUDE.md](../CLAUDE.md) at the repo root for the full architecture,
conventions, and hard rules.
