import {onSchedule} from "firebase-functions/v2/scheduler";
import * as admin from "firebase-admin";

const GRADES = [
  "Grade 1", "Grade 2", "Grade 3", "Grade 4",
  "Grade 5", "Grade 6", "Grade 7",
];

export const refreshLeaderboards = onSchedule(
  {schedule: "every day 01:00", timeZone: "Africa/Johannesburg"},
  async () => {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();
    const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);

    for (const grade of GRADES) {
      const usersSnap = await db
        .collection("users")
        .where("role", "==", "learner")
        .where("grade", "==", grade)
        .get();

      if (usersSnap.empty) continue;

      const entries: {
        uid: string; displayName: string; avatarEmoji: string;
        grade: string; allTimeXp: number; weeklyXp: number;
      }[] = [];

      for (const userDoc of usersSnap.docs) {
        const userData = userDoc.data();
        const rewardDoc = await db.collection("rewards").doc(userDoc.id).get();
        const allTimeXp = (rewardDoc.data()?.["totalPoints"] as number) ?? 0;

        const progressSnap = await db
          .collection("progress")
          .where("childUid", "==", userDoc.id)
          .where("completedAt", ">=", admin.firestore.Timestamp.fromDate(sevenDaysAgo))
          .get();
        const weeklyXp = progressSnap.docs.reduce(
          (sum, d) => sum + ((d.data()["pointsEarned"] as number) ?? 0),
          0
        );

        entries.push({
          uid: userDoc.id,
          displayName: `${userData["name"] ?? ""} ${userData["surname"] ?? ""}`.trim(),
          avatarEmoji: (userData["avatarEmoji"] as string) ?? "🦁",
          grade,
          allTimeXp,
          weeklyXp,
        });
      }

      // Write weekly board
      const weeklyRanked = [...entries]
        .sort((a, b) => b.weeklyXp - a.weeklyXp)
        .slice(0, 50);
      const weeklyBatch = db.batch();
      const existingWeekly = await db
        .collection("leaderboards").doc(grade).collection("weekly").get();
      existingWeekly.docs.forEach((d) => weeklyBatch.delete(d.ref));
      weeklyRanked.forEach((entry, i) => {
        const ref = db.collection("leaderboards").doc(grade)
          .collection("weekly").doc(entry.uid);
        weeklyBatch.set(ref, {
          uid: entry.uid,
          displayName: entry.displayName,
          avatarEmoji: entry.avatarEmoji,
          grade: entry.grade,
          xp: entry.weeklyXp,
          rank: i + 1,
          updatedAt: now,
        });
      });
      await weeklyBatch.commit();

      // Write allTime board
      const allTimeRanked = [...entries]
        .sort((a, b) => b.allTimeXp - a.allTimeXp)
        .slice(0, 50);
      const allTimeBatch = db.batch();
      const existingAllTime = await db
        .collection("leaderboards").doc(grade).collection("allTime").get();
      existingAllTime.docs.forEach((d) => allTimeBatch.delete(d.ref));
      allTimeRanked.forEach((entry, i) => {
        const ref = db.collection("leaderboards").doc(grade)
          .collection("allTime").doc(entry.uid);
        allTimeBatch.set(ref, {
          uid: entry.uid,
          displayName: entry.displayName,
          avatarEmoji: entry.avatarEmoji,
          grade: entry.grade,
          xp: entry.allTimeXp,
          rank: i + 1,
          updatedAt: now,
        });
      });
      await allTimeBatch.commit();

      console.log(`Leaderboard refreshed for ${grade}`);
    }
  }
);
