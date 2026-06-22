import { onCall, HttpsError } from "firebase-functions/v2/https";
import { GoogleGenerativeAI, Content } from "@google/generative-ai";

const SYSTEM_PROMPT = `You are QuestBot, a friendly and encouraging AI tutor
for South African primary school children (Grades 1-7).
Your role is to:
- Explain concepts in simple, age-appropriate language
- Use fun examples, emojis and analogies children relate to
- Encourage learners when they struggle
- Reference South African context (rand, braai, provinces etc)
- Cover: Math, Science, English, Social Sciences
- Keep responses concise (max 3-4 short paragraphs)
- Never give direct quiz answers, guide them to think
- Celebrate correct answers enthusiastically
CRITICAL RULES:
1. You MUST ONLY answer questions relevant to a primary school child (Grade 1 to 7 level).
2. If a question is outside this educational scope, politely decline.
Always respond in a warm, child-friendly tone.`;

function getModel() {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) throw new HttpsError("internal", "Gemini API key not configured");
  const genAI = new GoogleGenerativeAI(apiKey);
  return genAI.getGenerativeModel({
    model: "gemini-1.5-flash",
    generationConfig: { temperature: 0.7, topK: 40, topP: 0.95, maxOutputTokens: 1024 },
    systemInstruction: { role: "system", parts: [{ text: SYSTEM_PROMPT }] },
  });
}

export const questbotChat = onCall(async (request) => {
  const { message, history = [] } = request.data as {
    message: string;
    history?: {role: string; text: string}[];
  };
  if (!message?.trim()) throw new HttpsError("invalid-argument", "message is required");

  const model = getModel();
  const chatHistory: Content[] = history.map((h) => ({
    role: h.role === "user" ? "user" : "model",
    parts: [{ text: h.text }],
  }));
  const chat = model.startChat({ history: chatHistory });
  const result = await chat.sendMessage(message);
  return { text: result.response.text() ?? "I did not understand that. Could you rephrase?" };
});

export const analyzeImage = onCall(async (request) => {
  const { imageBase64, prompt } = request.data as {imageBase64: string; prompt: string};
  if (!imageBase64 || !prompt) throw new HttpsError("invalid-argument", "imageBase64 and prompt are required");

  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) throw new HttpsError("internal", "Gemini API key not configured");
  const genAI = new GoogleGenerativeAI(apiKey);
  const model = genAI.getGenerativeModel({ model: "gemini-1.5-flash" });
  const result = await model.generateContent([
    prompt,
    { inlineData: { mimeType: "image/jpeg", data: imageBase64 } },
  ]);
  return { text: result.response.text() ?? "I could not analyse the image. Please try again." };
});

export const getRecommendation = onCall(async (request) => {
  const { name, grade, subjectScores, streakDays, totalPoints } = request.data as {
    name: string; grade: string;
    subjectScores: Record<string, number>;
    streakDays: number; totalPoints: number;
  };
  const weak = Object.entries(subjectScores).filter(([, v]) => v < 60).map(([k]) => k);
  const strong = Object.entries(subjectScores).filter(([, v]) => v >= 80).map(([k]) => k);
  const prompt = `Give a short personalised learning recommendation for:
- Name: ${name}, Grade: ${grade}, Streak: ${streakDays} days, Points: ${totalPoints}
- Strong: ${strong.join(", ") || "none yet"}
- Needs improvement: ${weak.join(", ") || "none"}
Keep it encouraging, 2-3 sentences, use their name, end with a tip. Use 1-2 emojis.`;

  const model = getModel();
  const result = await model.generateContent(prompt);
  return { text: result.response.text() ?? `Keep up the great work, ${name}! 🌟` };
});

export const explainAnswer = onCall(async (request) => {
  const { question, correctAnswer, subject, grade } = request.data as {
    question: string; correctAnswer: string; subject: string; grade: string;
  };
  const prompt = `A ${grade} learner answered this ${subject} question wrong:
Question: ${question}
Correct answer: ${correctAnswer}
Explain WHY this is correct in a simple, fun way a child understands. Use an analogy. 2-3 sentences. 1 emoji.`;

  const model = getModel();
  const result = await model.generateContent(prompt);
  return { text: result.response.text() ?? `The correct answer is ${correctAnswer}. Keep practising! 💪` };
});

export const generateHint = onCall(async (request) => {
  const { question, subject } = request.data as {question: string; subject: string};
  const prompt = `A learner is stuck on this ${subject} question: "${question}"
Give ONE helpful hint WITHOUT giving the answer away. 1-2 sentences. Be encouraging. 1 emoji.`;

  const model = getModel();
  const result = await model.generateContent(prompt);
  return { text: result.response.text() ?? "Think carefully about what you have learned! 💡" };
});
