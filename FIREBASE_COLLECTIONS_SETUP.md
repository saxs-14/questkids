# Firebase Setup Guide - Collections & Rules

This guide explains how to set up Firestore collections, apply security rules, and configure Storage in your Firebase project.

---

## 📋 Table of Contents
1. [Firestore Collections Setup](#firestore-collections-setup)
2. [Applying Firestore Rules](#applying-firestore-rules)
3. [Storage Configuration](#storage-configuration)
4. [Collection Schemas](#collection-schemas)

---

## 🔥 Firestore Collections Setup

### Step 1: Create Collections in Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project: **questkids-mobile**
3. Navigate to **Cloud Firestore**
4. Click **Start collection**
5. Create the following collections (in order):

#### Collection 1: `users`
- **Document ID**: `auto`
- **Sample Document**:
```json
{
  "uid": "user123",
  "name": "John Doe",
  "email": "john@example.com",
  "role": "learner",
  "grade": "Grade 4",
  "parentUid": "",
  "avatarUrl": "",
  "totalPoints": 150,
  "streakDays": 5,
  "createdAt": 1716547200000,
  "linkedChildrenUids": []
}
```

#### Collection 2: `activities`
- **Document ID**: `auto`
- **Sample Document**:
```json
{
  "id": "activity001",
  "title": "Math Quiz - Fractions",
  "description": "Learn about fractions and solve problems",
  "subject": "Math",
  "type": "quiz",
  "difficulty": "medium",
  "rewardPoints": 25,
  "grade": "Grade 4",
  "requiresProof": false,
  "createdAt": 1716547200000,
  "questions": [
    {
      "question": "What is 1/2 + 1/4?",
      "options": ["1/2", "3/4", "1/4", "1/6"],
      "correctIndex": 1,
      "explanation": "1/2 = 2/4, so 2/4 + 1/4 = 3/4"
    }
  ]
}
```

#### Collection 3: `progress`
- **Document ID**: `auto`
- **Sample Document**:
```json
{
  "uid": "user123",
  "activityId": "activity001",
  "activityTitle": "Math Quiz - Fractions",
  "subject": "Math",
  "score": 100,
  "pointsEarned": 25,
  "completed": true,
  "verified": false,
  "proofUrl": "",
  "completedAt": 1716547200000,
  "timeTakenSeconds": 300
}
```

#### Collection 4: `rewards`
- **Document ID**: Use user UID
- **Sample Document**:
```json
{
  "uid": "user123",
  "totalPoints": 150,
  "level": 1,
  "streakDays": 5,
  "lastActiveDate": 1716547200000,
  "badges": [
    {
      "id": "badge001",
      "name": "First Quest",
      "description": "Complete your first quest",
      "icon": "🎯",
      "category": "special",
      "earnedAt": 1716547200000
    }
  ],
  "achievements": []
}
```

#### Collection 5: `notifications`
- **Document ID**: `auto`
- **Sample Document**:
```json
{
  "userId": "user123",
  "title": "Achievement Unlocked!",
  "body": "You earned the 'First Quest' badge!",
  "type": "achievement",
  "read": false,
  "createdAt": 1716547200000
}
```

---

## 📜 Applying Firestore Rules

### Step 1: Copy Firestore Rules
1. Open `firestore.rules` file in your project root
2. Copy all the rules

### Step 2: Deploy Rules to Firebase

**Option A: Using Firebase Console**
1. Go to **Firebase Console** → Your Project → **Cloud Firestore**
2. Click **Rules** tab
3. Paste the rules from `firestore.rules`
4. Click **Publish**

**Option B: Using Firebase CLI**
```bash
# Install Firebase CLI (if not already installed)
npm install -g firebase-tools

# Login to Firebase
firebase login

# Initialize Firebase in your project
firebase init

# Deploy rules
firebase deploy --only firestore:rules
```

---

## 💾 Storage Configuration

### Step 1: Copy Storage Rules
1. Open `storage.rules` file in your project root
2. Copy all the rules

### Step 2: Deploy Storage Rules

**Option A: Using Firebase Console**
1. Go to **Firebase Console** → Your Project → **Storage**
2. Click **Rules** tab
3. Paste the rules from `storage.rules`
4. Click **Publish**

**Option B: Using Firebase CLI**
```bash
firebase deploy --only storage
```

### Step 3: Create Storage Buckets (if needed)
1. Go to **Firebase Console** → **Storage**
2. Click **Get Started**
3. The default bucket should be created automatically
4. Create the following directories:
   - `avatars/`
   - `progress/`
   - `activities/`

---

## 📊 Collection Schemas Reference

### Users Collection
| Field | Type | Description |
|-------|------|-------------|
| `uid` | String | User's unique Firebase ID |
| `name` | String | User's full name |
| `email` | String | User's email address |
| `role` | String | User role: learner, parent, teacher, admin |
| `grade` | String | Grade level (for learners) |
| `parentUid` | String | Parent's UID (if learner) |
| `avatarUrl` | String | URL to user's profile picture |
| `totalPoints` | Number | Total points earned |
| `streakDays` | Number | Current streak days |
| `createdAt` | Timestamp | Account creation date |
| `linkedChildrenUids` | Array | Children UIDs (for parents) |

### Activities Collection
| Field | Type | Description |
|-------|------|-------------|
| `id` | String | Activity's unique ID |
| `title` | String | Activity title |
| `description` | String | Activity description |
| `subject` | String | Subject: Math, Science, English, Social Sciences |
| `type` | String | Activity type: quiz, practical, responsibility |
| `difficulty` | String | Difficulty: easy, medium, hard |
| `rewardPoints` | Number | Points awarded on completion |
| `grade` | String | Target grade level |
| `questions` | Array | List of questions (for quizzes) |
| `requiresProof` | Boolean | Whether proof upload is needed |
| `createdAt` | Timestamp | Creation date |

### Progress Collection
| Field | Type | Description |
|-------|------|-------------|
| `uid` | String | Learner's UID |
| `activityId` | String | Activity's ID |
| `activityTitle` | String | Activity's title |
| `subject` | String | Subject of activity |
| `score` | Number | Score percentage (0-100) |
| `pointsEarned` | Number | Points earned |
| `completed` | Boolean | Is activity completed? |
| `verified` | Boolean | Is progress verified by parent/teacher? |
| `proofUrl` | String | URL to proof image |
| `completedAt` | Timestamp | Completion date |
| `timeTakenSeconds` | Number | Time taken in seconds |

### Rewards Collection
| Field | Type | Description |
|-------|------|-------------|
| `uid` | String | User's UID |
| `totalPoints` | Number | Total points |
| `level` | Number | Current level |
| `streakDays` | Number | Current streak |
| `lastActiveDate` | Timestamp | Last activity date |
| `badges` | Array | List of earned badges |
| `achievements` | Array | List of achievements |

### Notifications Collection
| Field | Type | Description |
|-------|------|-------------|
| `userId` | String | Target user's UID |
| `title` | String | Notification title |
| `body` | String | Notification message |
| `type` | String | Type: achievement, reminder, alert |
| `read` | Boolean | Has user read it? |
| `createdAt` | Timestamp | Creation date |

---

## 🔐 Security Rules Explanation

### Users Collection Rules
- ✅ Users can read/write their own profile
- ✅ Parents can view their linked children's profiles
- ✅ Teachers can view learner profiles

### Activities Collection Rules
- ✅ All signed-in users can read activities
- ✅ Only teachers and admins can create/modify activities

### Progress Collection Rules
- ✅ Learners can create and update their own progress
- ✅ Parents and teachers can verify progress
- ✅ Parents can view their children's progress
- ✅ Teachers can view all learner progress

### Rewards Collection Rules
- ✅ Users can manage their own rewards
- ✅ Parents can view their children's rewards

### Storage Rules
- ✅ Users can upload avatars only to their own folder
- ✅ Users can upload proof to their progress folder
- ✅ Parents can view children's progress proofs
- ✅ Teachers can view proofs for verification
- ✅ All images limited to 5MB
- ✅ Only image files allowed

---

## ✅ Verification Checklist

After setup, verify:
- [ ] All 5 collections created in Firestore
- [ ] Firestore rules deployed and published
- [ ] Storage rules deployed and published
- [ ] Storage buckets created (avatars, progress, activities)
- [ ] Test collections have sample documents
- [ ] Security rules allow intended access patterns
- [ ] Rules deny unauthorized access

---

## 🔍 Testing Rules

You can test the rules in Firebase Console:

1. Go to **Cloud Firestore** → **Rules**
2. Click **Rules Playground** at bottom
3. Select a collection and test read/write permissions
4. Test with different user roles to verify security

---

## 📚 Additional Resources

- [Firebase Firestore Documentation](https://firebase.google.com/docs/firestore)
- [Firebase Storage Documentation](https://firebase.google.com/docs/storage)
- [Security Rules Guide](https://firebase.google.com/docs/rules)

---

**Last Updated**: May 24, 2026
**Version**: 1.0
