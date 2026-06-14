/**
 * QuestKids Firestore Seed Script
 * 
 * Uploads questkids_firestore_seed.json to your Firestore database.
 * 
 * Usage:
 *   node firestore_seed.js
 * 
 * Prerequisites:
 *   npm install firebase-admin
 */

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

const { getFirestore } = require('firebase-admin/firestore');
const serviceAccount = require('./serviceAccountKey.json');

const app = admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: serviceAccount.project_id || 'questkids-mobile',
});

const db = getFirestore(app, 'questkids');

async function seedFirestore() {
  // Read the JSON seed file
  const seedPath = path.join(__dirname, 'questkids_firestore_seed.json');
  const seedData = JSON.parse(fs.readFileSync(seedPath, 'utf8'));

  console.log('🚀 Starting Firestore seed upload...\n');

  // Each top-level key in the JSON is a collection name
  for (const [collectionName, documents] of Object.entries(seedData)) {
    console.log(`📂 Collection: "${collectionName}"`);
    
    for (const [docId, docData] of Object.entries(documents)) {
      try {
        await db.collection(collectionName).doc(docId).set(docData);
        console.log(`   ✅ Document "${docId}" uploaded successfully.`);
      } catch (error) {
        console.error(`   ❌ Error uploading "${docId}":`, error.message);
      }
    }
    console.log('');
  }

  console.log('🎉 Firestore seed upload complete!');
  process.exit(0);
}

seedFirestore().catch((err) => {
  console.error('Fatal error:', err);
  process.exit(1);
});
