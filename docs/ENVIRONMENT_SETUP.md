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
firebase emulators:start --only functions,firestore,auth
```

In a separate terminal, run the app pointing at emulators:
```bash
flutter run --dart-define=USE_EMULATORS=true
```
