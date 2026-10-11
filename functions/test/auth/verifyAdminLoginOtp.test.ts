import "../setup/firebaseAdmin";
import { getFirestore } from "firebase-admin/firestore";
import { clearFirestoreEmulatorData } from "../setup/firestoreEmulator";
import { verifyAdminLoginOtp } from "../../src/auth/verifyAdminLoginOtp";
import { requestActionOtp } from "../../src/parent/actionOtp";

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

const EMAIL = "admin@example.com";
const ADMIN_AUTH = { uid: "admin-1", role: "admin", email: EMAIL };

async function otpCodeFor(): Promise<string> {
  await requestActionOtp.run(requestAs({ action: "adminLogin" }, ADMIN_AUTH));
  const snap = await getFirestore().collection("emails").where("to", "==", EMAIL).get();
  const latest = snap.docs[snap.docs.length - 1].data();
  return (latest.data as { code: string }).code;
}

describe("verifyAdminLoginOtp", () => {
  beforeEach(async () => {
    await clearFirestoreEmulatorData();
  });

  it("rejects an unauthenticated caller", async () => {
    await expect(
      verifyAdminLoginOtp.run(requestAs({ otpCode: "123456" }))
    ).rejects.toMatchObject({ code: "unauthenticated" });
  });

  it("rejects a non-admin caller", async () => {
    await expect(
      verifyAdminLoginOtp.run(
        requestAs({ otpCode: "123456" }, { uid: "parent-1", role: "parent", email: "p@example.com" })
      )
    ).rejects.toMatchObject({ code: "permission-denied" });
  });

  it("rejects an incorrect code without granting access", async () => {
    await otpCodeFor();
    await expect(
      verifyAdminLoginOtp.run(requestAs({ otpCode: "000000" }, ADMIN_AUTH))
    ).rejects.toMatchObject({ code: "permission-denied" });
  });

  it("accepts the correct code", async () => {
    const code = await otpCodeFor();
    const result = (await verifyAdminLoginOtp.run(
      requestAs({ otpCode: code }, ADMIN_AUTH)
    )) as { verified: boolean };
    expect(result.verified).toBe(true);
  });
});
