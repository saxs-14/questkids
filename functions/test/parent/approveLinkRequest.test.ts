import "../setup/firebaseAdmin";
import { getFirestore } from "firebase-admin/firestore";
import { clearFirestoreEmulatorData } from "../setup/firestoreEmulator";
import { approveParentLinkRequest } from "../../src/parent/approveLinkRequest";

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

describe("approveParentLinkRequest", () => {
  beforeEach(async () => {
    await clearFirestoreEmulatorData();
  });

  it("rejects an unauthenticated caller", async () => {
    await expect(
      approveParentLinkRequest.run(requestAs({ requestId: "req-1" }))
    ).rejects.toMatchObject({ code: "unauthenticated" });
  });

  it("rejects a missing requestId", async () => {
    await expect(
      approveParentLinkRequest.run(requestAs({}, { uid: "parent-1", role: "parent" }))
    ).rejects.toMatchObject({ code: "invalid-argument" });
  });

  it("rejects a request that doesn't exist", async () => {
    await expect(
      approveParentLinkRequest.run(
        requestAs({ requestId: "ghost" }, { uid: "parent-1", role: "parent" })
      )
    ).rejects.toMatchObject({ code: "not-found" });
  });

  it("rejects approval by anyone other than the primary parent", async () => {
    await getFirestore().collection("parent_link_requests").doc("req-1").set({
      childUid: "child-1",
      primaryParentUid: "parent-1",
      requestingParentUid: "parent-2",
      status: "pending",
    });
    await expect(
      approveParentLinkRequest.run(
        requestAs({ requestId: "req-1" }, { uid: "parent-2", role: "parent" })
      )
    ).rejects.toMatchObject({ code: "permission-denied" });
  });

  it("rejects a request that's already resolved", async () => {
    await getFirestore().collection("parent_link_requests").doc("req-1").set({
      childUid: "child-1",
      primaryParentUid: "parent-1",
      requestingParentUid: "parent-2",
      status: "approved",
    });
    await expect(
      approveParentLinkRequest.run(
        requestAs({ requestId: "req-1" }, { uid: "parent-1", role: "parent" })
      )
    ).rejects.toMatchObject({ code: "failed-precondition" });
  });

  it("links both sides and marks the request approved", async () => {
    await getFirestore().collection("users").doc("child-1").set({ linkedParentUids: [] });
    await getFirestore().collection("users").doc("parent-2").set({ linkedChildrenUids: [] });
    await getFirestore().collection("parent_link_requests").doc("req-1").set({
      childUid: "child-1",
      primaryParentUid: "parent-1",
      requestingParentUid: "parent-2",
      status: "pending",
    });

    const result = (await approveParentLinkRequest.run(
      requestAs({ requestId: "req-1" }, { uid: "parent-1", role: "parent" })
    )) as { approved: boolean };
    expect(result).toEqual({ approved: true });

    const child = await getFirestore().collection("users").doc("child-1").get();
    expect(child.data()?.linkedParentUids).toContain("parent-2");

    const requester = await getFirestore().collection("users").doc("parent-2").get();
    expect(requester.data()?.linkedChildrenUids).toContain("child-1");

    const req = await getFirestore().collection("parent_link_requests").doc("req-1").get();
    expect(req.data()?.status).toBe("approved");
  });
});
