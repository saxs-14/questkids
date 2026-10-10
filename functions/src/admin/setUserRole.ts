import { onCall, HttpsError } from "firebase-functions/v2/https";
import { beforeUserCreated } from "firebase-functions/v2/identity";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";
import { ENFORCE_APP_CHECK } from "../config";

const VALID_ROLES = ["learner", "parent", "admin"] as const;
type Role = (typeof VALID_ROLES)[number];

/**
 * Admin-only callable: sets a user's role as a custom claim. Firestore
 * rules trust ONLY these claims for authorization — the `role` field
 * mirrored onto the user doc is for display purposes only and must never
 * be trusted for access control.
 */
export const setUserRole = onCall({ enforceAppCheck: ENFORCE_APP_CHECK }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "You must be signed in.");
  }
  if (request.auth.token.role !== "admin") {
    throw new HttpsError("permission-denied", "Only admins can set user roles.");
  }

  const { uid, role } = request.data as {
    uid: string;
    role: Role;
  };

  if (!uid || typeof uid !== "string") {
    throw new HttpsError("invalid-argument", "uid is required");
  }
  if (uid === request.auth.uid) {
    throw new HttpsError(
      "failed-precondition",
      "An admin cannot change their own role."
    );
  }
  if (!VALID_ROLES.includes(role)) {
    throw new HttpsError("invalid-argument", `role must be one of ${VALID_ROLES.join(", ")}`);
  }

  // The bootstrap administrator is the trust anchor. No other admin may
  // demote or otherwise alter that account through the general role API.
  const bootstrap = await getFirestore()
    .collection("system")
    .doc("adminBootstrap")
    .get();
  const authorisedAdminUid = bootstrap.data()?.adminUid;
  if (typeof authorisedAdminUid === "string" && uid === authorisedAdminUid && role !== "admin") {
    throw new HttpsError(
      "failed-precondition",
      "The configured QuestKids administrator cannot be demoted through this endpoint."
    );
  }

  // QuestKids uses a single bootstrap-authorized administrator. Do not allow
  // this general role-management endpoint to create additional admins.
  // The bootstrap document is written by bootstrapAdmin after granting the
  // configured administrator account its claim. Existing extra admins are
  // not automatically revoked here; they must be reviewed and demoted safely.
  if (role === "admin") {
    if (typeof authorisedAdminUid !== "string" || uid !== authorisedAdminUid) {
      throw new HttpsError(
        "permission-denied",
        "Only the configured QuestKids administrator can hold the admin role."
      );
    }
  }

  await getAuth().setCustomUserClaims(uid, { role });

  // Mirror role onto the user doc for display/query convenience only —
  // never read back for authorization decisions.
  await getFirestore().collection("users").doc(uid).set({ role }, { merge: true });

  return { uid, role };
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
 * whether a signup intends to be a learner or parent, so it can only ever
 * set the safe default. This trigger fires immediately after that doc
 * actually gets created (AuthService.registerWithEmail's createUser()
 * call, right after createUserWithEmailAndPassword) and upgrades the
 * claim to 'parent' if that's the self-declared role ('learner' is
 * already correct from assignDefaultRole, so left untouched to avoid a
 * redundant claims write on every single signup). 'admin' is never
 * self-declarable through this path -- it can only be granted by an
 * existing admin via the setUserRole callable above.
 *
 * Trusting this doc's role field here is intentional and safe, not an
 * oversight: it's the exact same self-declaration the client already made
 * in the create() call itself (firestore.rules' `allow create` requires
 * the POPIA consent fields for learner, or birthDate == null for parent,
 * but there is no stronger signal available at self-service signup --
 * same trust model as most consumer apps' self-service signup, this is
 * not a KYC flow). What must never happen -- and is guaranteed elsewhere,
 * not here -- is a self-declared parent getting pre-populated access to
 * another user's data: firestore.rules' `allow create` on /users/{uid}
 * requires linkedChildrenUids.size() == 0 on every role branch, closing
 * that off before this function ever runs.
 */
export const grantSelfDeclaredRoleClaim = onDocumentCreated(
  "users/{uid}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const role = snap.data()?.role;
    if (role !== "parent") return;

    const uid = event.params.uid;
    const user = await getAuth().getUser(uid);
    if (user.customClaims?.role === role) return;

    await getAuth().setCustomUserClaims(uid, {
      ...user.customClaims,
      role,
    });
  }
);
