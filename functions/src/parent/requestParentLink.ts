import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { ENFORCE_APP_CHECK } from "../config";

function cleanCode(value: unknown): string {
  return typeof value === "string" ? value.trim().toUpperCase() : "";
}

export const requestParentLink = onCall(
  { enforceAppCheck: ENFORCE_APP_CHECK },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "You must be signed in.");
    }
    if (request.auth.token.role !== "parent") {
      throw new HttpsError("permission-denied", "Only parent accounts can request a child link.");
    }

    const code = cleanCode(request.data?.code);
    if (!/^[A-Z0-9]{6}$/.test(code)) {
      throw new HttpsError("invalid-argument", "Enter the 6-character child link code.");
    }

    const db = getFirestore();
    const parentUid = request.auth.uid;
    const query = await db.collection("users")
      .where("childLinkCode", "==", code)
      .where("role", "==", "learner")
      .limit(2)
      .get();

    if (query.empty) {
      throw new HttpsError("not-found", "No child account was found for that code.");
    }
    if (query.size > 1) {
      throw new HttpsError("failed-precondition", "This link code is not unique. Ask the child to generate a new code.");
    }

    const childSnap = query.docs[0];
    const child = childSnap.data();
    const childUid = childSnap.id;
    const primaryParentUid = typeof child.parentUid === "string" ? child.parentUid : "";

    if (!primaryParentUid) {
      throw new HttpsError("failed-precondition", "This child does not have a primary parent yet.");
    }
    if (primaryParentUid === parentUid) {
      throw new HttpsError("already-exists", "You are already the primary parent for this child.");
    }

    const linkedParents = Array.isArray(child.linkedParentUids)
      ? child.linkedParentUids.filter((v): v is string => typeof v === "string")
      : [];
    if (linkedParents.includes(parentUid)) {
      throw new HttpsError("already-exists", "You are already linked to this child.");
    }

    const existing = await db.collection("parent_link_requests")
      .where("childUid", "==", childUid)
      .where("requestingParentUid", "==", parentUid)
      .where("status", "==", "pending")
      .limit(1)
      .get();
    if (!existing.empty) {
      throw new HttpsError("already-exists", "You already have a pending request for this child.");
    }

    const parentSnap = await db.collection("users").doc(parentUid).get();
    const parent = parentSnap.data();
    const requestRef = db.collection("parent_link_requests").doc();

    await requestRef.set({
      id: requestRef.id,
      childUid,
      childName: typeof child.name === "string" ? child.name : "Child",
      childGrade: typeof child.grade === "string" ? child.grade : "Grade 1",
      primaryParentUid,
      requestingParentUid: parentUid,
      requestingParentName: typeof parent?.name === "string" ? parent.name : "Parent",
      requestingParentEmail: request.auth.token.email ?? "",
      status: "pending",
      linkMethod: typeof request.data?.method === "string" ? request.data.method : "code",
      createdAt: FieldValue.serverTimestamp(),
    });

    return {
      requestId: requestRef.id,
      childUid,
      childName: typeof child.name === "string" ? child.name : "Child",
      grade: typeof child.grade === "string" ? child.grade : "Grade 1",
      status: "pending",
    };
  }
);
