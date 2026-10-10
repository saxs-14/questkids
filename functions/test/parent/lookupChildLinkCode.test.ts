import "../setup/firebaseAdmin";
import { getFirestore } from "firebase-admin/firestore";
import { clearFirestoreEmulatorData } from "../setup/firestoreEmulator";
import { lookupChildLinkCode } from "../../src/parent/lookupChildLinkCode";

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

describe("lookupChildLinkCode", () => {
  beforeEach(async () => {
    await clearFirestoreEmulatorData();
  });

  it("rejects an unauthenticated caller", async () => {
    await expect(
      lookupChildLinkCode.run(requestAs({ code: "ABC123" }))
    ).rejects.toMatchObject({ code: "unauthenticated" });
  });

  it("rejects a non-parent caller", async () => {
    await expect(
      lookupChildLinkCode.run(
        requestAs({ code: "ABC123" }, { uid: "learner-1", role: "learner" })
      )
    ).rejects.toMatchObject({ code: "permission-denied" });
  });

  it("rejects a malformed code", async () => {
    await expect(
      lookupChildLinkCode.run(
        requestAs({ code: "nope" }, { uid: "parent-1", role: "parent" })
      )
    ).rejects.toMatchObject({ code: "invalid-argument" });
  });

  it("rejects a code with no match", async () => {
    await expect(
      lookupChildLinkCode.run(
        requestAs({ code: "ZZZ999" }, { uid: "parent-1", role: "parent" })
      )
    ).rejects.toMatchObject({ code: "not-found" });
  });

  it("rejects an ambiguous code", async () => {
    await getFirestore().collection("users").doc("c1").set({ role: "learner", childLinkCode: "DUP111" });
    await getFirestore().collection("users").doc("c2").set({ role: "learner", childLinkCode: "DUP111" });
    await expect(
      lookupChildLinkCode.run(
        requestAs({ code: "DUP111" }, { uid: "parent-1", role: "parent" })
      )
    ).rejects.toMatchObject({ code: "failed-precondition" });
  });

  it("rejects a code matching a non-learner account", async () => {
    await getFirestore().collection("users").doc("not-a-child").set({
      role: "parent",
      childLinkCode: "ABC123",
    });
    await expect(
      lookupChildLinkCode.run(
        requestAs({ code: "ABC123" }, { uid: "parent-1", role: "parent" })
      )
    ).rejects.toMatchObject({ code: "not-found" });
  });

  it("reports a child with no primary parent and no existing link", async () => {
    await getFirestore().collection("users").doc("child-1").set({
      role: "learner",
      name: "Thandi",
      grade: "Grade 3",
      childLinkCode: "ABC123",
    });
    const result = (await lookupChildLinkCode.run(
      requestAs({ code: "abc123" }, { uid: "parent-1", role: "parent" })
    )) as Record<string, unknown>;
    expect(result).toMatchObject({
      childUid: "child-1",
      childName: "Thandi",
      hasPrimaryParent: false,
      alreadyLinked: false,
      isPrimaryParent: false,
    });
  });

  it("identifies the caller as the primary parent when parentUid matches", async () => {
    await getFirestore().collection("users").doc("child-1").set({
      role: "learner",
      childLinkCode: "ABC123",
      parentUid: "parent-1",
    });
    const result = (await lookupChildLinkCode.run(
      requestAs({ code: "ABC123" }, { uid: "parent-1", role: "parent" })
    )) as Record<string, unknown>;
    expect(result).toMatchObject({
      hasPrimaryParent: true,
      isPrimaryParent: true,
      alreadyLinked: false,
    });
  });

  it("identifies the caller as already linked when in linkedParentUids", async () => {
    await getFirestore().collection("users").doc("child-1").set({
      role: "learner",
      childLinkCode: "ABC123",
      parentUid: "parent-1",
      linkedParentUids: ["parent-2"],
    });
    const result = (await lookupChildLinkCode.run(
      requestAs({ code: "ABC123" }, { uid: "parent-2", role: "parent" })
    )) as Record<string, unknown>;
    expect(result).toMatchObject({
      hasPrimaryParent: true,
      isPrimaryParent: false,
      alreadyLinked: true,
    });
  });
});
