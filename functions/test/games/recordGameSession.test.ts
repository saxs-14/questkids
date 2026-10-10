import "../setup/firebaseAdmin";
import { getFirestore } from "firebase-admin/firestore";
import { clearFirestoreEmulatorData } from "../setup/firestoreEmulator";
import { recordGameSession } from "../../src/games/recordGameSession";

function requestAs(data: Record<string, unknown>, auth?: { uid: string; role: string }) {
  return {
    data,
    auth: auth
      ? { uid: auth.uid, token: { role: auth.role } as never, rawToken: "test-token" }
      : undefined,
    rawRequest: {} as never,
    acceptsStreaming: false,
  } as never;
}

async function seedLearner(uid: string) {
  await getFirestore().collection("users").doc(uid).set({ uid, role: "learner" });
}

const BASE_NON_LEVELLED = {
  id: "session-1",
  engineType: "tugOfWar",
  subject: "Mathematics",
  grade: "Grade 5",
  score: 80,
  accuracy: 0.8,
  timeTakenSeconds: 60,
};

describe("recordGameSession", () => {
  beforeEach(async () => {
    await clearFirestoreEmulatorData();
  });

  it("rejects an unauthenticated caller", async () => {
    await expect(
      recordGameSession.run(requestAs(BASE_NON_LEVELLED))
    ).rejects.toMatchObject({ code: "unauthenticated" });
  });

  it("rejects a non-learner caller", async () => {
    await expect(
      recordGameSession.run(requestAs(BASE_NON_LEVELLED, { uid: "parent-1", role: "parent" }))
    ).rejects.toMatchObject({ code: "permission-denied" });
  });

  it("rejects a missing/invalid required field", async () => {
    await seedLearner("child-1");
    await expect(
      recordGameSession.run(
        requestAs({ ...BASE_NON_LEVELLED, id: "" }, { uid: "child-1", role: "learner" })
      )
    ).rejects.toMatchObject({ code: "invalid-argument" });
  });

  it("rejects a non-numeric score", async () => {
    await seedLearner("child-1");
    await expect(
      recordGameSession.run(
        requestAs({ ...BASE_NON_LEVELLED, score: "a lot" }, { uid: "child-1", role: "learner" })
      )
    ).rejects.toMatchObject({ code: "invalid-argument" });
  });

  it("clamps an out-of-range score instead of rejecting it", async () => {
    await seedLearner("child-1");
    const result = (await recordGameSession.run(
      requestAs({ ...BASE_NON_LEVELLED, score: 150 }, { uid: "child-1", role: "learner" })
    )) as { result: string; xpEarned: number };
    expect(result.result).toBe("win");
    const session = await getFirestore()
      .collection("game_sessions")
      .doc("session-1")
      .get();
    expect(session.data()?.score).toBe(100);
  });

  it("rejects a level for a non-levelled catalogId", async () => {
    await seedLearner("child-1");
    await expect(
      recordGameSession.run(
        requestAs(
          { ...BASE_NON_LEVELLED, catalogId: "reading_g5_basics", metadata: { level: 2 } },
          { uid: "child-1", role: "learner" }
        )
      )
    ).rejects.toMatchObject({ code: "invalid-argument" });
  });

  it("rejects a levelled catalogId submitted without a level", async () => {
    await seedLearner("child-1");
    await expect(
      recordGameSession.run(
        requestAs(
          { ...BASE_NON_LEVELLED, catalogId: "math_g1_addition" },
          { uid: "child-1", role: "learner" }
        )
      )
    ).rejects.toMatchObject({ code: "invalid-argument" });
  });

  it("rejects when the caller's own account is not an active learner", async () => {
    await getFirestore().collection("users").doc("child-1").set({ role: "parent" });
    await expect(
      recordGameSession.run(requestAs(BASE_NON_LEVELLED, { uid: "child-1", role: "learner" }))
    ).rejects.toMatchObject({ code: "permission-denied" });
  });

  it("records a winning non-levelled session and updates stats/rewards/engine/user totals", async () => {
    await seedLearner("child-1");
    const result = (await recordGameSession.run(
      requestAs(BASE_NON_LEVELLED, { uid: "child-1", role: "learner" })
    )) as { recorded: boolean; result: string; xpEarned: number; coinsEarned: number };

    expect(result.recorded).toBe(true);
    expect(result.result).toBe("win");
    const expectedXp = Math.max(10, Math.round(80 * 1.2));
    expect(result.xpEarned).toBe(expectedXp);

    const stats = await getFirestore().collection("player_stats").doc("child-1").get();
    expect(stats.data()?.xp).toBe(expectedXp);
    expect(stats.data()?.gamesPlayed).toBe(1);
    expect(stats.data()?.wins).toBe(1);

    const user = await getFirestore().collection("users").doc("child-1").get();
    expect(user.data()?.totalPoints).toBe(expectedXp);

    const rewards = await getFirestore().collection("rewards").doc("child-1").get();
    const badgeIds = (rewards.data()?.badges ?? []).map((b: { id: string }) => b.id);
    expect(badgeIds).toContain("first_quest");

    const engine = await getFirestore()
      .collection("game_progress")
      .doc("child-1")
      .collection("engines")
      .doc("tugOfWar")
      .get();
    expect(engine.data()?.totalGames).toBe(1);
  });

  it("records a losing session as result 'loss' with no win credit", async () => {
    await seedLearner("child-1");
    const result = (await recordGameSession.run(
      requestAs({ ...BASE_NON_LEVELLED, score: 20 }, { uid: "child-1", role: "learner" })
    )) as { result: string };
    expect(result.result).toBe("loss");

    const stats = await getFirestore().collection("player_stats").doc("child-1").get();
    expect(stats.data()?.wins).toBe(0);
    expect(stats.data()?.losses).toBe(1);
  });

  it("awards the perfect_score badge for a 100% score", async () => {
    await seedLearner("child-1");
    await recordGameSession.run(
      requestAs({ ...BASE_NON_LEVELLED, score: 100 }, { uid: "child-1", role: "learner" })
    );
    const rewards = await getFirestore().collection("rewards").doc("child-1").get();
    const badgeIds = (rewards.data()?.badges ?? []).map((b: { id: string }) => b.id);
    expect(badgeIds).toContain("perfect_score");
  });

  it(
    "is idempotent on replay: resubmitting the same sessionId returns the original " +
      "result and does not double-award XP/coins",
    async () => {
      await seedLearner("child-1");
      const first = (await recordGameSession.run(
        requestAs(BASE_NON_LEVELLED, { uid: "child-1", role: "learner" })
      )) as { xpEarned: number; coinsEarned: number; result: string };

      const second = (await recordGameSession.run(
        requestAs(BASE_NON_LEVELLED, { uid: "child-1", role: "learner" })
      )) as { xpEarned: number; coinsEarned: number; result: string };

      expect(second).toEqual(first);

      const stats = await getFirestore().collection("player_stats").doc("child-1").get();
      expect(stats.data()?.xp).toBe(first.xpEarned);
      expect(stats.data()?.gamesPlayed).toBe(1); // not 2
    }
  );

  it("rejects skipping ahead of the learner's current level", async () => {
    await seedLearner("child-1");
    await getFirestore()
      .collection("game_level_progress")
      .doc("child-1")
      .collection("games")
      .doc("math_g1_addition")
      .set({ currentLevel: 3 });

    await expect(
      recordGameSession.run(
        requestAs(
          {
            ...BASE_NON_LEVELLED,
            catalogId: "math_g1_addition",
            metadata: { level: 5 },
          },
          { uid: "child-1", role: "learner" }
        )
      )
    ).rejects.toMatchObject({ code: "failed-precondition" });
  });

  it("advances to the next level on a winning levelled session", async () => {
    await seedLearner("child-1");
    const result = (await recordGameSession.run(
      requestAs(
        { ...BASE_NON_LEVELLED, catalogId: "math_g1_addition", score: 80, metadata: { level: 1 } },
        { uid: "child-1", role: "learner" }
      )
    )) as { currentLevel: number; levelAdvanced: boolean };

    expect(result.levelAdvanced).toBe(true);
    expect(result.currentLevel).toBe(2);

    const levelDoc = await getFirestore()
      .collection("game_level_progress")
      .doc("child-1")
      .collection("games")
      .doc("math_g1_addition")
      .get();
    expect(levelDoc.data()?.currentLevel).toBe(2);
  });

  it("does not advance the level on a losing levelled session", async () => {
    await seedLearner("child-1");
    const result = (await recordGameSession.run(
      requestAs(
        { ...BASE_NON_LEVELLED, catalogId: "math_g1_addition", score: 20, metadata: { level: 1 } },
        { uid: "child-1", role: "learner" }
      )
    )) as { currentLevel: number; levelAdvanced: boolean };

    expect(result.levelAdvanced).toBe(false);
    expect(result.currentLevel).toBe(1);
  });

  it("marks completedAllLevels when winning at the final level (10)", async () => {
    await seedLearner("child-1");
    await getFirestore()
      .collection("game_level_progress")
      .doc("child-1")
      .collection("games")
      .doc("math_g1_addition")
      .set({ currentLevel: 10 });

    const result = (await recordGameSession.run(
      requestAs(
        { ...BASE_NON_LEVELLED, catalogId: "math_g1_addition", score: 90, metadata: { level: 10 } },
        { uid: "child-1", role: "learner" }
      )
    )) as { currentLevel: number; completedAllLevels: boolean };

    expect(result.completedAllLevels).toBe(true);
    expect(result.currentLevel).toBe(10);
  });
});
