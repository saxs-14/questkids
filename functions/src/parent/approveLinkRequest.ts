import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { ENFORCE_APP_CHECK } from "../config";

/**
 * Completes approving a "Link to Existing Child" request
 * (parent_link_requests/{requestId}) -- the request document's own
 * status/resolvedAt fields are already updatable by the primary parent
 * directly (see firestore.rules' allow update on parent_link_requests),
 * but the two writes that actually perform the link are not: the
 * requesting parent's linkedChildrenUids is a locked field (allow update
 * rejects every client write to it unconditionally, see CLAUDE.md §6.3),
 * and the child's linkedParentUids update fails separately on ownership
 * (allow update: if isUser(uid), and neither parent is the child).
 *
 * Authorization model: the caller must be the child's PRIMARY parent
 * (parent_link_requests/{requestId}.primaryParentUid == caller uid) --
 * this is deliberately NOT the same check as linkRegisteredChild (which
 * confirms a fact the child's own doc already declares at creation
 * time). Here, a second/different parent is being granted access to a
 * child they did not create, so the authorization has to come from the
 * PRIMARY parent's explicit approval of a specific pending request, not
 * from anything the requesting parent can assert about themselves.
 */
export const approveParentLinkRequest = onCall({ enforceAppCheck: ENFORCE_APP_CHECK }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "You must be signed in.");
  }
  const primaryParentUid = request.auth.uid;

  const { requestId } = request.data as { requestId?: unknown };
  if (typeof requestId !== "string" || !requestId) {
    throw new HttpsError("invalid-argument", "requestId is required");
  }

  const db = getFirestore();
  const reqRef = db.collection("parent_link_requests").doc(requestId);

  await db.runTransaction(async (tx) => {
    const reqSnap = await tx.get(reqRef);
    if (!reqSnap.exists) {
      throw new HttpsError("not-found", "Link request not found.");
    }
    const reqData = reqSnap.data()!;
    if (reqData.primaryParentUid !== primaryParentUid) {
      throw new HttpsError(
        "permission-denied",
        "Only the child's primary parent can approve this request."
      );
    }
    if (reqData.status !== "pending") {
      throw new HttpsError(
        "failed-precondition",
        "This request has already been resolved."
      );
    }

    const childUid = reqData.childUid as string;
    const requestingParentUid = reqData.requestingParentUid as string;
    const childRef = db.collection("users").doc(childUid);
    const requestingParentRef = db.collection("users").doc(requestingParentUid);

    tx.update(reqRef, {
      status: "approved",
      resolvedAt: FieldValue.serverTimestamp(),
    });
    tx.update(childRef, {
      linkedParentUids: FieldValue.arrayUnion(requestingParentUid),
    });
    tx.update(requestingParentRef, {
      linkedChildrenUids: FieldValue.arrayUnion(childUid),
    });
  });

  return { approved: true };
});
