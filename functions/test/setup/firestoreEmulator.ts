/**
 * Wipes every document in the local Firestore emulator via its REST admin
 * endpoint. Call between tests (not once per file) so each test starts
 * from an empty database -- these functions read whole-collection
 * aggregates, so leftover docs from a previous test silently change the
 * expected counts.
 */
export async function clearFirestoreEmulatorData(): Promise<void> {
  const host = process.env.FIRESTORE_EMULATOR_HOST;
  if (!host) {
    throw new Error("FIRESTORE_EMULATOR_HOST is not set; refusing to clear a database.");
  }
  const projectId = require("./firebaseAdmin").TEST_PROJECT_ID;
  const url = `http://${host}/emulator/v1/projects/${projectId}/databases/(default)/documents`;
  const response = await fetch(url, { method: "DELETE" });
  if (!response.ok) {
    throw new Error(`Failed to clear Firestore emulator data: ${response.status} ${response.statusText}`);
  }
}
