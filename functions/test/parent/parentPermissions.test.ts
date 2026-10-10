import "../setup/firebaseAdmin";
import { getFirestore } from "firebase-admin/firestore";
import { clearFirestoreEmulatorData } from "../setup/firestoreEmulator";
import { getParentAccess, setParentPermissions } from "../../src/parent/parentPermissions";

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

async function seedChildWithSecondaryParent() {
  await getFirestore().collection("users").doc("child-1").set({
    uid: "child-1",
    role: "learner",
    parentUid: "parent-1",
    linkedParentUids: ["parent-2"],
    parentPermissions: { "parent-2": { viewProgress: true, verifyProgress: false } },
  });
  await getFirestore().collection("users").doc("parent-2").set({
    uid: "parent-2",
    name: "Second Parent",
    surname: "Smith",
    email: "p2@example.com",
  });
}

describe("getParentAccess", () => {
  beforeEach(async () => {
    await clearFirestoreEmulatorData();
  });

  it("rejects an unauthenticated caller", async () => {
    await expect(
      getParentAccess.run(requestAs({ childUid: "child-1" }))
    ).rejects.toMatchObject({ code: "unauthenticated" });
  });

  it("rejects a non-parent caller", async () => {
    await expect(
      getParentAccess.run(
        requestAs({ childUid: "child-1" }, { uid: "learner-1", role: "learner" })
      )
    ).rejects.toMatchObject({ code: "permission-denied" });
  });

  it("rejects a parent who isn't the child's primary parent", async () => {
    await seedChildWithSecondaryParent();
    await expect(
      getParentAccess.run(
        requestAs({ childUid: "child-1" }, { uid: "parent-2", role: "parent" })
      )
    ).rejects.toMatchObject({ code: "permission-denied" });
  });

  it("returns linked secondary parents with merged default+custom permissions", async () => {
    await seedChildWithSecondaryParent();
    const result = (await getParentAccess.run(
      requestAs({ childUid: "child-1" }, { uid: "parent-1", role: "parent" })
    )) as { parents: { uid: string; permissions: Record<string, boolean> }[] };

    expect(result.parents).toHaveLength(1);
    expect(result.parents[0].uid).toBe("parent-2");
    expect(result.parents[0].permissions).toMatchObject({
      viewProgress: true,
      verifyProgress: false,
      viewMood: true, // default, not explicitly set
    });
  });

  it("excludes the primary parent from the secondary-parents list", async () => {
    await getFirestore().collection("users").doc("child-1").set({
      role: "learner",
      parentUid: "parent-1",
      linkedParentUids: ["parent-1"],
    });
    const result = (await getParentAccess.run(
      requestAs({ childUid: "child-1" }, { uid: "parent-1", role: "parent" })
    )) as { parents: unknown[] };
    expect(result.parents).toHaveLength(0);
  });
});

describe("setParentPermissions", () => {
  beforeEach(async () => {
    await clearFirestoreEmulatorData();
  });

  it("rejects a parent who isn't the child's primary parent", async () => {
    await seedChildWithSecondaryParent();
    await expect(
      setParentPermissions.run(
        requestAs(
          { childUid: "child-1", parentUid: "parent-2", permissions: { viewProgress: false } },
          { uid: "parent-2", role: "parent" }
        )
      )
    ).rejects.toMatchObject({ code: "permission-denied" });
  });

  it("rejects setting permissions for a parentUid that isn't a linked secondary parent", async () => {
    await seedChildWithSecondaryParent();
    await expect(
      setParentPermissions.run(
        requestAs(
          { childUid: "child-1", parentUid: "not-linked", permissions: { viewProgress: false } },
          { uid: "parent-1", role: "parent" }
        )
      )
    ).rejects.toMatchObject({ code: "failed-precondition" });
  });

  it("rejects setting permissions on the primary parent themself", async () => {
    await getFirestore().collection("users").doc("child-1").set({
      role: "learner",
      parentUid: "parent-1",
      linkedParentUids: ["parent-1"],
    });
    await expect(
      setParentPermissions.run(
        requestAs(
          { childUid: "child-1", parentUid: "parent-1", permissions: { viewProgress: false } },
          { uid: "parent-1", role: "parent" }
        )
      )
    ).rejects.toMatchObject({ code: "failed-precondition" });
  });

  it("rejects a non-object permissions payload", async () => {
    await seedChildWithSecondaryParent();
    await expect(
      setParentPermissions.run(
        requestAs(
          { childUid: "child-1", parentUid: "parent-2", permissions: "everything" },
          { uid: "parent-1", role: "parent" }
        )
      )
    ).rejects.toMatchObject({ code: "invalid-argument" });
  });

  it("updates only known permission keys and ignores unknown ones", async () => {
    await seedChildWithSecondaryParent();
    const result = (await setParentPermissions.run(
      requestAs(
        {
          childUid: "child-1",
          parentUid: "parent-2",
          permissions: { verifyProgress: true, notARealPermission: true },
        },
        { uid: "parent-1", role: "parent" }
      )
    )) as { updated: boolean; permissions: Record<string, unknown> };

    expect(result.updated).toBe(true);
    expect(result.permissions).not.toHaveProperty("notARealPermission");
    expect(result.permissions.verifyProgress).toBe(true);

    const child = await getFirestore().collection("users").doc("child-1").get();
    expect(child.data()?.parentPermissions?.["parent-2"]?.verifyProgress).toBe(true);

    const notifications = await getFirestore()
      .collection("notifications")
      .where("recipientUid", "==", "parent-2")
      .where("type", "==", "parent_permissions_updated")
      .get();
    expect(notifications.size).toBe(1);
  });
});
