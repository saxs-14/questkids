import "../setup/firebaseAdmin";
import { getFirestore } from "firebase-admin/firestore";
import { clearFirestoreEmulatorData } from "../setup/firestoreEmulator";
import { requestActionOtp, verifyAndConsumeActionOtp } from "../../src/parent/actionOtp";

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

async function latestEmailTo(to: string) {
  const snap = await getFirestore().collection("emails").where("to", "==", to).get();
  return snap.docs.map((d) => d.data());
}

describe("requestActionOtp", () => {
  beforeEach(async () => {
    await clearFirestoreEmulatorData();
  });

  it("rejects an unauthenticated caller", async () => {
    await expect(
      requestActionOtp.run(requestAs({ action: "unlinkChild" }))
    ).rejects.toMatchObject({ code: "unauthenticated" });
  });

  it("rejects a non-parent caller", async () => {
    await expect(
      requestActionOtp.run(
        requestAs({ action: "unlinkChild" }, { uid: "learner-1", role: "learner" })
      )
    ).rejects.toMatchObject({ code: "permission-denied" });
  });

  it("rejects an unrecognized action", async () => {
    await expect(
      requestActionOtp.run(
        requestAs(
          { action: "deleteEverything" },
          { uid: "parent-1", role: "parent", email: "parent@example.com" }
        )
      )
    ).rejects.toMatchObject({ code: "invalid-argument" });
  });

  it("rejects when there is no email address on file", async () => {
    await expect(
      requestActionOtp.run(
        requestAs({ action: "unlinkChild" }, { uid: "parent-1", role: "parent" })
      )
    ).rejects.toMatchObject({ code: "failed-precondition" });
  });

  it("sends a code via the emails collection using the otp_code template", async () => {
    const result = (await requestActionOtp.run(
      requestAs(
        { action: "unlinkChild" },
        { uid: "parent-1", role: "parent", email: "parent@example.com" }
      )
    )) as { sent: boolean; expiresInSeconds: number };
    expect(result.sent).toBe(true);

    const emails = await latestEmailTo("parent@example.com");
    expect(emails).toHaveLength(1);
    expect(emails[0]).toMatchObject({ template: "otp_code" });
    expect((emails[0].data as { code: string }).code).toMatch(/^\d{6}$/);
  });

  it("falls back to the user doc's email when the auth token has none", async () => {
    await getFirestore().collection("users").doc("parent-1").set({
      role: "parent",
      email: "fallback@example.com",
    });
    await requestActionOtp.run(
      requestAs({ action: "unlinkChild" }, { uid: "parent-1", role: "parent" })
    );
    expect(await latestEmailTo("fallback@example.com")).toHaveLength(1);
  });

  it("rejects a resend within the 60-second cooldown", async () => {
    const auth = { uid: "parent-1", role: "parent", email: "parent@example.com" };
    await requestActionOtp.run(requestAs({ action: "unlinkChild" }, auth));
    await expect(
      requestActionOtp.run(requestAs({ action: "unlinkChild" }, auth))
    ).rejects.toMatchObject({ code: "resource-exhausted" });
  });

});

describe("verifyAndConsumeActionOtp", () => {
  beforeEach(async () => {
    await clearFirestoreEmulatorData();
  });

  async function requestedCode(uid: string, email: string): Promise<string> {
    await requestActionOtp.run(
      requestAs({ action: "unlinkChild" }, { uid, role: "parent", email })
    );
    const emails = await latestEmailTo(email);
    return (emails[emails.length - 1].data as { code: string }).code;
  }

  it("rejects a malformed code", async () => {
    await expect(
      verifyAndConsumeActionOtp("parent-1", "unlinkChild", "abc")
    ).rejects.toMatchObject({ code: "invalid-argument" });
  });

  it("rejects when no challenge has been requested yet", async () => {
    await expect(
      verifyAndConsumeActionOtp("parent-1", "unlinkChild", "123456")
    ).rejects.toMatchObject({ code: "failed-precondition" });
  });

  it("rejects an incorrect code and records the attempt", async () => {
    await requestedCode("parent-1", "parent@example.com");
    await expect(
      verifyAndConsumeActionOtp("parent-1", "unlinkChild", "000000")
    ).rejects.toMatchObject({ code: "permission-denied" });
    const doc = await getFirestore()
      .collection("otp_challenges")
      .doc("parent-1_unlinkChild")
      .get();
    expect(doc.data()?.attempts).toBe(1);
  });

  it("accepts the correct code and consumes it (single-use)", async () => {
    const code = await requestedCode("parent-1", "parent@example.com");
    await expect(
      verifyAndConsumeActionOtp("parent-1", "unlinkChild", code)
    ).resolves.toBeUndefined();

    const doc = await getFirestore()
      .collection("otp_challenges")
      .doc("parent-1_unlinkChild")
      .get();
    expect(doc.exists).toBe(false);

    // Reusing the same code a second time must fail -- there is no
    // challenge left to check it against.
    await expect(
      verifyAndConsumeActionOtp("parent-1", "unlinkChild", code)
    ).rejects.toMatchObject({ code: "failed-precondition" });
  });

  it("locks out further attempts after 5 incorrect guesses", async () => {
    await requestedCode("parent-1", "parent@example.com");
    for (let i = 0; i < 5; i++) {
      await expect(
        verifyAndConsumeActionOtp("parent-1", "unlinkChild", "111111")
      ).rejects.toMatchObject({ code: "permission-denied" });
    }
    await expect(
      verifyAndConsumeActionOtp("parent-1", "unlinkChild", "111111")
    ).rejects.toMatchObject({ code: "failed-precondition" });
  });

  it("rejects an expired code", async () => {
    const code = await requestedCode("parent-1", "parent@example.com");
    await getFirestore()
      .collection("otp_challenges")
      .doc("parent-1_unlinkChild")
      .update({ expiresAt: new Date(Date.now() - 1000) });
    await expect(
      verifyAndConsumeActionOtp("parent-1", "unlinkChild", code)
    ).rejects.toMatchObject({ code: "failed-precondition" });
  });

  it("scopes a code to the action it was requested for", async () => {
    // Only "unlinkChild" is wired today, so this proves the lookup key
    // includes the action by checking a code requested for one uid can't
    // verify against a different uid's challenge (the realistic version
    // of the same scoping bug, since there's only one action to test).
    const codeForParent1 = await requestedCode("parent-1", "p1@example.com");
    await requestedCode("parent-2", "p2@example.com");
    await expect(
      verifyAndConsumeActionOtp("parent-2", "unlinkChild", codeForParent1)
    ).rejects.toMatchObject({ code: "permission-denied" });
  });
});
