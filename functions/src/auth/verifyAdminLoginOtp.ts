import { onCall, HttpsError } from "firebase-functions/v2/https";
import { ENFORCE_APP_CHECK } from "../config";
import { verifyAndConsumeActionOtp } from "../parent/actionOtp";

/**
 * Second factor for the admin portal: confirms the code requestActionOtp
 * sent via {action: "adminLogin"} right after admin_login_screen.dart's
 * email/password step succeeds. No further side effect -- unlike
 * verifyRegistrationEmail, a login has nothing to persist on success, the
 * caller just proceeds to the dashboard once this resolves.
 */
export const verifyAdminLoginOtp = onCall(
  { enforceAppCheck: ENFORCE_APP_CHECK },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "You must be signed in.");
    }
    if (request.auth.token.role !== "admin") {
      throw new HttpsError("permission-denied", "Only admin accounts can use this.");
    }
    const uid = request.auth.uid;
    const email = request.auth.token.email;
    if (typeof email !== "string" || !email) {
      throw new HttpsError("failed-precondition", "No email address is on file to verify.");
    }
    const { otpCode } = request.data as { otpCode?: unknown };

    await verifyAndConsumeActionOtp(uid, "adminLogin", otpCode, email);

    return { verified: true };
  }
);
