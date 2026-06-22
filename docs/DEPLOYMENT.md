# QuestKids — Deployment Guide

## Pre-Deploy Checklist

- [ ] `flutter analyze` passes with no errors
- [ ] `cd functions && npm run build` succeeds
- [ ] Gemini API key is set in Firebase Secret Manager
- [ ] `android/key.properties` exists with correct keystore paths
- [ ] `android/questkids-release.jks` exists

## 1. Deploy Cloud Functions

```bash
# Set Gemini key in Secret Manager (first time only)
firebase functions:secrets:set GEMINI_API_KEY

# Build TypeScript
cd functions && npm run build && cd ..

# Deploy
firebase deploy --only functions
```

## 2. Deploy Firestore Rules + Indexes

```bash
firebase deploy --only firestore
```

## 3. Build Release APK

```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/QuestKids-release.apk
```

The APK is signed with the key from `android/key.properties`. Install on device:
```bash
adb install build/app/outputs/flutter-apk/QuestKids-release.apk
```

## 4. Deploy Everything at Once

```bash
cd functions && npm run build && cd ..
firebase deploy --only functions,firestore
flutter build apk --release
```

## 5. Firebase Hosting (Optional)

If you add a web build:
```bash
flutter build web --release
firebase deploy --only hosting
```

## Version Bumping

Edit `pubspec.yaml`:
```yaml
version: 1.1.0+2  # versionName+versionCode
```

## Rollback

To rollback Cloud Functions to a previous version:
```bash
firebase functions:list  # find the previous deploy ID
firebase deploy --only functions  # re-deploy from previous working commit
```

## Monitoring

- Firebase Console → Functions → Logs (for CF errors)
- Firebase Console → Firestore → Usage (for DB reads/writes)
- Crashlytics (to be integrated) for client-side crashes
