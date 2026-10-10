import "../setup/firebaseAdmin";

// No GEMINI_API_KEY is set in this file, so getAdaptiveMissions() short-
// circuits to [] (see its own `if (!apiKey) return [];` guard) -- this lets
// the teacher-assigned/curated tiers be tested without mocking Gemini too.
delete process.env.GEMINI_API_KEY;

import { getFirestore } from "firebase-admin/firestore";
import { clearFirestoreEmulatorData } from "../setup/firestoreEmulator";
import { generateDailyMissions } from "../../src/missions/generate";

async function missionsDocFor(uid: string) {
  const snap = await getFirestore()
    .collection("daily_missions")
    .doc(uid)
    .collection("today")
    .doc("missions")
    .get();
  return snap.data() as { missions: { id: string; gameId: string; source: string }[] } | undefined;
}

describe("generateDailyMissions", () => {
  beforeEach(async () => {
    await clearFirestoreEmulatorData();
  });

  it("does nothing (no crash) when there are no learners", async () => {
    await expect(generateDailyMissions.run({} as never)).resolves.toBeUndefined();
  });

  it("gives a learner with no teacher-assigned missions 3 curated missions", async () => {
    await getFirestore().collection("users").doc("child-1").set({ role: "learner", grade: "Grade 3" });
    await generateDailyMissions.run({} as never);
    const doc = await missionsDocFor("child-1");
    expect(doc?.missions).toHaveLength(3);
    expect(doc?.missions.every((m) => m.source === "curated")).toBe(true);
  });

  it("prioritizes teacher-assigned missions over curated ones, up to 3", async () => {
    await getFirestore().collection("users").doc("child-1").set({ role: "learner", grade: "Grade 3" });
    await getFirestore()
      .collection("daily_missions")
      .doc("child-1")
      .collection("assigned")
      .doc("t1")
      .set({ gameId: "tugOfWar", title: "Teacher Pick", subject: "Mathematics" });

    await generateDailyMissions.run({} as never);
    const doc = await missionsDocFor("child-1");
    expect(doc?.missions).toHaveLength(3);
    expect(doc?.missions[0]).toMatchObject({ source: "teacher", gameId: "tugOfWar" });
    expect(doc?.missions.slice(1).every((m) => m.source === "curated")).toBe(true);
  });

  it("does not duplicate a curated gameId already present from the teacher tier", async () => {
    await getFirestore().collection("users").doc("child-1").set({ role: "learner", grade: "Grade 3" });
    // Day index 1's curated catalog always includes at least one gameId --
    // assign that exact one via the teacher tier so the curated fill-in
    // logic must skip it rather than adding a duplicate.
    const { MISSION_CATALOG } = await import("../../src/missions/catalog");
    const dayIndex = new Date().getDay();
    const catalogGameId = MISSION_CATALOG[dayIndex]?.[0]?.gameId ?? MISSION_CATALOG[1][0].gameId;

    await getFirestore()
      .collection("daily_missions")
      .doc("child-1")
      .collection("assigned")
      .doc("t1")
      .set({ gameId: catalogGameId, title: "Teacher Pick", subject: "Mathematics" });

    await generateDailyMissions.run({} as never);
    const doc = await missionsDocFor("child-1");
    const gameIds = doc?.missions.map((m) => m.gameId) ?? [];
    expect(gameIds.filter((id) => id === catalogGameId)).toHaveLength(1);
  });

  it("caps teacher-assigned missions at 3 even if more are assigned", async () => {
    await getFirestore().collection("users").doc("child-1").set({ role: "learner", grade: "Grade 3" });
    for (let i = 0; i < 5; i++) {
      await getFirestore()
        .collection("daily_missions")
        .doc("child-1")
        .collection("assigned")
        .doc(`t${i}`)
        .set({ gameId: `game-${i}`, title: `Teacher ${i}`, subject: "Mathematics" });
    }
    await generateDailyMissions.run({} as never);
    const doc = await missionsDocFor("child-1");
    expect(doc?.missions).toHaveLength(3);
  });

  it("generates missions independently for multiple learners in the same run", async () => {
    await getFirestore().collection("users").doc("child-1").set({ role: "learner", grade: "Grade 3" });
    await getFirestore().collection("users").doc("child-2").set({ role: "learner", grade: "Grade 4" });
    await generateDailyMissions.run({} as never);
    expect((await missionsDocFor("child-1"))?.missions).toHaveLength(3);
    expect((await missionsDocFor("child-2"))?.missions).toHaveLength(3);
  });

  it("overwrites (not merges) a learner's missions on a re-run", async () => {
    await getFirestore().collection("users").doc("child-1").set({ role: "learner", grade: "Grade 3" });
    await generateDailyMissions.run({} as never);
    const first = await missionsDocFor("child-1");

    await getFirestore()
      .collection("daily_missions")
      .doc("child-1")
      .collection("assigned")
      .doc("t1")
      .set({ gameId: "tugOfWar", title: "New Teacher Pick", subject: "Mathematics" });
    await generateDailyMissions.run({} as never);
    const second = await missionsDocFor("child-1");

    expect(second?.missions).toHaveLength(3);
    expect(second?.missions[0].source).toBe("teacher");
    expect(second).not.toEqual(first);
  });
});
