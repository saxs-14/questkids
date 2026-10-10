import "../setup/firebaseAdmin";
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import { clearFirestoreEmulatorData } from "../setup/firestoreEmulator";
import { notifyParentsOfLearnerInactivity } from "../../src/notifications/parentInactivity";

const DAY_MS = 24 * 60 * 60 * 1000;

async function seedLearner(
  uid: string,
  { daysSincePlayed, previousLevel = 0, linkedParentUids = ["parent-1"] }:
    { daysSincePlayed: number | null; previousLevel?: number; linkedParentUids?: string[] }
) {
  await getFirestore().collection("users").doc(uid).set({
    uid,
    role: "learner",
    name: "Thandi",
    linkedParentUids,
  });
  if (daysSincePlayed !== null) {
    await getFirestore().collection("player_stats").doc(uid).set({
      lastPlayedAt: Timestamp.fromMillis(Date.now() - daysSincePlayed * DAY_MS),
      inactivityNotificationLevel: previousLevel,
    });
  }
}

async function seedLinkedParent(parentUid: string, childUid: string) {
  await getFirestore().collection("users").doc(parentUid).set({
    role: "parent",
    linkedChildrenUids: [childUid],
  });
}

async function inactivityNotesFor(parentUid: string) {
  const snap = await getFirestore()
    .collection("notifications")
    .where("recipientUid", "==", parentUid)
    .where("type", "==", "parent_inactivity")
    .get();
  return snap.docs.map((d) => d.data());
}

describe("notifyParentsOfLearnerInactivity", () => {
  beforeEach(async () => {
    await clearFirestoreEmulatorData();
  });

  it("skips a learner who has never played (no stats doc)", async () => {
    await seedLearner("child-1", { daysSincePlayed: null });
    await seedLinkedParent("parent-1", "child-1");
    await notifyParentsOfLearnerInactivity.run({} as never);
    expect(await inactivityNotesFor("parent-1")).toHaveLength(0);
  });

  it("skips a learner who played recently (below the 3-day threshold)", async () => {
    await seedLearner("child-1", { daysSincePlayed: 1 });
    await seedLinkedParent("parent-1", "child-1");
    await notifyParentsOfLearnerInactivity.run({} as never);
    expect(await inactivityNotesFor("parent-1")).toHaveLength(0);
  });

  it("notifies the linked parent at the 3-day threshold and advances the level", async () => {
    await seedLearner("child-1", { daysSincePlayed: 3 });
    await seedLinkedParent("parent-1", "child-1");
    await notifyParentsOfLearnerInactivity.run({} as never);

    const notes = await inactivityNotesFor("parent-1");
    expect(notes).toHaveLength(1);
    expect(notes[0]).toMatchObject({ inactivityDays: 3, childUid: "child-1" });

    const stats = await getFirestore().collection("player_stats").doc("child-1").get();
    expect(stats.data()?.inactivityNotificationLevel).toBe(3);
  });

  it(
    "is idempotent across repeated daily runs: does not re-notify the same " +
      "threshold once it has already been sent",
    async () => {
      await seedLearner("child-1", { daysSincePlayed: 3, previousLevel: 3 });
      await seedLinkedParent("parent-1", "child-1");
      await notifyParentsOfLearnerInactivity.run({} as never);
      expect(await inactivityNotesFor("parent-1")).toHaveLength(0);
    }
  );

  it("sends both the 3-day and 7-day alerts in one run if a scheduled run was missed", async () => {
    await seedLearner("child-1", { daysSincePlayed: 8, previousLevel: 0 });
    await seedLinkedParent("parent-1", "child-1");
    await notifyParentsOfLearnerInactivity.run({} as never);

    const notes = await inactivityNotesFor("parent-1");
    const daysSent = notes.map((n) => n.inactivityDays).sort();
    expect(daysSent).toEqual([3, 7]);

    const stats = await getFirestore().collection("player_stats").doc("child-1").get();
    expect(stats.data()?.inactivityNotificationLevel).toBe(7);
  });

  it("sends only the 7-day alert when the 3-day alert already fired previously", async () => {
    await seedLearner("child-1", { daysSincePlayed: 8, previousLevel: 3 });
    await seedLinkedParent("parent-1", "child-1");
    await notifyParentsOfLearnerInactivity.run({} as never);

    const notes = await inactivityNotesFor("parent-1");
    expect(notes.map((n) => n.inactivityDays)).toEqual([7]);
  });

  it("does not advance the notification level when there are no linked parents yet", async () => {
    await seedLearner("child-1", { daysSincePlayed: 3, linkedParentUids: [] });
    await notifyParentsOfLearnerInactivity.run({} as never);
    const stats = await getFirestore().collection("player_stats").doc("child-1").get();
    expect(stats.data()?.inactivityNotificationLevel).toBe(0);
  });

  it("does not notify a parent who isn't reciprocally linked", async () => {
    await seedLearner("child-1", { daysSincePlayed: 3, linkedParentUids: ["parent-1"] });
    await getFirestore().collection("users").doc("parent-1").set({
      role: "parent",
      linkedChildrenUids: [], // not linked back
    });
    await notifyParentsOfLearnerInactivity.run({} as never);
    expect(await inactivityNotesFor("parent-1")).toHaveLength(0);
  });
});
