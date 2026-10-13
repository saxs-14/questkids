import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore, FieldValue, Timestamp } from "firebase-admin/firestore";
import { createHash, randomInt } from "node:crypto";
import { resolveMx } from "node:dns/promises";
import { ENFORCE_APP_CHECK } from "../config";

const OTP_TTL_MS = 5 * 60 * 1000;
const RESEND_COOLDOWN_MS = 60 * 1000;
const MAX_VERIFY_ATTEMPTS = 5;
// A single OTP cycle only allows 5 guesses before its challenge is
// deleted, but nothing stopped an attacker from immediately requesting a
// fresh code and getting another 5 guesses, indefinitely. This counter
// persists across cycles (it survives challenge deletion/expiry) so
// repeated wrong guesses across many codes still add up to a lockout.
const MAX_FAILED_CYCLES = 10;
const LOCKOUT_MS = 15 * 60 * 1000;

/**
 * Parent actions gated behind an email step-up code. Add an action here
 * (and have that action's own callable call verifyAndConsumeActionOtp)
 * only when it fits a single deliberate "press one button" confirmation --
 * see unlinkChild.ts. setParentPermissions now qualifies too: its screen
 * (parent_access_screen.dart) batches every toggle flip into one pending
 * local edit per secondary parent and only calls this action once, from a
 * single "Save Changes" button -- so one OTP prompt per save, not per
 * toggle. "verifyEmail" and "adminLogin" also reuse it (from
 * verifyRegistrationEmail.ts and verifyAdminLoginOtp.ts) -- target is the
 * account's own email in both cases, not a child/parent uid. Despite the
 * name, this list isn't parent-exclusive any more; ROLE_FOR_ACTION below
 * is what actually gates who can request each one.
 */
export const SENSITIVE_PARENT_ACTIONS = [
  "unlinkChild",
  "setParentPermissions",
  "verifyEmail",
  "adminLogin",
] as const;
export type SensitiveParentAction = (typeof SENSITIVE_PARENT_ACTIONS)[number];

const ROLE_FOR_ACTION: Record<SensitiveParentAction, string> = {
  unlinkChild: "parent",
  setParentPermissions: "parent",
  verifyEmail: "parent",
  adminLogin: "admin",
};

// Best-effort list of well-known disposable/throwaway email providers.
// These domains have real, working mail servers (an MX check alone won't
// catch them) but exist specifically so the inbox can be abandoned right
// after reading one message -- the opposite of what a parent's account
// recovery/notification address needs. Not exhaustive; new ones appear
// constantly, so this is a speed bump against the obvious cases, not a
// guarantee.
const DISPOSABLE_EMAIL_DOMAINS = new Set([
  "mailinator.com",
  "10minutemail.com",
  "guerrillamail.com",
  "guerrillamail.info",
  "yopmail.com",
  "trashmail.com",
  "temp-mail.org",
  "tempmail.com",
  "discard.email",
  "getnada.com",
  "throwawaymail.com",
  "sharklasers.com",
  "maildrop.cc",
  "fakeinbox.com",
  "dispostable.com",
  "mintemail.com",
  "mailnesia.com",
  "spamgourmet.com",
  "33mail.com",
  "moakt.com",
]);

/**
 * Only used for the "verifyEmail" action, right before actually sending a
 * code: a domain with no mail server at all can never receive the code,
 * which is the clearest, zero-cost signal that an address is fake/typo'd
 * (e.g. "@fake.fake" or "@gmial.com"). Deliberately not applied to the
 * other sensitive actions -- an existing parent's email on file already
 * proved deliverable when they verified it, and re-checking DNS on every
 * step-up request would just add latency and a new failure mode for no
 * benefit.
 */
async function assertEmailIsDeliverable(email: string): Promise<void> {
  const domain = email.split("@")[1]?.toLowerCase();
  if (!domain) {
    throw new HttpsError("invalid-argument", "That doesn't look like a valid email address.");
  }
  if (DISPOSABLE_EMAIL_DOMAINS.has(domain)) {
    throw new HttpsError(
      "invalid-argument",
      "Temporary/disposable email addresses aren't allowed. Please use a real email you can access long-term."
    );
  }
  let records: Awaited<ReturnType<typeof resolveMx>>;
  try {
    records = await resolveMx(domain);
  } catch (error) {
    const errorCode =
      typeof error === "object" && error !== null && "code" in error ?
        error.code :
        undefined;
    if (errorCode !== "ENODATA" && errorCode !== "ENOTFOUND") {
      console.error("Unable to check email MX records.", error);
      throw new HttpsError(
        "unavailable",
        "We couldn't check this email address right now. Please try again."
      );
    }
    throw new HttpsError(
      "invalid-argument",
      "This email address can't receive mail. Please check for typos or use a different address."
    );
  }
  if (!records.length) {
    throw new HttpsError(
      "invalid-argument",
      "This email address can't receive mail. Please check for typos or use a different address."
    );
  }
}

function otpChallengeRef(uid: string, action: string) {
  return getFirestore().collection("otp_challenges").doc(`${uid}_${action}`);
}

function otpLockoutRef(uid: string, action: string) {
  return getFirestore().collection("otp_lockouts").doc(`${uid}_${action}`);
}

function hashOtpCode(
  code: string,
  uid: string,
  action: string,
  target: string
): string {
  return createHash("sha256")
    .update(`${uid}:${action}:${target}:${code}`)
    .digest("hex");
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

function requireTarget(data: unknown): string {
  const target = (data as { target?: unknown })?.target;
  if (typeof target !== "string" || !target.trim()) {
    throw new HttpsError(
      "invalid-argument",
      "target is required (identifies exactly what this code authorizes)."
    );
  }
  return target.trim();
}

/**
 * Requests a 6-digit email verification code for a sensitive parent
 * action. The code is single-use and expires in 5 minutes; resending is
 * rate-limited to once every 60 seconds per uid+action.
 *
 * `target` identifies exactly what the code authorizes (e.g. the
 * childUid being unlinked, or `${childUid}:${parentUid}` for a
 * permissions change) and is re-derived from the real action's own
 * parameters at verify time -- see verifyAndConsumeActionOtp. Without
 * this, a code requested for one child/secondary-parent pair could be
 * replayed against a different one for the same action type, since the
 * code itself only ever proved "this parent confirmed *an*
 * setParentPermissions/unlinkChild action", not which one.
 */
export const requestActionOtp = onCall(
  { enforceAppCheck: ENFORCE_APP_CHECK },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "You must be signed in.");
    }
    const action = requireSensitiveAction(request.data);
    const requiredRole = ROLE_FOR_ACTION[action];
    if (request.auth.token.role !== requiredRole) {
      throw new HttpsError(
        "permission-denied",
        `Only ${requiredRole} accounts can request this verification code.`
      );
    }
    const uid = request.auth.uid;
    const ref = otpChallengeRef(uid, action);

    const lockoutSnap = await otpLockoutRef(uid, action).get();
    const lockedUntil = lockoutSnap.data()?.lockedUntil as Timestamp | undefined;
    if (lockedUntil && Date.now() < lockedUntil.toMillis()) {
      throw new HttpsError(
        "resource-exhausted",
        "Too many incorrect attempts. Try again later."
      );
    }

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

    // verifyEmail's and adminLogin's target IS the account's own email --
    // forced from the on-file address rather than trusting the client, so
    // there's no way for the stored challenge and the later verify-time
    // re-derivation (see verifyRegistrationEmail.ts / verifyAdminLoginOtp.ts)
    // to ever disagree. Neither has a separate child/parent-pair target.
    const emailIsTarget = action === "verifyEmail" || action === "adminLogin";
    const target = emailIsTarget ? email : requireTarget(request.data);
    if (action === "verifyEmail") {
      await assertEmailIsDeliverable(email);
    }

    const code = generateOtpCode();
    const now = Date.now();
    await ref.set({
      codeHash: hashOtpCode(code, uid, action, target),
      action,
      target,
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
 *
 * `target` must be derived from the action's own real parameters (e.g.
 * the childUid actually being unlinked), never trusted from the same
 * client payload the otpCode came in on -- that's what stops a code
 * requested for target A from being replayed against target B.
 */
export async function verifyAndConsumeActionOtp(
  uid: string,
  action: SensitiveParentAction,
  suppliedCode: unknown,
  target: string
): Promise<void> {
  if (typeof suppliedCode !== "string" || !/^\d{6}$/.test(suppliedCode)) {
    throw new HttpsError(
      "invalid-argument",
      "A valid 6-digit verification code is required."
    );
  }
  const ref = otpChallengeRef(uid, action);
  const lockoutRef = otpLockoutRef(uid, action);

  const lockoutSnap = await lockoutRef.get();
  const lockedUntil = lockoutSnap.data()?.lockedUntil as Timestamp | undefined;
  if (lockedUntil && Date.now() < lockedUntil.toMillis()) {
    throw new HttpsError(
      "resource-exhausted",
      "Too many incorrect attempts. Try again later."
    );
  }

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
    if (data.target !== target) {
      // Deliberately not deleted/counted as a failed attempt: this is
      // the caller invoking the action against a different target than
      // the one it requested a code for, not a wrong-guess attack.
      return "target-mismatch" as const;
    }
    const attempts = typeof data.attempts === "number" ? data.attempts : 0;
    if (attempts >= MAX_VERIFY_ATTEMPTS) {
      tx.delete(ref);
      return "too-many-attempts" as const;
    }
    const expectedHash = hashOtpCode(suppliedCode, uid, action, target);
    if (expectedHash !== data.codeHash) {
      tx.update(ref, { attempts: attempts + 1 });
      return "incorrect" as const;
    }
    tx.delete(ref);
    return "ok" as const;
  });

  if (outcome === "ok") {
    // Clear any accumulated failure count now that a code was correctly
    // entered -- the lockout is for sustained guessing, not a one-off
    // earlier typo.
    await lockoutRef.delete();
    return;
  }

  if (outcome === "incorrect" || outcome === "too-many-attempts") {
    await getFirestore().runTransaction(async (tx) => {
      const snap = await tx.get(lockoutRef);
      const failedCycles = (snap.data()?.failedCycles as number | undefined) ?? 0;
      const nextFailedCycles =
        outcome === "too-many-attempts" ? failedCycles + 1 : failedCycles;
      if (nextFailedCycles >= MAX_FAILED_CYCLES) {
        tx.set(lockoutRef, {
          failedCycles: nextFailedCycles,
          lockedUntil: Timestamp.fromMillis(Date.now() + LOCKOUT_MS),
        });
      } else if (nextFailedCycles !== failedCycles) {
        tx.set(lockoutRef, { failedCycles: nextFailedCycles }, { merge: true });
      }
    });
  }

  switch (outcome) {
  case "not-found":
    throw new HttpsError("failed-precondition", "Request a new verification code first.");
  case "expired":
    throw new HttpsError(
      "failed-precondition",
      "That verification code has expired. Request a new one."
    );
  case "target-mismatch":
    throw new HttpsError(
      "failed-precondition",
      "This code was issued for a different request. Request a new verification code."
    );
  case "too-many-attempts":
    throw new HttpsError(
      "failed-precondition",
      "Too many incorrect attempts. Request a new verification code."
    );
  case "incorrect":
    throw new HttpsError("permission-denied", "Incorrect verification code.");
  }
}
