import "../setup/firebaseAdmin";
import { getFirestore } from "firebase-admin/firestore";
import { clearFirestoreEmulatorData } from "../setup/firestoreEmulator";
import { requestParentLink } from "../../src/parent/requestParentLink";

function requestAs(data: Record<string, unknown>, auth?: { uid: string; role: string; email?: string }) {
  return {
    data,
    auth: auth
      ? {
          uid: auth.uid,
          token: { role: auth.role, email: auth.email } as never,
          rawToken: "test-token",
        }
      : undefined,
    rawRequest: {} as never,
    acceptsStreaming: false,
  } as never;
}

async function seedChild(
  childUid: string,
  overrides: Record<string, unknown> = {}
) {
  await getFirestore().collection("users").doc(childUid).set({
    uid: childUid,
    role: "learner",
    name: "Thandi",
    grade: "Grade 3",
    childLinkCode: "ABC123",
    linkedParentUids: [],
    ...overrides,
  });
}

describe("requestParentLink", () => {
  beforeEach(async () => {
    await clearFirestoreEmulatorData();
  });

  it("rejects an unauthenticated caller", async () => {
    await expect(
      requestParentLink.run(requestAs({ code: "ABC123" }))
    ).rejects.toMatchObject({ code: "unauthenticated" });
  });

  it("rejects a non-parent caller", async () => {
    await expect(
      requestParentLink.run(
        requestAs({ code: "ABC123" }, { uid: "learner-1", role: "learner" })
      )
    ).rejects.toMatchObject({ code: "permission-denied" });
  });

  it("rejects a malformed code", async () => {
    await expect(
      requestParentLink.run(
        requestAs({ code: "bad" }, { uid: "parent-2", role: "parent" })
      )
    ).rejects.toMatchObject({ code: "invalid-argument" });
  });

  it("rejects a code that matches no child", async () => {
    await expect(
      requestParentLink.run(
        requestAs({ code: "ZZZ999" }, { uid: "parent-2", role: "parent" })
      )
    ).rejects.toMatchObject({ code: "not-found" });
  });

  it("rejects an ambiguous code shared by two accounts", async () => {
    await seedChild("child-1", { childLinkCode: "DUPE11" });
    await seedChild("child-2", { childLinkCode: "DUPE11" });
    await expect(
      requestParentLink.run(
        requestAs({ code: "DUPE11" }, { uid: "parent-2", role: "parent" })
      )
    ).rejects.toMatchObject({ code: "failed-precondition" });
  });

  it("rejects a code that matches a non-learner account", async () => {
    await getFirestore().collection("users").doc("not-a-child").set({
      uid: "not-a-child",
      role: "parent",
      childLinkCode: "ABC123",
    });
    await expect(
      requestParentLink.run(
        requestAs({ code: "ABC123" }, { uid: "parent-2", role: "parent" })
      )
    ).rejects.toMatchObject({ code: "not-found" });
  });

  it("rejects when the child has no primary parent yet", async () => {
    await seedChild("child-1");
    await expect(
      requestParentLink.run(
        requestAs({ code: "ABC123" }, { uid: "parent-2", role: "parent" })
      )
    ).rejects.toMatchObject({ code: "failed-precondition" });
  });

  it("rejects when the caller is already the primary parent", async () => {
    await seedChild("child-1", { parentUid: "parent-1" });
    await expect(
      requestParentLink.run(
        requestAs({ code: "ABC123" }, { uid: "parent-1", role: "parent" })
      )
    ).rejects.toMatchObject({ code: "already-exists" });
  });

  it("rejects when the caller is already a linked secondary parent", async () => {
    await seedChild("child-1", { parentUid: "parent-1", linkedParentUids: ["parent-2"] });
    await expect(
      requestParentLink.run(
        requestAs({ code: "ABC123" }, { uid: "parent-2", role: "parent" })
      )
    ).rejects.toMatchObject({ code: "already-exists" });
  });

  it("rejects a duplicate pending request for the same child", async () => {
    await seedChild("child-1", { parentUid: "parent-1" });
    await requestParentLink.run(
      requestAs({ code: "ABC123" }, { uid: "parent-2", role: "parent" })
    );
    await expect(
      requestParentLink.run(
        requestAs({ code: "ABC123" }, { uid: "parent-2", role: "parent" })
      )
    ).rejects.toMatchObject({ code: "already-exists" });
  });

  it("creates a pending request and notifies the primary parent", async () => {
    await seedChild("child-1", { parentUid: "parent-1" });
    await getFirestore().collection("users").doc("parent-2").set({
      uid: "parent-2",
      role: "parent",
      name: "Second Parent",
    });

    const result = (await requestParentLink.run(
      requestAs(
        { code: "abc123" },
        { uid: "parent-2", role: "parent", email: "parent2@example.com" }
      )
    )) as { requestId: string; childUid: string; status: string };

    expect(result.childUid).toBe("child-1");
    expect(result.status).toBe("pending");

    const reqDoc = await getFirestore()
      .collection("parent_link_requests")
      .doc(result.requestId)
      .get();
    expect(reqDoc.data()).toMatchObject({
      childUid: "child-1",
      primaryParentUid: "parent-1",
      requestingParentUid: "parent-2",
      status: "pending",
    });

    const notifications = await getFirestore()
      .collection("notifications")
      .where("recipientUid", "==", "parent-1")
      .where("type", "==", "parent_link_request")
      .get();
    expect(notifications.size).toBe(1);
  });
});
