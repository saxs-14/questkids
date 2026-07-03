import { defineSecret } from "firebase-functions/params";

/**
 * Firebase Functions v2 secret parameters, backed by Secret Manager.
 * `process.env.X` is NOT populated from Secret Manager automatically —
 * each function that needs one of these must both list it in its
 * `secrets: [...]` option AND read it via `.value()` at call time (not
 * at module load time, since the value isn't available until then).
 *
 * Set with:
 *   firebase functions:secrets:set GEMINI_API_KEY
 *   firebase functions:secrets:set MAIL_PASSWORD
 */
export const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");
export const MAIL_PASSWORD = defineSecret("MAIL_PASSWORD");
