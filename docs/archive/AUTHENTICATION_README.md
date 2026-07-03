# QuestKids 2.0 - Authentication & Firebase Integration

## 📋 Overview

This document provides a complete guide to the authentication system implemented for QuestKids 2.0, a gamified learning platform for grade 4 students.

### Key Features
- ✅ Email/Password authentication with verification
- ✅ Phone number authentication with OTP
- ✅ Google Sign-In for parents/guardians
- ✅ Play Games Services for Android
- ✅ Game Center support for iOS
- ✅ Automated email notifications via SMTP
- ✅ Firestore for secure data storage
- ✅ Cloud Functions for backend operations
- ✅ Complete error handling and user-friendly messages

---

## 🏗️ Architecture

### Service Layer
```
lib/core/services/
├── auth_service.dart          # 5 authentication provider implementations
├── email_service.dart          # Email templates and SMTP configuration
├── firestore_service.dart      # Database operations (CRUD)
└── firebase_initializer.dart   # Firebase initialization & configuration
```

### Data Models
```
lib/data/models/
└── auth_models.dart            # User, Request, Response models
```

### Configuration
```
lib/config/
└── firebase_config.dart        # Configuration constants & environment settings
```

### Cloud Functions
```
functions/src/
├── index.ts                    # SMTP email delivery via Nodemailer
├── package.json               # Dependencies management
└── tsconfig.json              # TypeScript configuration
```

---

## 🔐 Authentication Methods

### 1. Email/Password Authentication

**Flow:**
1. User enters email and password
2. Firebase validates and creates auth user
3. Firestore document created with user profile
4. Welcome email sent via Cloud Functions
5. Email verification link provided

**File:** `lib/core/services/auth_service.dart`

**Methods:**
```dart
// Sign up with email
Future<AuthResponse> signUpWithEmail(String email, String password, String displayName)

// Sign in with email
Future<AuthResponse> signInWithEmail(String email, String password)

// Send email verification
Future<void> sendEmailVerification()

// Verify email
Future<bool> verifyEmail(String code)

// Reset password
Future<void> resetPassword(String email)
```

### 2. Phone Number Authentication (OTP)

**Flow:**
1. User enters phone number
2. Firebase generates OTP and sends SMS
3. User enters 6-digit OTP code
4. Firebase verifies and creates auth user
5. User profile created in Firestore

**File:** `lib/core/services/auth_service.dart`

**Methods:**
```dart
// Send OTP to phone
Future<String> sendPhoneOTP(String phoneNumber)

// Verify OTP code
Future<AuthResponse> verifyPhoneOTP(String verificationId, String smsCode)
```

### 3. Google Sign-In

**Flow:**
1. User taps "Sign in with Google"
2. Google OAuth flow opens
3. User selects Google account
4. Google credential returned to app
5. Firebase authenticates with Google credential
6. Firestore document created with user info

**File:** `lib/core/services/auth_service.dart`

**Method:**
```dart
Future<AuthResponse> signInWithGoogle()
```

**Setup Required:**
- OAuth 2.0 credentials from Google Cloud Console
- Configure redirect URIs for web/mobile

### 4. Play Games Services (Android)

**Flow:**
1. User taps "Play Games Sign-In"
2. Play Games authentication dialog opens
3. User authenticates with Google account
4. Play Games credential returned
5. Firebase authenticates
6. Leaderboards and achievements integration ready

**File:** `lib/core/services/auth_service.dart`

**Method:**
```dart
Future<AuthResponse> signInWithPlayGames()
```

**Setup Required:**
- Google Play Developer account
- Play Games configuration in Play Console
- Debug keystore SHA-1 fingerprint registered

### 5. Game Center (iOS)

**Flow:**
1. User taps "Game Center Sign-In"
2. Game Center authentication sheet appears
3. User authenticates
4. Game Center credential returned
5. Firebase authenticates
6. Leaderboards and achievements ready

**File:** `lib/core/services/auth_service.dart`

**Method:**
```dart
Future<AuthResponse> signInWithGameCenter()
```

**Setup Required:**
- Apple Developer account
- Xcode Game Center configuration
- App Store Connect setup

---

## 📧 Email Service

### Email Configuration

**SMTP Settings:**
- Host: `smtp.gmail.com`
- Port: `587`
- Security: `TLS`
- Username: `questkids.dev@gmail.com`
- Password: Gmail App Password (16 characters)

**File:** `lib/core/services/email_service.dart`

### Email Templates

1. **Welcome Email**
   - Sent on successful signup
   - Contains greeting and getting started guide
   - Action: Verify email

2. **Email Verification**
   - Sent to verify email ownership
   - Contains verification link
   - 24-hour expiration

3. **Password Reset**
   - Sent when user requests password reset
   - Contains reset link
   - 24-hour expiration

4. **Achievement Notification**
   - Sent when user earns achievement/badge
   - Contains achievement details
   - Shows points earned

5. **Daily Challenge Reminder**
   - Sent each morning
   - Contains today's challenge
   - Encourages participation

6. **Level Up Notification**
   - Sent when user advances level
   - Shows current progress
   - Celebrates achievement

### Sending Emails

**File:** `lib/core/services/email_service.dart`

**Method:**
```dart
// Send welcome email
await EmailService().sendWelcomeEmail(
  email: user.email,
  displayName: user.displayName,
);

// Send achievement email
await EmailService().sendAchievementEmail(
  email: user.email,
  displayName: user.displayName,
  achievement: 'Math Master',
  points: 100,
);
```

### Cloud Functions Email Delivery

**File:** `functions/src/index.ts`

**How it works:**
1. App writes email document to Firestore 'emails' collection
2. Cloud Function triggers on document creation
3. Function reads email template and data
4. Nodemailer connects to Gmail SMTP
5. Email sent to recipient
6. Document marked as sent
7. Automatic cleanup after 30 days

**Setup:**
```bash
# Install dependencies
cd functions && npm install

# Set Gmail credentials
firebase functions:config:set \
  mail.sender="questkids.dev@gmail.com" \
  mail.password="your-16-char-app-password"

# Deploy
firebase deploy --only functions
```

---

## 💾 Firestore Database

### Collections Structure

#### Users Collection
```
/users/{uid}
├── uid: string
├── email: string
├── displayName: string
├── phoneNumber: string (optional)
├── photoUrl: string (optional)
├── authProvider: string (email|phone|google|playGames|gameCenter)
├── grade: number (default: 4)
├── points: number (default: 0)
├── level: number (default: 1)
├── isEmailVerified: boolean (default: false)
├── createdAt: timestamp
└── lastLogin: timestamp
```

#### Activities Collection
```
/activities/{activityId}
├── id: string
├── title: string
├── subject: string (math|science|english|social-studies)
├── gradeLevel: number
├── description: string
├── difficulty: string (easy|medium|hard)
├── pointsValue: number
├── estimatedTime: number (minutes)
├── imageUrl: string
├── createdAt: timestamp
└── updatedAt: timestamp
```

#### Progress Collection
```
/progress/{progressId}
├── userId: string (reference to /users/{uid})
├── activityId: string (reference to /activities/{id})
├── score: number
├── completionTime: number (seconds)
├── attemptsCount: number
├── completedAt: timestamp
└── updatedAt: timestamp
```

#### Rewards Collection
```
/rewards/{rewardId}
├── userId: string (reference to /users/{uid})
├── rewardName: string
├── rewardType: string (badge|achievement|points)
├── pointsEarned: number
├── earnedAt: timestamp
└── description: string
```

#### Notifications Collection
```
/notifications/{notificationId}
├── userId: string (reference to /users/{uid})
├── title: string
├── body: string
├── type: string (achievement|challenge|daily|system)
├── relatedEntityId: string (optional)
├── isRead: boolean
├── createdAt: timestamp
└── expiresAt: timestamp
```

#### Emails Collection (Internal)
```
/emails/{emailId}
├── to: string
├── subject: string
├── template: string
├── data: object
├── sent: boolean
├── sentAt: timestamp (optional)
├── error: string (optional)
└── createdAt: timestamp
```

### Security Rules

**File:** Apply in Firebase Console

**Features:**
- Users can only read/write their own data
- Activities are read-only for students
- Authenticated users can save progress
- Automatic user authorization checks
- Admin-only operations via Cloud Functions

**Rules Location:** `FIREBASE_SETUP_GUIDE.md` → Security Rules section

---

## 📱 Using the Authentication Services

### Initialization

**In `main.dart`:**
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await FirebaseInitializer().initialize();
  
  runApp(const QuestKidsApp());
}
```

### Sign Up Flow

```dart
// Create signup request
SignUpRequest request = SignUpRequest(
  email: 'student@example.com',
  password: 'SecurePass123',
  displayName: 'John Doe',
  grade: 4,
);

// Call auth service
final authService = AuthService();
final response = await authService.signUpWithEmail(
  request.email,
  request.password,
  request.displayName,
);

// Handle response
if (response.success) {
  print('Signup successful: ${response.user?.displayName}');
  // Navigate to home screen
} else {
  print('Signup error: ${response.error}');
  // Show error dialog
}
```

### Sign In Flow

```dart
// Create login request
LoginRequest request = LoginRequest(
  email: 'student@example.com',
  password: 'SecurePass123',
);

// Call auth service
final authService = AuthService();
final response = await authService.signInWithEmail(
  request.email,
  request.password,
);

// Handle response
if (response.success) {
  print('Login successful: ${response.user?.email}');
  // Navigate to home screen
} else {
  print('Login error: ${response.error}');
  // Show error dialog
}
```

### Google Sign-In Flow

```dart
final authService = AuthService();
final response = await authService.signInWithGoogle();

if (response.success) {
  print('Google Sign-In successful');
  // Navigate to home
} else {
  print('Error: ${response.error}');
}
```

### Phone OTP Flow

```dart
final authService = AuthService();

// Step 1: Send OTP
final verificationId = await authService.sendPhoneOTP('+1234567890');

// Step 2: User enters SMS code
final response = await authService.verifyPhoneOTP(
  verificationId: verificationId,
  smsCode: '123456', // User-entered SMS code
);

if (response.success) {
  print('Phone verified and signed in');
}
```

### Sign Out

```dart
final authService = AuthService();
await authService.signOut();
```

---

## 🔧 Configuration Files

### Environment Configuration
**File:** `lib/config/firebase_config.dart`

Contains all configuration constants:
- Firebase project ID
- SMTP settings
- Collection names
- Feature flags
- API endpoints

### Models
**File:** `lib/data/models/auth_models.dart`

Defines all data models:
- `UserProfile` - User information
- `LoginRequest` - Login credentials
- `SignUpRequest` - Registration data
- `AuthResponse` - Auth operation results
- `PhoneVerificationRequest` - OTP flow data

### Environment File
**File:** `.env.example`

Template for environment variables. Copy to `.env` and update values.
⚠️ Never commit `.env` to version control!

---

## 🚀 Deployment Checklist

### Pre-Deployment
- [ ] All Firebase providers enabled in Console
- [ ] google-services.json downloaded and placed
- [ ] GoogleService-Info.plist verified (iOS)
- [ ] Gmail App Password generated
- [ ] Cloud Functions deployed
- [ ] Firestore rules applied
- [ ] Test phone numbers configured

### Deployment
- [ ] All dependencies updated (`flutter pub get`)
- [ ] Build signed Android APK/AAB
- [ ] Build iOS app with Xcode
- [ ] Test on physical devices
- [ ] Verify email sending
- [ ] Monitor Cloud Functions logs

### Post-Deployment
- [ ] Monitor auth errors in Firebase Console
- [ ] Monitor email delivery logs
- [ ] Check user signup metrics
- [ ] Review Firestore costs
- [ ] Monitor Cloud Functions execution time

---

## 🐛 Troubleshooting

### Email Not Sending
**Problem:** Cloud Functions triggered but email not received

**Solution:**
1. Check Firebase Functions logs: `firebase functions:log`
2. Verify Gmail App Password is correct
3. Ensure 2FA enabled on questkids.dev@gmail.com
4. Check Firestore 'emails' collection for failed emails
5. Verify SMTP credentials in Functions config

### Google Sign-In Fails
**Problem:** Google Sign-In dialog appears but doesn't work

**Solution:**
1. Verify OAuth credentials in Google Cloud Console
2. Check package name (Android): com.questkids.questkids
3. Register SHA-1 fingerprint: `./gradlew signingReport`
4. Verify CFBundleURLSchemes in Info.plist (iOS)
5. Check Facebook/Google OAuth configuration

### Phone OTP Not Received
**Problem:** SMS codes not arriving

**Solution:**
1. Enable RECAPTCHA in Firebase Console
2. Add test phone numbers for testing
3. Check Firebase Phone Auth quotas
4. Verify phone number format: +1 [country code][number]

### Firestore Permission Denied
**Problem:** User can't read/write Firestore data

**Solution:**
1. Check Firestore security rules
2. Verify user is authenticated
3. Ensure user UID in document path
4. Check rule structure for correct collection names

---

## 📚 Dependencies

### Flutter Packages
```yaml
firebase_core: ^3.0.0
firebase_auth: ^5.0.0
cloud_firestore: ^5.0.0
firebase_storage: ^12.0.0
firebase_messaging: ^15.0.0
firebase_analytics: ^11.0.0
google_sign_in: ^6.2.0
play_games: ^3.0.0
```

### Cloud Functions
```
firebase-admin: ^11.10.1
firebase-functions: ^4.4.1
nodemailer: ^6.9.7
```

---

## 🔒 Security Best Practices

1. **Never Expose Secrets**
   - Gmail password only in Cloud Functions
   - OAuth credentials in Firebase Console
   - Use environment variables, not hardcoded values

2. **Firestore Security Rules**
   - Users access only their own data
   - Verify authentication in all rules
   - Use custom claims for admin operations

3. **Password Requirements**
   - Minimum 8 characters
   - Mix of uppercase, lowercase, numbers
   - Firebase handles hashing

4. **Email Verification**
   - Require email verification for sensitive ops
   - 24-hour link expiration
   - Resend option available

5. **Rate Limiting**
   - Implement to prevent brute force
   - Monitor login failures
   - Lock account after 5 failed attempts

6. **Parental Consent**
   - For grade 4 learners under 13
   - Collect parent email verification
   - COPPA compliance for US deployments

---

## 📞 Support Resources

- **Firebase Docs:** https://firebase.google.com/docs
- **FlutterFire:** https://firebase.flutter.dev/
- **Google Sign-In:** https://pub.dev/packages/google_sign_in
- **Play Games:** https://pub.dev/packages/play_games
- **Nodemailer:** https://nodemailer.com/
- **Firestore:** https://firebase.google.com/docs/firestore

---

## 🎉 Next Steps

1. ✅ Review this documentation
2. ✅ Download `google-services.json`
3. ✅ Deploy Cloud Functions
4. ✅ Set up test accounts
5. ✅ Test all authentication flows
6. ✅ Monitor logs and metrics
7. ✅ Prepare for production deployment

---

**Created:** 2024
**For:** QuestKids 2.0 Project
**Version:** 2.0.0

Happy coding! 🚀
