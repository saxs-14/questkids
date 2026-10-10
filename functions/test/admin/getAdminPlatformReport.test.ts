import "../setup/firebaseAdmin";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";
import { clearFirestoreEmulatorData } from "../setup/firestoreEmulator";
import { getAdminPlatformReport } from "../../src/admin/getAdminPlatformReport";

// getAdminPlatformReport only reads request.auth -- the rest of
// CallableRequest is unused by the handler, so a minimal fake is enough.
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

describe("getAdminPlatformReport", () => {
  beforeEach(async () => {
    await clearFirestoreEmulatorData();
  });

  it("rejects an unauthenticated caller", async () => {
    await expect(getAdminPlatformReport.run(requestAs())).rejects.toMatchObject({
      code: "unauthenticated",
    } satisfies Partial<HttpsError>);
  });

  it("rejects an authenticated caller who is not an admin", async () => {
    await expect(
      getAdminPlatformReport.run(requestAs({ uid: "parent-1", role: "parent" }))
    ).rejects.toMatchObject({ code: "permission-denied" } satisfies Partial<HttpsError>);
  });

  it("returns zeroed counts for an admin when the database is empty", async () => {
    const report = await getAdminPlatformReport.run(requestAs({ uid: "admin-1", role: "admin" }));

    expect(report).toMatchObject({
      users: 0,
      learners: 0,
      parents: 0,
      admins: 0,
      activities: 0,
      gameSessions: 0,
      gameSessionsLast7Days: 0,
      aiReports: 0,
      resolvedAiReports: 0,
      pendingAiReports: 0,
      weeklyReports: 0,
      periodDays: 7,
    });
    expect(typeof report.generatedAt).toBe("string");
  });

  it("counts pending AI reports as (total - resolved), matching the real status lifecycle", async () => {
    const db = getFirestore();
    await db.collection("ai_reports").add({
      uid: "learner-1",
      reason: "Made me uncomfortable",
      createdAt: FieldValue.serverTimestamp(),
      // No `status` field -- this is how FirestoreService.reportAiMessage
      // actually creates a report. Still-pending reports never had a
      // `status` field written at all.
    });
    await db.collection("ai_reports").add({
      uid: "learner-2",
      reason: "Confusing or wrong answer",
      status: "resolved",
      createdAt: FieldValue.serverTimestamp(),
      resolvedAt: FieldValue.serverTimestamp(),
    });

    const report = await getAdminPlatformReport.run(requestAs({ uid: "admin-1", role: "admin" }));

    expect(report.aiReports).toBe(2);
    expect(report.resolvedAiReports).toBe(1);
    expect(report.pendingAiReports).toBe(1);
  });

  it("counts users by role correctly", async () => {
    const db = getFirestore();
    await db.collection("users").add({ role: "learner" });
    await db.collection("users").add({ role: "learner" });
    await db.collection("users").add({ role: "parent" });
    await db.collection("users").add({ role: "admin" });

    const report = await getAdminPlatformReport.run(requestAs({ uid: "admin-1", role: "admin" }));

    expect(report.users).toBe(4);
    expect(report.learners).toBe(2);
    expect(report.parents).toBe(1);
    expect(report.admins).toBe(1);
  });
});
