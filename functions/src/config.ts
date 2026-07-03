/**
 * Shared, non-secret Cloud Functions config. Values here are plain env
 * vars (Firebase Functions v2 auto-loads a `.env`/`.env.<project-id>`
 * file placed in functions/ at deploy time — see .env.example) — unlike
 * secrets.ts, nothing here needs Secret Manager.
 */

// gemini-1.5-flash is deprecated / retired — gemini-2.5-flash is the
// current GA Flash model. Overridable via env for fast rollback if
// Google ships a breaking model change. Every Gemini call in this
// codebase must use this constant, not a hardcoded model string, so a
// rollback only requires one env var change.
export const GEMINI_MODEL = process.env.GEMINI_MODEL || "gemini-2.5-flash";

// Toggle at deploy time once App Check is verified end-to-end on all
// platforms (Android Play Integrity + Web reCAPTCHA v3). See CLAUDE.md §6.2.
export const ENFORCE_APP_CHECK = process.env.ENFORCE_APP_CHECK === "true";

// Not secret (it's the public "From" address), unlike MAIL_PASSWORD in
// secrets.ts.
export const MAIL_SENDER = process.env.MAIL_SENDER || "questkids.dev@gmail.com";
