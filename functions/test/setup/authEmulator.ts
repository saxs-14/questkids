/**
 * Wipes every Auth user in the local Auth emulator via its REST admin
 * endpoint. Call between tests (not once per file) -- unlike a fresh
 * Firestore collection per test, the Auth emulator keeps users across
 * tests in the same `firebase emulators:exec` run, so a uid/email reused
 * by a later test collides with one a previous test already created.
 */
export async function clearAuthEmulatorUsers(): Promise<void> {
  const host = process.env.FIREBASE_AUTH_EMULATOR_HOST;
  if (!host) {
    throw new Error("FIREBASE_AUTH_EMULATOR_HOST is not set; refusing to clear Auth users.");
  }
  const projectId = require("./firebaseAdmin").TEST_PROJECT_ID;
  const url = `http://${host}/emulator/v1/projects/${projectId}/accounts`;
  const response = await fetch(url, { method: "DELETE" });
  if (!response.ok) {
    throw new Error(`Failed to clear Auth emulator users: ${response.status} ${response.statusText}`);
  }
}
