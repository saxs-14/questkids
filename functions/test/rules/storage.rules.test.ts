import { RulesTestEnvironment, assertFails, assertSucceeds } from "@firebase/rules-unit-testing";
import { getBytes, ref, uploadBytes } from "firebase/storage";
import { doc, setDoc } from "firebase/firestore";
import { createRulesTestEnv } from "./testEnv";

let testEnv: RulesTestEnvironment;

const SMALL_PNG = new Uint8Array([0x89, 0x50, 0x4e, 0x47]);
const PNG_META = { contentType: "image/png" };
const TEXT_META = { contentType: "text/plain" };

function oversizedPngBytes(): Uint8Array {
  // Just over the 5MB limit enforced by isValidImage().
  return new Uint8Array(5 * 1024 * 1024 + 1);
}

beforeAll(async () => {
  testEnv = await createRulesTestEnv();
});

afterAll(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearStorage();
  await testEnv.clearFirestore();
});

describe("storage.rules: avatars/{uid}", () => {
  it("allows a user to upload their own avatar as a valid image", async () => {
    const alice = testEnv.authenticatedContext("alice");
    await assertSucceeds(
      uploadBytes(ref(alice.storage(), "avatars/alice/photo.png"), SMALL_PNG, PNG_META)
    );
  });

  it("denies a user uploading to another user's avatar path", async () => {
    const alice = testEnv.authenticatedContext("alice");
    await assertFails(
      uploadBytes(ref(alice.storage(), "avatars/bob/photo.png"), SMALL_PNG, PNG_META)
    );
  });

  it("denies uploading a non-image file as an avatar", async () => {
    const alice = testEnv.authenticatedContext("alice");
    await assertFails(
      uploadBytes(ref(alice.storage(), "avatars/alice/notes.txt"), SMALL_PNG, TEXT_META)
    );
  });

  it("denies uploading an avatar image over the 5MB limit", async () => {
    const alice = testEnv.authenticatedContext("alice");
    await assertFails(
      uploadBytes(ref(alice.storage(), "avatars/alice/huge.png"), oversizedPngBytes(), PNG_META)
    );
  });

  it("allows any signed-in user to read an avatar", async () => {
    const alice = testEnv.authenticatedContext("alice");
    const bob = testEnv.authenticatedContext("bob");
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await uploadBytes(ref(ctx.storage(), "avatars/alice/photo.png"), SMALL_PNG, PNG_META);
    });
    await assertSucceeds(getBytes(ref(bob.storage(), "avatars/alice/photo.png")));
  });

  it("denies an unauthenticated client reading an avatar", async () => {
    const anon = testEnv.unauthenticatedContext();
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await uploadBytes(ref(ctx.storage(), "avatars/alice/photo.png"), SMALL_PNG, PNG_META);
    });
    await assertFails(getBytes(ref(anon.storage(), "avatars/alice/photo.png")));
  });
});

describe("storage.rules: progress/{uid} proofs", () => {
  it("allows a user to upload their own progress proof", async () => {
    const alice = testEnv.authenticatedContext("alice");
    await assertSucceeds(
      uploadBytes(ref(alice.storage(), "progress/alice/proof.png"), SMALL_PNG, PNG_META)
    );
  });

  it("denies a user reading another user's progress proof", async () => {
    const bob = testEnv.authenticatedContext("bob");
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await uploadBytes(ref(ctx.storage(), "progress/alice/proof.png"), SMALL_PNG, PNG_META);
    });
    await assertFails(getBytes(ref(bob.storage(), "progress/alice/proof.png")));
  });

  it("allows an admin to read any user's progress proof", async () => {
    const admin = testEnv.authenticatedContext("admin-1", { role: "admin" });
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await uploadBytes(ref(ctx.storage(), "progress/alice/proof.png"), SMALL_PNG, PNG_META);
    });
    await assertSucceeds(getBytes(ref(admin.storage(), "progress/alice/proof.png")));
  });
});

describe("storage.rules: activities/{activityId}", () => {
  it("denies a non-admin writing an activity resource", async () => {
    const alice = testEnv.authenticatedContext("alice");
    await assertFails(
      uploadBytes(ref(alice.storage(), "activities/act-1/image.png"), SMALL_PNG, PNG_META)
    );
  });

  it("allows an admin to write a valid activity resource", async () => {
    const admin = testEnv.authenticatedContext("admin-1", { role: "admin" });
    await assertSucceeds(
      uploadBytes(ref(admin.storage(), "activities/act-1/image.png"), SMALL_PNG, PNG_META)
    );
  });

  it("allows any signed-in user to read activity resources", async () => {
    const alice = testEnv.authenticatedContext("alice");
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await uploadBytes(ref(ctx.storage(), "activities/act-1/image.png"), SMALL_PNG, PNG_META);
    });
    await assertSucceeds(getBytes(ref(alice.storage(), "activities/act-1/image.png")));
  });
});

describe("storage.rules: document_vault/{childUid}/{fileName} (cross-family isolation)", () => {
  async function linkParentToChild(parentUid: string, childUid: string) {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `users/${parentUid}`), {
        uid: parentUid,
        role: "parent",
        linkedChildrenUids: [childUid],
      });
    });
  }

  it("allows a linked parent to upload a document for their child", async () => {
    await linkParentToChild("parent-1", "child-1");
    const parent = testEnv.authenticatedContext("parent-1", { role: "parent" });
    await assertSucceeds(
      uploadBytes(ref(parent.storage(), "document_vault/child-1/report.pdf"), SMALL_PNG)
    );
  });

  it("denies an unlinked parent uploading a document for someone else's child", async () => {
    await linkParentToChild("parent-1", "child-1");
    const otherParent = testEnv.authenticatedContext("parent-2", { role: "parent" });
    await assertFails(
      uploadBytes(ref(otherParent.storage(), "document_vault/child-1/report.pdf"), SMALL_PNG)
    );
  });

  it("denies the child themself from uploading to their own document vault", async () => {
    await linkParentToChild("parent-1", "child-1");
    const child = testEnv.authenticatedContext("child-1");
    await assertFails(
      uploadBytes(ref(child.storage(), "document_vault/child-1/report.pdf"), SMALL_PNG)
    );
  });

  it("allows the child to read their own document vault", async () => {
    await linkParentToChild("parent-1", "child-1");
    const child = testEnv.authenticatedContext("child-1");
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await uploadBytes(ref(ctx.storage(), "document_vault/child-1/report.pdf"), SMALL_PNG);
    });
    await assertSucceeds(getBytes(ref(child.storage(), "document_vault/child-1/report.pdf")));
  });

  it("denies an unlinked parent reading a document vault that isn't theirs", async () => {
    await linkParentToChild("parent-1", "child-1");
    const otherParent = testEnv.authenticatedContext("parent-2", { role: "parent" });
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await uploadBytes(ref(ctx.storage(), "document_vault/child-1/report.pdf"), SMALL_PNG);
    });
    await assertFails(getBytes(ref(otherParent.storage(), "document_vault/child-1/report.pdf")));
  });
});

describe("storage.rules: default deny", () => {
  it("denies read/write on any path not covered by a specific rule", async () => {
    const alice = testEnv.authenticatedContext("alice");
    await assertFails(
      uploadBytes(ref(alice.storage(), "some_random_path/file.png"), SMALL_PNG, PNG_META)
    );
    await assertFails(getBytes(ref(alice.storage(), "some_random_path/file.png")));
  });
});
