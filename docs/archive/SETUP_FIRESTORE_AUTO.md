# 🚀 Automatic Firebase Collections Setup

This guide will help you automatically create all Firestore collections with sample data.

---

## 📋 Prerequisites

1. ✅ Firebase CLI installed (`firebase --version` should work)
2. ✅ Node.js installed (`node --version` should show v16+)
3. ✅ Firestore & Storage rules deployed (already done ✅)

---

## Step 1: Get Firebase Service Account Key

### A. Go to Firebase Console

1. Open: https://console.firebase.google.com/project/questkids-mobile
2. Click **⚙️ Project Settings** (gear icon, top right)
3. Go to **Service Accounts** tab
4. Click **Generate New Private Key** button

### B. A JSON file will download

It will look like `questkids-mobile-*.json` - this contains your credentials.

### C. Add the key to your project

Move the downloaded file to your project root:
```bash
# On Windows PowerShell:
Move-Item "Downloads\questkids-mobile-*.json" "d:\Projects\QuestKids\questkids-key.json"

# Or copy-paste manually to: d:\Projects\QuestKids\questkids-key.json
```

---

## Step 2: Install Dependencies

Run in your project root:

```bash
cd d:\Projects\QuestKids\scripts
npm install
```

This will install:
- `firebase-admin` - Firebase Admin SDK
- `ts-node` - TypeScript runner
- `typescript` - TypeScript compiler

---

## Step 3: Run the Collection Setup Script

```bash
cd d:\Projects\QuestKids\scripts
npm run init
```

### What it will do:

✅ **Create 5 Collections**:
1. `users` - 3 sample users (learner, parent, teacher)
2. `activities` - 3 educational quests
3. `progress` - 3 progress records
4. `rewards` - Rewards for all users
5. `notifications` - 4 notifications

✅ **Add Sample Data**:
- Demo learner with badges and achievements
- Demo parent linked to learner
- Demo teacher
- Multiple activities across subjects (Math, Science, English)
- Progress records showing completed and pending activities
- Reward badges and streaks

---

## 🔍 Verify It Worked

After running the script:

1. **Check console output** - Should see ✅ for each collection
2. **Open Firebase Console**:
   - https://console.firebase.google.com/project/questkids-mobile/firestore/data
   - You should see all 5 collections with documents

3. **Verify data** - Click on each collection to view documents

---

## 📊 Sample Data Created

### Users
```
demo-learner-1
  ├── name: Demo Learner
  ├── email: learner@demo.com
  ├── role: learner
  ├── totalPoints: 150
  └── streakDays: 5

demo-parent-1
  ├── name: Demo Parent
  ├── email: parent@demo.com
  ├── role: parent
  └── linkedChildrenUids: [demo-learner-1]

demo-teacher-1
  ├── name: Demo Teacher
  ├── email: teacher@demo.com
  ├── role: teacher
  └── grade: Grade 4
```

### Activities
```
math-fractions-001
  ├── title: Math Quest: Fractions
  ├── points: 25
  └── 3 quiz questions

science-planets-001
  ├── title: Science Quest: The Solar System
  ├── points: 30
  └── requires proof

english-reading-001
  ├── title: English Quest: Reading Comprehension
  ├── points: 20
  └── quiz questions
```

### Progress
```
- Learner completed Math & English quests
- Science quest pending
- Some verified, some waiting for parent/teacher verification
```

### Rewards
```
- Badges: "First Quest", "Math Master"
- Achievements: "Streak Started"
- Points: 150
- Level: 1
- Streak: 5 days
```

---

## 🧪 Test with the App

After collections are created:

```bash
# Build and run the Flutter app
cd d:\Projects\QuestKids
flutter run
```

### Sign in with demo account:
- **Email**: `learner@demo.com`
- **Password**: (You'll need to create this account separately)

Or create a new account to test the registration flow.

---

## ⚠️ Troubleshooting

### Error: "Service account key not found"

**Solution**: Make sure the key file is at `d:\Projects\QuestKids\questkids-key.json`

```bash
# Check if file exists:
Test-Path "d:\Projects\QuestKids\questkids-key.json"
# Should return: True
```

### Error: "node: command not found"

**Solution**: Node.js not installed. Download from https://nodejs.org/

### Error: "npm: command not found"

**Solution**: npm comes with Node.js. Reinstall or restart terminal.

### Error: "PERMISSION_DENIED"

**Solution**: Your service account key permissions issue:
1. Delete the key from Firebase Console
2. Generate a new one
3. Try again

### Error: "Cannot find module 'firebase-admin'"

**Solution**: Run `npm install` in the scripts directory:
```bash
cd d:\Projects\QuestKids\scripts
npm install
```

---

## 🔒 Security Note

⚠️ **IMPORTANT**: 
- The `questkids-key.json` file contains sensitive credentials
- **Never commit it to Git** - it's already in `.gitignore`
- **Don't share it** with anyone
- If compromised, delete it from Firebase Console and generate a new one

---

## 📝 Next Steps

1. ✅ Get service account key
2. ✅ Run `npm install` in scripts folder
3. ✅ Run `npm run init`
4. ✅ Verify collections in Firebase Console
5. ✅ Run your Flutter app and test sign-in

---

## 🎉 After Setup

Your app will have:

- ✅ Live Firestore rules protecting data
- ✅ Live Storage rules for uploads
- ✅ 5 collections with sample data
- ✅ Demo users to test with
- ✅ Sample quests and progress
- ✅ Ready for development!

---

**Estimated Time**: 5 minutes
**Difficulty**: Easy
**Support**: Check firebase-debug.log for detailed errors
