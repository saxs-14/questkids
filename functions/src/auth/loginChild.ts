import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore } from "firebase-admin/firestore";
import { getAuth } from "firebase-admin/auth";
import { ENFORCE_APP_CHECK } from "../config";

const OPTIONS = { enforceAppCheck: ENFORCE_APP_CHECK };

function normalizeName(value: unknown): string {
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", "Name is required.");
  }
  const name = value.trim();
  if (!name || name.length > 80) {
    throw new HttpsError("invalid-argument", "Name is required.");
  }
  return name;
}

function dateKeyInSouthAfrica(value: Date): string {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: "Africa/Johannesburg",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(value);
}

/**
 * Verifies a child login before creating a Firebase custom token.
 *
 * We intentionally distinguish:
 * - no learner with this name -> incorrect name
 * - learner name exists but DOB does not match -> incorrect date of birth
 *
 * App Check is enforced when enabled in the project configuration because
 * this endpoint intentionally exposes limited credential-validation feedback.
 */
export const loginChild = onCall(OPTIONS, async (request) => {
  const name = normalizeName(request.data?.name);
  const birthDate = request.data?.birthDate;

  if (typeof birthDate !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(birthDate)) {
    throw new HttpsError("invalid-argument", "Date of birth is required.");
  }

  const snapshot = await getFirestore()
    .collection("users")
    .where("name", "==", name)
    .get();

  const learners = snapshot.docs.filter(
    (doc) => doc.data().role === "learner"
  );

  if (learners.length === 0) {
    throw new HttpsError("not-found", "Incorrect name.");
  }

  const matchingChild = learners.find((doc) => {
    const stored = doc.data().birthDate;
    if (!stored || typeof stored.toDate !== "function") return false;
    return dateKeyInSouthAfrica(stored.toDate()) === birthDate;
  });

  if (!matchingChild) {
    throw new HttpsError("permission-denied", "Incorrect date of birth.");
  }

  const customToken = await getAuth().createCustomToken(matchingChild.id, {
    role: "learner",
  });

  return { token: customToken };
});
