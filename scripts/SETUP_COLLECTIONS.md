# 🚀 Firestore Collections Setup

I've created **two scripts** for you - choose the one that works best:

## Option 1: Firebase Admin SDK (Recommended - Easiest) ⭐

This requires a service account key file (no additional software needed).

### Steps:

1. **Get service account key:**
   - Go to: https://console.firebase.google.com/project/questkids-mobile/settings/serviceaccounts/adminsdk
   - Click "Generate New Private Key"
   - Save the downloaded file as `serviceAccountKey.json` in the `scripts/` folder

2. **Run the script:**
   ```bash
   cd d:\Projects\QuestKids\scripts
   npx ts-node init-firestore-admin.ts
   ```

**Expected output:**
```
🚀 Initializing QuestKids Firestore Collections

📝 Creating "users" collection...
   ✅ demo-learner-1
   ✅ demo-parent-1
   ✅ demo-teacher-1

[... more collections ...]

🎉 All collections created successfully!
```

---

## Option 2: Google Cloud CLI (Alternative)

This uses gcloud authentication (requires Google Cloud SDK installation).

### Steps:

1. **Install Google Cloud SDK:**
   - Download from: https://cloud.google.com/sdk/docs/install
   - Run installer and follow prompts
   - After installation, open a new terminal

2. **Authenticate:**
   ```bash
   gcloud auth application-default login
   ```
   - This opens a browser window for Google sign-in
   - Accept permissions

3. **Run the script:**
   ```bash
   cd d:\Projects\QuestKids\scripts
   npx ts-node init-firestore-rest.ts
   ```

---

## ✅ After Running (Verification)

1. **Check Firebase Console:**
   - Go to: https://console.firebase.google.com/project/questkids-mobile/firestore/data
   - You should see 5 collections:
     - ✅ **users** (3 documents)
     - ✅ **activities** (3 documents)  
     - ✅ **progress** (1 document)
     - ✅ **rewards** (3 documents)
     - ✅ **notifications** (1 document)

2. **Test Collections:**
   - Click each collection to verify documents
   - Sample accounts created:
     - Learner: `learner@demo.com` (Grade 4)
     - Parent: `parent@demo.com`
     - Teacher: `teacher@demo.com` (Grade 4)

3. **Security Rules:**
   - Your Firestore and Storage rules are already deployed
   - Test access restrictions in the Rules Playground

---

## 🆘 Troubleshooting

**"ServiceAccountKey.json not found"**
- Get it from Firebase Console settings (Option 1 step 1)
- Make sure it's in `d:\Projects\QuestKids\scripts\`

**"gcloud is not recognized"**
- Install Google Cloud SDK: https://cloud.google.com/sdk/docs/install
- Or use Option 1 (Firebase Admin SDK) instead

**"Permission denied" errors**
- Make sure you're signed in with the correct Google account
- Use `gcloud auth application-default login` or sign in to Firebase Console

---

## 📝 What Gets Created

Each script creates the same data:

### Users (3 documents)
- **demo-learner-1**: A student in Grade 4
- **demo-parent-1**: Parent linked to the learner
- **demo-teacher-1**: Teacher for Grade 4

### Activities (3 documents)
- **math-fractions-001**: Math quiz on fractions (25 points)
- **science-planets-001**: Science practical activity (30 points)
- **english-reading-001**: English reading quiz (20 points)

### Progress (1 document)
- Sample completion record for math quiz

### Rewards (3 documents)
- Reward tracking for each user

### Notifications (1 document)
- Welcome notification for learner

---

Choose **Option 1** if you just want to get collections created quickly. Choose **Option 2** if you already have Google Cloud SDK installed.
