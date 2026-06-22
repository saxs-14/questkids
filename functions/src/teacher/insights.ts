import {onCall, HttpsError} from "firebase-functions/v2/https";
import {GoogleGenerativeAI} from "@google/generative-ai";

export const getTeacherInsight = onCall(async (request) => {
  const {subjectAvg, totalLearners, completionRate, weakTopics} = request.data as {
    subjectAvg: Record<string, number>;
    totalLearners: number;
    completionRate: number;
    weakTopics: string[];
  };

  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) throw new HttpsError("internal", "Gemini API key not configured");

  const genAI = new GoogleGenerativeAI(apiKey);
  const model = genAI.getGenerativeModel({model: "gemini-1.5-flash"});

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
    return {text: text || "Focus on the identified weak subjects this week with targeted activities."};
  } catch {
    return {
      text: "Consider scheduling small group sessions for subjects below 60%, and celebrate the strong performers to keep motivation high.",
    };
  }
});
