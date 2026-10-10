import "../setup/firebaseAdmin";
import { getFirestore } from "firebase-admin/firestore";
import { getAuth } from "firebase-admin/auth";
import { clearFirestoreEmulatorData } from "../setup/firestoreEmulator";
import { clearAuthEmulatorUsers } from "../setup/authEmulator";
import { setUserDisabled } from "../../src/admin/setUserDisabled";

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

describe("setUserDisabled", () => {
  beforeEach(async () => {
    await clearFirestoreEmulatorData();
    await clearAuthEmulatorUsers();
  });

  it("rejects an unauthenticated caller", async () => {
    await expect(
      setUserDisabled.run(requestAs({ uid: "bob", disabled: true }))
    ).rejects.toMatchObject({ code: "unauthenticated" });
  });

  it("rejects a non-admin caller", async () => {
    await expect(
      setUserDisabled.run(
        requestAs({ uid: "bob", disabled: true }, { uid: "parent-1", role: "parent" })
      )
    ).rejects.toMatchObject({ code: "permission-denied" });
  });

  it("rejects a missing uid", async () => {
    await expect(
      setUserDisabled.run(requestAs({ disabled: true }, { uid: "admin-1", role: "admin" }))
    ).rejects.toMatchObject({ code: "invalid-argument" });
  });

  it("rejects a non-boolean disabled value", async () => {
    await expect(
      setUserDisabled.run(
        requestAs({ uid: "bob", disabled: "yes" }, { uid: "admin-1", role: "admin" })
      )
    ).rejects.toMatchObject({ code: "invalid-argument" });
  });

  it("rejects an admin disabling their own account", async () => {
    await getAuth().createUser({ uid: "admin-1" });
    await expect(
      setUserDisabled.run(
        requestAs({ uid: "admin-1", disabled: true }, { uid: "admin-1", role: "admin" })
      )
    ).rejects.toMatchObject({ code: "failed-precondition" });
  });

  it("allows an admin to re-enable their own account", async () => {
    await getAuth().createUser({ uid: "admin-1", disabled: true });
    const result = (await setUserDisabled.run(
      requestAs({ uid: "admin-1", disabled: false }, { uid: "admin-1", role: "admin" })
    )) as { uid: string; disabled: boolean };
    expect(result).toEqual({ uid: "admin-1", disabled: false });
  });

  it("disables another user's account and mirrors it to Firestore", async () => {
    await getAuth().createUser({ uid: "bob" });
    const result = (await setUserDisabled.run(
      requestAs({ uid: "bob", disabled: true }, { uid: "admin-1", role: "admin" })
    )) as { uid: string; disabled: boolean };
    expect(result).toEqual({ uid: "bob", disabled: true });

    const authUser = await getAuth().getUser("bob");
    expect(authUser.disabled).toBe(true);

    const userDoc = await getFirestore().collection("users").doc("bob").get();
    expect(userDoc.data()?.disabled).toBe(true);
  });

  it("re-enables another user's account", async () => {
    await getAuth().createUser({ uid: "bob", disabled: true });
    await setUserDisabled.run(
      requestAs({ uid: "bob", disabled: false }, { uid: "admin-1", role: "admin" })
    );

    const authUser = await getAuth().getUser("bob");
    expect(authUser.disabled).toBe(false);
  });
});
