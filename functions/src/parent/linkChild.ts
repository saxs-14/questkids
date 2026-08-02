import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore, FieldValue } from "firebase-admin/firestore";

/**
 * Completes the parent<->child link that no client can ever finish on its
 * own: firestore.rules locks linkedChildrenUids (see CLAUDE.md §6.3 and
 * lockedUserFields() in firestore.rules), so `allow update` rejects every
 * client write to it unconditionally, including a parent linking a child
 * they just created themselves during registration
 * (AuthService.registerWithEmail's child branch, createChildForParent).
 *
 * Authorization model: the caller must be uid == parentUid (a parent can
 * only ever link children to their own account), and the target child's
 * own doc must already declare parentUid == the caller's uid. That field
 * is set at child-doc creation time by the child's own temporary Auth
 * session (see the two call sites above), so this function is confirming
 * a fact the system already established in the same registration flow,
 * not granting new cross-account access on the caller's say-so alone --
 * it cannot be used to link an arbitrary existing child to a new parent
 * (see the "not yet implemented" note in docs/DEFERRED.md for that case,
 * which needs a different authorization model: link-code ownership or an
 * approved parent_link_requests entry, not this function).
 */
export const linkRegisteredChild = onCall(async (request) => {
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
  const childDoc = await childRef.get();
  if (!childDoc.exists) {
    throw new HttpsError("not-found", "Child account not found.");
  }
  if (childDoc.data()?.parentUid !== parentUid) {
    throw new HttpsError(
      "permission-denied",
      "This child account is not linked to your account."
    );
  }

  await db.collection("users").doc(parentUid).update({
    linkedChildrenUids: FieldValue.arrayUnion(childUid),
  });

  return { linked: true };
});
