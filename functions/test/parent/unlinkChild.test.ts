import "../setup/firebaseAdmin";
import { getFirestore } from "firebase-admin/firestore";
import { clearFirestoreEmulatorData } from "../setup/firestoreEmulator";
import { unlinkParentChild } from "../../src/parent/unlinkChild";

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

describe("unlinkParentChild", () => {
  beforeEach(async () => {
    await clearFirestoreEmulatorData();
  });

  it("rejects an unauthenticated caller", async () => {
    await expect(
      unlinkParentChild.run(requestAs({ childUid: "child-1" }))
    ).rejects.toMatchObject({ code: "unauthenticated" });
  });

  it("rejects a missing childUid", async () => {
    await expect(
      unlinkParentChild.run(requestAs({}, { uid: "parent-1", role: "parent" }))
    ).rejects.toMatchObject({ code: "invalid-argument" });
  });

  it("rejects unlinking a child that doesn't exist", async () => {
    await expect(
      unlinkParentChild.run(
        requestAs({ childUid: "ghost" }, { uid: "parent-1", role: "parent" })
      )
    ).rejects.toMatchObject({ code: "not-found" });
  });

  it("rejects a parent who isn't currently linked to the child", async () => {
    await getFirestore().collection("users").doc("child-1").set({
      linkedParentUids: ["parent-2"],
    });
    await expect(
      unlinkParentChild.run(
        requestAs({ childUid: "child-1" }, { uid: "parent-1", role: "parent" })
      )
    ).rejects.toMatchObject({ code: "permission-denied" });
  });

  it("removes the caller's own link from both sides", async () => {
    await getFirestore().collection("users").doc("child-1").set({
      linkedParentUids: ["parent-1", "parent-2"],
    });
    await getFirestore().collection("users").doc("parent-1").set({
      linkedChildrenUids: ["child-1"],
    });

    const result = (await unlinkParentChild.run(
      requestAs({ childUid: "child-1" }, { uid: "parent-1", role: "parent" })
    )) as { unlinked: boolean };
    expect(result).toEqual({ unlinked: true });

    const child = await getFirestore().collection("users").doc("child-1").get();
    expect(child.data()?.linkedParentUids).not.toContain("parent-1");
    expect(child.data()?.linkedParentUids).toContain("parent-2");

    const parent = await getFirestore().collection("users").doc("parent-1").get();
    expect(parent.data()?.linkedChildrenUids).not.toContain("child-1");
  });

  it("does not let one parent unlink a different parent's link to the child", async () => {
    await getFirestore().collection("users").doc("child-1").set({
      linkedParentUids: ["parent-1", "parent-2"],
    });
    await getFirestore().collection("users").doc("parent-3").set({
      linkedChildrenUids: [],
    });
    // parent-3 is not in child-1's linkedParentUids at all.
    await expect(
      unlinkParentChild.run(
        requestAs({ childUid: "child-1" }, { uid: "parent-3", role: "parent" })
      )
    ).rejects.toMatchObject({ code: "permission-denied" });

    const child = await getFirestore().collection("users").doc("child-1").get();
    expect(child.data()?.linkedParentUids).toEqual(["parent-1", "parent-2"]);
  });
});
