# 🚀 Quick Start: Auto-Create Collections

## ⚡ Fastest Way (2 minutes)

### Option 1: Using gcloud CLI (Easiest - No Service Account Key)

```bash
# Step 1: Install gcloud if not already installed
# https://cloud.google.com/sdk/docs/install

# Step 2: Authenticate with Google Cloud
gcloud auth application-default login

# Step 3: Go to scripts folder
cd d:\Projects\QuestKids\scripts

# Step 4: Install dependencies
npm install

# Step 5: Create collections
npm run init
```

✅ **That's it!** Firestore will be populated automatically.

---

### Option 2: Using Service Account Key

```bash
# Step 1: Get the service account key
# 1. Go to https://console.firebase.google.com/project/questkids-mobile/settings/serviceaccounts/adminsdk
# 2. Click "Generate New Private Key"
# 3. Save as d:\Projects\QuestKids\questkids-key.json

# Step 2: Create collections
cd d:\Projects\QuestKids\scripts
npm install
npm run init
```

---

### Option 3: Using REST API (No Setup Needed!)

```bash
# Just run:
cd d:\Projects\QuestKids\scripts
npm install axios
npx ts-node init-firestore-rest.ts
```

---

## 📊 What Gets Created

After running any option above:

✅ **5 Collections** with sample data:
- `users` (3 demo users)
- `activities` (3 educational quests)
- `progress` (learning records)
- `rewards` (badges & achievements)
- `notifications` (4 notifications)

✅ **Sample Users**:
- `demo-learner-1` - Student account
- `demo-parent-1` - Parent linked to learner
- `demo-teacher-1` - Teacher account

✅ **Sample Quests**:
- Math: Fractions quiz
- Science: Solar System
- English: Reading comprehension

---

## ✅ Verify It Worked

After running the script:

1. Check console for ✅ messages
2. Open Firebase Console: https://console.firebase.google.com/project/questkids-mobile/firestore/data
3. You should see all 5 collections
4. Click on any collection to view documents

---

## 🧪 Test the App

```bash
cd d:\Projects\QuestKids
flutter run
```

Your app is now fully set up with:
- ✅ Authentication working
- ✅ Dashboard displaying
- ✅ Collections with data
- ✅ Security rules active

Ready to start development! 🚀

---

## ⚠️ Troubleshooting

**"Cannot find module 'firebase-admin'"**
→ Run: `npm install` in scripts folder

**"gcloud: command not found"**
→ Install Google Cloud CLI from https://cloud.google.com/sdk/docs/install

**"PERMISSION_DENIED"**
→ Your account doesn't have permission. Ask project owner to add you.

---

Choose any of the 3 options above and you're done! ⚡
