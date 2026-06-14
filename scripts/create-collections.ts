/**
 * Script to initialize Firestore collections for QuestKids
 * Run this with: npx ts-node create-collections.ts
 * Or use with Cloud Functions
 */

import * as admin from 'firebase-admin';

const serviceAccount = require('./questkids-firebase-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'questkids-mobile',
});

const db = admin.firestore();

async function initializeCollections() {
  console.log('🚀 Initializing QuestKids Firestore Collections...\n');

  try {
    // 1. Create Users Collection
    console.log('📝 Creating users collection...');
    await db.collection('users').doc('sample-user-1').set({
      uid: 'sample-user-1',
      name: 'Sample Learner',
      email: 'learner@example.com',
      role: 'learner',
      grade: 'Grade 4',
      parentUid: '',
      avatarUrl: '',
      totalPoints: 0,
      streakDays: 0,
      createdAt: admin.firestore.Timestamp.now(),
      linkedChildrenUids: [],
    });
    console.log('✅ users collection created\n');

    // 2. Create Activities Collection
    console.log('📝 Creating activities collection...');
    await db.collection('activities').doc('math-quiz-001').set({
      id: 'math-quiz-001',
      title: 'Math Quiz - Fractions',
      description: 'Learn about fractions and solve problems',
      subject: 'Math',
      type: 'quiz',
      difficulty: 'medium',
      rewardPoints: 25,
      grade: 'Grade 4',
      requiresProof: false,
      createdAt: admin.firestore.Timestamp.now(),
      questions: [
        {
          question: 'What is 1/2 + 1/4?',
          options: ['1/2', '3/4', '1/4', '1/6'],
          correctIndex: 1,
          explanation: '1/2 = 2/4, so 2/4 + 1/4 = 3/4',
        },
      ],
    });
    console.log('✅ activities collection created\n');

    // 3. Create Progress Collection
    console.log('📝 Creating progress collection...');
    await db.collection('progress').add({
      uid: 'sample-user-1',
      activityId: 'math-quiz-001',
      activityTitle: 'Math Quiz - Fractions',
      subject: 'Math',
      score: 0,
      pointsEarned: 0,
      completed: false,
      verified: false,
      proofUrl: '',
      completedAt: admin.firestore.Timestamp.now(),
      timeTakenSeconds: 0,
    });
    console.log('✅ progress collection created\n');

    // 4. Create Rewards Collection
    console.log('📝 Creating rewards collection...');
    await db.collection('rewards').doc('sample-user-1').set({
      uid: 'sample-user-1',
      totalPoints: 0,
      level: 1,
      streakDays: 0,
      lastActiveDate: admin.firestore.Timestamp.now(),
      badges: [],
      achievements: [],
    });
    console.log('✅ rewards collection created\n');

    // 5. Create Notifications Collection
    console.log('📝 Creating notifications collection...');
    await db.collection('notifications').add({
      userId: 'sample-user-1',
      title: 'Welcome to QuestKids!',
      body: 'Start your learning journey today!',
      type: 'welcome',
      read: false,
      createdAt: admin.firestore.Timestamp.now(),
    });
    console.log('✅ notifications collection created\n');

    console.log('🎉 All collections initialized successfully!');
    process.exit(0);
  } catch (error) {
    console.error('❌ Error initializing collections:', error);
    process.exit(1);
  }
}

initializeCollections();
