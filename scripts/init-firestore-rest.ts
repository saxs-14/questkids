#!/usr/bin/env node
/**
 * Create Firestore collections using REST API
 * This doesn't require a service account key - uses Google Cloud authentication
 * 
 * Usage: 
 *   gcloud auth application-default login
 *   npx ts-node init-firestore-rest.ts
 */

import axios from 'axios';
import { execSync } from 'child_process';

const PROJECT_ID = 'questkids-mobile';
const DATABASE_ID = '(default)';
const BASE_URL = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/${DATABASE_ID}/documents`;

// Get ID token from gcloud
const getIdToken = async (): Promise<string> => {
  try {
    const token = execSync('gcloud auth application-default print-access-token', {
      encoding: 'utf-8',
    }).trim();
    return token;
  } catch (error) {
    throw new Error(
      'Failed to get Google Cloud credentials. Please run:\n' +
      '  gcloud auth application-default login'
    );
  }
};

const convertValue = (value: any): any => {
  if (value === null || value === undefined) {
    return { nullValue: null };
  } else if (typeof value === 'boolean') {
    return { booleanValue: value };
  } else if (typeof value === 'number') {
    return Number.isInteger(value)
      ? { integerValue: value.toString() }
      : { doubleValue: value };
  } else if (typeof value === 'string') {
    return { stringValue: value };
  } else if (value instanceof Date) {
    return { timestampValue: value.toISOString() };
  } else if (Array.isArray(value)) {
    return {
      arrayValue: {
        values: value.map(convertValue),
      },
    };
  } else if (typeof value === 'object') {
    return {
      mapValue: {
        fields: convertToFirestoreFields(value),
      },
    };
  }
  
  return { stringValue: String(value) };
};

const convertToFirestoreFields = (data: any): any => {
  const fields: any = {};
  
  for (const [key, value] of Object.entries(data)) {
    fields[key] = convertValue(value);
  }
  
  return fields;
};

const createDocument = async (
  collection: string,
  documentId: string,
  data: any,
  token: string
): Promise<void> => {
  const fields = convertToFirestoreFields(data);
  
  try {
    await axios.patch(
      `${BASE_URL}/${collection}/${documentId}`,
      { fields },
      {
        headers: {
          Authorization: `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
      }
    );
    console.log(`   ✅ ${collection}/${documentId}`);
  } catch (error: any) {
    console.error(`❌ Error creating ${collection}/${documentId}`);
    throw error;
  }
};

async function initializeCollections() {
  console.log('\n🚀 Initializing QuestKids Firestore Collections\n');
  
  try {
    console.log('🔐 Getting Google Cloud credentials...');
    const token = await getIdToken();
    console.log('✅ Authenticated\n');

    const now = new Date();

    // 1. Create Users
    console.log('📝 Creating "users" collection...');
    
    await createDocument('users', 'demo-learner-1', {
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
    }, token);

    await createDocument('users', 'demo-parent-1', {
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
    }, token);

    await createDocument('users', 'demo-teacher-1', {
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
    }, token);

    console.log('');

    // 2. Create Activities
    console.log('📝 Creating "activities" collection...');

    await createDocument('activities', 'math-fractions-001', {
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
    }, token);

    await createDocument('activities', 'science-planets-001', {
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
    }, token);

    await createDocument('activities', 'english-reading-001', {
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
    }, token);

    console.log('');

    // 3. Create Rewards
    console.log('📝 Creating "rewards" collection...');

    await createDocument('rewards', 'demo-learner-1', {
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
    }, token);

    await createDocument('rewards', 'demo-parent-1', {
      uid: 'demo-parent-1',
      totalPoints: 0,
      level: 1,
      streakDays: 0,
      lastActiveDate: now,
      badges: [],
      achievements: [],
    }, token);

    await createDocument('rewards', 'demo-teacher-1', {
      uid: 'demo-teacher-1',
      totalPoints: 0,
      level: 1,
      streakDays: 0,
      lastActiveDate: now,
      badges: [],
      achievements: [],
    }, token);

    console.log('');

    // 4. Create Progress
    console.log('📝 Creating "progress" collection...');

    await createDocument('progress', 'progress-1', {
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
    }, token);

    console.log('');

    // 5. Create Notifications
    console.log('📝 Creating "notifications" collection...');

    await createDocument('notifications', 'notif-1', {
      userId: 'demo-learner-1',
      title: 'Welcome to QuestKids! 🎮',
      body: 'Start your learning journey today!',
      type: 'welcome',
      read: false,
      createdAt: now,
    }, token);

    console.log('\n✨ ✨ ✨ ✨ ✨ ✨ ✨ ✨ ✨ ✨');
    console.log('🎉 All collections created successfully!');
    console.log('✨ ✨ ✨ ✨ ✨ ✨ ✨ ✨ ✨ ✨\n');

    console.log('📊 Summary:');
    console.log('   ✅ users (3 documents)');
    console.log('   ✅ activities (3 documents)');
    console.log('   ✅ progress (1 document)');
    console.log('   ✅ rewards (3 documents)');
    console.log('   ✅ notifications (1 document)\n');

    console.log('🔗 Firebase Console: https://console.firebase.google.com/project/questkids-mobile/firestore/data\n');

    process.exit(0);
  } catch (error) {
    console.error('\n❌ Error:', error instanceof Error ? error.message : error);
    process.exit(1);
  }
}

initializeCollections();
