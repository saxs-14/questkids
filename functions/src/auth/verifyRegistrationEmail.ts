import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";
import { ENFORCE_APP_CHECK } from "../config";
import { verifyAndConsumeActionOtp } from "../parent/actionOtp";

/**
 * Confirms the 6-digit code sent by requestActionOtp({action:
 * "verifyEmail"}) right after registration, then marks the account's
 * email verified on both sides that read it: the Firebase Auth user
 * record (emailVerified) and the mirrored users/{uid} Firestore doc
 * (NavigationService.getDashboard gates on the latter -- see
 * verify_email_screen.dart).
 */
export const verifyRegistrationEmail = onCall(
  { enforceAppCheck: ENFORCE_APP_CHECK },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "You must be signed in.");
    }
    const uid = request.auth.uid;
    const { otpCode } = request.data as { otpCode?: unknown };

    const db = getFirestore();
    const userRef = db.collection("users").doc(uid);
    const userSnap = await userRef.get();
    const email = request.auth.token.email ?? userSnap.data()?.email;
    if (typeof email !== "string" || !email) {
      throw new HttpsError(
        "failed-precondition",
        "No email address is on file to verify."
      );
    }

    const authUser = await getAuth().getUser(uid);
    if (authUser.emailVerified) {
      // Recover safely if Auth was updated but the Firestore mirror write
      // failed during an earlier attempt; the OTP has already been consumed.
      await userRef.update({ emailVerified: true });
      return { verified: true };
    }

    await verifyAndConsumeActionOtp(uid, "verifyEmail", otpCode, email);

    await getAuth().updateUser(uid, { emailVerified: true });
    await userRef.update({ emailVerified: true });

    return { verified: true };
  }
);
