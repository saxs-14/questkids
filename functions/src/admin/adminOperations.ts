import { onCall, HttpsError, CallableRequest } from "firebase-functions/v2/https";
import { getFirestore } from "firebase-admin/firestore";
import { ENFORCE_APP_CHECK } from "../config";
import { GEMINI_API_KEY } from "../secrets";
import { runLeaderboardRefresh } from "../leaderboard/refresh";
import { runDailyMissionsGeneration } from "../missions/generate";

function requireAdmin(request: CallableRequest): void {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "You must be signed in.");
  }
  if (request.auth.token.role !== "admin") {
    throw new HttpsError("permission-denied", "Only admins can run platform operations.");
  }
}

/**
 * Admin-console "Refresh leaderboards now" button. Runs the exact same
 * logic as the nightly refreshLeaderboards schedule (leaderboard/refresh.ts)
 * on demand, so an admin doesn't have to wait for 01:00 SAST to verify a
 * fix or recover from a bad run.
 */
export const adminRefreshLeaderboards = onCall(
  { enforceAppCheck: ENFORCE_APP_CHECK },
  async (request) => {
    requireAdmin(request);
    await runLeaderboardRefresh(getFirestore());
    return { refreshed: true };
  }
);

/**
 * Admin-console "Generate daily missions now" button. Runs the exact
 * same logic as the nightly generateDailyMissions schedule
 * (missions/generate.ts) on demand.
 */
export const adminGenerateDailyMissions = onCall(
  { enforceAppCheck: ENFORCE_APP_CHECK, secrets: [GEMINI_API_KEY] },
  async (request) => {
    requireAdmin(request);
    const result = await runDailyMissionsGeneration(getFirestore());
    return result;
  }
);
