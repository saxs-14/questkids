import { getFirestore, Timestamp } from "firebase-admin/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { ENFORCE_APP_CHECK } from "../config";

/**
 * Returns aggregate, non-identifying platform metrics for the protected
 * administrator reports screen. No learner names, emails, or scores are returned.
 */
export const getAdminPlatformReport = onCall(
  { enforceAppCheck: ENFORCE_APP_CHECK },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in to view platform reports.");
    }
    if (request.auth.token.role !== "admin") {
      throw new HttpsError("permission-denied", "Only admins can view platform reports.");
    }

    const db = getFirestore();
    const sevenDaysAgo = Timestamp.fromMillis(Date.now() - 7 * 24 * 60 * 60 * 1000);
    const counts = await Promise.all([
      db.collection("users").count().get(),
      db.collection("users").where("role", "==", "learner").count().get(),
      db.collection("users").where("role", "==", "parent").count().get(),
      db.collection("users").where("role", "==", "admin").count().get(),
      db.collection("activities").count().get(),
      db.collection("game_sessions").count().get(),
      db.collection("game_sessions").where("completedAt", ">=", sevenDaysAgo).count().get(),
      db.collection("ai_reports").count().get(),
      db.collection("ai_reports").where("status", "==", "resolved").count().get(),
      db.collection("weekly_reports").count().get(),
    ]);

    const totalReports = counts[7].data().count ?? 0;
    const resolvedReports = counts[8].data().count ?? 0;
    return {
      generatedAt: new Date().toISOString(),
      users: counts[0].data().count ?? 0,
      learners: counts[1].data().count ?? 0,
      parents: counts[2].data().count ?? 0,
      admins: counts[3].data().count ?? 0,
      activities: counts[4].data().count ?? 0,
      gameSessions: counts[5].data().count ?? 0,
      gameSessionsLast7Days: counts[6].data().count ?? 0,
      aiReports: totalReports,
      resolvedAiReports: resolvedReports,
      pendingAiReports: Math.max(0, totalReports - resolvedReports),
      weeklyReports: counts[9].data().count ?? 0,
      periodDays: 7,
    };
  }
);
