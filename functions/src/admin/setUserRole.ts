import { onCall, HttpsError } from "firebase-functions/v2/https";
import { beforeUserCreated } from "firebase-functions/v2/identity";
import * as admin from "firebase-admin";

const VALID_ROLES = ["learner", "parent", "teacher", "admin"] as const;
type Role = (typeof VALID_ROLES)[number];

/**
 * Admin-only callable: sets a user's role (and optional classId, for
 * teachers) as a custom claim. Firestore rules trust ONLY these claims for
 * authorization — the `role` field mirrored onto the user doc is for
 * display purposes only and must never be trusted for access control.
 */
export const setUserRole = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "You must be signed in.");
  }
  if (request.auth.token.role !== "admin") {
    throw new HttpsError("permission-denied", "Only admins can set user roles.");
  }

  const { uid, role, classId } = request.data as {
    uid: string;
    role: Role;
    classId?: string;
  };

  if (!uid || typeof uid !== "string") {
    throw new HttpsError("invalid-argument", "uid is required");
  }
  if (!VALID_ROLES.includes(role)) {
    throw new HttpsError("invalid-argument", `role must be one of ${VALID_ROLES.join(", ")}`);
  }

  const claims: Record<string, unknown> = { role };
  if (role === "teacher" && classId) {
    claims.classId = classId;
  }

  await admin.auth().setCustomUserClaims(uid, claims);

  // Mirror role onto the user doc for display/query convenience only —
  // never read back for authorization decisions.
  await admin.firestore().collection("users").doc(uid).set(
    { role, ...(claims.classId ? { classId: claims.classId } : {}) },
    { merge: true }
  );

  return { uid, role, classId: claims.classId ?? null };
});

/**
 * Every new Firebase Auth user gets a default 'learner' custom claim so
 * Firestore rules always have a role to check, even before the client's
 * user-doc create() call runs.
 */
export const assignDefaultRole = beforeUserCreated(() => {
  return {
    customClaims: { role: "learner" },
  };
});
