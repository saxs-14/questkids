import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore } from "firebase-admin/firestore";
import { ENFORCE_APP_CHECK } from "../config";

export const lookupChildLinkCode = onCall(
  { enforceAppCheck: ENFORCE_APP_CHECK },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "You must be signed in.");
    }
    if (request.auth.token.role !== "parent") {
      throw new HttpsError("permission-denied", "Only parent accounts can look up a child.");
    }

    const code =
      typeof request.data?.code === "string" ? request.data.code.trim().toUpperCase() : "";
    if (!/^[A-Z0-9]{6}$/.test(code)) {
      throw new HttpsError("invalid-argument", "Enter the 6-character child link code.");
    }

    const db = getFirestore();
    const query = await db.collection("users")
      .where("childLinkCode", "==", code)
      .limit(2)
      .get();

    if (query.empty) {
      throw new HttpsError("not-found", "No child account was found for that code.");
    }
    if (query.size > 1) {
      throw new HttpsError(
        "failed-precondition",
        "This link code is not unique. Ask the child to generate a new code."
      );
    }

    const doc = query.docs[0];
    const data = doc.data();
    if (data.role !== "learner") {
      throw new HttpsError("not-found", "No child account was found for that code.");
    }
    const linkedParents = Array.isArray(data.linkedParentUids) ? data.linkedParentUids : [];
    return {
      childUid: doc.id,
      childName: typeof data.name === "string" ? data.name : "Child",
      grade: typeof data.grade === "string" ? data.grade : "Grade 1",
      hasPrimaryParent: typeof data.parentUid === "string" && data.parentUid.length > 0,
      alreadyLinked: linkedParents.includes(request.auth.uid),
      isPrimaryParent: data.parentUid === request.auth.uid,
    };
  }
);
