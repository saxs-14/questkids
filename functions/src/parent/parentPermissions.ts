import { onCall, HttpsError, CallableRequest } from "firebase-functions/v2/https";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { ENFORCE_APP_CHECK } from "../config";

const PERMISSION_KEYS = [
  "viewProgress",
  "viewReports",
  "verifyProgress",
  "viewMood",
  "manageCalendar",
] as const;

type PermissionKey = typeof PERMISSION_KEYS[number];

const DEFAULT_PERMISSIONS: Record<PermissionKey, boolean> = {
  viewProgress: true,
  viewReports: true,
  verifyProgress: false,
  viewMood: true,
  manageCalendar: false,
};

function assertParent(request: CallableRequest): string {
  if (!request.auth) throw new HttpsError("unauthenticated", "You must be signed in.");
  if (request.auth.token.role !== "parent") {
    throw new HttpsError("permission-denied", "Only parent accounts can manage parent access.");
  }
  return request.auth.uid;
}

async function getChildForPrimaryParent(childUid: string, primaryParentUid: string) {
  const db = getFirestore();
  const snap = await db.collection("users").doc(childUid).get();
  if (!snap.exists || snap.data()?.role !== "learner" || snap.data()?.parentUid !== primaryParentUid) {
    throw new HttpsError("permission-denied", "Only the child's primary parent can manage access.");
  }
  return snap;
}

export const getParentAccess = onCall(
  { enforceAppCheck: ENFORCE_APP_CHECK },
  async (request) => {
    const primaryParentUid = assertParent(request);
    const childUid = typeof request.data?.childUid === "string" ? request.data.childUid.trim() : "";
    if (!childUid) throw new HttpsError("invalid-argument", "childUid is required.");

    const childSnap = await getChildForPrimaryParent(childUid, primaryParentUid);
    const child = childSnap.data()!;
    const linked = Array.isArray(child.linkedParentUids) ? child.linkedParentUids : [];
    const permissions = (child.parentPermissions ?? {}) as Record<string, Record<string, boolean>>;
    const db = getFirestore();

    const parents = [];
    for (const uid of linked) {
      if (uid === primaryParentUid) continue;
      const parentSnap = await db.collection("users").doc(uid).get();
      const p = parentSnap.data() ?? {};
      parents.push({
        uid,
        name: typeof p.name === "string" ? p.name : "Linked parent",
        surname: typeof p.surname === "string" ? p.surname : "",
        email: typeof p.email === "string" ? p.email : "",
        permissions: { ...DEFAULT_PERMISSIONS, ...(permissions[uid] ?? {}) },
      });
    }

    return {
      childUid,
      primaryParentUid,
      parents,
      defaults: DEFAULT_PERMISSIONS,
    };
  },
);

export const setParentPermissions = onCall(
  { enforceAppCheck: ENFORCE_APP_CHECK },
  async (request) => {
    const primaryParentUid = assertParent(request);
    const childUid = typeof request.data?.childUid === "string" ? request.data.childUid.trim() : "";
    const parentUid = typeof request.data?.parentUid === "string" ? request.data.parentUid.trim() : "";
    if (!childUid || !parentUid) {
      throw new HttpsError("invalid-argument", "childUid and parentUid are required.");
    }

    const childSnap = await getChildForPrimaryParent(childUid, primaryParentUid);
    const child = childSnap.data()!;
    const linked = Array.isArray(child.linkedParentUids) ? child.linkedParentUids : [];
    if (!linked.includes(parentUid) || parentUid === primaryParentUid) {
      throw new HttpsError("failed-precondition", "That account is not a linked secondary parent.");
    }

    const incoming = request.data?.permissions;
    if (!incoming || typeof incoming !== "object") {
      throw new HttpsError("invalid-argument", "permissions must be an object.");
    }

    const clean: Record<string, boolean> = {};
    for (const key of PERMISSION_KEYS) {
      if (typeof incoming[key] === "boolean") clean[key] = incoming[key];
    }

    const db = getFirestore();
    await db.collection("users").doc(childUid).update({
      [`parentPermissions.${parentUid}`]: { ...DEFAULT_PERMISSIONS, ...clean },
    });

    await db.collection("notifications").doc().set({
      recipientUid: parentUid,
      title: "Parent access updated",
      body: "The primary parent changed the permissions for your QuestKids account.",
      type: "parent_permissions_updated",
      isRead: false,
      createdAt: FieldValue.serverTimestamp(),
    });

    return { updated: true, permissions: { ...DEFAULT_PERMISSIONS, ...clean } };
  },
);
