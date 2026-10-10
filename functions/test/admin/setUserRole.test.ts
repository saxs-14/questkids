import "../setup/firebaseAdmin";
import { getFirestore } from "firebase-admin/firestore";
import { getAuth } from "firebase-admin/auth";
import { clearFirestoreEmulatorData } from "../setup/firestoreEmulator";
import { clearAuthEmulatorUsers } from "../setup/authEmulator";
import {
  setUserRole,
  grantSelfDeclaredRoleClaim,
} from "../../src/admin/setUserRole";

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

async function ensureAuthUser(uid: string) {
  try {
    await getAuth().getUser(uid);
  } catch {
    await getAuth().createUser({ uid });
  }
}

describe("setUserRole", () => {
  beforeEach(async () => {
    await clearFirestoreEmulatorData();
    await clearAuthEmulatorUsers();
  });

  it("rejects an unauthenticated caller", async () => {
    await expect(
      setUserRole.run(requestAs({ uid: "bob", role: "parent" }))
    ).rejects.toMatchObject({ code: "unauthenticated" });
  });

  it("rejects a non-admin caller", async () => {
    await expect(
      setUserRole.run(
        requestAs({ uid: "bob", role: "parent" }, { uid: "parent-1", role: "parent" })
      )
    ).rejects.toMatchObject({ code: "permission-denied" });
  });

  it("rejects a missing uid", async () => {
    await expect(
      setUserRole.run(requestAs({ role: "parent" }, { uid: "admin-1", role: "admin" }))
    ).rejects.toMatchObject({ code: "invalid-argument" });
  });

  it("rejects an invalid role string", async () => {
    await expect(
      setUserRole.run(
        requestAs({ uid: "bob", role: "superuser" }, { uid: "admin-1", role: "admin" })
      )
    ).rejects.toMatchObject({ code: "invalid-argument" });
  });

  it("rejects an admin changing their own role", async () => {
    await expect(
      setUserRole.run(
        requestAs({ uid: "admin-1", role: "parent" }, { uid: "admin-1", role: "admin" })
      )
    ).rejects.toMatchObject({ code: "failed-precondition" });
  });

  it("rejects demoting the configured bootstrap administrator", async () => {
    await getFirestore().collection("system").doc("adminBootstrap").set({
      adminUid: "bootstrap-admin",
    });
    await expect(
      setUserRole.run(
        requestAs({ uid: "bootstrap-admin", role: "parent" }, { uid: "admin-2", role: "admin" })
      )
    ).rejects.toMatchObject({ code: "failed-precondition" });
  });

  it("rejects granting admin to anyone other than the bootstrap administrator", async () => {
    await getFirestore().collection("system").doc("adminBootstrap").set({
      adminUid: "bootstrap-admin",
    });
    await ensureAuthUser("random-uid");
    await expect(
      setUserRole.run(
        requestAs({ uid: "random-uid", role: "admin" }, { uid: "admin-2", role: "admin" })
      )
    ).rejects.toMatchObject({ code: "permission-denied" });
  });

  it("rejects granting admin when no bootstrap administrator is configured yet", async () => {
    await ensureAuthUser("random-uid");
    await expect(
      setUserRole.run(
        requestAs({ uid: "random-uid", role: "admin" }, { uid: "admin-2", role: "admin" })
      )
    ).rejects.toMatchObject({ code: "permission-denied" });
  });

  it("allows an admin to change another user's role to a valid non-admin role", async () => {
    await ensureAuthUser("bob");
    await getFirestore().collection("users").doc("bob").set({ role: "learner" });

    const result = (await setUserRole.run(
      requestAs({ uid: "bob", role: "parent" }, { uid: "admin-1", role: "admin" })
    )) as { uid: string; role: string };
    expect(result).toEqual({ uid: "bob", role: "parent" });

    const authUser = await getAuth().getUser("bob");
    expect(authUser.customClaims?.role).toBe("parent");

    const userDoc = await getFirestore().collection("users").doc("bob").get();
    expect(userDoc.data()?.role).toBe("parent");
  });
});

describe("grantSelfDeclaredRoleClaim", () => {
  beforeEach(async () => {
    await clearFirestoreEmulatorData();
    await clearAuthEmulatorUsers();
  });

  function docCreatedEvent(uid: string, role: string | undefined) {
    return {
      data: { data: () => ({ role }) },
      params: { uid },
    } as never;
  }

  it("does nothing for a learner self-declaration", async () => {
    // No Auth user is created for this uid -- if the handler incorrectly
    // tried to touch Auth for a non-parent role, getUser() would throw and
    // fail this test.
    await expect(
      grantSelfDeclaredRoleClaim.run(docCreatedEvent("learner-uid", "learner"))
    ).resolves.toBeUndefined();
  });

  it("upgrades a learner's default claim to parent on self-declared parent signup", async () => {
    await getAuth().createUser({ uid: "parent-uid" });
    await getAuth().setCustomUserClaims("parent-uid", { role: "learner" });

    await grantSelfDeclaredRoleClaim.run(docCreatedEvent("parent-uid", "parent"));

    const user = await getAuth().getUser("parent-uid");
    expect(user.customClaims?.role).toBe("parent");
  });

  it("preserves other existing custom claims when upgrading to parent", async () => {
    await getAuth().createUser({ uid: "parent-uid-2" });
    await getAuth().setCustomUserClaims("parent-uid-2", {
      role: "learner",
      someOtherClaim: true,
    });

    await grantSelfDeclaredRoleClaim.run(docCreatedEvent("parent-uid-2", "parent"));

    const user = await getAuth().getUser("parent-uid-2");
    expect(user.customClaims).toMatchObject({ role: "parent", someOtherClaim: true });
  });

  it("is a no-op when the claim already matches parent", async () => {
    await getAuth().createUser({ uid: "parent-uid-3" });
    await getAuth().setCustomUserClaims("parent-uid-3", { role: "parent" });

    await expect(
      grantSelfDeclaredRoleClaim.run(docCreatedEvent("parent-uid-3", "parent"))
    ).resolves.toBeUndefined();

    const user = await getAuth().getUser("parent-uid-3");
    expect(user.customClaims?.role).toBe("parent");
  });
});
