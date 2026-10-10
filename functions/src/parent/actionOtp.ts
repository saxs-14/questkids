import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore, FieldValue, Timestamp } from "firebase-admin/firestore";
import { createHash, randomInt } from "node:crypto";
import { ENFORCE_APP_CHECK } from "../config";

const OTP_TTL_MS = 5 * 60 * 1000;
const RESEND_COOLDOWN_MS = 60 * 1000;
const MAX_VERIFY_ATTEMPTS = 5;

/**
 * Parent actions gated behind an email step-up code. Add an action here
 * (and have that action's own callable call verifyAndConsumeActionOtp)
 * only when it fits a single deliberate "press one button" confirmation --
 * see unlinkChild.ts. setParentPermissions was deliberately NOT added:
 * its screen saves on every individual switch toggle, so gating it the
 * same way would mean an OTP prompt per toggle flip. That needs a
 * batch/"Save changes" redesign first, which is a separate piece of work.
 */
export const SENSITIVE_PARENT_ACTIONS = ["unlinkChild"] as const;
export type SensitiveParentAction = (typeof SENSITIVE_PARENT_ACTIONS)[number];

function otpChallengeRef(uid: string, action: string) {
  return getFirestore().collection("otp_challenges").doc(`${uid}_${action}`);
}

function hashOtpCode(code: string, uid: string, action: string): string {
  return createHash("sha256").update(`${uid}:${action}:${code}`).digest("hex");
}

function generateOtpCode(): string {
  return randomInt(0, 1_000_000).toString().padStart(6, "0");
}

function requireSensitiveAction(data: unknown): SensitiveParentAction {
  const action = (data as { action?: unknown })?.action;
  if (
    typeof action !== "string" ||
    !(SENSITIVE_PARENT_ACTIONS as readonly string[]).includes(action)
  ) {
    throw new HttpsError(
      "invalid-argument",
      `action must be one of ${SENSITIVE_PARENT_ACTIONS.join(", ")}`
    );
  }
  return action as SensitiveParentAction;
}

/**
 * Requests a 6-digit email verification code for a sensitive parent
 * action. The code is single-use and expires in 5 minutes; resending is
 * rate-limited to once every 60 seconds per uid+action.
 */
export const requestActionOtp = onCall(
  { enforceAppCheck: ENFORCE_APP_CHECK },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "You must be signed in.");
    }
    if (request.auth.token.role !== "parent") {
      throw new HttpsError(
        "permission-denied",
        "Only parent accounts can request a verification code."
      );
    }
    const action = requireSensitiveAction(request.data);
    const uid = request.auth.uid;
    const ref = otpChallengeRef(uid, action);

    const existing = await ref.get();
    const lastSentAt = existing.data()?.lastSentAt as Timestamp | undefined;
    if (lastSentAt && Date.now() - lastSentAt.toMillis() < RESEND_COOLDOWN_MS) {
      throw new HttpsError(
        "resource-exhausted",
        "Please wait a moment before requesting another code."
      );
    }

    const db = getFirestore();
    const userSnap = await db.collection("users").doc(uid).get();
    const email = request.auth.token.email ?? userSnap.data()?.email;
    if (typeof email !== "string" || !email) {
      throw new HttpsError(
        "failed-precondition",
        "No email address is on file to send a verification code to."
      );
    }

    const code = generateOtpCode();
    const now = Date.now();
    await ref.set({
      codeHash: hashOtpCode(code, uid, action),
      action,
      attempts: 0,
      expiresAt: Timestamp.fromMillis(now + OTP_TTL_MS),
      lastSentAt: Timestamp.fromMillis(now),
      createdAt: FieldValue.serverTimestamp(),
    });

    await db.collection("emails").doc().set({
      to: email,
      subject: "Your QuestKids verification code",
      template: "otp_code",
      data: { code },
      createdAt: FieldValue.serverTimestamp(),
    });

    return { sent: true, expiresInSeconds: OTP_TTL_MS / 1000 };
  }
);

/**
 * Verifies a previously-requested OTP for a sensitive parent action and
 * consumes it (single-use). Call this from inside the action's own
 * callable (see unlinkChild.ts), before performing the action -- there is
 * no separate "verified" token to generate, store, or forget to check.
 */
export async function verifyAndConsumeActionOtp(
  uid: string,
  action: SensitiveParentAction,
  suppliedCode: unknown
): Promise<void> {
  if (typeof suppliedCode !== "string" || !/^\d{6}$/.test(suppliedCode)) {
    throw new HttpsError(
      "invalid-argument",
      "A valid 6-digit verification code is required."
    );
  }
  const ref = otpChallengeRef(uid, action);

  // A transaction aborts ALL of its queued writes if the updateFunction
  // throws -- including a tx.update() made earlier in the same call. The
  // attempts counter below MUST actually commit even when the code is
  // wrong (that's the entire point of the lockout), so the transaction
  // returns a status instead of throwing, and the matching HttpsError is
  // thrown only after the transaction has committed.
  const outcome = await getFirestore().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) {
      return "not-found" as const;
    }
    const data = snap.data()!;
    const expiresAt = data.expiresAt as Timestamp;
    if (Date.now() > expiresAt.toMillis()) {
      tx.delete(ref);
      return "expired" as const;
    }
    const attempts = typeof data.attempts === "number" ? data.attempts : 0;
    if (attempts >= MAX_VERIFY_ATTEMPTS) {
      tx.delete(ref);
      return "too-many-attempts" as const;
    }
    const expectedHash = hashOtpCode(suppliedCode, uid, action);
    if (expectedHash !== data.codeHash) {
      tx.update(ref, { attempts: attempts + 1 });
      return "incorrect" as const;
    }
    tx.delete(ref);
    return "ok" as const;
  });

  switch (outcome) {
  case "not-found":
    throw new HttpsError("failed-precondition", "Request a new verification code first.");
  case "expired":
    throw new HttpsError(
      "failed-precondition",
      "That verification code has expired. Request a new one."
    );
  case "too-many-attempts":
    throw new HttpsError(
      "failed-precondition",
      "Too many incorrect attempts. Request a new verification code."
    );
  case "incorrect":
    throw new HttpsError("permission-denied", "Incorrect verification code.");
  case "ok":
    return;
  }
}
