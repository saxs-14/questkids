import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getAuth } from "firebase-admin/auth";
import { ENFORCE_APP_CHECK } from "../config";

export const setUserDisabled = onCall(
  { enforceAppCheck: ENFORCE_APP_CHECK },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "You must be signed in.");
    }
    if (request.auth.token.role !== "admin") {
      throw new HttpsError("permission-denied", "Only admins can manage accounts.");
    }

    const { uid, disabled } = request.data as { uid?: string; disabled?: boolean };
    if (!uid || typeof uid !== "string") {
      throw new HttpsError("invalid-argument", "uid is required.");
    }
    if (typeof disabled !== "boolean") {
      throw new HttpsError("invalid-argument", "disabled must be a boolean.");
    }
    if (uid === request.auth.uid && disabled) {
      throw new HttpsError("failed-precondition", "You cannot disable your own admin account.");
    }

    await getAuth().updateUser(uid, { disabled });
    return { uid, disabled };
  }
);
