/**
 * Shared Admin SDK bootstrap for Functions tests.
 *
 * Function modules under src/ call getFirestore()/getAuth() against the
 * *default* app, which is only initialized once, in src/index.ts, at
 * deploy time. Tests import individual function modules directly (not
 * index.ts), so this module takes over that responsibility -- side-effect
 * import it first in every test file, before importing the function
 * under test.
 *
 * Must only ever run against the Firestore/Auth emulators: this throws if
 * FIRESTORE_EMULATOR_HOST isn't set, so a misconfigured test run fails
 * loudly instead of quietly hitting production data.
 */
import { getApps, initializeApp } from "firebase-admin/app";

if (!process.env.FIRESTORE_EMULATOR_HOST) {
  throw new Error(
    "FIRESTORE_EMULATOR_HOST is not set. Run tests via `npm test`, which " +
    "wraps Jest in `firebase emulators:exec` -- never run this suite " +
    "directly against production Firestore."
  );
}

export const TEST_PROJECT_ID = "questkids-mobile";

if (getApps().length === 0) {
  initializeApp({ projectId: TEST_PROJECT_ID });
}
