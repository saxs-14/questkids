import "../setup/firebaseAdmin";
import { getFirestore } from "firebase-admin/firestore";
import { clearFirestoreEmulatorData } from "../setup/firestoreEmulator";
import { sendQuestReminders } from "../../src/notifications/reminders";

async function seedLearnerWithMissions(
  uid: string,
  missions: { completed?: boolean }[] | null
) {
  await getFirestore().collection("users").doc(uid).set({ uid, role: "learner" });
  if (missions !== null) {
    await getFirestore()
      .collection("daily_missions")
      .doc(uid)
      .collection("today")
      .doc("missions")
      .set({ missions });
  }
}

async function remindersFor(uid: string) {
  const snap = await getFirestore()
    .collection("notifications")
    .where("recipientUid", "==", uid)
    .where("type", "==", "reminder")
    .get();
  return snap.docs.map((d) => d.data());
}

describe("sendQuestReminders", () => {
  beforeEach(async () => {
    await clearFirestoreEmulatorData();
  });

  it("skips a learner with no missions generated yet today", async () => {
    await seedLearnerWithMissions("child-1", null);
    await sendQuestReminders.run({} as never);
    expect(await remindersFor("child-1")).toHaveLength(0);
  });

  it("skips a learner who has already completed at least one mission today", async () => {
    await seedLearnerWithMissions("child-1", [{ completed: true }, { completed: false }]);
    await sendQuestReminders.run({} as never);
    expect(await remindersFor("child-1")).toHaveLength(0);
  });

  it("reminds a learner with missions but none completed yet", async () => {
    await seedLearnerWithMissions("child-1", [{ completed: false }, { completed: false }]);
    await sendQuestReminders.run({} as never);
    expect(await remindersFor("child-1")).toHaveLength(1);
  });

  it("does not remind a non-learner account even with pending missions", async () => {
    await getFirestore().collection("users").doc("parent-1").set({ role: "parent" });
    await getFirestore()
      .collection("daily_missions")
      .doc("parent-1")
      .collection("today")
      .doc("missions")
      .set({ missions: [{ completed: false }] });
    await sendQuestReminders.run({} as never);
    expect(await remindersFor("parent-1")).toHaveLength(0);
  });

  it("reminds multiple eligible learners independently in one run", async () => {
    await seedLearnerWithMissions("child-1", [{ completed: false }]);
    await seedLearnerWithMissions("child-2", [{ completed: true }]);
    await seedLearnerWithMissions("child-3", [{ completed: false }]);
    await sendQuestReminders.run({} as never);
    expect(await remindersFor("child-1")).toHaveLength(1);
    expect(await remindersFor("child-2")).toHaveLength(0);
    expect(await remindersFor("child-3")).toHaveLength(1);
  });
});
