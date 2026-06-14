import * as admin from 'firebase-admin';
import * as fs from 'fs';
import * as path from 'path';

// Initialize Firebase Admin
const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS || 
                          path.join(__dirname, '../questkids-key.json');

if (!fs.existsSync(serviceAccountPath)) {
  console.error('❌ Service account key not found at:', serviceAccountPath);
  console.error('\nTo use this script, you need to:');
  console.error('1. Go to Firebase Console → Project Settings → Service Accounts');
  console.error('2. Click "Generate New Private Key"');
  console.error('3. Save as questkids-key.json in project root');
  console.error('4. Set GOOGLE_APPLICATION_CREDENTIALS environment variable\n');
  process.exit(1);
}

let app: admin.app.App;

try {
  const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, 'utf8'));
  app = admin.initializeApp({
    credential: admin.credential.cert(serviceAccount as admin.ServiceAccount),
    projectId: 'questkids-mobile',
  });
} catch (error) {
  console.error('❌ Error initializing Firebase:', error);
  process.exit(1);
}

const db = admin.firestore();

async function createCollections() {
  console.log('🚀 Initializing QuestKids Firestore Collections...\n');

  try {
    // 1. Create Users Collection
    console.log('📝 Creating "users" collection...');
    const usersRef = db.collection('users');
    
    await usersRef.doc('demo-learner-1').set({
      uid: 'demo-learner-1',
      name: 'Demo Learner',
      email: 'learner@demo.com',
      role: 'learner',
      grade: 'Grade 4',
      parentUid: '',
      avatarUrl: '',
      totalPoints: 150,
      streakDays: 5,
      createdAt: admin.firestore.Timestamp.now(),
      linkedChildrenUids: [],
    });
    
    await usersRef.doc('demo-parent-1').set({
      uid: 'demo-parent-1',
      name: 'Demo Parent',
      email: 'parent@demo.com',
      role: 'parent',
      grade: '',
      parentUid: '',
      avatarUrl: '',
      totalPoints: 0,
      streakDays: 0,
      createdAt: admin.firestore.Timestamp.now(),
      linkedChildrenUids: ['demo-learner-1'],
    });
    
    await usersRef.doc('demo-teacher-1').set({
      uid: 'demo-teacher-1',
      name: 'Demo Teacher',
      email: 'teacher@demo.com',
      role: 'teacher',
      grade: 'Grade 4',
      parentUid: '',
      avatarUrl: '',
      totalPoints: 0,
      streakDays: 0,
      createdAt: admin.firestore.Timestamp.now(),
      linkedChildrenUids: [],
    });
    
    console.log('   ✅ Created 3 sample users (learner, parent, teacher)\n');

    // 2. Create Activities Collection
    console.log('📝 Creating "activities" collection...');
    const activitiesRef = db.collection('activities');
    
    await activitiesRef.doc('math-fractions-001').set({
      id: 'math-fractions-001',
      title: 'Math Quest: Fractions',
      description: 'Master the fundamentals of fractions through interactive quizzes',
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
        {
          question: 'What fraction is equivalent to 2/4?',
          options: ['1/4', '1/2', '2/3', '3/4'],
          correctIndex: 1,
          explanation: '2/4 simplifies to 1/2 by dividing both numerator and denominator by 2',
        },
        {
          question: 'Which is larger: 3/5 or 1/2?',
          options: ['3/5', '1/2', 'They are equal', 'Cannot determine'],
          correctIndex: 0,
          explanation: '3/5 = 0.6 and 1/2 = 0.5, so 3/5 is larger',
        },
      ],
    });

    await activitiesRef.doc('science-planets-001').set({
      id: 'science-planets-001',
      title: 'Science Quest: The Solar System',
      description: 'Explore the planets and learn about our solar system',
      subject: 'Science',
      type: 'practical',
      difficulty: 'easy',
      rewardPoints: 30,
      grade: 'Grade 4',
      requiresProof: true,
      createdAt: admin.firestore.Timestamp.now(),
      questions: [],
    });

    await activitiesRef.doc('english-reading-001').set({
      id: 'english-reading-001',
      title: 'English Quest: Reading Comprehension',
      description: 'Improve your reading skills with interactive stories',
      subject: 'English',
      type: 'quiz',
      difficulty: 'easy',
      rewardPoints: 20,
      grade: 'Grade 4',
      requiresProof: false,
      createdAt: admin.firestore.Timestamp.now(),
      questions: [
        {
          question: 'What is the main idea of a story?',
          options: ['The title', 'The most important point', 'The first sentence', 'The last sentence'],
          correctIndex: 1,
          explanation: 'The main idea is the most important point that the author wants to convey',
        },
      ],
    });

    console.log('   ✅ Created 3 sample activities\n');

    // 3. Create Progress Collection
    console.log('📝 Creating "progress" collection...');
    const progressRef = db.collection('progress');
    
    await progressRef.add({
      uid: 'demo-learner-1',
      activityId: 'math-fractions-001',
      activityTitle: 'Math Quest: Fractions',
      subject: 'Math',
      score: 100,
      pointsEarned: 25,
      completed: true,
      verified: true,
      proofUrl: '',
      completedAt: admin.firestore.Timestamp.now(),
      timeTakenSeconds: 300,
    });

    await progressRef.add({
      uid: 'demo-learner-1',
      activityId: 'english-reading-001',
      activityTitle: 'English Quest: Reading Comprehension',
      subject: 'English',
      score: 80,
      pointsEarned: 16,
      completed: true,
      verified: false,
      proofUrl: '',
      completedAt: admin.firestore.Timestamp.now(),
      timeTakenSeconds: 450,
    });

    await progressRef.add({
      uid: 'demo-learner-1',
      activityId: 'science-planets-001',
      activityTitle: 'Science Quest: The Solar System',
      subject: 'Science',
      score: 0,
      pointsEarned: 0,
      completed: false,
      verified: false,
      proofUrl: '',
      completedAt: admin.firestore.Timestamp.now(),
      timeTakenSeconds: 0,
    });

    console.log('   ✅ Created 3 progress records\n');

    // 4. Create Rewards Collection
    console.log('📝 Creating "rewards" collection...');
    const rewardsRef = db.collection('rewards');
    
    await rewardsRef.doc('demo-learner-1').set({
      uid: 'demo-learner-1',
      totalPoints: 150,
      level: 1,
      streakDays: 5,
      lastActiveDate: admin.firestore.Timestamp.now(),
      badges: [
        {
          id: 'first-quest',
          name: 'First Quest',
          description: 'Complete your first quest',
          icon: '🎯',
          category: 'special',
          earnedAt: admin.firestore.Timestamp.now(),
        },
        {
          id: 'math-master',
          name: 'Math Master',
          description: 'Complete 5 math quests',
          icon: '🧮',
          category: 'subject',
          earnedAt: admin.firestore.Timestamp.now(),
        },
      ],
      achievements: [
        {
          id: 'achievement-1',
          name: 'Streak Started',
          description: 'Keep a 3-day streak',
          earnedAt: admin.firestore.Timestamp.now(),
        },
      ],
    });

    await rewardsRef.doc('demo-parent-1').set({
      uid: 'demo-parent-1',
      totalPoints: 0,
      level: 1,
      streakDays: 0,
      lastActiveDate: admin.firestore.Timestamp.now(),
      badges: [],
      achievements: [],
    });

    await rewardsRef.doc('demo-teacher-1').set({
      uid: 'demo-teacher-1',
      totalPoints: 0,
      level: 1,
      streakDays: 0,
      lastActiveDate: admin.firestore.Timestamp.now(),
      badges: [],
      achievements: [],
    });

    console.log('   ✅ Created rewards for all users\n');

    // 5. Create Notifications Collection
    console.log('📝 Creating "notifications" collection...');
    const notificationsRef = db.collection('notifications');
    
    await notificationsRef.add({
      userId: 'demo-learner-1',
      title: 'Welcome to QuestKids! 🎮',
      body: 'Start your learning journey today!',
      type: 'welcome',
      read: false,
      createdAt: admin.firestore.Timestamp.now(),
    });

    await notificationsRef.add({
      userId: 'demo-learner-1',
      title: 'Achievement Unlocked! 🏆',
      body: 'You earned the "First Quest" badge!',
      type: 'achievement',
      read: false,
      createdAt: admin.firestore.Timestamp.now(),
    });

    await notificationsRef.add({
      userId: 'demo-learner-1',
      title: '🔥 Streak Alert',
      body: 'You have a 5-day streak! Keep it going!',
      type: 'reminder',
      read: false,
      createdAt: admin.firestore.Timestamp.now(),
    });

    await notificationsRef.add({
      userId: 'demo-parent-1',
      title: 'Child Achievement! 🎉',
      body: 'Your child completed "Math Quest: Fractions"',
      type: 'child-achievement',
      read: false,
      createdAt: admin.firestore.Timestamp.now(),
    });

    console.log('   ✅ Created notifications\n');

    console.log('✨ ✨ ✨ ✨ ✨ ✨ ✨ ✨ ✨ ✨ ✨ ✨ ✨');
    console.log('🎉 All collections created successfully!');
    console.log('✨ ✨ ✨ ✨ ✨ ✨ ✨ ✨ ✨ ✨ ✨ ✨ ✨\n');

    console.log('📊 Collections Created:');
    console.log('   ✅ users (3 documents)');
    console.log('   ✅ activities (3 documents)');
    console.log('   ✅ progress (3 documents)');
    console.log('   ✅ rewards (3 documents)');
    console.log('   ✅ notifications (4 documents)\n');

    console.log('🔗 Firebase Console: https://console.firebase.google.com/project/questkids-mobile/firestore/data');
    console.log('\n🚀 Your app is ready to run!\n');

    await admin.app().delete();
    process.exit(0);
  } catch (error) {
    console.error('\n❌ Error creating collections:', error);
    await admin.app().delete();
    process.exit(1);
  }
}

createCollections();
