import "../setup/firebaseAdmin";

const mockGenerateContent = jest.fn();
const mockSendMessage = jest.fn();
const mockStartChat = jest.fn(() => ({ sendMessage: mockSendMessage }));
const mockGetGenerativeModel = jest.fn(() => ({
  generateContent: mockGenerateContent,
  startChat: mockStartChat,
}));

// There is no Gemini emulator -- @google/generative-ai is mocked so this
// suite can verify the real business logic around it (auth, the AI usage
// quota/cost-control counter, input validation, admin gating, and response
// fallback handling) without making a real paid API call.
jest.mock("@google/generative-ai", () => ({
  GoogleGenerativeAI: jest.fn().mockImplementation(() => ({
    getGenerativeModel: mockGetGenerativeModel,
  })),
  HarmCategory: {
    HARM_CATEGORY_HARASSMENT: "HARASSMENT",
    HARM_CATEGORY_HATE_SPEECH: "HATE_SPEECH",
    HARM_CATEGORY_SEXUALLY_EXPLICIT: "SEXUALLY_EXPLICIT",
    HARM_CATEGORY_DANGEROUS_CONTENT: "DANGEROUS_CONTENT",
  },
  HarmBlockThreshold: { BLOCK_LOW_AND_ABOVE: "BLOCK_LOW_AND_ABOVE" },
}));

// defineSecret(...).value() reads straight from process.env (see
// firebase-functions/params) -- a locally-invented test value, never real.
process.env.GEMINI_API_KEY = "test-gemini-key-not-real";

import { getFirestore } from "firebase-admin/firestore";
import { clearFirestoreEmulatorData } from "../setup/firestoreEmulator";
import {
  questyChat,
  analyzeImage,
  getRecommendation,
  explainAnswer,
  generateHint,
  generateGameDraft,
} from "../../src/gemini/proxy";

function requestAs(data: Record<string, unknown>, auth?: { uid: string; role?: string }) {
  return {
    data,
    auth: auth
      ? { uid: auth.uid, token: { role: auth.role } as never, rawToken: "test-token" }
      : undefined,
    rawRequest: {} as never,
    acceptsStreaming: false,
  } as never;
}

function mockModelReply(text: string) {
  mockSendMessage.mockResolvedValue({ response: { text: () => text } });
  mockGenerateContent.mockResolvedValue({ response: { text: () => text } });
}

describe("gemini/proxy", () => {
  beforeEach(async () => {
    await clearFirestoreEmulatorData();
    mockGenerateContent.mockReset();
    mockSendMessage.mockReset();
    mockModelReply("A helpful AI reply.");
  });

  describe("auth gating (shared by every non-admin AI function)", () => {
    it("rejects an unauthenticated caller for questyChat", async () => {
      await expect(
        questyChat.run(requestAs({ message: "hi" }))
      ).rejects.toMatchObject({ code: "unauthenticated" });
    });

    it("rejects an unauthenticated caller for analyzeImage", async () => {
      await expect(
        analyzeImage.run(requestAs({ prompt: "describe", imageBase64: "abc" }))
      ).rejects.toMatchObject({ code: "unauthenticated" });
    });
  });

  describe("input validation", () => {
    it("rejects an empty chat message", async () => {
      await expect(
        questyChat.run(requestAs({ message: "" }, { uid: "child-1" }))
      ).rejects.toMatchObject({ code: "invalid-argument" });
    });

    it("rejects analyzeImage with no image payload", async () => {
      await expect(
        analyzeImage.run(requestAs({ prompt: "describe this" }, { uid: "child-1" }))
      ).rejects.toMatchObject({ code: "invalid-argument" });
    });

    it("rejects analyzeImage with an oversized image payload", async () => {
      const huge = "a".repeat(5 * 1024 * 1024);
      await expect(
        analyzeImage.run(
          requestAs({ prompt: "describe this", imageBase64: huge }, { uid: "child-1" })
        )
      ).rejects.toMatchObject({ code: "invalid-argument" });
    });

    it("rejects explainAnswer with a missing question", async () => {
      await expect(
        explainAnswer.run(
          requestAs(
            { question: "", correctAnswer: "42", subject: "Math", grade: "Grade 4" },
            { uid: "child-1" }
          )
        )
      ).rejects.toMatchObject({ code: "invalid-argument" });
    });
  });

  describe("questyChat", () => {
    it("returns the model's reply and includes the caller's first name in the system prompt", async () => {
      await getFirestore().collection("users").doc("child-1").set({ name: "Thandeka Mokoena" });
      mockModelReply("Hi there!");

      const result = (await questyChat.run(
        requestAs({ message: "Hello QuestBot" }, { uid: "child-1" })
      )) as { text: string };

      expect(result.text).toBe("Hi there!");
      expect(mockGetGenerativeModel).toHaveBeenCalled();
      const calls = mockGetGenerativeModel.mock.calls as unknown as {
        systemInstruction: { parts: { text: string }[] };
      }[][];
      const config = calls[calls.length - 1][0];
      expect(config.systemInstruction.parts[0].text).toContain("Thandeka");
      expect(config.systemInstruction.parts[0].text).not.toContain("Mokoena");
    });

    it("falls back to a default message when the model returns no text (?? guards null/undefined, not '')", async () => {
      mockSendMessage.mockResolvedValue({ response: { text: () => undefined } });
      const result = (await questyChat.run(
        requestAs({ message: "Hello" }, { uid: "child-1" })
      )) as { text: string };
      expect(result.text).toBe("I did not understand that. Could you rephrase?");
    });
  });

  describe("generateGameDraft (admin-only, no quota)", () => {
    it("rejects a non-admin caller", async () => {
      await expect(
        generateGameDraft.run(
          requestAs({ document: "a game design doc" }, { uid: "teacher-1", role: "teacher" })
        )
      ).rejects.toMatchObject({ code: "permission-denied" });
    });

    it("parses a fenced JSON response into the draft object", async () => {
      mockGenerateContent.mockResolvedValue({
        response: { text: () => '```json\n{"title":"Fraction Quest"}\n```' },
      });
      const result = (await generateGameDraft.run(
        requestAs({ document: "a game design doc" }, { uid: "admin-1", role: "admin" })
      )) as { draft: { title?: string } };
      expect(result.draft).toEqual({ title: "Fraction Quest" });
    });

    it("falls back to the raw text when the model doesn't return valid JSON", async () => {
      mockGenerateContent.mockResolvedValue({ response: { text: () => "not json at all" } });
      const result = (await generateGameDraft.run(
        requestAs({ document: "a game design doc" }, { uid: "admin-1", role: "admin" })
      )) as { draft: { raw?: string } };
      expect(result.draft).toEqual({ raw: "not json at all" });
    });

    it("does not consume the shared AI usage quota (admin tooling, not a child-facing call)", async () => {
      await generateGameDraft.run(
        requestAs({ document: "doc" }, { uid: "admin-1", role: "admin" })
      );
      const usage = await getFirestore().collection("usage_ai").doc("admin-1").get();
      expect(usage.exists).toBe(false);
    });
  });

  describe("AI usage quota (shared usage_ai/{uid} counter, cost control)", () => {
    it("allows up to the daily limit (50) and rejects the 51st call", async () => {
      for (let i = 0; i < 50; i++) {
        await expect(
          questyChat.run(requestAs({ message: `message ${i}` }, { uid: "child-1" }))
        ).resolves.toBeDefined();
      }
      await expect(
        questyChat.run(requestAs({ message: "one too many" }, { uid: "child-1" }))
      ).rejects.toMatchObject({ code: "resource-exhausted" });

      const usage = await getFirestore().collection("usage_ai").doc("child-1").get();
      expect(usage.data()?.count).toBe(50);
    }, 30000);

    it("shares the same quota counter across different AI functions", async () => {
      for (let i = 0; i < 49; i++) {
        await questyChat.run(requestAs({ message: `message ${i}` }, { uid: "child-1" }));
      }
      // The 50th call via a *different* function should still be allowed...
      await expect(
        getRecommendation.run(
          requestAs(
            { name: "Thandi", grade: "Grade 4", subjectScores: {}, streakDays: 1, totalPoints: 10 },
            { uid: "child-1" }
          )
        )
      ).resolves.toBeDefined();
      // ...and the 51st, via yet another function, should now be rejected.
      await expect(
        generateHint.run(
          requestAs({ question: "2+2", subject: "Math" }, { uid: "child-1" })
        )
      ).rejects.toMatchObject({ code: "resource-exhausted" });
    }, 30000);

    it("keeps each uid's quota independent", async () => {
      for (let i = 0; i < 50; i++) {
        await questyChat.run(requestAs({ message: `message ${i}` }, { uid: "child-1" }));
      }
      await expect(
        questyChat.run(requestAs({ message: "hi" }, { uid: "child-2" }))
      ).resolves.toBeDefined();
    }, 30000);
  });
});
