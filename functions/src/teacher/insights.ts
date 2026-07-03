import { onCall, HttpsError } from "firebase-functions/v2/https";
import { GoogleGenerativeAI } from "@google/generative-ai";
import * as admin from "firebase-admin";
import { GEMINI_API_KEY } from "../secrets";
import { ENFORCE_APP_CHECK, GEMINI_MODEL } from "../config";

const DAILY_INSIGHT_QUOTA = 20;

/** Per-uid daily cap, mirroring gemini/proxy.ts's enforceQuota — teachers
 * get their own counter so this never competes with a learner's Questy
 * chat quota. */
async function enforceInsightQuota(uid: string): Promise<void> {
  const today = new Date().toISOString().slice(0, 10);
  const ref = admin.firestore().collection("usage_ai_teacher").doc(uid);

  await admin.firestore().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const data = snap.data();
    const count = data?.date === today ? (data.count as number) : 0;

    if (count >= DAILY_INSIGHT_QUOTA) {
      throw new HttpsError(
        "resource-exhausted",
        "You've reached today's insight limit. Come back tomorrow!"
      );
    }

    tx.set(ref, { date: today, count: count + 1 }, { merge: true });
  });
}

export const getTeacherInsight = onCall(
  { enforceAppCheck: ENFORCE_APP_CHECK, secrets: [GEMINI_API_KEY] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "You must be signed in.");
    }
    const role = request.auth.token.role;
    if (role !== "teacher" && role !== "admin") {
      throw new HttpsError("permission-denied", "Only teachers can request class insights.");
    }
    await enforceInsightQuota(request.auth.uid);

    const { subjectAvg, totalLearners, completionRate, weakTopics } = request.data as {
    subjectAvg: Record<string, number>;
    totalLearners: number;
    completionRate: number;
    weakTopics: string[];
  };

    const apiKey = GEMINI_API_KEY.value();
    if (!apiKey) throw new HttpsError("internal", "Gemini API key not configured");

    const genAI = new GoogleGenerativeAI(apiKey);
    const model = genAI.getGenerativeModel({ model: GEMINI_MODEL });

    const avgStr = Object.entries(subjectAvg)
      .map(([s, v]) => `${s}: ${Number(v).toFixed(1)}%`)
      .join(", ");

    const prompt = `You are an educational advisor for South African primary schools (CAPS curriculum).
Class data: ${totalLearners} learners, ${(completionRate * 100).toFixed(1)}% quest completion rate.
Subject averages: ${avgStr || "no data yet"}.
Weak areas below 60%: ${weakTopics.length > 0 ? weakTopics.join(", ") : "none"}.

Write exactly 2 sentences of specific, actionable advice for the teacher. Be encouraging and practical.
Focus on the weakest areas. No bullet points, no lists — just 2 clear sentences.`;

    try {
      const result = await model.generateContent(prompt);
      const text = result.response.text()?.trim();
      return { text: text || "Focus on the identified weak subjects this week with targeted activities." };
    } catch {
      return {
        text: "Consider small group sessions for subjects below 60% " +
        "and celebrate strong performers to maintain motivation.",
      };
    }
  });
