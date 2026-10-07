import { onCall, HttpsError, CallableRequest } from "firebase-functions/v2/https";
import { getFirestore, Transaction } from "firebase-admin/firestore";
import textToSpeech from "@google-cloud/text-to-speech";
import { ENFORCE_APP_CHECK } from "../config";

const DAILY_TTS_QUOTA = 200;
const MAX_TEXT_CHARS = 600;

// Lazily constructed -- the client reads its credentials from the Cloud
// Functions runtime's default service account, same as firebase-admin.
let client: InstanceType<typeof textToSpeech.TextToSpeechClient> | undefined;
function getClient() {
  if (!client) client = new textToSpeech.TextToSpeechClient();
  return client;
}

function requireAuth(request: CallableRequest): string {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "You must be signed in.");
  }
  return request.auth.uid;
}

async function enforceTtsQuota(uid: string): Promise<void> {
  const today = new Date().toISOString().slice(0, 10);
  const ref = getFirestore().collection("usage_tts").doc(uid);

  await getFirestore().runTransaction(async (tx: Transaction) => {
    const snap = await tx.get(ref);
    const data = snap.data();
    const count = data?.date === today ? (data.count as number) : 0;

    if (count >= DAILY_TTS_QUOTA) {
      throw new HttpsError(
        "resource-exhausted",
        "You've reached today's voice limit with QuestBot."
      );
    }

    tx.set(ref, { date: today, count: count + 1 }, { merge: true });
  });
}

/**
 * Synthesizes speech for QuestBot's chat replies using a neural voice,
 * so it sounds like a person rather than the device's built-in TTS.
 * Returns base64-encoded MP3 audio; the client decodes and plays it,
 * falling back to flutter_tts if this call fails for any reason.
 */
export const synthesizeSpeech = onCall(
  { enforceAppCheck: ENFORCE_APP_CHECK },
  async (request) => {
    const uid = requireAuth(request);
    await enforceTtsQuota(uid);

    const { text } = request.data as { text: string };
    if (typeof text !== "string" || !text.trim()) {
      throw new HttpsError("invalid-argument", "text is required");
    }
    const safeText = text.trim().slice(0, MAX_TEXT_CHARS);

    const [response] = await getClient().synthesizeSpeech({
      input: { text: safeText },
      voice: {
        languageCode: "en-US",
        name: "en-US-Chirp3-HD-Charon",
      },
      audioConfig: {
        audioEncoding: "MP3",
      },
    });

    const audioContent = response.audioContent;
    if (!audioContent) {
      throw new HttpsError("internal", "Speech synthesis returned no audio");
    }

    return {
      audioBase64: Buffer.from(audioContent as Uint8Array).toString("base64"),
    };
  }
);
