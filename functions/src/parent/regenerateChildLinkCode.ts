import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore } from "firebase-admin/firestore";
import { randomInt } from "node:crypto";
import { ENFORCE_APP_CHECK } from "../config";

const CODE_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
const CODE_LENGTH = 6;
const MAX_ATTEMPTS = 5;

function generateCode(): string {
  let code = "";
  for (let i = 0; i < CODE_LENGTH; i++) {
    code += CODE_CHARS[randomInt(CODE_CHARS.length)];
  }
  return code;
}

/**
 * Self-service: a learner regenerates their own child-link code (the one
 * shown as a QR code / shareable 6-char code on their dashboard). This is
 * the only path that can write childLinkCode now that it's a locked user
 * field (see lockedUserFields() in firestore.rules) -- the previous client
 * write (ParentProvider.generateChildLinkCode -> saveLinkCode) let a
 * client set childLinkCode to an arbitrary value, including one that
 * collided with another learner's active code.
 */
export const regenerateChildLinkCode = onCall(
  { enforceAppCheck: ENFORCE_APP_CHECK },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "You must be signed in.");
    }
    if (request.auth.token.role !== "learner") {
      throw new HttpsError(
        "permission-denied",
        "Only learner accounts have a link code."
      );
    }

    const db = getFirestore();
    const usersRef = db.collection("users");

    for (let attempt = 0; attempt < MAX_ATTEMPTS; attempt++) {
      const code = generateCode();
      const existing = await usersRef.where("childLinkCode", "==", code).limit(1).get();
      if (existing.empty) {
        await usersRef.doc(request.auth.uid).update({ childLinkCode: code });
        return { code };
      }
    }

    throw new HttpsError(
      "internal",
      "Could not generate a unique code. Please try again."
    );
  }
);
