import { getFirestore, FieldValue, Transaction } from "firebase-admin/firestore";
import { onCall, HttpsError, CallableRequest } from "firebase-functions/v2/https";
import { GoogleGenerativeAI } from "@google/generative-ai";
import { ENFORCE_APP_CHECK, GEMINI_MODEL } from "../config";
import { GEMINI_API_KEY } from "../secrets";

const DAILY_PARENT_INSIGHT_QUOTA = 10;
const MAX_SESSIONS = 30;

function requireParent(request: CallableRequest): string {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in with your parent account to view learning insights.");
  }
  if (request.auth.token.role !== "parent") {
    throw new HttpsError("permission-denied", "Only linked parents can request parent learning insights.");
  }
  return request.auth.uid;
}

async function enforceParentInsightQuota(parentUid: string): Promise<void> {
  const db = getFirestore();
  const today = new Date().toISOString().slice(0, 10);
  const ref = db.collection("usage_parent_ai").doc(parentUid);
  await db.runTransaction(async (tx: Transaction) => {
    const snap = await tx.get(ref);
    const data = snap.data();
    const count = data?.date === today && typeof data.count === "number" ? data.count : 0;
    if (count >= DAILY_PARENT_INSIGHT_QUOTA) {
      throw new HttpsError(
        "resource-exhausted",
        "You've reached today's AI insight limit. Please try again tomorrow."
      );
    }
    tx.set(ref, { date: today, count: count + 1, updatedAt: FieldValue.serverTimestamp() }, { merge: true });
  });
}

function firstNameOf(value: unknown): string {
  if (typeof value !== "string" || !value.trim()) return "your child";
  return value.trim().split(/\s+/)[0].slice(0, 40);
}

function parseJson(raw: string): Record<string, unknown> {
  const cleaned = raw.replace(/```json/gi, "").replace(/```/g, "").trim();
  try {
    const parsed: unknown = JSON.parse(cleaned);
    if (parsed && typeof parsed === "object" && !Array.isArray(parsed)) {
      return parsed as Record<string, unknown>;
    }
  } catch {
    // A safe fallback is returned below when the model doesn't produce JSON.
  }
  return {
    summary: raw.slice(0, 700),
    strengths: [],
    focusAreas: [],
    actions: ["Review your child's recent activity together and encourage regular practice."],
    disclaimer: "These suggestions are based only on recorded game activity.",
  };
}

/**
 * Produces parent-facing educational suggestions from server-read game sessions.
 * The client supplies only the child UID; it cannot submit fabricated scores.
 */
export const getParentLearningInsights = onCall(
  { enforceAppCheck: ENFORCE_APP_CHECK, secrets: [GEMINI_API_KEY] },
  async (request) => {
    const parentUid = requireParent(request);
    const childUid = request.data?.childUid;
    if (typeof childUid !== "string" || !childUid.trim() || childUid.length > 128) {
      throw new HttpsError("invalid-argument", "A valid childUid is required.");
    }

    const db = getFirestore();
    const [parentSnap, childSnap] = await Promise.all([
      db.collection("users").doc(parentUid).get(),
      db.collection("users").doc(childUid).get(),
    ]);
    if (!parentSnap.exists || parentSnap.data()?.role !== "parent") {
      throw new HttpsError("permission-denied", "A verified parent profile is required.");
    }
    if (!childSnap.exists || childSnap.data()?.role !== "learner") {
      throw new HttpsError("not-found", "The learner profile could not be found.");
    }

    const parent = parentSnap.data()!;
    const child = childSnap.data()!;
    const parentLinks = Array.isArray(parent.linkedChildrenUids) ? parent.linkedChildrenUids : [];
    const childLinks = Array.isArray(child.linkedParentUids) ? child.linkedParentUids : [];
    const isLinked = parentLinks.includes(childUid) &&
      (child.parentUid === parentUid || childLinks.includes(parentUid));
    if (!isLinked) {
      throw new HttpsError("permission-denied", "You can only view insights for a child linked to your account.");
    }

    await enforceParentInsightQuota(parentUid);

    const sessionsSnap = await db.collection("game_sessions")
      .where("uid", "==", childUid)
      .orderBy("completedAt", "desc")
      .limit(MAX_SESSIONS)
      .get();

    const sessions = sessionsSnap.docs.map((doc) => doc.data()).filter((s) => {
      return typeof s.completedAt?.toDate === "function" &&
        typeof s.score === "number" &&
        s.score >= 0 && s.score <= 100;
    });
    const subjectTotals = new Map<string, { count: number; totalScore: number }>();
    for (const session of sessions) {
      const subject = typeof session.subject === "string" && session.subject.trim() ?
        session.subject.slice(0, 60) : "General";
      const bucket = subjectTotals.get(subject) ?? { count: 0, totalScore: 0 };
      bucket.count += 1;
      bucket.totalScore += session.score;
      subjectTotals.set(subject, bucket);
    }

    const subjects = [...subjectTotals.entries()].map(([subject, values]) => ({
      subject,
      games: values.count,
      averageScore: Math.round(values.totalScore / values.count),
    }));
    const averageScore = sessions.length ?
      Math.round(sessions.reduce((sum, session) => sum + session.score, 0) / sessions.length) :
      null;
    const recentActivity = sessions.map((session) => ({
      subject: typeof session.subject === "string" ? session.subject.slice(0, 60) : "General",
      score: session.score,
      completedAt: session.completedAt.toDate().toISOString(),
    }));

    // Do not ask the model to infer trends when there are no valid scored sessions.
    // This deterministic response prevents unsupported claims for a new learner.
    if (sessions.length === 0) {
      return {
        childUid,
        generatedAt: new Date().toISOString(),
        sessionsAnalysed: 0,
        averageScore: null,
        subjects: [],
        insights: {
          summary: "There are not enough scored game sessions yet to identify learning patterns. " +
            "Your child can play a few games, then you can return for more specific suggestions.",
          strengths: [],
          focusAreas: [],
          actions: [
            "Choose one age-appropriate QuestKids game to play together.",
            "Ask your child to explain one thing they learned after playing.",
            "Try another short session later so progress can be compared over time.",
          ],
          disclaimer: "These suggestions are general encouragement, not a formal school assessment; " +
            "no scored game sessions were available to analyse.",
        },
      };
    }

    const apiKey = GEMINI_API_KEY.value();
    if (!apiKey) throw new HttpsError("internal", "AI insights are temporarily unavailable.");
    const model = new GoogleGenerativeAI(apiKey).getGenerativeModel({
      model: GEMINI_MODEL,
      generationConfig: { temperature: 0.25, maxOutputTokens: 650 },
    });
    const firstName = firstNameOf(child.name);
    const prompt = `You are an educational assistant helping a parent support a South African primary-school learner.
Use only the supplied recorded game data. Be supportive, specific, practical, and age-appropriate.
Never diagnose, label the learner, infer a disability, or make medical/psychological claims.
If data is insufficient, say so instead of inventing trends. Do not include surname or private account details.
Return valid JSON with exactly these keys:
summary (2 short sentences), strengths (array up to 3 strings), focusAreas (array up to 3 strings),
actions (array of exactly 3 practical parent-child learning actions), disclaimer (one sentence).
Learner first name: ${firstName}
Grade: ${String(child.grade ?? "primary school").slice(0, 30)}
Recorded games analysed: ${sessions.length}
Overall average score: ${averageScore === null ? "No scored sessions available" : averageScore + "%"}
Subject results: ${JSON.stringify(subjects)}
Recent session scores: ${JSON.stringify(recentActivity)}
Make clear that scores describe recorded game sessions only and are not a formal school assessment.`;

    try {
      const result = await model.generateContent(prompt);
      const raw = result.response.text().trim();
      const insights = parseJson(raw);
      return {
        childUid,
        generatedAt: new Date().toISOString(),
        sessionsAnalysed: sessions.length,
        averageScore,
        subjects,
        insights,
      };
    } catch (error) {
      console.error("Parent learning insight generation failed", error);
      throw new HttpsError("unavailable", "AI insights could not be generated right now. Please try again later.");
    }
  }
);
