import "../setup/firebaseAdmin";

// No GEMINI_API_KEY in this file, so adminGenerateDailyMissions' adaptive
// tier short-circuits to [] -- same reasoning as test/missions/generate.test.ts.
delete process.env.GEMINI_API_KEY;

import { getFirestore } from "firebase-admin/firestore";
import { clearFirestoreEmulatorData } from "../setup/firestoreEmulator";
import { adminRefreshLeaderboards, adminGenerateDailyMissions } from "../../src/admin/adminOperations";

function requestAs(auth?: { uid: string; role: string }) {
  return {
    data: {},
    auth: auth
      ? { uid: auth.uid, token: { role: auth.role } as never, rawToken: "test-token" }
      : undefined,
    rawRequest: {} as never,
    acceptsStreaming: false,
  } as never;
}

describe("adminRefreshLeaderboards", () => {
  beforeEach(async () => {
    await clearFirestoreEmulatorData();
  });

  it("rejects an unauthenticated caller", async () => {
    await expect(
      adminRefreshLeaderboards.run(requestAs())
    ).rejects.toMatchObject({ code: "unauthenticated" });
  });

  it("rejects a non-admin caller", async () => {
    await expect(
      adminRefreshLeaderboards.run(requestAs({ uid: "parent-1", role: "parent" }))
    ).rejects.toMatchObject({ code: "permission-denied" });
  });

  it("runs the real refresh and writes a leaderboard doc for a seeded learner", async () => {
    const db = getFirestore();
    await db.collection("users").doc("child-1").set({ uid: "child-1", role: "learner", grade: "Grade 3", name: "Testy" });
    await db.collection("rewards").doc("child-1").set({ totalPoints: 42 });

    const result = (await adminRefreshLeaderboards.run(
      requestAs({ uid: "admin-1", role: "admin" })
    )) as { refreshed: boolean };
    expect(result.refreshed).toBe(true);

    const board = await db.collection("leaderboards").doc("Grade 3").collection("allTime").doc("child-1").get();
    expect(board.data()?.xp).toBe(42);
  });
});

describe("adminGenerateDailyMissions", () => {
  beforeEach(async () => {
    await clearFirestoreEmulatorData();
  });

  it("rejects an unauthenticated caller", async () => {
    await expect(
      adminGenerateDailyMissions.run(requestAs())
    ).rejects.toMatchObject({ code: "unauthenticated" });
  });

  it("rejects a non-admin caller", async () => {
    await expect(
      adminGenerateDailyMissions.run(requestAs({ uid: "parent-1", role: "parent" }))
    ).rejects.toMatchObject({ code: "permission-denied" });
  });

  it("runs the real generation and reports total/failed counts", async () => {
    const db = getFirestore();
    await db.collection("users").doc("child-1").set({ role: "learner", grade: "Grade 3" });

    const result = (await adminGenerateDailyMissions.run(
      requestAs({ uid: "admin-1", role: "admin" })
    )) as { total: number; failed: number };
    expect(result).toEqual({ total: 1, failed: 0 });

    const missions = await db
      .collection("daily_missions").doc("child-1")
      .collection("today").doc("missions")
      .get();
    expect(missions.data()?.missions).toHaveLength(3);
  });
});
