import { onCall, HttpsError } from "firebase-functions/v2/https";
import { GoogleGenerativeAI } from "@google/generative-ai";
import { getFirestore, Timestamp, Transaction } from "firebase-admin/firestore";
import { GEMINI_API_KEY } from "../secrets";
import { ENFORCE_APP_CHECK, GEMINI_MODEL } from "../config";

const DAILY_INSIGHT_QUOTA = 20;
const MAX_LEARNERS = 30; // mirrors TeacherRepository.getClassAnalytics's own cap

interface ClassStats {
  totalLearners: number;
  subjectAvg: Record<string, number>;
  completionRate: number;
  weakTopics: string[];
}

/** Recomputes class stats from Firestore instead of trusting whatever the
 * client sends — mirrors TeacherRepository.getClassAnalytics's logic
 * (lib/data/repositories/teacher_repository.dart) so the AI prompt is
 * built from real data a teacher can't fabricate by calling this function
 * with made-up numbers. linkedTeacherUids is the array field the live
 * "Add Learner" flow actually writes (teacher_dashboard.dart) -- not the
 * singular linkedTeacherUid field on UserModel, which no live code path
 * writes (see test/data/teacher_repository_test.dart). */
async function computeClassStats(teacherUid: string): Promise<ClassStats> {
  const db = getFirestore();
  const learnersSnap = await db
    .collection("users")
    .where("linkedTeacherUids", "array-contains", teacherUid)
    .get();

  if (learnersSnap.empty) {
    return { totalLearners: 0, subjectAvg: {}, completionRate: 0, weakTopics: [] };
  }

  const learnerUids = learnersSnap.docs.map((d) => d.id).slice(0, MAX_LEARNERS);
  const thirtyDaysAgo = Timestamp.fromMillis(Date.now() - 30 * 24 * 60 * 60 * 1000);

  const sessionsSnaps = await Promise.all(
    learnerUids.map((uid) =>
      db
        .collection("game_sessions")
        .where("uid", "==", uid)
        .where("completedAt", ">=", thirtyDaysAgo)
        .get()
    )
  );

  const subjectScores: Record<string, number[]> = {};
  let totalAttempted = 0;
  let totalCompleted = 0;

  for (const sessSnap of sessionsSnaps) {
    totalAttempted += sessSnap.docs.length;
    for (const doc of sessSnap.docs) {
      const data = doc.data();
      const subj = (data.subject as string | undefined) ?? "Other";
      const score = (data.score as number | undefined) ?? 0;
      const result = (data.result as string | undefined) ?? "";
      if (result === "win" || result === "complete") totalCompleted++;
      (subjectScores[subj] ??= []).push(score);
    }
  }

  const subjectAvg: Record<string, number> = {};
  for (const [subject, scores] of Object.entries(subjectScores)) {
    subjectAvg[subject] = scores.reduce((a, b) => a + b, 0) / scores.length;
  }

  const weakTopics = Object.entries(subjectAvg)
    .filter(([, avg]) => avg < 60)
    .sort(([, a], [, b]) => a - b)
    .map(([subject]) => subject);

  return {
    totalLearners: learnerUids.length,
    subjectAvg,
    completionRate: totalAttempted === 0 ? 0 : totalCompleted / totalAttempted,
    weakTopics,
  };
}

/** Per-uid daily cap, mirroring gemini/proxy.ts's enforceQuota — teachers
 * get their own counter so this never competes with a learner's Questy
 * chat quota. */
async function enforceInsightQuota(uid: string): Promise<void> {
  const today = new Date().toISOString().slice(0, 10);
  const ref = getFirestore().collection("usage_ai_teacher").doc(uid);

  await getFirestore().runTransaction(async (tx: Transaction) => {
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

    const { subjectAvg, totalLearners, completionRate, weakTopics } =
      await computeClassStats(request.auth.uid);

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
    } catch (error) {
      console.error(`getTeacherInsight: Gemini call failed for uid ${request.auth.uid}`, error);
      return {
        text: "Consider small group sessions for subjects below 60% " +
        "and celebrate strong performers to maintain motivation.",
      };
    }
  });
