/**
 * End-to-end integration test chaining the real callables together the way
 * a real session does: register parent+child -> a second parent links via
 * code -> primary parent approves -> primary parent changes the second
 * parent's permissions through the OTP-gated flow -> the child regenerates
 * their link code (invalidating the old one) -> an admin account sees the
 * resulting data in the platform report.
 *
 * This exists because the live browser-driven walkthrough for this session
 * was repeatedly blocked by machine-wide memory pressure (not a code issue)
 * -- this proves the same backend logic actually works together as a real
 * flow, against the real local Firestore/Auth emulator, without a browser.
 */
import "../setup/firebaseAdmin";
import { getFirestore } from "firebase-admin/firestore";
import { clearFirestoreEmulatorData } from "../setup/firestoreEmulator";
import { requestParentLink } from "../../src/parent/requestParentLink";
import { resolveParentLinkRequest } from "../../src/parent/resolveParentLinkRequest";
import { getParentAccess, setParentPermissions } from "../../src/parent/parentPermissions";
import { regenerateChildLinkCode } from "../../src/parent/regenerateChildLinkCode";
import { requestActionOtp } from "../../src/parent/actionOtp";
import { getAdminPlatformReport } from "../../src/admin/getAdminPlatformReport";

function requestAs(data: Record<string, unknown>, auth: { uid: string; role: string; email?: string }) {
  return {
    data,
    auth: { uid: auth.uid, token: { role: auth.role, email: auth.email } as never, rawToken: "test-token" },
    rawRequest: {} as never,
    acceptsStreaming: false,
  } as never;
}

async function otpCodeFor(
  uid: string,
  action: string,
  email: string,
  target: string
): Promise<string> {
  await requestActionOtp.run(requestAs({ action, target }, { uid, role: "parent", email }));
  const snap = await getFirestore().collection("emails").where("to", "==", email).get();
  const latest = snap.docs[snap.docs.length - 1].data();
  return (latest.data as { code: string }).code;
}

describe("full parent/child link + permissions + link-code lifecycle", () => {
  beforeEach(async () => {
    await clearFirestoreEmulatorData();
  });

  it("walks the entire real flow end to end", async () => {
    const db = getFirestore();

    // 1. Seed a primary parent and their child, as registration would.
    await db.collection("users").doc("parent-primary").set({
      uid: "parent-primary",
      role: "parent",
      name: "Primary",
      surname: "Parent",
      email: "primary@example.com",
      linkedChildrenUids: ["child-1"],
    });
    await db.collection("users").doc("child-1").set({
      uid: "child-1",
      role: "learner",
      name: "Testy",
      grade: "Grade 1",
      parentUid: "parent-primary",
      linkedParentUids: ["parent-primary"],
      childLinkCode: "ORIGIN",
    });

    // 2. A second parent (whose own account already exists, same as any
    // real registered parent) requests a link using the child's code.
    await db.collection("users").doc("parent-secondary").set({
      uid: "parent-secondary",
      role: "parent",
      name: "Secondary",
      surname: "Parent",
      email: "secondary@example.com",
    });
    const linkResult = (await requestParentLink.run(
      requestAs(
        { code: "ORIGIN" },
        { uid: "parent-secondary", role: "parent", email: "secondary@example.com" }
      )
    )) as { requestId: string; status: string };
    expect(linkResult.status).toBe("pending");

    const pendingRequests = await db
      .collection("parent_link_requests")
      .where("childUid", "==", "child-1")
      .where("status", "==", "pending")
      .get();
    expect(pendingRequests.size).toBe(1);
    const requestId = pendingRequests.docs[0].id;

    // 3. The primary parent approves it.
    const resolveResult = (await resolveParentLinkRequest.run(
      requestAs(
        { requestId, action: "approve" },
        { uid: "parent-primary", role: "parent", email: "primary@example.com" }
      )
    )) as { resolved: boolean };
    expect(resolveResult.resolved).toBe(true);

    const childAfterApproval = await db.collection("users").doc("child-1").get();
    expect(childAfterApproval.data()?.linkedParentUids).toContain("parent-secondary");

    // 4. Primary parent sees the new secondary parent with default permissions.
    const access = (await getParentAccess.run(
      requestAs(
        { childUid: "child-1" },
        { uid: "parent-primary", role: "parent", email: "primary@example.com" }
      )
    )) as { parents: { uid: string; permissions: Record<string, boolean> }[] };
    expect(access.parents).toHaveLength(1);
    expect(access.parents[0].uid).toBe("parent-secondary");
    expect(access.parents[0].permissions.verifyProgress).toBe(false);

    // 5. Primary parent changes permissions through the OTP-gated flow.
    const otpCode = await otpCodeFor(
      "parent-primary",
      "setParentPermissions",
      "primary@example.com",
      "child-1:parent-secondary"
    );
    const setResult = (await setParentPermissions.run(
      requestAs(
        {
          childUid: "child-1",
          parentUid: "parent-secondary",
          permissions: { verifyProgress: true },
          otpCode,
        },
        { uid: "parent-primary", role: "parent", email: "primary@example.com" }
      )
    )) as { updated: boolean; permissions: Record<string, boolean> };
    expect(setResult.updated).toBe(true);
    expect(setResult.permissions.verifyProgress).toBe(true);

    // 6. The child regenerates their own link code.
    const regenResult = (await regenerateChildLinkCode.run(
      requestAs({}, { uid: "child-1", role: "learner" })
    )) as { code: string };
    expect(regenResult.code).toMatch(/^[A-Z0-9]{6}$/);
    expect(regenResult.code).not.toBe("ORIGIN");

    // 7. The old code no longer links to anything.
    await expect(
      requestParentLink.run(
        requestAs(
          { code: "ORIGIN" },
          { uid: "parent-tertiary", role: "parent", email: "tertiary@example.com" }
        )
      )
    ).rejects.toMatchObject({ code: "not-found" });

    // The new code does.
    const linkViaNewCode = (await requestParentLink.run(
      requestAs(
        { code: regenResult.code },
        { uid: "parent-tertiary", role: "parent", email: "tertiary@example.com" }
      )
    )) as { status: string };
    expect(linkViaNewCode.status).toBe("pending");

    // 8. An admin sees the real resulting data in the platform report.
    await db.collection("users").doc("admin-1").set({
      uid: "admin-1",
      role: "admin",
      name: "Admin",
    });
    const report = (await getAdminPlatformReport.run(
      requestAs({}, { uid: "admin-1", role: "admin" })
    )) as { users: number; learners: number; parents: number; admins: number };
    // parent-tertiary never needed a users/{uid} doc of their own just to
    // send a link request, so only primary, secondary, child, and admin
    // actually have one.
    expect(report.users).toBe(4);
    expect(report.learners).toBe(1);
    expect(report.parents).toBe(2);
    expect(report.admins).toBe(1);
  });
});
