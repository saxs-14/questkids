import { onSchedule } from "firebase-functions/v2/scheduler";
import * as admin from "firebase-admin";
import { GoogleGenerativeAI } from "@google/generative-ai";
import { MISSION_CATALOG } from "./catalog";

interface MissionEntry {
  id: string;
  gameId: string;
  title: string;
  subject: string;
  emoji: string;
  xpBonus: number;
  completed: boolean;
  source: "teacher" | "adaptive" | "curated";
}

function nextMidnightSAST(): Date {
  const sastOffset = 2 * 60 * 60 * 1000;
  const sastNow = new Date(Date.now() + sastOffset);
  return new Date(
    Date.UTC(
      sastNow.getUTCFullYear(),
      sastNow.getUTCMonth(),
      sastNow.getUTCDate() + 1,
      0, 0, 0, 0
    ) - sastOffset
  );
}

async function getAdaptiveMissions(
  uid: string,
  grade: string,
  dayIndex: number
): Promise<{gameId: string; subject: string; emoji: string; title: string}[]> {
  const db = admin.firestore();
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) return [];

  const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
  const progressSnap = await db.collection("progress")
    .where("childUid", "==", uid)
    .where("completedAt", ">=", admin.firestore.Timestamp.fromDate(thirtyDaysAgo))
    .get();

  if (progressSnap.size < 7) return [];

  const subjectScores: Record<string, number[]> = {};
  progressSnap.docs.forEach((d) => {
    const data = d.data();
    const subj = (data["subject"] as string) || "General";
    if (!subjectScores[subj]) subjectScores[subj] = [];
    subjectScores[subj].push((data["score"] as number) || 0);
  });

  const avgScores: Record<string, number> = {};
  for (const [subj, scores] of Object.entries(subjectScores)) {
    avgScores[subj] = scores.reduce((a, b) => a + b, 0) / scores.length;
  }

  const weakSubjects = Object.entries(avgScores)
    .filter(([, v]) => v < 65)
    .map(([k]) => k)
    .slice(0, 2);

  if (weakSubjects.length === 0) return [];

  const catalogSubset = MISSION_CATALOG[dayIndex].map((m) => m.gameId).join(", ");

  const genAI = new GoogleGenerativeAI(apiKey);
  const model = genAI.getGenerativeModel({ model: "gemini-1.5-flash" });

  const prompt = `A Grade ${grade} learner is weak in: ${weakSubjects.join(", ")}.
Available game IDs: ${catalogSubset}
Pick 1-2 game IDs that target their weak subjects. Respond ONLY with valid JSON:
{"missions":[{"gameId":"<id>","reason":"<one sentence>"}]}
If no games match the weak subjects, return {"missions":[]}`;

  try {
    const result = await model.generateContent(prompt);
    const text = result.response.text().trim();
    const jsonMatch = text.match(/\{[\s\S]*\}/);
    if (!jsonMatch) return [];
    const parsed = JSON.parse(jsonMatch[0]) as {missions: {gameId: string}[]};
    const validIds = new Set(MISSION_CATALOG[dayIndex].map((m) => m.gameId));
    return (parsed.missions || [])
      .filter((m) => validIds.has(m.gameId))
      .map((m) => {
        const catalog = MISSION_CATALOG[dayIndex].find((c) => c.gameId === m.gameId)!;
        return {
          gameId: m.gameId,
          subject: catalog.subject,
          emoji: catalog.emoji,
          title: catalog.title,
        };
      })
      .slice(0, 2);
  } catch {
    return [];
  }
}

export const generateDailyMissions = onSchedule(
  { schedule: "every day 00:00", timeZone: "Africa/Johannesburg", memory: "512MiB" },
  async () => {
    const db = admin.firestore();
    const expiresAt = admin.firestore.Timestamp.fromDate(nextMidnightSAST());
    const generatedAt = admin.firestore.Timestamp.now();
    const dayIndex = new Date().getDay();

    const learnersSnap = await db.collection("users")
      .where("role", "==", "learner")
      .get();

    const batchSize = 20;
    const learners = learnersSnap.docs;

    for (let i = 0; i < learners.length; i += batchSize) {
      const chunk = learners.slice(i, i + batchSize);
      await Promise.all(chunk.map(async (learnerDoc) => {
        const uid = learnerDoc.id;
        const grade = (learnerDoc.data()["grade"] as string) || "Grade 1";
        const gradeNum = parseInt(grade.replace(/\D/g, ""), 10) || 1;
        const missions: MissionEntry[] = [];

        // Tier 1: Teacher-assigned missions
        const assignedSnap = await db
          .collection("daily_missions").doc(uid)
          .collection("assigned").limit(3).get();
        assignedSnap.docs.forEach((d) => {
          if (missions.length < 3) {
            const data = d.data();
            missions.push({
              id: d.id,
              gameId: (data["gameId"] as string) || "",
              title: (data["title"] as string) || "Teacher Mission",
              subject: (data["subject"] as string) || "General",
              emoji: (data["emoji"] as string) || "📋",
              xpBonus: 20,
              completed: false,
              source: "teacher",
            });
          }
        });

        // Tier 2: Adaptive Gemini missions
        if (missions.length < 3) {
          const adaptive = await getAdaptiveMissions(uid, String(gradeNum), dayIndex);
          adaptive.forEach((m) => {
            if (missions.length < 3) {
              missions.push({
                id: `adaptive_${m.gameId}_${Date.now()}`,
                gameId: m.gameId,
                title: m.title,
                subject: m.subject,
                emoji: m.emoji,
                xpBonus: 15,
                completed: false,
                source: "adaptive",
              });
            }
          });
        }

        // Tier 3: Curated rotation to fill remaining slots
        const catalog = MISSION_CATALOG[dayIndex] ?? MISSION_CATALOG[1];
        catalog.forEach((m) => {
          if (missions.length < 3 &&
              !missions.some((existing) => existing.gameId === m.gameId)) {
            missions.push({
              id: `curated_${m.gameId}_${dayIndex}`,
              gameId: m.gameId,
              title: m.title,
              subject: m.subject,
              emoji: m.emoji,
              xpBonus: 10,
              completed: false,
              source: "curated",
            });
          }
        });

        await db.collection("daily_missions").doc(uid)
          .collection("today").doc("missions")
          .set({ missions, generatedAt, expiresAt }, { merge: false });
      }));
    }

    console.log(`Daily missions generated for ${learners.length} learners`);
  }
);
