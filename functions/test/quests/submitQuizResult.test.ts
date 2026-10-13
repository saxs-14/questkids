import "../setup/firebaseAdmin";
import { getFirestore } from "firebase-admin/firestore";
import { clearFirestoreEmulatorData } from "../setup/firestoreEmulator";
import { submitQuizResult } from "../../src/quests/submitQuizResult";

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

const BASE = {
  submissionId: "quiz-submission-1",
  activityId: "multiplication",
  answers: ["42", "63"],
  timeTakenSeconds: 60,
};

async function seedQuiz() {
  const db = getFirestore();
  await db.collection("users").doc("child-1").set({
    uid: "child-1",
    role: "learner",
    totalPoints: 0,
  });
  await db.collection("activities").doc("multiplication").set({
    title: "Multiplication",
    subject: "Mathematics",
    rewardPoints: 20,
    questions: [
      { question: "6 x 7", options: ["40", "42"], correctIndex: 1 },
      { question: "7 x 9", options: ["63", "72"], correctIndex: 0 },
    ],
  });
}

describe("submitQuizResult", () => {
  beforeEach(async () => {
    await clearFirestoreEmulatorData();
  });

  it("rejects unauthenticated and non-learner callers", async () => {
    await expect(submitQuizResult.run(requestAs(BASE))).rejects.toMatchObject({
      code: "unauthenticated",
    });
    await expect(
      submitQuizResult.run(requestAs(BASE, { uid: "parent-1", role: "parent" }))
    ).rejects.toMatchObject({ code: "permission-denied" });
  });

  it("writes quiz progress and rewards atomically using server-checked answers", async () => {
    await seedQuiz();
    const result = await submitQuizResult.run(
      requestAs(BASE, { uid: "child-1", role: "learner" })
    ) as { recorded: boolean; score: number; pointsEarned: number };

    expect(result).toMatchObject({ recorded: true, score: 100, pointsEarned: 40 });
    const db = getFirestore();
    const progress = await db.collection("progress").doc(BASE.submissionId).get();
    const rewards = await db.collection("rewards").doc("child-1").get();
    const user = await db.collection("users").doc("child-1").get();
    expect(progress.data()?.pointsEarned).toBe(40);
    expect(rewards.data()?.totalPoints).toBe(40);
    expect(user.data()?.totalPoints).toBe(40);
  });

  it("does not award progress or points twice when a queued request is retried", async () => {
    await seedQuiz();
    const request = requestAs(BASE, { uid: "child-1", role: "learner" });
    await submitQuizResult.run(request);
    const retry = await submitQuizResult.run(request) as { recorded: boolean };

    expect(retry.recorded).toBe(false);
    const db = getFirestore();
    expect((await db.collection("progress").get()).size).toBe(1);
    expect((await db.collection("rewards").doc("child-1").get()).data()?.totalPoints)
      .toBe(40);
    expect((await db.collection("users").doc("child-1").get()).data()?.totalPoints)
      .toBe(40);
  });

  it("rejects invalid or stale quiz submissions without writing partial data", async () => {
    await seedQuiz();
    await expect(
      submitQuizResult.run(
        requestAs({ ...BASE, answers: ["42"] }, { uid: "child-1", role: "learner" })
      )
    ).rejects.toMatchObject({ code: "failed-precondition" });
    expect((await getFirestore().collection("progress").get()).empty).toBe(true);
  });
});
