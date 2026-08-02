# QuestKids — Environment Setup

## Prerequisites

- Flutter 3.4+ (`flutter --version`)
- Dart 3.4+
- Node.js 22+ (for Cloud Functions)
- Firebase CLI (`npm install -g firebase-tools`)
- Android Studio / Xcode (for mobile builds)

## 1. Clone & Install Dependencies

```bash
git clone https://github.com/saxs-14/questkids.git
cd questkids
flutter pub get
cd functions && npm install && cd ..
```

## 2. Firebase Setup

```bash
firebase login
firebase use --add  # select your project (questkids-xxxxxxxx)
```

## 3. Gemini API Key

The Gemini key lives on the server only. Never add it to Flutter client code.

**Local development (functions emulator):**
```bash
echo "GEMINI_API_KEY=your_key_here" > functions/.env
```

**Production deploy:**
```bash
firebase functions:secrets:set GEMINI_API_KEY
# Paste your key when prompted
```

## 4. Build & Run (Debug)

```bash
flutter run
```

## 5. Build Release APK

First create an Android signing keystore if you don't have one:
```bash
keytool -genkey -v -keystore android/questkids-release.jks \
  -alias questkids -keyalg RSA -keysize 2048 -validity 10000
```

Then create `android/key.properties` (gitignored):
```
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=questkids
storeFile=../questkids-release.jks
```

Build:
```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/QuestKids-release.apk
```

## 6. Deploy Cloud Functions

```bash
cd functions && npm run build && cd ..
firebase deploy --only functions
firebase deploy --only firestore   # deploys rules + indexes
```

## 7. Firebase Emulator (Local Testing)

```bash
firebase emulators:start --only functions,firestore,auth,storage
```

In a separate terminal, run the app pointing at emulators:
```bash
flutter run --dart-define=USE_EMULATORS=true
```

`core/config/emulator_config.dart`'s `connectToEmulatorsIfEnabled` wires `USE_EMULATORS` to
`FirebaseAuth`/`Firestore`/`Functions`/`Storage` (ports match `firebase.json`'s `emulators`
block), gated behind `kDebugMode` so it can never activate in a release build. This must be
called on every `FirebaseApp` instance separately, not just once globally — `lib/main.dart`
calls it for the default app, and `lib/core/services/auth_service.dart` calls it for each of
the three secondary/temporary `FirebaseApp` instances it creates for child-account
registration. A secondary app that skips this call silently talks to production even while
the default app is correctly emulated. The emulator UI is at http://localhost:4000 — use it
to create a test user and inspect/edit their Firestore user doc (e.g. set `grade` to
`grade4`, `role` to `learner`) without touching production data.
