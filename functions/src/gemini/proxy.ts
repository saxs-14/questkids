import { onCall, HttpsError, CallableRequest } from "firebase-functions/v2/https";
import {
  GoogleGenerativeAI,
  Content,
  HarmCategory,
  HarmBlockThreshold,
} from "@google/generative-ai";
import * as admin from "firebase-admin";

// Toggle at deploy time once App Check is verified end-to-end on all
// platforms (Android Play Integrity + Web reCAPTCHA v3). See CLAUDE.md §6.2.
const ENFORCE_APP_CHECK = process.env.ENFORCE_APP_CHECK === "true";

// gemini-1.5-flash is deprecated / retired — gemini-2.5-flash is the current
// GA Flash model. Overridable via env for fast rollback if Google ships a
// breaking model change.
const GEMINI_MODEL = process.env.GEMINI_MODEL || "gemini-2.5-flash";

const DAILY_AI_QUOTA = 50;
const MAX_MESSAGE_CHARS = 1000;
const MAX_HISTORY_TURNS = 20;
const MAX_IMAGE_BYTES = 4 * 1024 * 1024; // 4MB, base64 payload size

const SAFETY_SETTINGS = [
  { category: HarmCategory.HARM_CATEGORY_HARASSMENT, threshold: HarmBlockThreshold.BLOCK_LOW_AND_ABOVE },
  { category: HarmCategory.HARM_CATEGORY_HATE_SPEECH, threshold: HarmBlockThreshold.BLOCK_LOW_AND_ABOVE },
  { category: HarmCategory.HARM_CATEGORY_SEXUALLY_EXPLICIT, threshold: HarmBlockThreshold.BLOCK_LOW_AND_ABOVE },
  { category: HarmCategory.HARM_CATEGORY_DANGEROUS_CONTENT, threshold: HarmBlockThreshold.BLOCK_LOW_AND_ABOVE },
];

const SYSTEM_PROMPT = `You are Questy, a friendly and encouraging AI tutor
for South African primary school children (Grades 1-7).
Your role is to:
- Explain concepts in simple, age-appropriate language
- Use fun examples, emojis and analogies children relate to
- Encourage learners when they struggle
- Reference South African context (rand coins, braai, provinces, Ubuntu etc)
- Cover: Mathematics, Natural Sciences, English, Social Sciences, Life Skills, Technology, EMS
- Keep responses concise (max 3-4 short paragraphs)
- Never give direct quiz answers, guide them to think
- Celebrate correct answers enthusiastically
CRITICAL RULES:
1. You MUST ONLY answer questions relevant to a primary school child (Grade 1 to 7 level).
2. If a question is outside this educational scope, politely decline.
3. Your name is Questy — never call yourself QuestBot or anything else.
4. If a child mentions self-harm, abuse, or feeling unsafe, gently and warmly
   encourage them to talk to a trusted adult (parent, teacher, or caregiver)
   right away — never attempt to counsel them yourself.
5. Never ask a child for personal information (full name, address, phone
   number, school name, or any identifying details).
Always respond in a warm, child-friendly tone.`;

function requireAuth(request: CallableRequest): string {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "You must be signed in to use Questy.");
  }
  return request.auth.uid;
}

function clampString(value: unknown, maxLen: number, field: string): string {
  if (typeof value !== "string" || !value.trim()) {
    throw new HttpsError("invalid-argument", `${field} is required`);
  }
  return value.slice(0, maxLen);
}

function sanitizeHistory(history: unknown): Content[] {
  if (!Array.isArray(history)) return [];
  return history
    .filter((h): h is { role: string; text: string } => h && typeof h.text === "string")
    .filter((h) => h.role === "user" || h.role === "model")
    .slice(-MAX_HISTORY_TURNS)
    .map((h) => ({
      role: h.role,
      parts: [{ text: String(h.text).slice(0, MAX_MESSAGE_CHARS) }],
    }));
}

/**
 * Enforces a per-uid daily AI call quota using a transactional counter at
 * usage_ai/{uid}. Counter resets when the stored date no longer matches
 * today (Africa/Johannesburg-independent — we just use UTC calendar day,
 * which is fine for a soft daily cap).
 */
async function enforceQuota(uid: string): Promise<void> {
  const today = new Date().toISOString().slice(0, 10);
  const ref = admin.firestore().collection("usage_ai").doc(uid);

  await admin.firestore().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const data = snap.data();
    const count = data?.date === today ? (data.count as number) : 0;

    if (count >= DAILY_AI_QUOTA) {
      throw new HttpsError(
        "resource-exhausted",
        "You've reached today's chat limit with Questy. Come back tomorrow!"
      );
    }

    tx.set(ref, { date: today, count: count + 1 }, { merge: true });
  });
}

function getModel(withSystemPrompt = true) {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) throw new HttpsError("internal", "Gemini API key not configured");
  const genAI = new GoogleGenerativeAI(apiKey);
  return genAI.getGenerativeModel({
    model: GEMINI_MODEL,
    generationConfig: { temperature: 0.7, topK: 40, topP: 0.95, maxOutputTokens: 1024 },
    safetySettings: SAFETY_SETTINGS,
    ...(withSystemPrompt ? { systemInstruction: { role: "system", parts: [{ text: SYSTEM_PROMPT }] } } : {}),
  });
}

const CALLABLE_OPTS = { enforceAppCheck: ENFORCE_APP_CHECK };

export const questyChat = onCall(CALLABLE_OPTS, async (request) => {
  const uid = requireAuth(request);
  await enforceQuota(uid);

  const { message, history } = request.data as {
    message: string;
    history?: { role: string; text: string }[];
  };
  const safeMessage = clampString(message, MAX_MESSAGE_CHARS, "message");
  const chatHistory = sanitizeHistory(history);

  const model = getModel();
  const chat = model.startChat({ history: chatHistory });
  const result = await chat.sendMessage(safeMessage);
  return { text: result.response.text() ?? "I did not understand that. Could you rephrase?" };
});

export const analyzeImage = onCall(CALLABLE_OPTS, async (request) => {
  const uid = requireAuth(request);
  await enforceQuota(uid);

  const { imageBase64, prompt } = request.data as { imageBase64: string; prompt: string };
  const safePrompt = clampString(prompt, MAX_MESSAGE_CHARS, "prompt");
  if (typeof imageBase64 !== "string" || !imageBase64) {
    throw new HttpsError("invalid-argument", "imageBase64 is required");
  }
  if (imageBase64.length > MAX_IMAGE_BYTES) {
    throw new HttpsError("invalid-argument", "image is too large (max 4MB)");
  }

  const model = getModel(false);
  const result = await model.generateContent([
    safePrompt,
    { inlineData: { mimeType: "image/jpeg", data: imageBase64 } },
  ]);
  return { text: result.response.text() ?? "I could not analyse the image. Please try again." };
});

export const getRecommendation = onCall(CALLABLE_OPTS, async (request) => {
  const uid = requireAuth(request);
  await enforceQuota(uid);

  const { name, grade, subjectScores, streakDays, totalPoints } = request.data as {
    name: string; grade: string;
    subjectScores: Record<string, number>;
    streakDays: number; totalPoints: number;
  };
  const safeName = clampString(name, 100, "name");
  const weak = Object.entries(subjectScores ?? {}).filter(([, v]) => v < 60).map(([k]) => k);
  const strong = Object.entries(subjectScores ?? {}).filter(([, v]) => v >= 80).map(([k]) => k);
  const prompt = `Give a short personalised learning recommendation for:
- Name: ${safeName}, Grade: ${grade}, Streak: ${streakDays} days, Points: ${totalPoints}
- Strong: ${strong.join(", ") || "none yet"}
- Needs improvement: ${weak.join(", ") || "none"}
Keep it encouraging, 2-3 sentences, use their name, end with a tip. Use 1-2 emojis.`;

  const model = getModel(false);
  const result = await model.generateContent(prompt);
  return { text: result.response.text() ?? `Keep up the great work, ${safeName}! 🌟` };
});

export const explainAnswer = onCall(CALLABLE_OPTS, async (request) => {
  const uid = requireAuth(request);
  await enforceQuota(uid);

  const { question, correctAnswer, subject, grade } = request.data as {
    question: string; correctAnswer: string; subject: string; grade: string;
  };
  const safeQuestion = clampString(question, MAX_MESSAGE_CHARS, "question");
  const safeAnswer = clampString(correctAnswer, 200, "correctAnswer");
  const prompt = `A ${grade} learner answered this ${subject} question wrong:
Question: ${safeQuestion}
Correct answer: ${safeAnswer}
Explain WHY this is correct in a simple, fun way a child understands. Use an analogy. 2-3 sentences. 1 emoji.`;

  const model = getModel(false);
  const result = await model.generateContent(prompt);
  return { text: result.response.text() ?? `The correct answer is ${safeAnswer}. Keep practising! 💪` };
});

export const generateHint = onCall(CALLABLE_OPTS, async (request) => {
  const uid = requireAuth(request);
  await enforceQuota(uid);

  const { question, subject } = request.data as { question: string; subject: string };
  const safeQuestion = clampString(question, MAX_MESSAGE_CHARS, "question");
  const prompt = `A learner is stuck on this ${subject} question: "${safeQuestion}"
Give ONE helpful hint WITHOUT giving the answer away. 1-2 sentences. Be encouraging. 1 emoji.`;

  const model = getModel(false);
  const result = await model.generateContent(prompt);
  return { text: result.response.text() ?? "Think carefully about what you have learned! 💡" };
});
