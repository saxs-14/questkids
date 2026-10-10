import "../setup/firebaseAdmin";
import { getFirestore } from "firebase-admin/firestore";
import { clearFirestoreEmulatorData } from "../setup/firestoreEmulator";
import { runLeaderboardRefresh } from "../../src/leaderboard/refresh";

async function seedLearner(
  uid: string,
  grade: string,
  name: string,
  totalPoints: number,
  progress: { subject: string; pointsEarned: number; completedAt: number }[]
) {
  const db = getFirestore();
  await db.collection("users").doc(uid).set({ uid, role: "learner", grade, name });
  await db.collection("rewards").doc(uid).set({ totalPoints });
  for (let i = 0; i < progress.length; i++) {
    await db.collection("progress").doc(`${uid}-p${i}`).set({
      uid,
      subject: progress[i].subject,
      pointsEarned: progress[i].pointsEarned,
      completedAt: progress[i].completedAt,
    });
  }
}

describe("runLeaderboardRefresh", () => {
  beforeEach(async () => {
    await clearFirestoreEmulatorData();
  });

  it("writes nothing for a grade with no learners", async () => {
    await runLeaderboardRefresh(getFirestore());
    const board = await getFirestore()
      .collection("leaderboards")
      .doc("Grade 1")
      .collection("allTime")
      .get();
    expect(board.empty).toBe(true);
  });

  it("ranks learners by all-time XP, highest first", async () => {
    const now = Date.now();
    await seedLearner("low", "Grade 3", "Low Scorer", 50, [
      { subject: "Mathematics", pointsEarned: 50, completedAt: now },
    ]);
    await seedLearner("high", "Grade 3", "High Scorer", 200, [
      { subject: "Mathematics", pointsEarned: 200, completedAt: now },
    ]);

    await runLeaderboardRefresh(getFirestore());

    const board = await getFirestore()
      .collection("leaderboards")
      .doc("Grade 3")
      .collection("allTime")
      .orderBy("rank")
      .get();
    const ranked = board.docs.map((d) => d.data());
    expect(ranked[0]).toMatchObject({ uid: "high", rank: 1, xp: 200 });
    expect(ranked[1]).toMatchObject({ uid: "low", rank: 2, xp: 50 });
  });

  it("only counts progress from the last 7 days toward the weekly board", async () => {
    const now = Date.now();
    const eightDaysAgo = now - 8 * 24 * 60 * 60 * 1000;
    await seedLearner("child-1", "Grade 2", "Thandi", 300, [
      { subject: "English", pointsEarned: 100, completedAt: eightDaysAgo }, // stale
      { subject: "English", pointsEarned: 50, completedAt: now }, // recent
    ]);

    await runLeaderboardRefresh(getFirestore());

    const weekly = await getFirestore()
      .collection("leaderboards")
      .doc("Grade 2")
      .collection("weekly")
      .doc("child-1")
      .get();
    expect(weekly.data()?.xp).toBe(50); // only the recent entry

    const allTime = await getFirestore()
      .collection("leaderboards")
      .doc("Grade 2")
      .collection("allTime")
      .doc("child-1")
      .get();
    expect(allTime.data()?.xp).toBe(300); // from rewards.totalPoints, not progress
  });

  it("splits weekly/all-time XP per subject into separate subject boards", async () => {
    const now = Date.now();
    await seedLearner("child-1", "Grade 4", "Thandi", 0, [
      { subject: "Mathematics", pointsEarned: 40, completedAt: now },
      { subject: "English", pointsEarned: 20, completedAt: now },
    ]);

    await runLeaderboardRefresh(getFirestore());

    const mathBoard = await getFirestore()
      .collection("leaderboards")
      .doc("Grade 4_Mathematics")
      .collection("weekly")
      .doc("child-1")
      .get();
    expect(mathBoard.data()?.xp).toBe(40);

    const englishBoard = await getFirestore()
      .collection("leaderboards")
      .doc("Grade 4_English")
      .collection("weekly")
      .doc("child-1")
      .get();
    expect(englishBoard.data()?.xp).toBe(20);
  });

  it("fully replaces a board rather than merging stale entries", async () => {
    // A learner who no longer qualifies (e.g. moved grade) should disappear
    // from the board on the next refresh, not linger from a prior run.
    await getFirestore()
      .collection("leaderboards")
      .doc("Grade 5")
      .collection("allTime")
      .doc("stale-uid")
      .set({ uid: "stale-uid", xp: 999, rank: 1 });

    await seedLearner("child-1", "Grade 5", "Thandi", 10, []);
    await runLeaderboardRefresh(getFirestore());

    const stale = await getFirestore()
      .collection("leaderboards")
      .doc("Grade 5")
      .collection("allTime")
      .doc("stale-uid")
      .get();
    expect(stale.exists).toBe(false);
  });

  it("never exposes a surname on the leaderboard (UserModel stores it in a separate field)", async () => {
    const now = Date.now();
    await getFirestore().collection("users").doc("child-1").set({
      uid: "child-1",
      role: "learner",
      grade: "Grade 1",
      name: "Thandi",
      surname: "Mokoena", // a real, separate field this function must never read
    });
    await getFirestore().collection("rewards").doc("child-1").set({ totalPoints: 10 });
    await getFirestore().collection("progress").doc("child-1-p0").set({
      uid: "child-1",
      subject: "Mathematics",
      pointsEarned: 10,
      completedAt: now,
    });

    await runLeaderboardRefresh(getFirestore());

    const entry = await getFirestore()
      .collection("leaderboards")
      .doc("Grade 1")
      .collection("allTime")
      .doc("child-1")
      .get();
    expect(entry.data()?.displayName).toBe("Thandi");
    expect(JSON.stringify(entry.data())).not.toContain("Mokoena");
  });
});
