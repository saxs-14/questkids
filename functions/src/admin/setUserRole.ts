import { onCall, HttpsError } from "firebase-functions/v2/https";
import { beforeUserCreated } from "firebase-functions/v2/identity";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";
import { ENFORCE_APP_CHECK } from "../config";

const VALID_ROLES = ["learner", "parent", "teacher", "admin"] as const;
type Role = (typeof VALID_ROLES)[number];

/**
 * Admin-only callable: sets a user's role (and optional classId, for
 * teachers) as a custom claim. Firestore rules trust ONLY these claims for
 * authorization — the `role` field mirrored onto the user doc is for
 * display purposes only and must never be trusted for access control.
 */
export const setUserRole = onCall({ enforceAppCheck: ENFORCE_APP_CHECK }, async (request) => {
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

  await getAuth().setCustomUserClaims(uid, claims);

  // Mirror role onto the user doc for display/query convenience only —
  // never read back for authorization decisions.
  await getFirestore().collection("users").doc(uid).set(
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

/**
 * assignDefaultRole above fires at Auth-account-creation time, before the
 * client's users/{uid} Firestore doc exists -- it has no way to know
 * whether a signup intends to be a learner, parent, or teacher, so it can
 * only ever set the safe default. This trigger fires immediately after
 * that doc actually gets created (AuthService.registerWithEmail's
 * createUser() call, right after createUserWithEmailAndPassword) and
 * upgrades the claim to match the self-declared role if it's 'parent' or
 * 'teacher' ('learner' is already correct from assignDefaultRole, so left
 * untouched to avoid a redundant claims write on every single signup).
 *
 * Trusting this doc's role field here is intentional and safe, not an
 * oversight: it's the exact same self-declaration the client already made
 * in the create() call itself (firestore.rules' `allow create` requires
 * the POPIA consent fields for learner, or birthDate == null for
 * parent/teacher, but there is no stronger signal available at self-
 * service signup to verify someone actually IS a teacher -- same
 * trust model as most consumer apps' self-service signup, this is not a
 * KYC flow). What must never happen -- and is guaranteed elsewhere, not
 * here -- is a self-declared parent/teacher getting pre-populated access
 * to another user's data: firestore.rules' `allow create` on /users/{uid}
 * requires linkedChildrenUids.size() == 0 on every role branch, closing
 * that off before this function ever runs.
 */
export const grantSelfDeclaredRoleClaim = onDocumentCreated(
  "users/{uid}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const role = snap.data()?.role;
    if (role !== "parent" && role !== "teacher") return;

    const uid = event.params.uid;
    const user = await getAuth().getUser(uid);
    if (user.customClaims?.role === role) return;

    await getAuth().setCustomUserClaims(uid, {
      ...user.customClaims,
      role,
    });
  }
);
