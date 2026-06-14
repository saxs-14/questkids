#!/usr/bin/env node
/**
 * Create Firestore collections using Firebase Admin SDK
 * 
 * This requires a service account key file. To get one:
 * 1. Go to: https://console.firebase.google.com/project/questkids-mobile/settings/serviceaccounts/adminsdk
 * 2. Click "Generate New Private Key"
 * 3. Save it as "serviceAccountKey.json" in this directory
 * 
 * Usage: npx ts-node init-firestore-admin.ts
 */

import * as admin from 'firebase-admin';
import * as fs from 'fs';
import * as path from 'path';

const keyPath = path.join(__dirname, 'serviceAccountKey.json');

if (!fs.existsSync(keyPath)) {
  console.error('\n❌ Service account key not found!\n');
  console.log('To set up:');
  console.log('1. Go to: https://console.firebase.google.com/project/questkids-mobile/settings/serviceaccounts/adminsdk');
  console.log('2. Click "Generate New Private Key"');
  console.log('3. Save the downloaded file as "serviceAccountKey.json" in this directory\n');
  process.exit(1);
}

const serviceAccount = JSON.parse(fs.readFileSync(keyPath, 'utf-8'));

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'questkids-mobile',
});

const db = admin.firestore();

async function createCollections() {
  console.log('\n🚀 Initializing QuestKids Firestore Collections\n');

  try {
    const now = admin.firestore.Timestamp.now();
    const serverTimestamp = admin.firestore.FieldValue.serverTimestamp();

    // 1. Create Users Collection
    console.log('📝 Creating "users" collection...');

    await db.collection('users').doc('demo-learner-1').set({
      uid: 'demo-learner-1',
      name: 'Demo Learner',
      email: 'learner@demo.com',
      role: 'learner',
      grade: 'Grade 4',
      parentUid: '',
      avatarUrl: '',
      totalPoints: 150,
      streakDays: 5,
      createdAt: now,
      linkedChildrenUids: [],
    });
    console.log('   ✅ demo-learner-1');

    await db.collection('users').doc('demo-parent-1').set({
      uid: 'demo-parent-1',
      name: 'Demo Parent',
      email: 'parent@demo.com',
      role: 'parent',
      grade: '',
      parentUid: '',
      avatarUrl: '',
      totalPoints: 0,
      streakDays: 0,
      createdAt: now,
      linkedChildrenUids: ['demo-learner-1'],
    });
    console.log('   ✅ demo-parent-1');

    await db.collection('users').doc('demo-teacher-1').set({
      uid: 'demo-teacher-1',
      name: 'Demo Teacher',
      email: 'teacher@demo.com',
      role: 'teacher',
      grade: 'Grade 4',
      parentUid: '',
      avatarUrl: '',
      totalPoints: 0,
      streakDays: 0,
      createdAt: now,
      linkedChildrenUids: [],
    });
    console.log('   ✅ demo-teacher-1\n');

    // 2. Create Activities Collection
    console.log('📝 Creating "activities" collection...');

    await db.collection('activities').doc('math-fractions-001').set({
      id: 'math-fractions-001',
      title: 'Math Quest: Fractions',
      description: 'Master the fundamentals of fractions',
      subject: 'Math',
      type: 'quiz',
      difficulty: 'medium',
      rewardPoints: 25,
      grade: 'Grade 4',
      requiresProof: false,
      createdAt: now,
      questions: [
        {
          question: 'What is 1/2 + 1/4?',
          options: ['1/2', '3/4', '1/4', '1/6'],
          correctIndex: 1,
          explanation: '1/2 = 2/4, so 2/4 + 1/4 = 3/4',
        },
      ],
    });
    console.log('   ✅ math-fractions-001');

    await db.collection('activities').doc('science-planets-001').set({
      id: 'science-planets-001',
      title: 'Science Quest: The Solar System',
      description: 'Explore the planets',
      subject: 'Science',
      type: 'practical',
      difficulty: 'easy',
      rewardPoints: 30,
      grade: 'Grade 4',
      requiresProof: true,
      createdAt: now,
      questions: [],
    });
    console.log('   ✅ science-planets-001');

    await db.collection('activities').doc('english-reading-001').set({
      id: 'english-reading-001',
      title: 'English Quest: Reading Comprehension',
      description: 'Improve your reading skills',
      subject: 'English',
      type: 'quiz',
      difficulty: 'easy',
      rewardPoints: 20,
      grade: 'Grade 4',
      requiresProof: false,
      createdAt: now,
      questions: [],
    });
    console.log('   ✅ english-reading-001\n');

    // 3. Create Rewards Collection
    console.log('📝 Creating "rewards" collection...');

    await db.collection('rewards').doc('demo-learner-1').set({
      uid: 'demo-learner-1',
      totalPoints: 150,
      level: 1,
      streakDays: 5,
      lastActiveDate: now,
      badges: [
        {
          id: 'first-quest',
          name: 'First Quest',
          description: 'Complete your first quest',
          icon: '🎯',
          category: 'special',
          earnedAt: now,
        },
      ],
      achievements: [],
    });
    console.log('   ✅ demo-learner-1');

    await db.collection('rewards').doc('demo-parent-1').set({
      uid: 'demo-parent-1',
      totalPoints: 0,
      level: 1,
      streakDays: 0,
      lastActiveDate: now,
      badges: [],
      achievements: [],
    });
    console.log('   ✅ demo-parent-1');

    await db.collection('rewards').doc('demo-teacher-1').set({
      uid: 'demo-teacher-1',
      totalPoints: 0,
      level: 1,
      streakDays: 0,
      lastActiveDate: now,
      badges: [],
      achievements: [],
    });
    console.log('   ✅ demo-teacher-1\n');

    // 4. Create Progress Collection
    console.log('📝 Creating "progress" collection...');

    await db.collection('progress').doc('progress-1').set({
      uid: 'demo-learner-1',
      activityId: 'math-fractions-001',
      activityTitle: 'Math Quest: Fractions',
      subject: 'Math',
      score: 100,
      pointsEarned: 25,
      completed: true,
      verified: true,
      proofUrl: '',
      completedAt: now,
      timeTakenSeconds: 300,
    });
    console.log('   ✅ progress-1\n');

    // 5. Create Notifications Collection
    console.log('📝 Creating "notifications" collection...');

    await db.collection('notifications').doc('notif-1').set({
      userId: 'demo-learner-1',
      title: 'Welcome to QuestKids! 🎮',
      body: 'Start your learning journey today!',
      type: 'welcome',
      read: false,
      createdAt: now,
    });
    console.log('   ✅ notif-1\n');

    console.log('✨ ✨ ✨ ✨ ✨ ✨ ✨ ✨ ✨ ✨');
    console.log('🎉 All collections created successfully!');
    console.log('✨ ✨ ✨ ✨ ✨ ✨ ✨ ✨ ✨ ✨\n');

    console.log('📊 Summary:');
    console.log('   ✅ users (3 documents)');
    console.log('   ✅ activities (3 documents)');
    console.log('   ✅ progress (1 document)');
    console.log('   ✅ rewards (3 documents)');
    console.log('   ✅ notifications (1 document)\n');

    console.log('🔗 Firebase Console: https://console.firebase.google.com/project/questkids-mobile/firestore/data\n');

    await admin.app().delete();
    process.exit(0);
  } catch (error) {
    console.error('\n❌ Error:', error instanceof Error ? error.message : error);
    process.exit(1);
  }
}

createCollections();
