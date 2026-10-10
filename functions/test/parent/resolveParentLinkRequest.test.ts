import "../setup/firebaseAdmin";
import { getFirestore } from "firebase-admin/firestore";
import { clearFirestoreEmulatorData } from "../setup/firestoreEmulator";
import { resolveParentLinkRequest } from "../../src/parent/resolveParentLinkRequest";

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

async function seedPendingRequest(
  requestId: string,
  overrides: Record<string, unknown> = {}
) {
  await getFirestore().collection("parent_link_requests").doc(requestId).set({
    id: requestId,
    childUid: "child-1",
    primaryParentUid: "parent-1",
    requestingParentUid: "parent-2",
    status: "pending",
    ...overrides,
  });
}

async function seedAccounts() {
  await getFirestore().collection("users").doc("child-1").set({
    uid: "child-1",
    role: "learner",
  });
  await getFirestore().collection("users").doc("parent-1").set({
    uid: "parent-1",
    role: "parent",
    linkedChildrenUids: [],
  });
  await getFirestore().collection("users").doc("parent-2").set({
    uid: "parent-2",
    role: "parent",
    linkedChildrenUids: [],
  });
}

describe("resolveParentLinkRequest", () => {
  beforeEach(async () => {
    await clearFirestoreEmulatorData();
  });

  it("rejects an unauthenticated caller", async () => {
    await expect(
      resolveParentLinkRequest.run(requestAs({ requestId: "req-1", action: "approve" }))
    ).rejects.toMatchObject({ code: "unauthenticated" });
  });

  it("rejects a non-parent caller", async () => {
    await expect(
      resolveParentLinkRequest.run(
        requestAs(
          { requestId: "req-1", action: "approve" },
          { uid: "learner-1", role: "learner" }
        )
      )
    ).rejects.toMatchObject({ code: "permission-denied" });
  });

  it("rejects an invalid action", async () => {
    await expect(
      resolveParentLinkRequest.run(
        requestAs(
          { requestId: "req-1", action: "delete-everything" },
          { uid: "parent-1", role: "parent" }
        )
      )
    ).rejects.toMatchObject({ code: "invalid-argument" });
  });

  it("rejects a request that doesn't exist", async () => {
    await expect(
      resolveParentLinkRequest.run(
        requestAs({ requestId: "ghost", action: "approve" }, { uid: "parent-1", role: "parent" })
      )
    ).rejects.toMatchObject({ code: "not-found" });
  });

  it("rejects a request that's already been resolved", async () => {
    await seedAccounts();
    await seedPendingRequest("req-1", { status: "approved" });
    await expect(
      resolveParentLinkRequest.run(
        requestAs({ requestId: "req-1", action: "approve" }, { uid: "parent-1", role: "parent" })
      )
    ).rejects.toMatchObject({ code: "failed-precondition" });
  });

  it("rejects approval by anyone other than the primary parent", async () => {
    await seedAccounts();
    await seedPendingRequest("req-1");
    await expect(
      resolveParentLinkRequest.run(
        requestAs(
          { requestId: "req-1", action: "approve" },
          { uid: "some-rando", role: "parent" }
        )
      )
    ).rejects.toMatchObject({ code: "permission-denied" });
  });

  it("rejects decline by anyone other than the primary parent", async () => {
    await seedAccounts();
    await seedPendingRequest("req-1");
    await expect(
      resolveParentLinkRequest.run(
        requestAs(
          { requestId: "req-1", action: "decline" },
          { uid: "parent-2", role: "parent" }
        )
      )
    ).rejects.toMatchObject({ code: "permission-denied" });
  });

  it("rejects cancel by anyone other than the requesting parent", async () => {
    await seedAccounts();
    await seedPendingRequest("req-1");
    await expect(
      resolveParentLinkRequest.run(
        requestAs(
          { requestId: "req-1", action: "cancel" },
          { uid: "parent-1", role: "parent" }
        )
      )
    ).rejects.toMatchObject({ code: "permission-denied" });
  });

  it("approves the request, links both sides, and sets default permissions", async () => {
    await seedAccounts();
    await seedPendingRequest("req-1");

    const result = (await resolveParentLinkRequest.run(
      requestAs({ requestId: "req-1", action: "approve" }, { uid: "parent-1", role: "parent" })
    )) as { resolved: boolean; action: string };
    expect(result).toEqual({ resolved: true, action: "approve" });

    const child = await getFirestore().collection("users").doc("child-1").get();
    expect(child.data()?.linkedParentUids).toContain("parent-2");
    expect(child.data()?.parentPermissions?.["parent-2"]).toMatchObject({
      viewProgress: true,
      verifyProgress: false,
    });

    const requester = await getFirestore().collection("users").doc("parent-2").get();
    expect(requester.data()?.linkedChildrenUids).toContain("child-1");

    const req = await getFirestore().collection("parent_link_requests").doc("req-1").get();
    expect(req.data()?.status).toBe("approved");

    const notifications = await getFirestore()
      .collection("notifications")
      .where("recipientUid", "==", "parent-2")
      .where("type", "==", "link_approved")
      .get();
    expect(notifications.size).toBe(1);
  });

  it("rejects approval when the child or requester account no longer exists", async () => {
    await seedPendingRequest("req-1"); // accounts not seeded
    await getFirestore().collection("users").doc("parent-1").set({ role: "parent" });
    await expect(
      resolveParentLinkRequest.run(
        requestAs({ requestId: "req-1", action: "approve" }, { uid: "parent-1", role: "parent" })
      )
    ).rejects.toMatchObject({ code: "not-found" });
  });

  it("the primary parent can decline a pending request", async () => {
    await seedAccounts();
    await seedPendingRequest("req-1");
    const result = (await resolveParentLinkRequest.run(
      requestAs({ requestId: "req-1", action: "decline" }, { uid: "parent-1", role: "parent" })
    )) as { resolved: boolean; action: string };
    expect(result).toEqual({ resolved: true, action: "decline" });
    const req = await getFirestore().collection("parent_link_requests").doc("req-1").get();
    expect(req.data()?.status).toBe("declined");
  });

  it("the requesting parent can cancel their own pending request", async () => {
    await seedAccounts();
    await seedPendingRequest("req-1");
    const result = (await resolveParentLinkRequest.run(
      requestAs({ requestId: "req-1", action: "cancel" }, { uid: "parent-2", role: "parent" })
    )) as { resolved: boolean; action: string };
    expect(result).toEqual({ resolved: true, action: "cancel" });
    const req = await getFirestore().collection("parent_link_requests").doc("req-1").get();
    expect(req.data()?.status).toBe("cancelled");
  });
});
