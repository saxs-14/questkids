import "../setup/firebaseAdmin";
import { getFirestore } from "firebase-admin/firestore";
import { clearFirestoreEmulatorData } from "../setup/firestoreEmulator";
import { unlinkParentChild } from "../../src/parent/unlinkChild";
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

async function otpCodeFor(uid: string, email = "parent@example.com"): Promise<string> {
  await requestActionOtp.run(
    requestAs({ action: "unlinkChild" }, { uid, role: "parent", email })
  );
  const snap = await getFirestore()
    .collection("emails")
    .where("to", "==", email)
    .get();
  const latest = snap.docs[snap.docs.length - 1].data();
  return (latest.data as { code: string }).code;
}

describe("unlinkParentChild", () => {
  beforeEach(async () => {
    await clearFirestoreEmulatorData();
  });

  it("rejects an unauthenticated caller", async () => {
    await expect(
      unlinkParentChild.run(requestAs({ childUid: "child-1" }))
    ).rejects.toMatchObject({ code: "unauthenticated" });
  });

  it("rejects a missing childUid", async () => {
    await expect(
      unlinkParentChild.run(requestAs({}, { uid: "parent-1", role: "parent" }))
    ).rejects.toMatchObject({ code: "invalid-argument" });
  });

  it("rejects a missing OTP code", async () => {
    await expect(
      unlinkParentChild.run(
        requestAs({ childUid: "child-1" }, { uid: "parent-1", role: "parent" })
      )
    ).rejects.toMatchObject({ code: "invalid-argument" });
  });

  it("rejects when no OTP code was ever requested", async () => {
    await expect(
      unlinkParentChild.run(
        requestAs(
          { childUid: "child-1", otpCode: "123456" },
          { uid: "parent-1", role: "parent" }
        )
      )
    ).rejects.toMatchObject({ code: "failed-precondition" });
  });

  it("rejects an incorrect OTP code", async () => {
    await otpCodeFor("parent-1");
    await expect(
      unlinkParentChild.run(
        requestAs(
          { childUid: "child-1", otpCode: "000000" },
          { uid: "parent-1", role: "parent" }
        )
      )
    ).rejects.toMatchObject({ code: "permission-denied" });
  });

  it("rejects unlinking a child that doesn't exist (after a valid OTP)", async () => {
    const code = await otpCodeFor("parent-1");
    await expect(
      unlinkParentChild.run(
        requestAs(
          { childUid: "ghost", otpCode: code },
          { uid: "parent-1", role: "parent" }
        )
      )
    ).rejects.toMatchObject({ code: "not-found" });
  });

  it("rejects a parent who isn't currently linked to the child (after a valid OTP)", async () => {
    await getFirestore().collection("users").doc("child-1").set({
      linkedParentUids: ["parent-2"],
    });
    const code = await otpCodeFor("parent-1");
    await expect(
      unlinkParentChild.run(
        requestAs(
          { childUid: "child-1", otpCode: code },
          { uid: "parent-1", role: "parent" }
        )
      )
    ).rejects.toMatchObject({ code: "permission-denied" });
  });

  it("removes the caller's own link from both sides and consumes the OTP", async () => {
    await getFirestore().collection("users").doc("child-1").set({
      linkedParentUids: ["parent-1", "parent-2"],
    });
    await getFirestore().collection("users").doc("parent-1").set({
      linkedChildrenUids: ["child-1"],
    });
    const code = await otpCodeFor("parent-1");

    const result = (await unlinkParentChild.run(
      requestAs(
        { childUid: "child-1", otpCode: code },
        { uid: "parent-1", role: "parent" }
      )
    )) as { unlinked: boolean };
    expect(result).toEqual({ unlinked: true });

    const child = await getFirestore().collection("users").doc("child-1").get();
    expect(child.data()?.linkedParentUids).not.toContain("parent-1");
    expect(child.data()?.linkedParentUids).toContain("parent-2");

    const parent = await getFirestore().collection("users").doc("parent-1").get();
    expect(parent.data()?.linkedChildrenUids).not.toContain("child-1");

    // Single-use: the same code can't be replayed for a second unlink call.
    const challenge = await getFirestore()
      .collection("otp_challenges")
      .doc("parent-1_unlinkChild")
      .get();
    expect(challenge.exists).toBe(false);
  });

  it("does not let one parent unlink a different parent's link to the child", async () => {
    await getFirestore().collection("users").doc("child-1").set({
      linkedParentUids: ["parent-1", "parent-2"],
    });
    await getFirestore().collection("users").doc("parent-3").set({
      linkedChildrenUids: [],
    });
    // parent-3 is not in child-1's linkedParentUids at all.
    const code = await otpCodeFor("parent-3");
    await expect(
      unlinkParentChild.run(
        requestAs(
          { childUid: "child-1", otpCode: code },
          { uid: "parent-3", role: "parent" }
        )
      )
    ).rejects.toMatchObject({ code: "permission-denied" });

    const child = await getFirestore().collection("users").doc("child-1").get();
    expect(child.data()?.linkedParentUids).toEqual(["parent-1", "parent-2"]);
  });
});
