import "../setup/firebaseAdmin";
import { getFirestore } from "firebase-admin/firestore";
import { clearFirestoreEmulatorData } from "../setup/firestoreEmulator";
import { onBadgeAwarded } from "../../src/notifications/badgeAward";

function updateEvent(
  uid: string,
  before: Record<string, unknown>,
  after: Record<string, unknown>
) {
  return {
    data: { before: { data: () => before }, after: { data: () => after } },
    params: { uid },
  } as never;
}

async function notificationsFor(recipientUid: string) {
  const snap = await getFirestore()
    .collection("notifications")
    .where("recipientUid", "==", recipientUid)
    .get();
  return snap.docs.map((d) => d.data());
}

describe("onBadgeAwarded", () => {
  beforeEach(async () => {
    await clearFirestoreEmulatorData();
  });

  it("does nothing when no new badge was added", async () => {
    await getFirestore().collection("users").doc("child-1").set({ name: "Thandi" });
    await onBadgeAwarded.run(
      updateEvent(
        "child-1",
        { badges: [{ id: "first_quest" }] },
        { badges: [{ id: "first_quest" }] }
      )
    );
    expect(await notificationsFor("child-1")).toHaveLength(0);
  });

  it("notifies the learner when a new badge is added, with no linked parents", async () => {
    await getFirestore().collection("users").doc("child-1").set({
      name: "Thandi",
      linkedParentUids: [],
    });
    await onBadgeAwarded.run(
      updateEvent("child-1", { badges: [] }, { badges: [{ id: "first_quest", name: "First Quest" }] })
    );
    const notes = await notificationsFor("child-1");
    expect(notes).toHaveLength(1);
    expect(notes[0]).toMatchObject({ type: "achievement", recipientUid: "child-1" });
  });

  it("also notifies every linked parent", async () => {
    await getFirestore().collection("users").doc("child-1").set({
      name: "Thandi",
      linkedParentUids: ["parent-1", "parent-2"],
    });
    await onBadgeAwarded.run(
      updateEvent("child-1", { badges: [] }, { badges: [{ id: "first_quest", name: "First Quest" }] })
    );
    expect(await notificationsFor("child-1")).toHaveLength(1);
    expect(await notificationsFor("parent-1")).toHaveLength(1);
    expect(await notificationsFor("parent-2")).toHaveLength(1);
    const parentNote = (await notificationsFor("parent-1"))[0];
    expect(parentNote).toMatchObject({ type: "parent_update" });
  });

  it("notifies once per new badge when multiple are added in the same update", async () => {
    await getFirestore().collection("users").doc("child-1").set({
      name: "Thandi",
      linkedParentUids: ["parent-1"],
    });
    await onBadgeAwarded.run(
      updateEvent(
        "child-1",
        { badges: [{ id: "first_quest" }] },
        {
          badges: [
            { id: "first_quest" },
            { id: "perfect_score", name: "Perfect Score" },
            { id: "quest_master", name: "Quest Master" },
          ],
        }
      )
    );
    expect(await notificationsFor("child-1")).toHaveLength(2); // perfect_score + quest_master
    expect(await notificationsFor("parent-1")).toHaveLength(2);
  });

  it("does nothing if the learner's own user document no longer exists", async () => {
    await onBadgeAwarded.run(
      updateEvent("ghost-child", { badges: [] }, { badges: [{ id: "first_quest" }] })
    );
    expect(await notificationsFor("ghost-child")).toHaveLength(0);
  });
});
