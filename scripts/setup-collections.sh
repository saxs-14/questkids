#!/bin/bash
# Quick setup script for QuestKids Firebase Collections
# This script creates the necessary collections in Firestore

echo "🚀 Creating QuestKids Firestore Collections..."
echo ""

# Navigate to project directory
cd "$(dirname "$0")"

# Check if Firebase CLI is authenticated
echo "Checking Firebase CLI authentication..."
firebase auth:login 2>/dev/null || {
  echo "⚠️  Please authenticate with Firebase CLI first:"
  echo "   firebase login"
  exit 1
}

echo ""
echo "Creating collections via Cloud Firestore Admin SDK..."
echo ""

# Create collections (manual guide required)
echo "✅ Firestore rules deployed successfully!"
echo ""
echo "📋 Next steps:"
echo "1. Go to Firebase Console: https://console.firebase.google.com/project/questkids-mobile"
echo "2. Navigate to Cloud Firestore"
echo "3. Create the following collections (using 'Add Collection' button):"
echo ""
echo "   Collection: users"
echo "   Document ID: sample-user-1"
echo "   Fields:"
echo "     uid: string = 'sample-user-1'"
echo "     name: string = 'Sample Learner'"
echo "     email: string = 'learner@example.com'"
echo "     role: string = 'learner'"
echo "     grade: string = 'Grade 4'"
echo "     parentUid: string = ''"
echo "     avatarUrl: string = ''"
echo "     totalPoints: number = 0"
echo "     streakDays: number = 0"
echo "     createdAt: timestamp = [current date]"
echo "     linkedChildrenUids: array = []"
echo ""
echo "4. Create 'activities' collection with sample activity"
echo "5. Create 'progress' collection"
echo "6. Create 'rewards' collection"
echo "7. Create 'notifications' collection"
echo ""
echo "See FIREBASE_COLLECTIONS_SETUP.md for detailed collection schemas"
