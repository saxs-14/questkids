import { RulesTestEnvironment, assertFails, assertSucceeds } from "@firebase/rules-unit-testing";
import { deleteDoc, doc, getDoc, setDoc, updateDoc } from "firebase/firestore";
import { createRulesTestEnv } from "./testEnv";

let testEnv: RulesTestEnvironment;

beforeAll(async () => {
  testEnv = await createRulesTestEnv();
});

afterAll(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

function learnerDoc(uid: string) {
  return {
    uid,
    role: "learner",
    consentGivenBy: "Parent Name",
    consentEmail: "parent@example.com",
    consentAt: Date.now(),
    policyVersion: "v1",
    linkedChildrenUids: [],
  };
}

function parentDoc(uid: string, extra: Record<string, unknown> = {}) {
  return {
    uid,
    role: "parent",
    birthDate: null,
    linkedChildrenUids: [],
    ...extra,
  };
}

describe("firestore.rules: users/{uid}", () => {
  it("denies a user reading another user's document", async () => {
    const alice = testEnv.authenticatedContext("alice");
    const bob = testEnv.authenticatedContext("bob");
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "users/bob"), learnerDoc("bob"));
    });
    await assertFails(getDoc(doc(alice.firestore(), "users/bob")));
    await assertSucceeds(getDoc(doc(bob.firestore(), "users/bob")));
  });

  it("allows an admin to read any user's document", async () => {
    const admin = testEnv.authenticatedContext("admin-1", { role: "admin" });
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "users/bob"), learnerDoc("bob"));
    });
    await assertSucceeds(getDoc(doc(admin.firestore(), "users/bob")));
  });

  it("denies creating a user document for a different uid", async () => {
    const alice = testEnv.authenticatedContext("alice");
    await assertFails(
      setDoc(doc(alice.firestore(), "users/bob"), learnerDoc("bob"))
    );
  });

  it("denies self-registering as admin", async () => {
    const alice = testEnv.authenticatedContext("alice");
    await assertFails(
      setDoc(doc(alice.firestore(), "users/alice"), {
        uid: "alice",
        role: "admin",
        linkedChildrenUids: [],
      })
    );
  });

  it("denies a learner create missing the POPIA consent trail", async () => {
    const alice = testEnv.authenticatedContext("alice");
    await assertFails(
      setDoc(doc(alice.firestore(), "users/alice"), {
        uid: "alice",
        role: "learner",
        linkedChildrenUids: [],
      })
    );
  });

  it(
    "denies a learner create that pre-populates linkedChildrenUids " +
      "(the role-escalation laundering path this rule exists to block)",
    async () => {
      const alice = testEnv.authenticatedContext("alice");
      await assertFails(
        setDoc(doc(alice.firestore(), "users/alice"), {
          ...learnerDoc("alice"),
          linkedChildrenUids: ["some-other-child-uid"],
        })
      );
    }
  );

  it("denies a parent create that pre-populates linkedChildrenUids", async () => {
    const alice = testEnv.authenticatedContext("alice");
    await assertFails(
      setDoc(doc(alice.firestore(), "users/alice"), {
        ...parentDoc("alice"),
        linkedChildrenUids: ["some-child-uid"],
      })
    );
  });

  it("allows a valid learner create and a valid parent create", async () => {
    const alice = testEnv.authenticatedContext("alice");
    const parent = testEnv.authenticatedContext("parent-1");
    await assertSucceeds(
      setDoc(doc(alice.firestore(), "users/alice"), learnerDoc("alice"))
    );
    await assertSucceeds(
      setDoc(doc(parent.firestore(), "users/parent-1"), parentDoc("parent-1"))
    );
  });

  it("denies a user escalating their own role via update", async () => {
    const alice = testEnv.authenticatedContext("alice");
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "users/alice"), learnerDoc("alice"));
    });
    await assertFails(
      updateDoc(doc(alice.firestore(), "users/alice"), { role: "admin" })
    );
  });

  it("denies a user granting themselves xp/coins via update", async () => {
    const alice = testEnv.authenticatedContext("alice");
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "users/alice"), learnerDoc("alice"));
    });
    await assertFails(
      updateDoc(doc(alice.firestore(), "users/alice"), { xp: 999999, coins: 999999 })
    );
  });

  it("denies a user self-linking a child via update", async () => {
    const alice = testEnv.authenticatedContext("alice");
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "users/alice"), parentDoc("alice"));
    });
    await assertFails(
      updateDoc(doc(alice.firestore(), "users/alice"), {
        linkedChildrenUids: ["someone-elses-child"],
      })
    );
  });

  it("allows a user to update their own non-locked fields", async () => {
    const alice = testEnv.authenticatedContext("alice");
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "users/alice"), learnerDoc("alice"));
    });
    await assertSucceeds(
      updateDoc(doc(alice.firestore(), "users/alice"), { displayName: "New Name" })
    );
  });

  it("denies a parent with no permission from reading a child's document", async () => {
    const parent = testEnv.authenticatedContext("parent-1", { role: "parent" });
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "users/child-1"), learnerDoc("child-1"));
    });
    await assertFails(getDoc(doc(parent.firestore(), "users/child-1")));
  });

  it("allows the primary parent to read their linked child's document", async () => {
    const parent = testEnv.authenticatedContext("parent-1", { role: "parent" });
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "users/child-1"), {
        ...learnerDoc("child-1"),
        parentUid: "parent-1",
      });
    });
    await assertSucceeds(getDoc(doc(parent.firestore(), "users/child-1")));
  });

  it("denies a secondary parent without the viewProgress permission flag", async () => {
    const otherParent = testEnv.authenticatedContext("parent-2", { role: "parent" });
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "users/child-1"), {
        ...learnerDoc("child-1"),
        parentUid: "parent-1",
        parentPermissions: { "parent-2": { viewProgress: false } },
      });
    });
    await assertFails(getDoc(doc(otherParent.firestore(), "users/child-1")));
  });

  it("allows a secondary parent with the viewProgress permission flag", async () => {
    const otherParent = testEnv.authenticatedContext("parent-2", { role: "parent" });
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "users/child-1"), {
        ...learnerDoc("child-1"),
        parentUid: "parent-1",
        parentPermissions: { "parent-2": { viewProgress: true } },
      });
    });
    await assertSucceeds(getDoc(doc(otherParent.firestore(), "users/child-1")));
  });
});

describe("firestore.rules: progress/{progressId} (cross-family isolation)", () => {
  async function seedChildWithParent(childUid: string, parentUid: string) {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `users/${childUid}`), {
        ...learnerDoc(childUid),
        parentUid,
        parentPermissions: {},
      });
      await setDoc(doc(ctx.firestore(), "progress/progress-1"), {
        uid: childUid,
        verified: false,
        topic: "fractions",
      });
    });
  }

  it("denies a learner reading another learner's progress", async () => {
    await seedChildWithParent("child-1", "parent-1");
    const otherChild = testEnv.authenticatedContext("child-2");
    await assertFails(getDoc(doc(otherChild.firestore(), "progress/progress-1")));
  });

  it("denies an unrelated parent reading a child's progress they don't own", async () => {
    await seedChildWithParent("child-1", "parent-1");
    const otherParent = testEnv.authenticatedContext("parent-2", { role: "parent" });
    await assertFails(getDoc(doc(otherParent.firestore(), "progress/progress-1")));
  });

  it("denies an unrelated parent verifying another family's progress", async () => {
    await seedChildWithParent("child-1", "parent-1");
    const otherParent = testEnv.authenticatedContext("parent-2", { role: "parent" });
    await assertFails(
      updateDoc(doc(otherParent.firestore(), "progress/progress-1"), { verified: true })
    );
  });

  it("denies a child marking their own progress verified", async () => {
    await seedChildWithParent("child-1", "parent-1");
    const child = testEnv.authenticatedContext("child-1");
    await assertFails(
      updateDoc(doc(child.firestore(), "progress/progress-1"), { verified: true })
    );
  });

  it("allows the linked parent to verify their own child's progress", async () => {
    await seedChildWithParent("child-1", "parent-1");
    const parent = testEnv.authenticatedContext("parent-1", { role: "parent" });
    await assertSucceeds(
      updateDoc(doc(parent.firestore(), "progress/progress-1"), {
        verified: true,
        proofUrl: "https://example.com/proof.png",
      })
    );
  });

  it("denies the linked parent changing fields other than verified/proofUrl", async () => {
    await seedChildWithParent("child-1", "parent-1");
    const parent = testEnv.authenticatedContext("parent-1", { role: "parent" });
    await assertFails(
      updateDoc(doc(parent.firestore(), "progress/progress-1"), {
        verified: true,
        topic: "tampered",
      })
    );
  });
});

describe("firestore.rules: server-authoritative collections reject all client writes", () => {
  it("denies a client creating its own game_sessions document", async () => {
    const alice = testEnv.authenticatedContext("alice");
    await assertFails(
      setDoc(doc(alice.firestore(), "game_sessions/session-1"), {
        uid: "alice",
        score: 100,
      })
    );
  });

  it("denies a client writing its own usage_ai quota document", async () => {
    const alice = testEnv.authenticatedContext("alice");
    await assertFails(
      setDoc(doc(alice.firestore(), "usage_ai/alice"), { count: 0 })
    );
  });

  it("denies a client writing parent_link_requests directly", async () => {
    const alice = testEnv.authenticatedContext("alice", { role: "parent" });
    await assertFails(
      setDoc(doc(alice.firestore(), "parent_link_requests/req-1"), {
        primaryParentUid: "alice",
        requestingParentUid: "alice",
        childUid: "child-1",
      })
    );
  });
});

describe("firestore.rules: emails/{emailId} (open-relay regression test)", () => {
  it("denies any signed-in client from creating an email document", async () => {
    const alice = testEnv.authenticatedContext("alice");
    await assertFails(
      setDoc(doc(alice.firestore(), "emails/email-1"), {
        to: "victim@example.com",
        template: "whatever",
        data: {},
      })
    );
  });
});

describe("firestore.rules: ai_reports/{reportId}", () => {
  it("allows a signed-in user to create a report under their own uid", async () => {
    const alice = testEnv.authenticatedContext("alice");
    await assertSucceeds(
      setDoc(doc(alice.firestore(), "ai_reports/report-1"), {
        uid: "alice",
        messageId: "msg-1",
        reason: "inappropriate",
      })
    );
  });

  it("denies creating a report under someone else's uid", async () => {
    const alice = testEnv.authenticatedContext("alice");
    await assertFails(
      setDoc(doc(alice.firestore(), "ai_reports/report-1"), {
        uid: "bob",
        messageId: "msg-1",
        reason: "inappropriate",
      })
    );
  });

  it("denies the reporter from reading their own report back", async () => {
    const alice = testEnv.authenticatedContext("alice");
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "ai_reports/report-1"), {
        uid: "alice",
        messageId: "msg-1",
        reason: "inappropriate",
      });
    });
    await assertFails(getDoc(doc(alice.firestore(), "ai_reports/report-1")));
  });

  it("allows an admin to read and resolve a report", async () => {
    const admin = testEnv.authenticatedContext("admin-1", { role: "admin" });
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "ai_reports/report-1"), {
        uid: "alice",
        messageId: "msg-1",
        reason: "inappropriate",
      });
    });
    await assertSucceeds(getDoc(doc(admin.firestore(), "ai_reports/report-1")));
    await assertSucceeds(
      updateDoc(doc(admin.firestore(), "ai_reports/report-1"), { status: "resolved" })
    );
  });
});

describe("firestore.rules: otp_challenges/{challengeId} (server-only)", () => {
  it("denies a signed-in client reading an OTP challenge, even their own", async () => {
    const parent = testEnv.authenticatedContext("parent-1", { role: "parent" });
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "otp_challenges/parent-1_unlinkChild"), {
        codeHash: "abc",
        attempts: 0,
      });
    });
    await assertFails(getDoc(doc(parent.firestore(), "otp_challenges/parent-1_unlinkChild")));
  });

  it("denies a signed-in client writing an OTP challenge directly", async () => {
    const parent = testEnv.authenticatedContext("parent-1", { role: "parent" });
    await assertFails(
      setDoc(doc(parent.firestore(), "otp_challenges/parent-1_unlinkChild"), {
        codeHash: "attacker-controlled",
        attempts: 0,
      })
    );
  });
});

describe("firestore.rules: default deny for unauthenticated access", () => {
  it("denies an unauthenticated client reading a user document", async () => {
    const anon = testEnv.unauthenticatedContext();
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "users/alice"), learnerDoc("alice"));
    });
    await assertFails(getDoc(doc(anon.firestore(), "users/alice")));
  });

  it("denies deleting a document that doesn't belong to the caller", async () => {
    const bob = testEnv.authenticatedContext("bob");
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "users/alice"), learnerDoc("alice"));
    });
    await assertFails(deleteDoc(doc(bob.firestore(), "users/alice")));
  });
});
