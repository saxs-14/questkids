import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore } from "firebase-admin/firestore";
import { getAuth } from "firebase-admin/auth";
import { createHash } from "node:crypto";
import { ENFORCE_APP_CHECK } from "../config";

const OPTIONS = { enforceAppCheck: ENFORCE_APP_CHECK };

const RATE_WINDOW_MS = 15 * 60 * 1000;
const MAX_NAME_ATTEMPTS = 10;
const MAX_IP_ATTEMPTS = 60;

function rateLimitKey(value: string): string {
  return createHash("sha256").update(value).digest("hex");
}

/**
 * Rate-limit attempts without persisting raw names or IP addresses.
 * A per-name/IP bucket slows guessing one learner's DOB; an IP bucket
 * limits broad name enumeration from one client/network.
 */
async function enforceLoginRateLimit(ip: string, normalizedName: string): Promise<void> {
  const db = getFirestore();
  const now = Date.now();
  const keys = [
    { id: rateLimitKey(`name:${ip}:${normalizedName}`), limit: MAX_NAME_ATTEMPTS },
    { id: rateLimitKey(`ip:${ip}`), limit: MAX_IP_ATTEMPTS },
  ];
  const refs = keys.map(({ id }) => db.collection("security_login_attempts").doc(id));

  await db.runTransaction(async (transaction) => {
    const snapshots = await Promise.all(refs.map((ref) => transaction.get(ref)));
    const updates = snapshots.map((snapshot, index) => {
      const data = snapshot.data();
      const startedAt = typeof data?.windowStartedAt === "number"
        ? data.windowStartedAt
        : 0;
      const inWindow = now - startedAt < RATE_WINDOW_MS && now >= startedAt;
      const attempts = inWindow && typeof data?.attempts === "number"
        ? data.attempts
        : 0;
      if (attempts >= keys[index].limit) {
        throw new HttpsError(
          "resource-exhausted",
          "Too many login attempts. Please wait 15 minutes and try again."
        );
      }
      return {
        ref: refs[index],
        value: {
          windowStartedAt: inWindow ? startedAt : now,
          attempts: attempts + 1,
          updatedAt: new Date(now),
        },
      };
    });
    for (const update of updates) {
      transaction.set(update.ref, update.value);
    }
  });
}

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
 * Supports the date formats already written by QuestKids:
 * - Firestore Timestamp objects
 * - milliseconds since epoch (UserModel.toMap format)
 * - YYYY-MM-DD strings from older/imported records
 */
function storedBirthDateKey(value: unknown): string | null {
  let date: Date;

  if (typeof value === "number" && Number.isFinite(value)) {
    date = new Date(value);
  } else if (typeof value === "string") {
    const normalized = value.trim();
    if (/^\d{4}-\d{2}-\d{2}$/.test(normalized)) {
      const parsed = new Date(`${normalized}T00:00:00.000Z`);
      if (
        Number.isNaN(parsed.getTime()) ||
        parsed.toISOString().slice(0, 10) !== normalized
      ) {
        return null;
      }
      return normalized;
    }
    date = new Date(normalized);
  } else if (
    typeof value === "object" &&
    value !== null &&
    "toDate" in value &&
    typeof (value as { toDate?: unknown }).toDate === "function"
  ) {
    date = (value as { toDate: () => Date }).toDate();
  } else {
    return null;
  }

  if (Number.isNaN(date.getTime())) return null;
  return dateKeyInSouthAfrica(date);
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

  const clientIp = request.rawRequest.ip || "unknown";
  await enforceLoginRateLimit(clientIp, name.toLocaleLowerCase("en-ZA"));

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

  const matchingChild = learners.find(
    (doc) => storedBirthDateKey(doc.data().birthDate) === birthDate
  );

  if (!matchingChild) {
    throw new HttpsError("permission-denied", "Incorrect date of birth.");
  }

  const customToken = await getAuth().createCustomToken(matchingChild.id, {
    role: "learner",
  });

  return { token: customToken };
});
