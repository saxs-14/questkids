"""
FIREBASE AUTHENTICATION SETUP GUIDE FOR QUESTKIDS 2.0
=====================================================

Complete setup instructions for grade 4 gamified learning app with multiple auth providers.

PROJECT: questkids-mobile
ACCOUNT: questkids.dev@gmail.com
DATABASE: Firestore (default)

═══════════════════════════════════════════════════════════════════════════════
STEP 1: FIREBASE CONSOLE SETUP
═══════════════════════════════════════════════════════════════════════════════

1. Go to: https://console.firebase.google.com/
2. Select project: "questkids-mobile"
3. Navigate to: Authentication → Sign-in method

═══════════════════════════════════════════════════════════════════════════════
STEP 2: ENABLE AUTHENTICATION PROVIDERS
═══════════════════════════════════════════════════════════════════════════════

┌─ EMAIL/PASSWORD AUTHENTICATION ─┐
│ 1. Click "Email/Password"
│ 2. Toggle "Enable"
│ 3. Check "Email link (passwordless sign-in)" - OPTIONAL
│ 4. Save
│ Status: ✓ REQUIRED for age-appropriate sign-up
└─────────────────────────────────┘

┌─ PHONE AUTHENTICATION ─┐
│ 1. Click "Phone"
│ 2. Toggle "Enable"
│ 3. Add test phone numbers (optional, for testing)
│    Example: +1 650-253-0000
│ 4. Save
│ Status: ✓ For parent verification / account recovery
└───────────────────────┘

┌─ GOOGLE AUTHENTICATION ─┐
│ 1. Click "Google"
│ 2. Toggle "Enable"
│ 3. Project name: "QuestKids"
│ 4. Support email: questkids.dev@gmail.com
│ 5. Save
│ Status: ✓ Parent/Guardian sign-in
└──────────────────────┘

┌─ PLAY GAMES (Android) ─┐
│ Prerequisites:
│ • Google Play Developer account
│ • Android app published/in testing
│ 
│ 1. Set up in: https://play.google.com/console/
│ 2. Create Games Services project
│ 3. Configure leaderboards and achievements
│ 4. In Firebase: Click "Play Games"
│ 5. Toggle "Enable"
│ 6. Select or create Games Services project
│ 7. Save
│ Status: ⚠️ ANDROID ONLY - requires native setup
└─────────────────────┘

┌─ GAME CENTER (iOS) ─┐
│ Prerequisites:
│ • Apple Developer account
│ • App ID configured in App Store Connect
│ 
│ 1. In Firebase: Click "Game Center"
│ 2. Toggle "Enable"
│ 3. Save
│ Status: ⚠️ iOS ONLY - requires native setup
│ Note: Requires Xcode configuration
└────────────────────┘

═══════════════════════════════════════════════════════════════════════════════
STEP 3: GOOGLE OAUTH 2.0 SETUP (For Google Sign-In)
═══════════════════════════════════════════════════════════════════════════════

1. Go to: Google Cloud Console → https://console.cloud.google.com/
2. Ensure "questkids-mobile" project is selected
3. Navigate to: APIs & Services → Credentials
4. Click "Create Credentials" → OAuth 2.0 Client ID
5. Choose "Web application"
6. Add Authorized JavaScript origins:
   - http://localhost:7777 (local testing)
   - https://questkids.firebaseapp.com (Firebase hosting)
7. Add Authorized redirect URIs:
   - https://questkids-mobile.firebaseapp.com/__/auth/handler
8. Copy Client ID (you may need it for web testing)
9. For Android & iOS: Use Firebase Console generated credentials

═══════════════════════════════════════════════════════════════════════════════
STEP 4: ANDROID CONFIGURATION
═══════════════════════════════════════════════════════════════════════════════

File: android/app/build.gradle.kts

Add dependencies (if not already present):
─────────────────────────────────────────
dependencies {
    // Google Play Services
    implementation 'com.google.android.gms:play-services-auth:20.7.0'
    implementation 'com.google.android.gms:play-services-games:23.1.0'
}

File: android/app/src/main/AndroidManifest.xml

Add permissions:
────────────────
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />

File: Generated google-services.json

Location: android/app/google-services.json
• Download from Firebase Console: Project Settings → Download google-services.json
• Place in: android/app/

═══════════════════════════════════════════════════════════════════════════════
STEP 5: iOS CONFIGURATION
═══════════════════════════════════════════════════════════════════════════════

File: Generated GoogleService-Info.plist

Location: ios/Runner/GoogleService-Info.plist (already in project)
• Download from Firebase Console: Project Settings → Download GoogleService-Info.plist
• Ensure it's added to Xcode project

File: ios/Podfile

Uncomment if needed:
─────────────────
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
        '$(inherited)',
        'PERMISSION_GOOGLE_SIGN_IN=1',
      ]
    end
  end
end

File: ios/Runner/Info.plist

Add URL schemes for Google Sign-In:
────────────────────────────────────
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>com.googleusercontent.apps.YOUR_GOOGLE_CLIENT_ID</string>
    </array>
  </dict>
</array>

For Game Center (iOS):
──────────────────────
<key>NSGameCenterEnabled</key>
<true/>

═══════════════════════════════════════════════════════════════════════════════
STEP 6: SMTP EMAIL CONFIGURATION
═══════════════════════════════════════════════════════════════════════════════

Method 1: Using Firebase Cloud Functions (RECOMMENDED)
───────────────────────────────────────────────────────

1. Install Firebase CLI:
   npm install -g firebase-tools

2. Initialize Cloud Functions in your project:
   firebase init functions

3. Create function: functions/src/index.ts

   See provided: FIREBASE_CLOUD_FUNCTION_SMTP.ts
   
4. Update environment configuration:
   firebase functions:config:set mail.apikey="your-gmail-app-password"
   
5. Deploy:
   firebase deploy --only functions

Method 2: Gmail SMTP Setup
──────────────────────────

For questkids.dev@gmail.com:

1. Enable 2-Factor Authentication:
   • Go to: https://myaccount.google.com/security
   • Enable 2-Step Verification

2. Create App Password:
   • Go to: https://myaccount.google.com/apppasswords
   • Select: Mail + Windows Computer (or your setup)
   • Google will generate 16-character password
   • Copy this password

3. Update in Firebase Cloud Function:
   SMTP_USERNAME: questkids.dev@gmail.com
   SMTP_PASSWORD: [16-character app password from above]
   SMTP_HOST: smtp.gmail.com
   SMTP_PORT: 587
   SMTP_SECURITY: TLS

Configuration File: lib/core/config/smtp_config.dart
───────────────────────────────────────────────────
See provided: SMTP_CONFIG.dart

═══════════════════════════════════════════════════════════════════════════════
STEP 7: FIRESTORE DATABASE SETUP
═══════════════════════════════════════════════════════════════════════════════

Database Name: default (already created)
Location: us-central1 (or closest to your region)

Current Status: NO COLLECTIONS (ready for initial data)

Collections to Create (when needed):
───────────────────────────────────

1. users/
   Document structure:
   {
     "uid": "user_id",
     "email": "user@example.com",
     "displayName": "User Name",
     "authProvider": "email|google|phone|playGames|gameCenter",
     "createdAt": timestamp,
     "lastLogin": timestamp,
     "grade": 4,
     "points": 0,
     "level": 1,
     "isEmailVerified": false
   }

2. activities/ (quizzes, challenges)
   {
     "title": "Math Quiz 1",
     "subject": "mathematics",
     "difficulty": 1,
     "points": 100,
     "createdAt": timestamp
   }

3. progress/
   {
     "userId": "user_id",
     "activityId": "activity_id",
     "score": 85,
     "completedAt": timestamp,
     "timeSpent": 300
   }

4. rewards/
   {
     "userId": "user_id",
     "badges": ["badge1", "badge2"],
     "totalPoints": 5000,
     "level": 10,
     "updatedAt": timestamp
   }

5. notifications/
   {
     "userId": "user_id",
     "title": "Daily Challenge",
     "message": "Complete today's math challenge",
     "type": "achievement|reminder|reward",
     "read": false,
     "createdAt": timestamp
   }

Security Rules: (Update in Firebase Console)
──────────────

rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can only read/write their own data
    match /users/{userId} {
      allow read, write: if request.auth.uid == userId;
    }
    
    // Activities are publicly readable, written by admin only
    match /activities/{document=**} {
      allow read: if request.auth != null;
      allow write: if false; // Admin only via backend
    }
    
    // Progress entries are user-specific
    match /progress/{document=**} {
      allow read, write: if request.auth != null;
    }
    
    // Rewards are user-specific
    match /rewards/{userId} {
      allow read, write: if request.auth.uid == userId;
    }
    
    // Notifications are user-specific
    match /notifications/{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}

═══════════════════════════════════════════════════════════════════════════════
STEP 8: FLUTTER APP INTEGRATION
═══════════════════════════════════════════════════════════════════════════════

Files already created:
─────────────────────
✓ lib/core/services/auth_service.dart - Authentication service
✓ lib/core/services/email_service.dart - Email/SMTP service
✓ lib/core/services/firestore_service.dart - Firestore operations
✓ lib/firebase_options.dart - Firebase configuration (auto-generated)

Next: Add to pubspec.yaml (already done):
─────────────────────────────────────────
dependencies:
  firebase_core: ^3.0.0
  firebase_auth: ^5.0.0
  cloud_firestore: ^5.0.0
  firebase_storage: ^12.0.0
  firebase_messaging: ^15.0.0
  firebase_analytics: ^11.0.0
  google_sign_in: ^6.2.0
  play_games: ^3.0.0

═══════════════════════════════════════════════════════════════════════════════
STEP 9: TESTING AUTHENTICATION
═══════════════════════════════════════════════════════════════════════════════

Test Email/Password:
────────────────────
1. Create test account in Firebase Console
   • Authentication → Users → Add user
   • Email: test@questkids.com
   • Password: Test123456!

2. Run app and test login:
   flutter run -d chrome (or Android/iOS)

Test Google Sign-In:
─────────────────────
1. Use Google account: questkids.dev@gmail.com
2. Should redirect to Google login
3. Should create user document in Firestore

Test Phone:
───────────
1. Use test phone numbers configured in Firebase
2. Verify OTP flow

═══════════════════════════════════════════════════════════════════════════════
STEP 10: IMPORTANT FILES CHECKLIST
═══════════════════════════════════════════════════════════════════════════════

Location: What: Status:
─────────────────────────────────────────────────────────────
android/app/google-services.json ✓ Downloaded & placed
ios/Runner/GoogleService-Info.plist ✓ Already exists
lib/firebase_options.dart ✓ Auto-generated by flutterfire
lib/core/services/auth_service.dart ✓ Created
lib/core/services/email_service.dart ✓ Created
lib/core/services/firestore_service.dart ✓ Already created
pubspec.yaml ✓ Updated with auth packages
functions/src/index.ts ⏳ To be created for SMTP

═══════════════════════════════════════════════════════════════════════════════
DOWNLOADS & INSTALLATION SUMMARY
═══════════════════════════════════════════════════════════════════════════════

1. google-services.json
   • Download from: Firebase Console → Project Settings → Download
   • Place at: android/app/
   • Required for: Android authentication

2. GoogleService-Info.plist
   • Already in: ios/Runner/GoogleService-Info.plist
   • Required for: iOS authentication

3. Dependencies (run command):
   flutter pub get

4. Firebase CLI (for SMTP Cloud Functions):
   npm install -g firebase-tools
   firebase login
   firebase init functions

═══════════════════════════════════════════════════════════════════════════════
TROUBLESHOOTING
═══════════════════════════════════════════════════════════════════════════════

Android Google Sign-In not working:
• Ensure SHA-1 fingerprint is registered in Firebase Console
  Run: ./gradlew signingReport (in android/)
  Add fingerprint to Project Settings → Your apps

iOS Google Sign-In not working:
• Verify CFBundleURLSchemes in Info.plist
• Check CocoaPods: cd ios && pod update

Phone authentication fails:
• Verify RECAPTCHA is enabled in Firebase Console
• Add test phone numbers

SMTP emails not sending:
• Check Cloud Functions logs: firebase functions:log
• Verify Gmail App Password is correct
• Ensure 2FA is enabled on questkids.dev@gmail.com

═══════════════════════════════════════════════════════════════════════════════
SECURITY BEST PRACTICES
═══════════════════════════════════════════════════════════════════════════════

1. Never commit secrets to Git
   • Use Firebase Functions environment variables
   • Use .env file (add to .gitignore)

2. SMTP Password Security
   • Use Gmail App Passwords (not main account password)
   • Rotate periodically
   • Store in Firebase Cloud Functions only

3. Firestore Security Rules
   • Test rules in Firebase Console → Firestore → Rules
   • Never allow public write access
   • Implement proper role-based access control

4. User Data Protection
   • Enable email verification before some features
   • Require age verification for grade 4 learners
   • Implement parental consent where required

═══════════════════════════════════════════════════════════════════════════════
"""
