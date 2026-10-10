import "../setup/firebaseAdmin";
import { getFirestore } from "firebase-admin/firestore";
import { clearFirestoreEmulatorData } from "../setup/firestoreEmulator";
import { linkRegisteredChild } from "../../src/parent/linkChild";

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

describe("linkRegisteredChild", () => {
  beforeEach(async () => {
    await clearFirestoreEmulatorData();
  });

  it("rejects an unauthenticated caller", async () => {
    await expect(
      linkRegisteredChild.run(requestAs({ childUid: "child-1" }))
    ).rejects.toMatchObject({ code: "unauthenticated" });
  });

  it("rejects a missing childUid", async () => {
    await expect(
      linkRegisteredChild.run(requestAs({}, { uid: "parent-1", role: "parent" }))
    ).rejects.toMatchObject({ code: "invalid-argument" });
  });

  it("rejects linking a child that doesn't exist", async () => {
    await expect(
      linkRegisteredChild.run(
        requestAs({ childUid: "ghost-child" }, { uid: "parent-1", role: "parent" })
      )
    ).rejects.toMatchObject({ code: "not-found" });
  });

  it("rejects linking a child whose parentUid doesn't match the caller (cross-family)", async () => {
    await getFirestore().collection("users").doc("child-1").set({
      uid: "child-1",
      role: "learner",
      parentUid: "someone-elses-parent-uid",
    });
    await expect(
      linkRegisteredChild.run(
        requestAs({ childUid: "child-1" }, { uid: "parent-1", role: "parent" })
      )
    ).rejects.toMatchObject({ code: "permission-denied" });
  });

  it("links a child whose own doc already declares this parent", async () => {
    await getFirestore().collection("users").doc("child-1").set({
      uid: "child-1",
      role: "learner",
      parentUid: "parent-1",
    });
    await getFirestore().collection("users").doc("parent-1").set({
      uid: "parent-1",
      role: "parent",
      linkedChildrenUids: [],
    });

    const result = (await linkRegisteredChild.run(
      requestAs({ childUid: "child-1" }, { uid: "parent-1", role: "parent" })
    )) as { linked: boolean };
    expect(result).toEqual({ linked: true });

    const parentDoc = await getFirestore().collection("users").doc("parent-1").get();
    expect(parentDoc.data()?.linkedChildrenUids).toContain("child-1");
  });
});
