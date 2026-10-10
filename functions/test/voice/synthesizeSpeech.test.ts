import "../setup/firebaseAdmin";

const mockSynthesizeSpeech = jest.fn();

// There is no Text-to-Speech emulator -- @google-cloud/text-to-speech is
// mocked so this suite can verify the quota/validation logic around it
// without making a real paid API call.
jest.mock("@google-cloud/text-to-speech", () => ({
  TextToSpeechClient: jest.fn().mockImplementation(() => ({
    synthesizeSpeech: mockSynthesizeSpeech,
  })),
}));

import { getFirestore } from "firebase-admin/firestore";
import { clearFirestoreEmulatorData } from "../setup/firestoreEmulator";
import { synthesizeSpeech } from "../../src/voice/synthesizeSpeech";

function requestAs(data: Record<string, unknown>, auth?: { uid: string }) {
  return {
    data,
    auth: auth ? { uid: auth.uid, token: {} as never, rawToken: "test-token" } : undefined,
    rawRequest: {} as never,
    acceptsStreaming: false,
  } as never;
}

describe("synthesizeSpeech", () => {
  beforeEach(async () => {
    await clearFirestoreEmulatorData();
    mockSynthesizeSpeech.mockReset();
    mockSynthesizeSpeech.mockResolvedValue([{ audioContent: Buffer.from("fake-mp3-bytes") }]);
  });

  it("rejects an unauthenticated caller", async () => {
    await expect(
      synthesizeSpeech.run(requestAs({ text: "Hello" }))
    ).rejects.toMatchObject({ code: "unauthenticated" });
  });

  it("rejects empty text", async () => {
    await expect(
      synthesizeSpeech.run(requestAs({ text: "" }, { uid: "child-1" }))
    ).rejects.toMatchObject({ code: "invalid-argument" });
  });

  it("returns base64-encoded audio on success", async () => {
    const result = (await synthesizeSpeech.run(
      requestAs({ text: "Hello there" }, { uid: "child-1" })
    )) as { audioBase64: string };
    expect(result.audioBase64).toBe(Buffer.from("fake-mp3-bytes").toString("base64"));
  });

  it("truncates text longer than the 600-character limit before sending it", async () => {
    const longText = "a".repeat(1000);
    await synthesizeSpeech.run(requestAs({ text: longText }, { uid: "child-1" }));
    const call = mockSynthesizeSpeech.mock.calls[0][0] as { input: { text: string } };
    expect(call.input.text.length).toBe(600);
  });

  it("throws internal when the API returns no audio content", async () => {
    mockSynthesizeSpeech.mockResolvedValue([{ audioContent: undefined }]);
    await expect(
      synthesizeSpeech.run(requestAs({ text: "Hello" }, { uid: "child-1" }))
    ).rejects.toMatchObject({ code: "internal" });
  });

  it("rejects after the daily quota (200) is exceeded", async () => {
    await getFirestore().collection("usage_tts").doc("child-1").set({
      date: new Date().toISOString().slice(0, 10),
      count: 200,
    });
    await expect(
      synthesizeSpeech.run(requestAs({ text: "Hello" }, { uid: "child-1" }))
    ).rejects.toMatchObject({ code: "resource-exhausted" });
  });

  it("keeps the TTS quota separate from the chat AI quota (different collection)", async () => {
    await getFirestore().collection("usage_ai").doc("child-1").set({
      date: new Date().toISOString().slice(0, 10),
      count: 50, // chat quota maxed out
    });
    await expect(
      synthesizeSpeech.run(requestAs({ text: "Hello" }, { uid: "child-1" }))
    ).resolves.toBeDefined();
  });
});
