import { onSchedule } from "firebase-functions/v2/scheduler";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { GoogleGenerativeAI } from "@google/generative-ai";
import { GEMINI_MODEL } from "../config";
import { GEMINI_API_KEY } from "../secrets";

const DAYS = 7;

function weekKey(date: Date): string {
  const d = new Date(date);
  d.setHours(0, 0, 0, 0);
  const day = d.getDay();
  const diff = day === 0 ? -6 : 1 - day;
  d.setDate(d.getDate() + diff);
  return d.toISOString().slice(0, 10);
}

export const generateWeeklyGameReports = onSchedule(
  { schedule: "every monday 06:00", timeZone: "Africa/Johannesburg" },
  async () => {
    const db = getFirestore();
    const now = new Date();
    const from = new Date(now.getTime() - DAYS * 24 * 60 * 60 * 1000);
    const sessions = await db.collection("game_sessions")
      .where("completedAt", ">=", from)
      .get();

    const byChild = new Map<string, Array<Record<string, unknown>>>();
    for (const doc of sessions.docs) {
      const data = doc.data();
      const uid = typeof data.uid === "string" ? data.uid : "";
      if (!uid) continue;
      const list = byChild.get(uid) ?? [];
      list.push(data);
      byChild.set(uid, list);
    }

    const apiKey = GEMINI_API_KEY.value();
    if (!apiKey) {
      console.error("GEMINI_API_KEY is not configured; weekly reports skipped.");
      return;
    }

    const model = new GoogleGenerativeAI(apiKey).getGenerativeModel({
      model: GEMINI_MODEL,
      generationConfig: { temperature: 0.45, maxOutputTokens: 700 },
    });

    for (const [childUid, childSessions] of byChild.entries()) {
      try {
        const childSnap = await db.collection("users").doc(childUid).get();
        if (!childSnap.exists) continue;
        const child = childSnap.data()!;
        if (child.role !== "learner") continue;

        const scores = childSessions.map((s) => Number(s.score ?? 0));
        let avgScore = 0;
        if (scores.length > 0) {
          avgScore = scores.reduce((a, b) => a + b, 0) / scores.length;
        }

        const subjects: Record<string, { games: number; total: number }> = {};
        for (const s of childSessions) {
          const subject = typeof s.subject === "string" ? s.subject : "General";
          const bucket = subjects[subject] ?? { games: 0, total: 0 };
          bucket.games += 1;
          bucket.total += Number(s.score ?? 0);
          subjects[subject] = bucket;
        }

        const subjectSummary = Object.entries(subjects)
          .map(([subject, value]) =>
            `${subject}: ${value.games} games, ${Math.round(value.total / value.games)}% average`)
          .join("\n");

        const prompt = `Create a short weekly learning report for a South African primary-school child.
Child first name: ${String(child.name ?? "Learner").split(/\\s+/)[0]}
Grade: ${child.grade ?? "Primary"}
Games completed this week: ${childSessions.length}
Overall average score: ${Math.round(avgScore)}%
Subject performance:
${subjectSummary || "No subject breakdown"}

Return JSON with exactly these keys:
summary (2-3 friendly sentences),
strengths (array of 2 short strings),
focusAreas (array of up to 2 short strings),
nextWeekPlan (array of 3 short actions),
encouragement (one warm sentence with one emoji).

Do not diagnose the child or make medical claims. Keep it educational and encouraging.`;

        const response = await model.generateContent(prompt);
        const raw = response.response.text().trim();
        let report: Record<string, unknown>;
        try {
          const cleaned = raw.replace("\`\`\`json", "").replace("\`\`\`", "").trim();
          report = JSON.parse(cleaned);
        } catch {
          report = {
            summary: raw.slice(0, 900),
            strengths: [],
            focusAreas: [],
            nextWeekPlan: [],
            encouragement: "Keep learning and keep having fun! 🌈",
          };
        }

        const key = weekKey(now);
        const reportRef = db.collection("weekly_reports").doc(`${childUid}_${key}`);
        const linkedParents = new Set<string>();
        if (typeof child.parentUid === "string") linkedParents.add(child.parentUid);
        if (Array.isArray(child.linkedParentUids)) {
          for (const uid of child.linkedParentUids) if (typeof uid === "string") linkedParents.add(uid);
        }

        await reportRef.set({
          childUid,
          childName: child.name ?? "Learner",
          grade: child.grade ?? "Primary",
          weekStart: from,
          weekKey: key,
          gamesCompleted: childSessions.length,
          averageScore: Math.round(avgScore * 10) / 10,
          subjectSummary: subjects,
          report,
          generatedBy: "gemini",
          generatedAt: FieldValue.serverTimestamp(),
        }, { merge: true });

        for (const parentUid of linkedParents) {
          await db.collection("notifications").doc().set({
            recipientUid: parentUid,
            title: "Weekly QuestKids report is ready",
            body: `The AI progress report for ${child.name ?? "your child"} is ready to view.`,
            type: "weekly_game_report",
            childUid,
            reportId: reportRef.id,
            isRead: false,
            createdAt: FieldValue.serverTimestamp(),
          });
        }
      } catch (error) {
        console.error(`Weekly report failed for child ${childUid}`, error);
      }
    }
  },
);
