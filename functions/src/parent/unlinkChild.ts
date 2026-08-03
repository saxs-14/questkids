import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore, FieldValue } from "firebase-admin/firestore";

/**
 * Removes the caller's own link to a child. Self-service only -- a parent
 * can remove their own access, never another parent's (that would need a
 * "primary parent revokes a co-parent" design decision, not made here; see
 * docs/DEFERRED.md). linkedChildrenUids is a locked field (no client write
 * to it can ever succeed) and the child's linkedParentUids update is
 * separately rejected on ownership, same root cause as linkRegisteredChild
 * and approveParentLinkRequest -- this completes both sides via the Admin
 * SDK after confirming the caller is actually currently linked.
 */
export const unlinkParentChild = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "You must be signed in.");
  }
  const parentUid = request.auth.uid;

  const { childUid } = request.data as { childUid?: unknown };
  if (typeof childUid !== "string" || !childUid) {
    throw new HttpsError("invalid-argument", "childUid is required");
  }

  const db = getFirestore();
  const childRef = db.collection("users").doc(childUid);
  const parentRef = db.collection("users").doc(parentUid);

  await db.runTransaction(async (tx) => {
    const childSnap = await tx.get(childRef);
    if (!childSnap.exists) {
      throw new HttpsError("not-found", "Child account not found.");
    }
    const linkedParents: string[] = childSnap.data()?.linkedParentUids ?? [];
    if (!linkedParents.includes(parentUid)) {
      throw new HttpsError(
        "permission-denied",
        "You are not linked to this child."
      );
    }

    tx.update(childRef, {
      linkedParentUids: FieldValue.arrayRemove(parentUid),
    });
    tx.update(parentRef, {
      linkedChildrenUids: FieldValue.arrayRemove(childUid),
    });
  });

  return { unlinked: true };
});
