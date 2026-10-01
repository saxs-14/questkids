import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { ENFORCE_APP_CHECK } from "../config";

export const resolveParentLinkRequest = onCall(
  { enforceAppCheck: ENFORCE_APP_CHECK },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "You must be signed in.");
    }
    if (request.auth.token.role !== "parent") {
      throw new HttpsError("permission-denied", "Only parent accounts can resolve parent-link requests.");
    }

    const requestId = typeof request.data?.requestId === "string"
      ? request.data.requestId.trim()
      : "";
    const action = request.data?.action;

    if (!requestId || !["approve", "decline", "cancel"].includes(action)) {
      throw new HttpsError("invalid-argument", "A valid requestId and action are required.");
    }

    const db = getFirestore();
    const requestRef = db.collection("parent_link_requests").doc(requestId);

    await db.runTransaction(async (tx) => {
      const requestSnap = await tx.get(requestRef);
      if (!requestSnap.exists) {
        throw new HttpsError("not-found", "Link request not found.");
      }

      const data = requestSnap.data()!;
      const primaryParentUid = data.primaryParentUid as string | undefined;
      const requestingParentUid = data.requestingParentUid as string | undefined;
      const childUid = data.childUid as string | undefined;

      if (!primaryParentUid || !requestingParentUid || !childUid) {
        throw new HttpsError("failed-precondition", "This link request is incomplete.");
      }
      if (data.status !== "pending") {
        throw new HttpsError("failed-precondition", "This request has already been resolved.");
      }

      const caller = request.auth!.uid;
      const isPrimary = caller === primaryParentUid;
      const isRequester = caller === requestingParentUid;

      if (action === "approve") {
        if (!isPrimary) {
          throw new HttpsError("permission-denied", "Only the child's primary parent can approve this request.");
        }

        const childRef = db.collection("users").doc(childUid);
        const requesterRef = db.collection("users").doc(requestingParentUid);
        const childSnap = await tx.get(childRef);
        const requesterSnap = await tx.get(requesterRef);

        if (!childSnap.exists || !requesterSnap.exists) {
          throw new HttpsError("not-found", "The child or requesting parent account no longer exists.");
        }

        const child = childSnap.data()!;
        const requester = requesterSnap.data()!;
        if (child.role !== "learner" || requester.role !== "parent") {
          throw new HttpsError("failed-precondition", "The accounts no longer have the required roles.");
        }

        tx.update(childRef, {
          linkedParentUids: FieldValue.arrayUnion(requestingParentUid),
        });
        tx.update(requesterRef, {
          linkedChildrenUids: FieldValue.arrayUnion(childUid),
        });
        tx.update(requestRef, {
          status: "approved",
          resolvedAt: FieldValue.serverTimestamp(),
        });
        return;
      }

      if (action === "decline" && !isPrimary) {
        throw new HttpsError("permission-denied", "Only the child's primary parent can decline this request.");
      }
      if (action === "cancel" && !isRequester) {
        throw new HttpsError("permission-denied", "Only the requesting parent can cancel this request.");
      }

      tx.update(requestRef, {
        status: action === "approve" ? "approved" : action === "decline" ? "declined" : "cancelled",
        resolvedAt: FieldValue.serverTimestamp(),
      });
    });

    return { resolved: true, action };
  }
);
