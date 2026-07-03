# 📋 Firestore Collections - Manual Setup Data

Copy and paste this data into Firebase Console to create collections manually.

---

## 1️⃣ USERS Collection

### Document: `demo-learner-1`
```json
{
  "uid": "demo-learner-1",
  "name": "Demo Learner",
  "email": "learner@demo.com",
  "role": "learner",
  "grade": "Grade 4",
  "parentUid": "",
  "avatarUrl": "",
  "totalPoints": 150,
  "streakDays": 5,
  "createdAt": "2026-05-24T00:00:00Z",
  "linkedChildrenUids": []
}
```

### Document: `demo-parent-1`
```json
{
  "uid": "demo-parent-1",
  "name": "Demo Parent",
  "email": "parent@demo.com",
  "role": "parent",
  "grade": "",
  "parentUid": "",
  "avatarUrl": "",
  "totalPoints": 0,
  "streakDays": 0,
  "createdAt": "2026-05-24T00:00:00Z",
  "linkedChildrenUids": ["demo-learner-1"]
}
```

### Document: `demo-teacher-1`
```json
{
  "uid": "demo-teacher-1",
  "name": "Demo Teacher",
  "email": "teacher@demo.com",
  "role": "teacher",
  "grade": "Grade 4",
  "parentUid": "",
  "avatarUrl": "",
  "totalPoints": 0,
  "streakDays": 0,
  "createdAt": "2026-05-24T00:00:00Z",
  "linkedChildrenUids": []
}
```

---

## 2️⃣ ACTIVITIES Collection

### Document: `math-fractions-001`
```json
{
  "id": "math-fractions-001",
  "title": "Math Quest: Fractions",
  "description": "Master the fundamentals of fractions",
  "subject": "Math",
  "type": "quiz",
  "difficulty": "medium",
  "rewardPoints": 25,
  "grade": "Grade 4",
  "requiresProof": false,
  "createdAt": "2026-05-24T00:00:00Z",
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

### Document: `science-planets-001`
```json
{
  "id": "science-planets-001",
  "title": "Science Quest: The Solar System",
  "description": "Explore the planets",
  "subject": "Science",
  "type": "practical",
  "difficulty": "easy",
  "rewardPoints": 30,
  "grade": "Grade 4",
  "requiresProof": true,
  "createdAt": "2026-05-24T00:00:00Z",
  "questions": []
}
```

### Document: `english-reading-001`
```json
{
  "id": "english-reading-001",
  "title": "English Quest: Reading Comprehension",
  "description": "Improve your reading skills",
  "subject": "English",
  "type": "quiz",
  "difficulty": "easy",
  "rewardPoints": 20,
  "grade": "Grade 4",
  "requiresProof": false,
  "createdAt": "2026-05-24T00:00:00Z",
  "questions": []
}
```

---

## 3️⃣ REWARDS Collection

### Document: `demo-learner-1`
```json
{
  "uid": "demo-learner-1",
  "totalPoints": 150,
  "level": 1,
  "streakDays": 5,
  "lastActiveDate": "2026-05-24T00:00:00Z",
  "badges": [
    {
      "id": "first-quest",
      "name": "First Quest",
      "description": "Complete your first quest",
      "icon": "🎯",
      "category": "special",
      "earnedAt": "2026-05-24T00:00:00Z"
    }
  ],
  "achievements": []
}
```

### Document: `demo-parent-1`
```json
{
  "uid": "demo-parent-1",
  "totalPoints": 0,
  "level": 1,
  "streakDays": 0,
  "lastActiveDate": "2026-05-24T00:00:00Z",
  "badges": [],
  "achievements": []
}
```

### Document: `demo-teacher-1`
```json
{
  "uid": "demo-teacher-1",
  "totalPoints": 0,
  "level": 1,
  "streakDays": 0,
  "lastActiveDate": "2026-05-24T00:00:00Z",
  "badges": [],
  "achievements": []
}
```

---

## 4️⃣ PROGRESS Collection

### Document: `progress-1`
```json
{
  "uid": "demo-learner-1",
  "activityId": "math-fractions-001",
  "activityTitle": "Math Quest: Fractions",
  "subject": "Math",
  "score": 100,
  "pointsEarned": 25,
  "completed": true,
  "verified": true,
  "proofUrl": "",
  "completedAt": "2026-05-24T00:00:00Z",
  "timeTakenSeconds": 300
}
```

---

## 5️⃣ NOTIFICATIONS Collection

### Document: `notif-1`
```json
{
  "userId": "demo-learner-1",
  "title": "Welcome to QuestKids! 🎮",
  "body": "Start your learning journey today!",
  "type": "welcome",
  "read": false,
  "createdAt": "2026-05-24T00:00:00Z"
}
```

---

## 📊 Quick Reference Table

| Collection | Documents | Purpose |
|-----------|-----------|---------|
| **users** | 3 | Store user accounts (learner, parent, teacher) |
| **activities** | 3 | Store quiz/activity content |
| **rewards** | 3 | Track points, badges, achievements |
| **progress** | 1 | Track completed activities |
| **notifications** | 1 | Store user notifications |

---

## 🎯 How to Input Manually

1. Go to: https://console.firebase.google.com/project/questkids-mobile/firestore/data
2. Click "Start collection"
3. Enter collection name (e.g., "users")
4. Click "Auto-generate ID" → Enter ID (e.g., "demo-learner-1")
5. Copy fields from above and paste them in
6. Repeat for each document

---

## ✅ Field Types When Entering

- **String**: text values (name, email, etc.)
- **Number**: numeric values (totalPoints, streakDays, etc.)
- **Boolean**: true/false (completed, verified, etc.)
- **Array**: list of items (options, linkedChildrenUids, badges, etc.)
- **Map**: nested objects (questions, badge objects, etc.)
- **Timestamp**: dates (use current time or "2026-05-24T00:00:00Z")
- **GeoPoint**: coordinates (not used here)
- **Reference**: links to other documents (not used here)

---

## 📝 Notes

- Empty strings ("") for optional fields
- Empty arrays ([]) for optional list fields
- Timestamps: Firebase will convert ISO format to timestamps
- All sample data uses fictional IDs starting with "demo-"
