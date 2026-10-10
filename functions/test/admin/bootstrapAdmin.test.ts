import "../setup/firebaseAdmin";
import { getFirestore } from "firebase-admin/firestore";
import { getAuth } from "firebase-admin/auth";
import { clearFirestoreEmulatorData } from "../setup/firestoreEmulator";
import { clearAuthEmulatorUsers } from "../setup/authEmulator";
import { bootstrapAdmin } from "../../src/admin/bootstrapAdmin";

const ADMIN_EMAIL = "questkids.game@gmail.com";

// defineSecret(...).value() reads straight from process.env at call time
// (see firebase-functions/params) -- this is a locally-invented test value,
// never a real secret, and is only ever read against the emulator.
const TEST_TOKEN = "test-bootstrap-token-0123456789-not-real";
process.env.QUESTKIDS_ADMIN_BOOTSTRAP_TOKEN = TEST_TOKEN;

function requestAs(data: Record<string, unknown>) {
  return {
    data,
    auth: undefined,
    rawRequest: {} as never,
    acceptsStreaming: false,
  } as never;
}

describe("bootstrapAdmin", () => {
  beforeEach(async () => {
    await clearFirestoreEmulatorData();
    await clearAuthEmulatorUsers();
  });

  it("rejects a missing bootstrap token", async () => {
    await expect(bootstrapAdmin.run(requestAs({}))).rejects.toMatchObject({
      code: "permission-denied",
    });
  });

  it("rejects a token shorter than 32 characters", async () => {
    await expect(
      bootstrapAdmin.run(requestAs({ bootstrapToken: "too-short" }))
    ).rejects.toMatchObject({ code: "permission-denied" });
  });

  it("rejects an incorrect (but long enough) token", async () => {
    await expect(
      bootstrapAdmin.run(
        requestAs({ bootstrapToken: "wrong-token-but-long-enough-0123456789" })
      )
    ).rejects.toMatchObject({ code: "permission-denied" });
  });

  it("rejects when bootstrap has already been completed", async () => {
    await getFirestore().collection("system").doc("adminBootstrap").set({
      completed: true,
      adminUid: "already-done-uid",
    });
    await expect(
      bootstrapAdmin.run(requestAs({ bootstrapToken: TEST_TOKEN }))
    ).rejects.toMatchObject({ code: "failed-precondition" });
  });

  it("rejects when the configured admin Auth account doesn't exist", async () => {
    await expect(
      bootstrapAdmin.run(requestAs({ bootstrapToken: TEST_TOKEN }))
    ).rejects.toMatchObject({ code: "failed-precondition" });
  });

  it("rejects when the configured admin Auth account is disabled", async () => {
    await getAuth().createUser({ email: ADMIN_EMAIL, disabled: true });
    await expect(
      bootstrapAdmin.run(requestAs({ bootstrapToken: TEST_TOKEN }))
    ).rejects.toMatchObject({ code: "failed-precondition" });
  });

  it("grants the admin claim and writes the bootstrap record on success", async () => {
    const created = await getAuth().createUser({ email: ADMIN_EMAIL });

    const result = (await bootstrapAdmin.run(
      requestAs({ bootstrapToken: TEST_TOKEN })
    )) as { success: boolean; uid: string; email: string; role: string };

    expect(result).toEqual({
      success: true,
      uid: created.uid,
      email: ADMIN_EMAIL,
      role: "admin",
    });

    const authUser = await getAuth().getUser(created.uid);
    expect(authUser.customClaims?.role).toBe("admin");

    const userDoc = await getFirestore().collection("users").doc(created.uid).get();
    expect(userDoc.data()?.role).toBe("admin");

    const bootstrapDoc = await getFirestore()
      .collection("system")
      .doc("adminBootstrap")
      .get();
    expect(bootstrapDoc.data()).toMatchObject({
      completed: true,
      adminUid: created.uid,
      adminEmail: ADMIN_EMAIL,
    });
  });

  it("preserves any existing custom claims on the admin account", async () => {
    const created = await getAuth().createUser({ email: ADMIN_EMAIL });
    await getAuth().setCustomUserClaims(created.uid, { someOtherClaim: true });

    await bootstrapAdmin.run(requestAs({ bootstrapToken: TEST_TOKEN }));

    const authUser = await getAuth().getUser(created.uid);
    expect(authUser.customClaims).toMatchObject({ role: "admin", someOtherClaim: true });
  });

  it("rejects a second bootstrap attempt after the first succeeds", async () => {
    await getAuth().createUser({ email: ADMIN_EMAIL });
    await bootstrapAdmin.run(requestAs({ bootstrapToken: TEST_TOKEN }));

    await expect(
      bootstrapAdmin.run(requestAs({ bootstrapToken: TEST_TOKEN }))
    ).rejects.toMatchObject({ code: "failed-precondition" });
  });
});
