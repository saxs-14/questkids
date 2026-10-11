import "../setup/firebaseAdmin";
import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";
import { clearFirestoreEmulatorData } from "../setup/firestoreEmulator";
import { verifyRegistrationEmail } from "../../src/auth/verifyRegistrationEmail";
import { requestActionOtp } from "../../src/parent/actionOtp";

function requestAs(data: Record<string, unknown>, auth?: { uid: string; email?: string }) {
  return {
    data,
    auth: auth
      ? {
          uid: auth.uid,
          token: { role: "parent", email: auth.email } as never,
          rawToken: "test-token",
        }
      : undefined,
    rawRequest: {} as never,
    acceptsStreaming: false,
  } as never;
}

const EMAIL = "newparent@gmail.com";

async function createTestUser(uid: string, email: string) {
  await getAuth().createUser({ uid, email, password: "Test1234!pass" });
  await getFirestore().collection("users").doc(uid).set({ role: "parent", email, emailVerified: false });
}

async function otpCodeFor(uid: string, email: string): Promise<string> {
  await requestActionOtp.run(requestAs({ action: "verifyEmail" }, { uid, email }));
  const snap = await getFirestore().collection("emails").where("to", "==", email).get();
  const latest = snap.docs[snap.docs.length - 1].data();
  return (latest.data as { code: string }).code;
}

describe("verifyRegistrationEmail", () => {
  beforeEach(async () => {
    await clearFirestoreEmulatorData();
  });

  it("rejects an unauthenticated caller", async () => {
    await expect(
      verifyRegistrationEmail.run(requestAs({ otpCode: "123456" }))
    ).rejects.toMatchObject({ code: "unauthenticated" });
  });

  it("rejects an incorrect code", async () => {
    // Auth emulator users persist across tests in this file (only
    // Firestore is wiped in beforeEach) -- each test needs its own uid.
    await createTestUser("parent-wrong-code", "wrongcode@gmail.com");
    await otpCodeFor("parent-wrong-code", "wrongcode@gmail.com");
    await expect(
      verifyRegistrationEmail.run(
        requestAs({ otpCode: "000000" }, { uid: "parent-wrong-code", email: "wrongcode@gmail.com" })
      )
    ).rejects.toMatchObject({ code: "permission-denied" });
  });

  it("marks the Auth user and Firestore doc verified on a correct code", async () => {
    await createTestUser("parent-verified", EMAIL);
    const code = await otpCodeFor("parent-verified", EMAIL);

    const result = (await verifyRegistrationEmail.run(
      requestAs({ otpCode: code }, { uid: "parent-verified", email: EMAIL })
    )) as { verified: boolean };
    expect(result.verified).toBe(true);

    const authUser = await getAuth().getUser("parent-verified");
    expect(authUser.emailVerified).toBe(true);

    const doc = await getFirestore().collection("users").doc("parent-verified").get();
    expect(doc.data()?.emailVerified).toBe(true);
  });
});
