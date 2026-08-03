/**
 * Shared, non-secret Cloud Functions config. Values here are plain env
 * vars (Firebase Functions v2 auto-loads a `.env`/`.env.<project-id>`
 * file placed in functions/ at deploy time — see .env.example) — unlike
 * secrets.ts, nothing here needs Secret Manager.
 */

// gemini-2.5-flash is still stable for existing projects, but as of
// 2026-08 Google restricts it from *new* API keys/projects (confirmed
// via a live 404 "no longer available to new users" from the API
// itself after rotating to a new key) -- gemini-3.5-flash-lite is the
// current cheapest/fastest stable flash-tier model available to new
// keys. Overridable via env for fast rollback if Google ships another
// breaking model change. Every Gemini call in this codebase must use
// this constant, not a hardcoded model string, so a rollback only
// requires one env var change.
export const GEMINI_MODEL = process.env.GEMINI_MODEL || "gemini-3.5-flash-lite";

// Toggle at deploy time once App Check is verified end-to-end on all
// platforms (Android Play Integrity + Web reCAPTCHA v3). See CLAUDE.md §6.2.
export const ENFORCE_APP_CHECK = process.env.ENFORCE_APP_CHECK === "true";

// Not secret (it's the public "From" address), unlike MAIL_PASSWORD in
// secrets.ts.
export const MAIL_SENDER = process.env.MAIL_SENDER || "questkids.game@gmail.com";
