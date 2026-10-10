import "../setup/firebaseAdmin";
import { getFirestore } from "firebase-admin/firestore";
import { clearFirestoreEmulatorData } from "../setup/firestoreEmulator";
import { regenerateChildLinkCode } from "../../src/parent/regenerateChildLinkCode";

function requestAs(auth?: { uid: string; role: string }) {
  return {
    data: {},
    auth: auth
      ? { uid: auth.uid, token: { role: auth.role } as never, rawToken: "test-token" }
      : undefined,
    rawRequest: {} as never,
    acceptsStreaming: false,
  } as never;
}

describe("regenerateChildLinkCode", () => {
  beforeEach(async () => {
    await clearFirestoreEmulatorData();
  });

  it("rejects an unauthenticated caller", async () => {
    await expect(
      regenerateChildLinkCode.run(requestAs())
    ).rejects.toMatchObject({ code: "unauthenticated" });
  });

  it("rejects a non-learner caller", async () => {
    await expect(
      regenerateChildLinkCode.run(requestAs({ uid: "parent-1", role: "parent" }))
    ).rejects.toMatchObject({ code: "permission-denied" });
  });

  it("generates a new 6-character code and writes it to the caller's own doc", async () => {
    await getFirestore().collection("users").doc("child-1").set({
      role: "learner",
      childLinkCode: "OLD123",
    });

    const result = (await regenerateChildLinkCode.run(
      requestAs({ uid: "child-1", role: "learner" })
    )) as { code: string };

    expect(result.code).toMatch(/^[A-Z0-9]{6}$/);
    expect(result.code).not.toBe("OLD123");

    const child = await getFirestore().collection("users").doc("child-1").get();
    expect(child.data()?.childLinkCode).toBe(result.code);
  });

  it("never returns a code that collides with another learner's active code", async () => {
    await getFirestore().collection("users").doc("child-1").set({
      role: "learner",
      childLinkCode: "AAAAAA",
    });
    await getFirestore().collection("users").doc("child-2").set({
      role: "learner",
      childLinkCode: "BBBBBB",
    });

    const result = (await regenerateChildLinkCode.run(
      requestAs({ uid: "child-2", role: "learner" })
    )) as { code: string };

    expect(result.code).not.toBe("AAAAAA");
  });
});
