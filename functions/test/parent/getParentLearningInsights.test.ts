import "../setup/firebaseAdmin";

const mockGenerateContent = jest.fn();
const mockGetGenerativeModel = jest.fn(() => ({ generateContent: mockGenerateContent }));

jest.mock("@google/generative-ai", () => ({
  GoogleGenerativeAI: jest.fn().mockImplementation(() => ({
    getGenerativeModel: mockGetGenerativeModel,
  })),
}));

process.env.GEMINI_API_KEY = "test-gemini-key-not-real";

import { getFirestore, Timestamp } from "firebase-admin/firestore";
import { clearFirestoreEmulatorData } from "../setup/firestoreEmulator";
import { getParentLearningInsights } from "../../src/parent/getParentLearningInsights";

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

async function seedLinkedFamily() {
  await getFirestore().collection("users").doc("parent-1").set({
    role: "parent",
    linkedChildrenUids: ["child-1"],
  });
  await getFirestore().collection("users").doc("child-1").set({
    role: "learner",
    name: "Thandi Mokoena",
    grade: "Grade 4",
    parentUid: "parent-1",
  });
}

describe("getParentLearningInsights", () => {
  beforeEach(async () => {
    await clearFirestoreEmulatorData();
    mockGenerateContent.mockReset();
    mockGenerateContent.mockResolvedValue({
      response: { text: () => '{"summary":"Doing well!","strengths":["Math"],"focusAreas":[],"actions":["a","b","c"],"disclaimer":"d"}' },
    });
  });

  it("rejects an unauthenticated caller", async () => {
    await expect(
      getParentLearningInsights.run(requestAs({ childUid: "child-1" }))
    ).rejects.toMatchObject({ code: "unauthenticated" });
  });

  it("rejects a non-parent caller", async () => {
    await expect(
      getParentLearningInsights.run(
        requestAs({ childUid: "child-1" }, { uid: "learner-1", role: "learner" })
      )
    ).rejects.toMatchObject({ code: "permission-denied" });
  });

  it("rejects a missing childUid", async () => {
    await expect(
      getParentLearningInsights.run(requestAs({}, { uid: "parent-1", role: "parent" }))
    ).rejects.toMatchObject({ code: "invalid-argument" });
  });

  it("rejects when the child account doesn't exist", async () => {
    await getFirestore().collection("users").doc("parent-1").set({
      role: "parent",
      linkedChildrenUids: [],
    });
    await expect(
      getParentLearningInsights.run(
        requestAs({ childUid: "ghost-child" }, { uid: "parent-1", role: "parent" })
      )
    ).rejects.toMatchObject({ code: "not-found" });
  });

  it("rejects a parent who isn't actually linked to the child (cross-family)", async () => {
    await getFirestore().collection("users").doc("parent-2").set({
      role: "parent",
      linkedChildrenUids: [], // not linked to child-1
    });
    await getFirestore().collection("users").doc("child-1").set({
      role: "learner",
      parentUid: "someone-else",
      linkedParentUids: [],
    });
    await expect(
      getParentLearningInsights.run(
        requestAs({ childUid: "child-1" }, { uid: "parent-2", role: "parent" })
      )
    ).rejects.toMatchObject({ code: "permission-denied" });
  });

  it(
    "returns a deterministic response with no AI call when there are no valid scored sessions",
    async () => {
      await seedLinkedFamily();
      const result = (await getParentLearningInsights.run(
        requestAs({ childUid: "child-1" }, { uid: "parent-1", role: "parent" })
      )) as unknown as { sessionsAnalysed: number; insights: { summary: string } };

      expect(result.sessionsAnalysed).toBe(0);
      expect(mockGenerateContent).not.toHaveBeenCalled();
    }
  );

  it("filters out sessions with an invalid score or missing completedAt", async () => {
    await seedLinkedFamily();
    const db = getFirestore();
    await db.collection("game_sessions").doc("s1").set({
      uid: "child-1",
      score: 80,
      subject: "Mathematics",
      completedAt: Timestamp.now(),
    });
    await db.collection("game_sessions").doc("s2").set({
      uid: "child-1",
      score: 150, // invalid, out of range
      subject: "Mathematics",
      completedAt: Timestamp.now(),
    });
    await db.collection("game_sessions").doc("s3").set({
      uid: "child-1",
      score: 70,
      subject: "English",
      // no completedAt at all
    });

    const result = (await getParentLearningInsights.run(
      requestAs({ childUid: "child-1" }, { uid: "parent-1", role: "parent" })
    )) as { sessionsAnalysed: number; averageScore: number };

    expect(result.sessionsAnalysed).toBe(1);
    expect(result.averageScore).toBe(80);
  });

  it("calls Gemini and returns parsed insights when valid sessions exist", async () => {
    await seedLinkedFamily();
    await getFirestore().collection("game_sessions").doc("s1").set({
      uid: "child-1",
      score: 90,
      subject: "Mathematics",
      completedAt: Timestamp.now(),
    });

    const result = (await getParentLearningInsights.run(
      requestAs({ childUid: "child-1" }, { uid: "parent-1", role: "parent" })
    )) as unknown as { insights: { summary: string } };

    expect(mockGenerateContent).toHaveBeenCalledTimes(1);
    expect(result.insights.summary).toBe("Doing well!");
  });

  it("falls back to a deterministic structure when Gemini doesn't return valid JSON", async () => {
    await seedLinkedFamily();
    await getFirestore().collection("game_sessions").doc("s1").set({
      uid: "child-1",
      score: 90,
      subject: "Mathematics",
      completedAt: Timestamp.now(),
    });
    mockGenerateContent.mockResolvedValue({ response: { text: () => "not valid json" } });

    const result = (await getParentLearningInsights.run(
      requestAs({ childUid: "child-1" }, { uid: "parent-1", role: "parent" })
    )) as unknown as { insights: { summary: string; actions: string[] } };

    expect(result.insights.summary).toContain("not valid json");
    expect(result.insights.actions).toHaveLength(1);
  });

  it("throws 'unavailable' when the Gemini call itself fails", async () => {
    await seedLinkedFamily();
    await getFirestore().collection("game_sessions").doc("s1").set({
      uid: "child-1",
      score: 90,
      subject: "Mathematics",
      completedAt: Timestamp.now(),
    });
    mockGenerateContent.mockRejectedValue(new Error("Gemini is down"));

    await expect(
      getParentLearningInsights.run(
        requestAs({ childUid: "child-1" }, { uid: "parent-1", role: "parent" })
      )
    ).rejects.toMatchObject({ code: "unavailable" });
  });

  it("enforces the daily parent-insight quota (10) even on the zero-session deterministic path", async () => {
    await seedLinkedFamily();
    await getFirestore().collection("usage_parent_ai").doc("parent-1").set({
      date: new Date().toISOString().slice(0, 10),
      count: 10,
    });
    await expect(
      getParentLearningInsights.run(
        requestAs({ childUid: "child-1" }, { uid: "parent-1", role: "parent" })
      )
    ).rejects.toMatchObject({ code: "resource-exhausted" });
  });
});
