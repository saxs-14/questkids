# ⚡ QuestKids 2.0 - Quick Start Guide

Get your QuestKids project running in 15 minutes!

---

## ✅ Prerequisites

Before you start, make sure you have:
- ✅ Flutter SDK installed (v3.12.0+)
- ✅ Android Studio or Xcode (for device testing)
- ✅ Firebase project created (`questkids-mobile`)
- ✅ FlutterFire CLI installed
- ✅ Gmail account (`questkids.dev@gmail.com`)

---

## 🚀 Quick Start (5 Steps)

### Step 1: Clone & Setup Project
```bash
# Navigate to project directory
cd d:\Projects\QuestKids

# Get all dependencies
flutter pub get

# Verify Flutter setup
flutter doctor
```

**Time:** 2 minutes

### Step 2: Download google-services.json
```bash
# Go to Firebase Console
# https://console.firebase.google.com/

# 1. Select project: questkids-mobile
# 2. Click ⚙️ Settings → Project Settings
# 3. Find "Your apps" section
# 4. Click "Download google-services.json"
# 5. Save to: android/app/google-services.json
```

**Time:** 3 minutes

### Step 3: Set Up Cloud Functions (Optional but Recommended)
```bash
# Navigate to functions directory
cd functions

# Install dependencies
npm install

# Generate Gmail App Password:
# 1. Go to https://myaccount.google.com/apppasswords
# 2. Enable 2FA first if not done
# 3. Select "Mail" + "Windows"
# 4. Copy the 16-character password

# Set credentials
firebase functions:config:set mail.sender="questkids.dev@gmail.com" mail.password="your-16-char-password"

# Deploy functions
firebase deploy --only functions

# Return to project root
cd ..
```

**Time:** 5 minutes

### Step 4: Enable Firebase Providers (Console)
```
Go to Firebase Console:
https://console.firebase.google.com/project/questkids-mobile/authentication

1. Click "Sign-in method"
2. Enable:
   ✅ Email/Password
   ✅ Phone (optional)
   ✅ Google
   ⚠️ Play Games (requires Play Developer account)
   ⚠️ Game Center (requires Apple Developer account)
```

**Time:** 2 minutes

### Step 5: Run the App
```bash
# Build web version (fastest)
flutter run -d chrome

# OR Android emulator
flutter run

# OR iOS simulator
flutter run -d ios
```

**Time:** 2-3 minutes

---

## ✨ Expected Output

When you run the app, you should see:

```
✅ QuestKids 2.0 - Firebase Connected ✅
```

This confirms:
- ✅ Flutter app initialized
- ✅ Firebase connected successfully
- ✅ Firestore ready
- ✅ Authentication ready

---

## 🧪 Test Authentication

### Test Email/Password
```dart
1. Tap "Sign Up"
2. Enter:
   - Email: test@example.com
   - Password: TestPass123
   - Name: Test User
3. Tap "Create Account"
4. Check Firestore: users/{uid} document created
5. Check email: Welcome email should arrive (if functions deployed)
```

### Test Google Sign-In
```dart
1. Tap "Sign in with Google"
2. Select your Google account
3. Grant permissions
4. Should automatically sign in
5. User document created in Firestore
```

### Test Phone OTP
```dart
1. Tap "Phone Sign-In"
2. Enter test number: +1 650-253-0000 (if in testing mode)
3. SMS code: 123456 (for test numbers)
4. Should complete authentication
```

---

## 📁 Project Structure Overview

```
QuestKids/
├── 📁 lib/
│   ├── main.dart                    ← App entry point
│   ├── firebase_options.dart        ← Firebase config (auto-generated)
│   ├── 📁 core/services/
│   │   ├── auth_service.dart       ← All 5 auth methods
│   │   ├── email_service.dart      ← Email templates
│   │   └── firebase_initializer.dart ← Firebase setup
│   ├── 📁 data/models/
│   │   └── auth_models.dart        ← User models
│   └── 📁 config/
│       └── firebase_config.dart    ← Configuration constants
│
├── 📁 functions/
│   ├── src/index.ts               ← Cloud Functions
│   ├── package.json               ← Functions dependencies
│   └── tsconfig.json              ← TypeScript config
│
├── 📁 android/
│   └── app/
│       └── google-services.json    ← ⏳ To be downloaded
│
├── 📁 ios/
│   └── Runner/
│       └── GoogleService-Info.plist ✅ Already present
│
├── pubspec.yaml                    ← Flutter dependencies
├── SETUP_SUMMARY.md               ← What was done & next steps
├── FIREBASE_SETUP_GUIDE.md        ← Detailed setup instructions
├── AUTHENTICATION_README.md       ← Full documentation
└── QUICK_START.md                 ← This file
```

---

## 🔧 Troubleshooting Quick Fixes

### "Firebase not initialized"
```bash
# Make sure you ran Flutter pub get
flutter pub get

# Clean and rebuild
flutter clean
flutter pub get
flutter run
```

### "google-services.json not found"
```bash
# File must be at: android/app/google-services.json
# NOT in a subfolder like android/app/src/

# Verify location:
ls android/app/google-services.json  # Should not show error
```

### "Google Sign-In fails"
```bash
# For Android, register SHA-1:
cd android
./gradlew signingReport
# Copy the SHA-1 and add to Firebase Console
```

### "Emails not sending"
```bash
# Check Cloud Functions logs
firebase functions:log

# Verify Gmail credentials
firebase functions:config:get mail

# Re-set if needed:
firebase functions:config:set mail.sender="questkids.dev@gmail.com" mail.password="new-password"
firebase deploy --only functions
```

### "Firestore permission denied"
```
1. Go to Firebase Console
2. Navigate to Firestore Database → Rules
3. Replace with rules from FIREBASE_SETUP_GUIDE.md
4. Publish the rules
5. Try again
```

---

## 📊 Monitoring

### Check User Signups
```
Firebase Console → Authentication → Users
Shows all registered users with sign-in methods
```

### Monitor Firestore
```
Firebase Console → Firestore Database
- users collection: Check user documents
- emails collection: Check email delivery status
```

### View Cloud Functions Logs
```bash
firebase functions:log

# Filter by function name
firebase functions:log --only sendEmail
```

### Email Delivery Status
```
Firebase Console → Firestore → emails collection
- sent: true = delivered
- sent: false = failed
- error field shows failure reason
```

---

## 🆘 Need Help?

### Check These Files First
1. **SETUP_SUMMARY.md** - What's been done & what's next
2. **FIREBASE_SETUP_GUIDE.md** - Detailed configuration steps
3. **AUTHENTICATION_README.md** - Complete auth documentation
4. **TROUBLESHOOTING** - Error messages and solutions

### Common Issues Solved
- google-services.json placement
- Firebase CLI not found
- Gmail App Password errors
- Google Sign-In SHA-1 issues
- Firestore permission errors
- Email not sending

---

## ✅ Success Checklist

After completing these steps, you should have:
- ✅ Firebase connected to your app
- ✅ Authentication working (at least email/password)
- ✅ User documents creating in Firestore
- ✅ Cloud Functions deployed (if you did step 3)
- ✅ App running on device/emulator

---

## 🎯 Next Steps

After quick start:
1. **Test all auth methods** - Try each sign-in option
2. **Verify email sending** - Check if welcome emails arrive
3. **Review Firestore data** - See user documents created
4. **Build UI components** - Create login/signup screens
5. **Implement navigation** - Connect screens with GoRouter
6. **Add dashboard** - Show user progress and activities
7. **Deploy to Play Store/App Store** - When ready

---

## 📱 Development Commands

```bash
# Run on Chrome web
flutter run -d chrome

# Run on Android emulator
flutter run

# Run on iOS simulator
flutter run -d ios

# Run on physical device
flutter run

# Build release APK (Android)
flutter build apk --release

# Build release IPA (iOS)
flutter build ios --release

# View Firebase logs
firebase functions:log

# Emulate locally (advanced)
firebase emulators:start

# Deploy everything
firebase deploy

# Deploy only functions
firebase deploy --only functions
```

---

## 🎉 You're Ready!

Your QuestKids 2.0 project is now set up with:
- ✅ Complete authentication system
- ✅ 5 sign-in providers
- ✅ Email automation
- ✅ Secure Firestore database
- ✅ Cloud Functions backend

**Estimated total time:** ~15 minutes

**Start from:** Step 1 in "Quick Start" section above

Happy coding! 🚀

---

**Version:** 1.0
**Last Updated:** 2024
**For:** QuestKids 2.0 Project
