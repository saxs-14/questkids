import { onSchedule } from "firebase-functions/v2/scheduler";
import { getFirestore, Firestore, WriteBatch, Timestamp } from "firebase-admin/firestore";

// Must match UserModel.grade values exactly ('grade1'..'grade7' -- see
// lib/core/constants/labels.dart). A prior version of this file used
// "Grade 1"-style values, which never matched any real user document, so
// every leaderboard was silently empty.
const GRADES = [
  "grade1", "grade2", "grade3", "grade4",
  "grade5", "grade6", "grade7",
];

// Must match the `subject` values used in lib/core/constants/game_catalog.dart.
const SUBJECTS = [
  "Mathematics", "English", "Life Skills",
  "Natural Sciences", "Social Sciences", "Technology", "EMS",
];

// Firestore doc IDs can't contain "/" and read poorly with spaces, so
// subject leaderboards live at doc id `${grade}_${subjectKey(subject)}`
// under the same `leaderboards` collection the overall boards use --
// LeaderboardRepository.subjectDocId() on the client must produce the
// same id.
function subjectKey(subject: string): string {
  return subject.replace(/\s+/g, "");
}

interface Entry {
  uid: string;
  displayName: string;
  avatarEmoji: string;
  grade: string;
  allTimeXp: number;
  weeklyXp: number;
  subjectWeeklyXp: Record<string, number>;
  subjectAllTimeXp: Record<string, number>;
}

function writeBoard(
  db: Firestore,
  batch: WriteBatch,
  docId: string,
  period: "weekly" | "allTime",
  ranked: { uid: string; displayName: string; avatarEmoji: string; grade: string; xp: number }[],
  now: Timestamp
) {
  ranked.forEach((entry, i) => {
    const ref = db.collection("leaderboards").doc(docId).collection(period).doc(entry.uid);
    batch.set(ref, {
      uid: entry.uid,
      displayName: entry.displayName,
      avatarEmoji: entry.avatarEmoji,
      grade: entry.grade,
      xp: entry.xp,
      rank: i + 1,
      updatedAt: now,
    });
  });
}

async function clearBoard(
  db: Firestore,
  docId: string,
  period: "weekly" | "allTime"
): Promise<void> {
  const existing = await db.collection("leaderboards").doc(docId).collection(period).get();
  if (existing.empty) return;

  const docs = existing.docs;
  for (let i = 0; i < docs.length; i += 400) {
    const chunk = docs.slice(i, i + 400);
    const batch = db.batch();
    chunk.forEach((d) => batch.delete(d.ref));
    await batch.commit();
  }
}

// Exported separately (not just as the onSchedule body) so it can be
// invoked directly -- scheduled functions cannot be triggered from the
// local Functions emulator (no pubsub emulator), so this is the only way
// to exercise the refresh logic outside of production.
export async function runLeaderboardRefresh(db: Firestore): Promise<void> {
  const now = Timestamp.now();
  const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);

  for (const grade of GRADES) {
    const usersSnap = await db
      .collection("users")
      .where("role", "==", "learner")
      .where("grade", "==", grade)
      .get();

    if (usersSnap.empty) continue;

    const entries: Entry[] = [];

    for (const userDoc of usersSnap.docs) {
      const userData = userDoc.data();
      const rewardDoc = await db.collection("rewards").doc(userDoc.id).get();
      const allTimeXp = (rewardDoc.data()?.["totalPoints"] as number) ?? 0;

      // Fetch every progress doc once (not just the last 7 days) so we
      // can derive both the weekly and all-time per-subject splits from
      // a single query.
      const progressSnap = await db
        .collection("progress")
        .where("uid", "==", userDoc.id)
        .get();

      let weeklyXp = 0;
      const subjectWeeklyXp: Record<string, number> = {};
      const subjectAllTimeXp: Record<string, number> = {};

      for (const d of progressSnap.docs) {
        const data = d.data();
        const points = (data["pointsEarned"] as number) ?? 0;
        const subject = data["subject"] as string | undefined;
        const completedAtMs = data["completedAt"] as number | undefined;
        const isRecent =
            completedAtMs !== undefined && completedAtMs >= sevenDaysAgo.getTime();

        if (subject) {
          subjectAllTimeXp[subject] = (subjectAllTimeXp[subject] ?? 0) + points;
          if (isRecent) {
            subjectWeeklyXp[subject] = (subjectWeeklyXp[subject] ?? 0) + points;
          }
        }
        if (isRecent) weeklyXp += points;
      }

      // Leaderboards are readable by every signed-in learner in the app,
      // so only ever expose a first name + avatar here -- never surname,
      // email, or any school identifier. See docs/SECURITY.md.
      entries.push({
        uid: userDoc.id,
        displayName: `${userData["name"] ?? "Learner"}`.trim(),
        avatarEmoji: (userData["avatarEmoji"] as string) ?? "🦁",
        grade,
        allTimeXp,
        weeklyXp,
        subjectWeeklyXp,
        subjectAllTimeXp,
      });
    }

    // ---- Overall (grade-wide) boards ----
    await clearBoard(db, grade, "weekly");
    await clearBoard(db, grade, "allTime");
    const batch = db.batch();

    const weeklyRanked = [...entries]
      .sort((a, b) => b.weeklyXp - a.weeklyXp)
      .slice(0, 50)
      .map((e) => ({ ...e, xp: e.weeklyXp }));
    writeBoard(db, batch, grade, "weekly", weeklyRanked, now);

    const allTimeRanked = [...entries]
      .sort((a, b) => b.allTimeXp - a.allTimeXp)
      .slice(0, 50)
      .map((e) => ({ ...e, xp: e.allTimeXp }));
    writeBoard(db, batch, grade, "allTime", allTimeRanked, now);

    await batch.commit();

    // ---- Per-subject boards ----
    for (const subject of SUBJECTS) {
      const docId = `${grade}_${subjectKey(subject)}`;
      await clearBoard(db, docId, "weekly");
      await clearBoard(db, docId, "allTime");
      const subjectBatch = db.batch();

      const subjectWeeklyRanked = [...entries]
        .map((e) => ({ ...e, xp: e.subjectWeeklyXp[subject] ?? 0 }))
        .sort((a, b) => b.xp - a.xp)
        .slice(0, 50);
      writeBoard(db, subjectBatch, docId, "weekly", subjectWeeklyRanked, now);

      const subjectAllTimeRanked = [...entries]
        .map((e) => ({ ...e, xp: e.subjectAllTimeXp[subject] ?? 0 }))
        .sort((a, b) => b.xp - a.xp)
        .slice(0, 50);
      writeBoard(db, subjectBatch, docId, "allTime", subjectAllTimeRanked, now);

      await subjectBatch.commit();
    }

    console.log(`Leaderboard refreshed for ${grade}`);
  }
}

export const refreshLeaderboards = onSchedule(
  { schedule: "every day 01:00", timeZone: "Africa/Johannesburg" },
  async () => {
    await runLeaderboardRefresh(getFirestore());
  }
);
