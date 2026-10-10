import "../setup/firebaseAdmin";
import { getFirestore } from "firebase-admin/firestore";
import { clearFirestoreEmulatorData } from "../setup/firestoreEmulator";
import { notifyParentsOfGameSession } from "../../src/notifications/parentGameActivity";

function createdEvent(sessionId: string, session: Record<string, unknown>) {
  return {
    data: { data: () => session },
    params: { sessionId },
  } as never;
}

async function notificationsFor(recipientUid: string) {
  const snap = await getFirestore()
    .collection("notifications")
    .where("recipientUid", "==", recipientUid)
    .get();
  return snap.docs.map((d) => d.data());
}

describe("notifyParentsOfGameSession", () => {
  beforeEach(async () => {
    await clearFirestoreEmulatorData();
  });

  it("does nothing when the learner has no linked parents", async () => {
    await getFirestore().collection("users").doc("child-1").set({
      name: "Thandi",
      linkedParentUids: [],
    });
    await notifyParentsOfGameSession.run(
      createdEvent("session-1", { uid: "child-1", score: 90, result: "win", engineType: "tugOfWar" })
    );
    expect(await notificationsFor("child-1")).toHaveLength(0);
  });

  it("notifies a reciprocally-linked parent", async () => {
    await getFirestore().collection("users").doc("child-1").set({
      name: "Thandi",
      linkedParentUids: ["parent-1"],
    });
    await getFirestore().collection("users").doc("parent-1").set({
      role: "parent",
      linkedChildrenUids: ["child-1"],
    });
    await notifyParentsOfGameSession.run(
      createdEvent("session-1", {
        uid: "child-1",
        score: 90,
        result: "win",
        engineType: "tugOfWar",
        catalogId: "eng_g1_nouns",
      })
    );
    const notes = await notificationsFor("parent-1");
    expect(notes).toHaveLength(1);
    expect(notes[0]).toMatchObject({ type: "parent_update", childUid: "child-1" });
    expect(notes[0].body).toContain("90%");
  });

  it("does not notify a parent the child lists but who doesn't list the child back", async () => {
    await getFirestore().collection("users").doc("child-1").set({
      name: "Thandi",
      linkedParentUids: ["parent-1"],
    });
    await getFirestore().collection("users").doc("parent-1").set({
      role: "parent",
      linkedChildrenUids: [], // not reciprocally linked
    });
    await notifyParentsOfGameSession.run(
      createdEvent("session-1", { uid: "child-1", score: 90, result: "win" })
    );
    expect(await notificationsFor("parent-1")).toHaveLength(0);
  });

  it("does not notify an account that isn't actually a parent", async () => {
    await getFirestore().collection("users").doc("child-1").set({
      linkedParentUids: ["not-a-parent"],
    });
    await getFirestore().collection("users").doc("not-a-parent").set({
      role: "learner",
      linkedChildrenUids: ["child-1"],
    });
    await notifyParentsOfGameSession.run(
      createdEvent("session-1", { uid: "child-1", score: 50, result: "loss" })
    );
    expect(await notificationsFor("not-a-parent")).toHaveLength(0);
  });

  it("does nothing when the learner's own account no longer exists", async () => {
    await notifyParentsOfGameSession.run(
      createdEvent("session-1", { uid: "ghost-child", score: 50, result: "win" })
    );
    // No throw, and nothing created for a uid that was never a recipient.
    expect(await notificationsFor("ghost-child")).toHaveLength(0);
  });
});
