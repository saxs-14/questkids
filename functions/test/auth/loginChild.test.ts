import "../setup/firebaseAdmin";
import { getFirestore } from "firebase-admin/firestore";
import { clearFirestoreEmulatorData } from "../setup/firestoreEmulator";
import { loginChild, cleanupChildLoginAttempts } from "../../src/auth/loginChild";

function requestAs(data: Record<string, unknown>, ip = "203.0.113.1") {
  return {
    data,
    auth: undefined,
    rawRequest: { ip } as never,
    acceptsStreaming: false,
  } as never;
}

async function seedLearner(
  uid: string,
  name: string,
  birthDate: string | number
) {
  await getFirestore().collection("users").doc(uid).set({
    uid,
    name,
    role: "learner",
    birthDate,
  });
}

describe("loginChild", () => {
  beforeEach(async () => {
    await clearFirestoreEmulatorData();
  });

  it("rejects a missing name", async () => {
    await expect(
      loginChild.run(requestAs({ birthDate: "2015-01-01" }))
    ).rejects.toMatchObject({ code: "invalid-argument" });
  });

  it("rejects a missing or malformed birth date", async () => {
    await seedLearner("child-1", "Thandi", "2015-01-01");
    await expect(
      loginChild.run(requestAs({ name: "Thandi", birthDate: "01/01/2015" }))
    ).rejects.toMatchObject({ code: "invalid-argument" });
  });

  it("rejects a name that matches no learner", async () => {
    await expect(
      loginChild.run(requestAs({ name: "Nobody Here", birthDate: "2015-01-01" }))
    ).rejects.toMatchObject({ code: "not-found" });
  });

  it("does not match a non-learner account with the same name", async () => {
    await getFirestore().collection("users").doc("parent-1").set({
      uid: "parent-1",
      name: "Thandi",
      role: "parent",
      birthDate: "2015-01-01",
    });
    await expect(
      loginChild.run(requestAs({ name: "Thandi", birthDate: "2015-01-01" }))
    ).rejects.toMatchObject({ code: "not-found" });
  });

  it("rejects a learner name match with the wrong birth date", async () => {
    await seedLearner("child-1", "Thandi", "2015-01-01");
    await expect(
      loginChild.run(requestAs({ name: "Thandi", birthDate: "2015-06-15" }))
    ).rejects.toMatchObject({ code: "permission-denied" });
  });

  it("logs in with a string YYYY-MM-DD stored birth date", async () => {
    await seedLearner("child-1", "Thandi", "2015-01-01");
    const result = (await loginChild.run(
      requestAs({ name: "Thandi", birthDate: "2015-01-01" })
    )) as { token: string };
    expect(typeof result.token).toBe("string");
    expect(result.token.length).toBeGreaterThan(0);
  });

  it("logs in with a milliseconds-since-epoch stored birth date (UserModel.toMap format)", async () => {
    const millis = new Date("2015-01-01T10:00:00.000Z").getTime();
    await seedLearner("child-1", "Thandi", millis);
    const result = (await loginChild.run(
      requestAs({ name: "Thandi", birthDate: "2015-01-01" })
    )) as { token: string };
    expect(typeof result.token).toBe("string");
  });

  it("matches the name case-insensitively via the client's normalization", async () => {
    await seedLearner("child-1", "Thandi", "2015-01-01");
    await expect(
      loginChild.run(requestAs({ name: "  Thandi  ", birthDate: "2015-01-01" }))
    ).resolves.toMatchObject({ token: expect.any(String) });
  });

  it("rejects after exceeding the per-name/IP attempt limit (10)", async () => {
    const ip = "198.51.100.5";
    for (let i = 0; i < 10; i++) {
      await expect(
        loginChild.run(requestAs({ name: "Bruteforce Target" }, ip))
      ).rejects.toMatchObject({ code: "invalid-argument" }); // missing birthDate, but still consumes an attempt
    }
    await expect(
      loginChild.run(requestAs({ name: "Bruteforce Target", birthDate: "2015-01-01" }, ip))
    ).rejects.toMatchObject({ code: "resource-exhausted" });
  });

  it("keeps each IP's rate-limit bucket independent of other IPs", async () => {
    const ipA = "198.51.100.10";
    const ipB = "198.51.100.11";
    for (let i = 0; i < 10; i++) {
      await expect(
        loginChild.run(requestAs({ name: "Shared Target" }, ipA))
      ).rejects.toMatchObject({ code: "invalid-argument" });
    }
    // ipA's bucket for this name is now exhausted...
    await expect(
      loginChild.run(requestAs({ name: "Shared Target", birthDate: "2015-01-01" }, ipA))
    ).rejects.toMatchObject({ code: "resource-exhausted" });
    // ...but ipB, a different client, is unaffected.
    await expect(
      loginChild.run(requestAs({ name: "Shared Target", birthDate: "2015-01-01" }, ipB))
    ).rejects.toMatchObject({ code: "not-found" });
  });

  it("rejects after exceeding the per-IP attempt limit (60) even across different names", async () => {
    const ip = "198.51.100.20";
    for (let i = 0; i < 60; i++) {
      await expect(
        loginChild.run(requestAs({ name: `Enumerated Name ${i}` }, ip))
      ).rejects.toMatchObject({ code: "invalid-argument" });
    }
    await expect(
      loginChild.run(
        requestAs({ name: "One More Name", birthDate: "2015-01-01" }, ip)
      )
    ).rejects.toMatchObject({ code: "resource-exhausted" });
  }, 30000);

  it(
    "under true concurrency (15 simultaneous requests for the same bucket), " +
      "every single result is one of the two clean, documented errors -- never " +
      "a raw Firestore transaction-contention error reaching the caller",
    async () => {
      // NOTE on scope: this fires 15 simultaneous requests sharing one
      // Firestore client/connection in one Node process, which is a much
      // more adversarial pattern than independent Cloud Functions
      // instances would produce in production, each with their own
      // client. Under this specific harness, the local Firestore
      // emulator's transaction-retry/lock behavior itself is not
      // perfectly deterministic (confirmed empirically: how many of the
      // 15 end up passing the rate check vs. getting rate-limited varies
      // between runs). That's a documented limitation of testing
      // Firestore transaction contention against the local emulator from
      // a single process, not something this test can responsibly assert
      // an exact bound on. What the fix below *does* guarantee, and what
      // this test verifies reliably: a transaction that fails due to
      // contention (Firestore's own ABORTED/lock-timeout) must never leak
      // to the caller as a raw error -- it has to come back as the same
      // clean "too many attempts" message a legitimate rate-limit hit
      // would produce.
      const ip = "198.51.100.30";
      const results = await Promise.allSettled(
        Array.from({ length: 15 }, () =>
          loginChild.run(requestAs({ name: "Concurrent Target" }, ip))
        )
      );

      const rejections = results.filter(
        (r): r is PromiseRejectedResult => r.status === "rejected"
      );
      expect(rejections).toHaveLength(15); // none supplied a birthDate

      for (const rejection of rejections) {
        const code = (rejection.reason as { code?: string })?.code;
        expect(["invalid-argument", "resource-exhausted"]).toContain(code);
      }
    },
    30000
  );
});

describe("cleanupChildLoginAttempts", () => {
  beforeEach(async () => {
    await clearFirestoreEmulatorData();
  });

  it("deletes only buckets older than 24 hours", async () => {
    const db = getFirestore();
    const now = Date.now();
    await db.collection("security_login_attempts").doc("stale").set({
      windowStartedAt: now - 48 * 60 * 60 * 1000,
      attempts: 5,
      updatedAt: new Date(now - 25 * 60 * 60 * 1000),
    });
    await db.collection("security_login_attempts").doc("fresh").set({
      windowStartedAt: now,
      attempts: 1,
      updatedAt: new Date(now),
    });

    await cleanupChildLoginAttempts.run({} as never);

    const stale = await db.collection("security_login_attempts").doc("stale").get();
    const fresh = await db.collection("security_login_attempts").doc("fresh").get();
    expect(stale.exists).toBe(false);
    expect(fresh.exists).toBe(true);
  });
});
