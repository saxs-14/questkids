import "../setup/firebaseAdmin";

const mockGenerateContent = jest.fn();
const mockGetGenerativeModel = jest.fn(() => ({ generateContent: mockGenerateContent }));

jest.mock("@google/generative-ai", () => ({
  GoogleGenerativeAI: jest.fn().mockImplementation(() => ({
    getGenerativeModel: mockGetGenerativeModel,
  })),
}));

import { getFirestore, Timestamp } from "firebase-admin/firestore";
import { clearFirestoreEmulatorData } from "../setup/firestoreEmulator";
import { generateWeeklyGameReports } from "../../src/reports/weeklyGameReport";

describe("generateWeeklyGameReports", () => {
  beforeEach(async () => {
    await clearFirestoreEmulatorData();
    mockGenerateContent.mockReset();
    mockGenerateContent.mockResolvedValue({
      response: {
        text: () =>
          '{"summary":"Great week!","strengths":["Math"],"focusAreas":[],"nextWeekPlan":["a","b","c"],"encouragement":"Keep going! 🌟"}',
      },
    });
  });

  it("skips entirely (no crash, no report) when GEMINI_API_KEY is not configured", async () => {
    delete process.env.GEMINI_API_KEY;
    const db = getFirestore();
    await db.collection("users").doc("child-1").set({ role: "learner", name: "Thandi" });
    await db.collection("game_sessions").doc("s1").set({
      uid: "child-1",
      score: 90,
      subject: "Mathematics",
      completedAt: Timestamp.now(),
    });

    await generateWeeklyGameReports.run({} as never);
    expect(mockGenerateContent).not.toHaveBeenCalled();
    const reports = await db.collection("weekly_reports").get();
    expect(reports.empty).toBe(true);
  });

  describe("with a configured API key", () => {
    beforeEach(() => {
      process.env.GEMINI_API_KEY = "test-gemini-key-not-real";
    });

    it("generates a report for a learner with recent sessions and notifies linked parents", async () => {
      const db = getFirestore();
      await db.collection("users").doc("child-1").set({
        role: "learner",
        name: "Thandi",
        grade: "Grade 4",
        parentUid: "parent-1",
        linkedParentUids: ["parent-2"],
      });
      await db.collection("game_sessions").doc("s1").set({
        uid: "child-1",
        score: 90,
        subject: "Mathematics",
        completedAt: Timestamp.now(),
      });
      await db.collection("game_sessions").doc("s2").set({
        uid: "child-1",
        score: 70,
        subject: "English",
        completedAt: Timestamp.now(),
      });

      await generateWeeklyGameReports.run({} as never);

      const reports = await db.collection("weekly_reports").get();
      expect(reports.size).toBe(1);
      const report = reports.docs[0].data();
      expect(report.childUid).toBe("child-1");
      expect(report.gamesCompleted).toBe(2);
      expect(report.averageScore).toBe(80);
      expect(report.report.summary).toBe("Great week!");

      const notifsP1 = await db
        .collection("notifications")
        .where("recipientUid", "==", "parent-1")
        .where("type", "==", "weekly_game_report")
        .get();
      const notifsP2 = await db
        .collection("notifications")
        .where("recipientUid", "==", "parent-2")
        .where("type", "==", "weekly_game_report")
        .get();
      expect(notifsP1.size).toBe(1);
      expect(notifsP2.size).toBe(1);
    });

    it("excludes sessions older than 7 days", async () => {
      const db = getFirestore();
      await db.collection("users").doc("child-1").set({ role: "learner", name: "Thandi" });
      const eightDaysAgo = Timestamp.fromMillis(Date.now() - 8 * 24 * 60 * 60 * 1000);
      await db.collection("game_sessions").doc("stale").set({
        uid: "child-1",
        score: 10,
        subject: "Mathematics",
        completedAt: eightDaysAgo,
      });

      await generateWeeklyGameReports.run({} as never);
      const reports = await db.collection("weekly_reports").get();
      expect(reports.empty).toBe(true);
    });

    it("skips a session whose uid no longer has a user account", async () => {
      const db = getFirestore();
      await db.collection("game_sessions").doc("s1").set({
        uid: "ghost-child",
        score: 90,
        subject: "Mathematics",
        completedAt: Timestamp.now(),
      });
      await generateWeeklyGameReports.run({} as never);
      const reports = await db.collection("weekly_reports").get();
      expect(reports.empty).toBe(true);
    });

    it("skips a session belonging to a non-learner account", async () => {
      const db = getFirestore();
      await db.collection("users").doc("parent-1").set({ role: "parent" });
      await db.collection("game_sessions").doc("s1").set({
        uid: "parent-1",
        score: 90,
        subject: "Mathematics",
        completedAt: Timestamp.now(),
      });
      await generateWeeklyGameReports.run({} as never);
      const reports = await db.collection("weekly_reports").get();
      expect(reports.empty).toBe(true);
    });

    it("falls back to a deterministic report structure when Gemini doesn't return valid JSON", async () => {
      const db = getFirestore();
      await db.collection("users").doc("child-1").set({ role: "learner", name: "Thandi" });
      await db.collection("game_sessions").doc("s1").set({
        uid: "child-1",
        score: 90,
        subject: "Mathematics",
        completedAt: Timestamp.now(),
      });
      mockGenerateContent.mockResolvedValue({ response: { text: () => "not json" } });

      await generateWeeklyGameReports.run({} as never);
      const reports = await db.collection("weekly_reports").get();
      expect(reports.docs[0].data().report.summary).toContain("not json");
    });
  });
});
